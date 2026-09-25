import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../data/filesystem/ios_deployment.dart';
import '../../../data/filesystem/project_file_repository.dart';
import '../../../services/llm/key_check.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service_provider.dart';
import '../../projects/providers/providers.dart';
import '../../tracker/models/tracker_enums.dart';
import '../../tracker/providers/tracker_providers.dart';
import '../data/command_runner.dart';
import '../data/completion_guard.dart';
import '../data/impl_agent.dart';
import '../data/impl_workspace.dart';
import '../models/run_session.dart';
import 'implementation_providers.dart';

/// Everything an implementation run needs: the target feature plus the project
/// context (spec/handoff) and the linked repo it edits.
class ImplBrief {
  ImplBrief({
    required this.projectPath,
    required this.projectName,
    required this.repoPath,
    required this.featureId,
    required this.featureTitle,
    this.featureDescription,
    this.targetVersion,
    this.lockedSpec,
    this.goalStatement,
    this.components = const [],
    this.checklist = const [],
  });

  final String projectPath;
  final String projectName;
  final String repoPath;
  final String featureId;
  final String featureTitle;
  final String? featureDescription;
  final String? targetVersion;
  final String? lockedSpec;
  final String? goalStatement;
  final List<String> components;
  final List<Map<String, dynamic>> checklist;
}

/// One implementation run per feature.
// KeepAlive (not autoDispose) so a build keeps running when the window is
// closed and the user navigates back to the board — re-opening re-attaches to
// the same live run instead of restarting it.
final implRunProvider =
    NotifierProvider.family<ImplRunNotifier, ImplRunState, String>(
  ImplRunNotifier.new,
);

class ImplRunNotifier extends FamilyNotifier<ImplRunState, String> {
  ImplBrief? _brief;
  final _runner = CommandRunner();

  // Streaming-display state for the planning phase.
  String _partial = ''; // current unfinished streamed line
  ConsoleLineKind _partialKind = ConsoleLineKind.thinking;
  bool _streamStarted = false;
  Timer? _waitTimer;

  /// The last run's failure report, fed back to the agent by [fix].
  String? _fixContext;

  // Incremented on every start/stop/reset so a stale in-flight stream (which
  // we can't hard-cancel) can't mutate the state of a newer run.
  int _gen = 0;

  @override
  ImplRunState build(String featureId) {
    ref.onDispose(() {
      _runner.cancel();
      _waitTimer?.cancel();
    });
    final runId = '${featureId.substring(0, featureId.length.clamp(0, 8))}'
        '-${DateTime.now().millisecondsSinceEpoch}';
    return ImplRunState.initial(runId);
  }

  /// Hard cap on retained console lines so a flood of command output can never
  /// grow memory unbounded (and take the app down).
  static const _maxConsole = 5000;
  List<ConsoleLine> _cap(List<ConsoleLine> lines) => lines.length > _maxConsole
      ? lines.sublist(lines.length - _maxConsole)
      : lines;

  void _log(ConsoleLineKind kind, String text) {
    state = state.copyWith(
      console: _cap([...state.console, ConsoleLine(kind, text, DateTime.now())]),
    );
    _streamStarted = false; // a discrete line closes any open streamed line
  }

  /// Sets the run phase AND mirrors it to the app-level registry so the tracker
  /// board's status dot updates live. Stamps [endedAt] on terminal phases so
  /// the elapsed timer freezes.
  void _phase(RunPhase p) {
    state = state.copyWith(
      phase: p,
      endedAt: p.isTerminal ? DateTime.now() : null,
    );
    ref.read(implActiveRunsProvider.notifier).set(arg, p);
  }

  /// Appends streamed text to the console like a terminal: text accumulates on
  /// the current line until a newline closes it and opens the next. This keeps
  /// the full stream as real, scrollable lines (no truncation). [kind] lets us
  /// distinguish the model's internal reasoning from its external presentation;
  /// a kind change starts a fresh line.
  void _appendStream(String text, ConsoleLineKind kind) {
    if (text.isEmpty) return;
    final continuing = _streamStarted && kind == _partialKind;
    final combined = (continuing ? _partial : '') + text;
    final segs = combined.split('\n');
    final console = [...state.console];
    if (continuing && console.isNotEmpty) {
      console.removeLast(); // drop the old partial line; we re-add it updated
    }
    for (var i = 0; i < segs.length - 1; i++) {
      console.add(ConsoleLine(kind, segs[i], DateTime.now()));
    }
    console.add(ConsoleLine(kind, segs.last, DateTime.now()));
    _partial = segs.last;
    _partialKind = kind;
    _streamStarted = true;
    state = state.copyWith(console: _cap(console));
  }

  /// Handles one streamed delta. Reasoning models stream their chain-of-thought
  /// as [thinking] deltas — the model's INTERNAL thoughts (dim, collapsible),
  /// shown live so you watch it reason. Content deltas are the JSON answer,
  /// which the agent parses; they are not displayed raw (the green "Summary"
  /// and the plan cards convey the outcome).
  void _onDelta(String text, bool thinking, int gen) {
    if (gen != _gen) return; // stale stream from a stopped/reset run
    _waitTimer?.cancel();
    if (thinking) _appendStream(text, ConsoleLineKind.thinking);
  }

  /// Kicks off the run: streams the agent's plan, then waits for approval. The
  /// window no longer auto-starts — the user triggers this from the compose
  /// screen (a Build action or the prompt box), optionally with an [instruction]
  /// describing what to build.
  Future<void> start(ImplBrief brief, {String? instruction}) async {
    if (state.phase != RunPhase.idle) return;
    _brief = brief;
    state = state.copyWith(startedAt: DateTime.now(), error: null);
    _log(ConsoleLineKind.narration, 'Building: "${brief.featureTitle}"');
    _log(ConsoleLineKind.info, 'Repo: ${brief.repoPath}');
    final resolved = ref.read(llmServiceProvider).resolve(LlmRole.executor);
    if (resolved != null) {
      _log(ConsoleLineKind.info,
          'Model: ${resolved.provider.name} · ${resolved.modelId}');
    }
    await _plan(feedback: instruction);
  }

  /// A quick preset action (Run checks, Fix errors, Suggest improvements, …) or
  /// the prompt box. Each is a standalone entry point: when idle it starts a
  /// fresh run with [instruction] (no need to press "Build this feature" first);
  /// otherwise it steers the current plan. [brief] is required so the first
  /// action can start a run even before any build has set the notifier's brief.
  Future<void> action(ImplBrief brief, String instruction) async {
    if (state.phase.isBusy) return;
    _brief ??= brief;
    if (state.phase == RunPhase.idle) {
      await start(brief, instruction: instruction);
      return;
    }
    await steer(instruction);
  }

  /// Deterministic "Commit & push" — the action done most across sessions.
  /// Stages + commits the linked repo with [message] and pushes to origin.
  Future<void> commitAndPush(String repoPath, String message) async {
    final path = repoPath.isNotEmpty ? repoPath : (_brief?.repoPath ?? '');
    if (path.isEmpty || state.phase.isBusy) return;
    _log(ConsoleLineKind.command, '\$ git add -A && git commit -m "$message" && git push');
    final committed = await ProjectFileRepository.gitCommitAll(path, message);
    if (!committed) {
      _log(ConsoleLineKind.info, 'Nothing to commit (or not a git repo).');
      return;
    }
    _log(ConsoleLineKind.success, '✓ committed: $message');
    final pushed = await ProjectFileRepository.gitPush(path);
    _log(pushed ? ConsoleLineKind.success : ConsoleLineKind.stderr,
        pushed ? '✓ pushed to origin' : '✗ push failed (no remote / auth?)');
  }

  /// The always-available "vibecode" input: steer the AI with a free-text
  /// instruction. Works whenever the agent is idle between actions — awaiting
  /// approval, or after a run finished/failed/was stopped. A fresh planning
  /// round folds the instruction (and the current plan, if any) into context.
  Future<void> steer(String message) async {
    final m = message.trim();
    if (m.isEmpty || _brief == null) return;
    if (state.phase.isBusy) return; // can't steer mid-work — Stop first
    _log(ConsoleLineKind.command, '▸ $m');
    await _plan(previousPlan: state.plan, feedback: m);
  }

  /// Shared planning body used by both [start] and [revise].
  Future<void> _plan({AgentPlan? previousPlan, String? feedback}) async {
    final brief = _brief;
    if (brief == null) return;
    final gen = ++_gen;
    _partial = '';
    _streamStarted = false;
    _partialKind = ConsoleLineKind.thinking;
    _phase(RunPhase.planning);

    // Load the project's ingested reference context — the SAME pool the
    // interview and spec stages already read — so the build starts with the
    // intake docs, not just code. Re-read each round so docs added mid-session
    // are picked up, and surface a line so the user can SEE context was loaded.
    final repo = ref.read(projectFileRepositoryProvider);
    String? ingestedContext;
    try {
      ingestedContext = await repo.readIngestedSummary(brief.projectPath);
    } catch (_) {}
    if (ingestedContext != null && ingestedContext.trim().isNotEmpty) {
      final words = ingestedContext.trim().split(RegExp(r'\s+')).length;
      _log(ConsoleLineKind.info, 'Loaded reference context (~$words words)');
    } else {
      _log(ConsoleLineKind.info,
          'No reference context yet — add docs on the project to ground builds.');
    }

    // Load prior-build memory — what already shipped on this project — so the
    // build accumulates context across features instead of starting cold.
    String? buildMemory;
    try {
      buildMemory = await repo.readBuildMemory(brief.projectPath);
    } catch (_) {}
    if (buildMemory != null && buildMemory.trim().isNotEmpty) {
      final n = RegExp(r'(?:^|\n)### ').allMatches(buildMemory).length;
      _log(ConsoleLineKind.info,
          'Loaded build memory ($n prior feature${n == 1 ? '' : 's'})');
    }

    // A manifest of the whole doc pool the scout may pull from on demand — used
    // for pools too large to sit fully in the always-on context above.
    var docManifest = const <DocPoolEntry>[];
    try {
      docManifest = await repo.gatherDocManifest(brief.projectPath);
    } catch (_) {}

    _log(ConsoleLineKind.info, 'Waiting for the model to respond…');

    // Reassure the user while we wait for the first streamed token — a large
    // cloud model can take a while to start, and a static console looks stuck.
    _waitTimer = Timer.periodic(const Duration(seconds: 8), (t) {
      if (_streamStarted || state.phase != RunPhase.planning) {
        t.cancel();
        return;
      }
      final secs = state.startedAt == null
          ? 0
          : DateTime.now().difference(state.startedAt!).inSeconds;
      _log(ConsoleLineKind.info, 'Still working… (${secs}s)');
    });

    try {
      final agent = ref.read(implAgentProvider);
      final plan = await agent.proposePlan(
        featureTitle: brief.featureTitle,
        featureDescription: brief.featureDescription,
        targetVersion: brief.targetVersion,
        repoPath: brief.repoPath,
        lockedSpec: brief.lockedSpec,
        goalStatement: brief.goalStatement,
        ingestedContext: ingestedContext,
        buildMemory: buildMemory,
        docManifest: docManifest,
        readDoc: (id) => repo.readDocEntry(brief.projectPath, id),
        components: brief.components,
        previousPlan: previousPlan,
        feedback: feedback,
        onDelta: (t, thinking) => _onDelta(t, thinking, gen),
        onStatus: (s) {
          if (gen == _gen) _log(ConsoleLineKind.narration, s);
        },
      );
      // Ignore a stream that finished after the user stopped or restarted.
      if (gen != _gen || state.phase == RunPhase.stopped) return;
      // Always surface a plain-English takeaway in green.
      if (plan.summary.isNotEmpty) {
        _log(ConsoleLineKind.presentation, 'Summary: ${plan.summary}');
      }
      _log(
        ConsoleLineKind.info,
        '${previousPlan == null ? 'Proposed' : 'Revised —'} '
        '${plan.edits.length} file change'
        '${plan.edits.length == 1 ? '' : 's'} and ${plan.commands.length} '
        'command${plan.commands.length == 1 ? '' : 's'}.',
      );
      // A fresh plan clears prior skip decisions and the fixable state.
      _fixContext = null;
      state = state.copyWith(
        plan: plan,
        skippedEdits: {},
        skippedCommands: {},
        canFix: false,
      );
      _phase(RunPhase.awaitingApproval);
    } catch (e) {
      if (gen != _gen || state.phase == RunPhase.stopped) return;
      // Surface the model's raw output so the user can see (and copy) exactly
      // what it returned — invaluable for diagnosing a bad-JSON failure.
      if (e is ImplAgentException && (e.raw?.trim().isNotEmpty ?? false)) {
        _log(ConsoleLineKind.info,
            '— the model returned this (select to copy) —');
        for (final line in _rawTail(e.raw!)) {
          _log(ConsoleLineKind.stderr, line);
        }
      }
      _log(ConsoleLineKind.error, 'Planning failed: ${friendlyLlmError(e)}');
      state = state.copyWith(error: friendlyLlmError(e));
      _phase(RunPhase.failed);
    } finally {
      if (gen == _gen) _waitTimer?.cancel();
    }
  }

  /// The tail of a raw model response, split into console lines (bounded).
  static List<String> _rawTail(String raw) {
    var s = raw.trim();
    const cap = 4000;
    if (s.length > cap) s = '…${s.substring(s.length - cap)}';
    final lines = s.split('\n');
    return lines.length > 80 ? lines.sublist(lines.length - 80) : lines;
  }

  /// Hand-edit: replace the proposed content of one edit with the user's own.
  void editProposedContent(int index, String newContent) {
    final plan = state.plan;
    if (plan == null || index < 0 || index >= plan.edits.length) return;
    final old = plan.edits[index];
    final edits = [...plan.edits];
    edits[index] = ProposedEdit(
      path: old.path,
      rationale: old.rationale.isEmpty ? 'Edited by you' : old.rationale,
      oldContent: old.oldContent,
      newContent: newContent,
    );
    state = state.copyWith(
      plan: AgentPlan(
        summary: plan.summary,
        rationale: plan.rationale,
        edits: edits,
        commands: plan.commands,
      ),
    );
  }

  void toggleEdit(int index) {
    if (state.phase != RunPhase.awaitingApproval) return;
    final skipped = {...state.skippedEdits};
    skipped.contains(index) ? skipped.remove(index) : skipped.add(index);
    state = state.copyWith(skippedEdits: skipped);
  }

  void toggleCommand(int index) {
    if (state.phase != RunPhase.awaitingApproval) return;
    final skipped = {...state.skippedCommands};
    skipped.contains(index) ? skipped.remove(index) : skipped.add(index);
    state = state.copyWith(skippedCommands: skipped);
  }

  /// Applies approved edits, runs approved commands (streamed), then verifies.
  Future<void> applyAndRun() async {
    final brief = _brief;
    final plan = state.plan;
    if (brief == null || plan == null) return;
    if (state.phase != RunPhase.awaitingApproval) return;
    try {
      await _applyAndRun(brief, plan);
    } catch (e) {
      _log(ConsoleLineKind.error, 'Run failed: ${friendlyLlmError(e)}');
      state = state.copyWith(error: friendlyLlmError(e));
      _phase(RunPhase.failed);
    }
  }

  Future<void> _applyAndRun(ImplBrief brief, AgentPlan plan) async {
    // --- Apply edits ---
    _phase(RunPhase.applying);
    // Clear any completion warning from a prior attempt in this run (the fix
    // loop re-enters here) so a stale flag never outlives the build it judged.
    state = state.copyWith(clearCompletionWarning: true);
    final applied = {...state.appliedEditPaths};
    for (var i = 0; i < plan.edits.length; i++) {
      if (state.skippedEdits.contains(i)) continue;
      final edit = plan.edits[i];
      try {
        await ImplWorkspace.applyEdit(
          repoPath: brief.repoPath,
          projectPath: brief.projectPath,
          runId: state.runId,
          edit: edit,
        );
        applied.add(edit.path);
        _log(ConsoleLineKind.success,
            '${edit.isNewFile ? 'Created' : 'Edited'} ${edit.path}');
      } catch (e) {
        _log(ConsoleLineKind.error, 'Failed to write ${edit.path}: $e');
      }
    }
    state = state.copyWith(appliedEditPaths: applied);

    // Accumulate a failure report so "Fix it" can feed it back to the agent.
    final failures = StringBuffer();

    // --- Auto-tidy: clean the cosmetic debris AI edits leave behind ---
    // Runs the analyzer's safe automated fixes (unused imports, `const`, etc.)
    // and the formatter, so every build lands clean instead of accumulating
    // unused-import warnings and unformatted code the user has to chase.
    if (applied.isNotEmpty) {
      await _tidy(brief);
    }

    // --- Analyze gate: catch edits that don't compile (BUG-IMPL-003 class) ---
    // A find/replace hunk can land a stray brace or drop a symbol. Right after
    // applying edits, run the project's analyzer so a broken edit is surfaced
    // (and routed to "Fix it") in THIS run instead of silently landing.
    if (applied.isNotEmpty) {
      await _analyzeGate(brief, failures);
    }

    // --- Run commands (streamed) ---
    _phase(RunPhase.running);
    for (var i = 0; i < plan.commands.length; i++) {
      if (state.skippedCommands.contains(i)) continue;
      final cmd = plan.commands[i];
      _log(ConsoleLineKind.command, '\$ ${cmd.raw}');
      final captured = <String>[];
      final result = await _runner.run(
        cmd.raw,
        workingDirectory: brief.repoPath,
        onOutput: (o) {
          captured.add(o.text);
          _log(
            o.isError ? ConsoleLineKind.stderr : ConsoleLineKind.stdout,
            o.text,
          );
        },
      );
      if (result.ok) {
        _log(ConsoleLineKind.success, '✓ command succeeded');
      } else {
        _log(ConsoleLineKind.error,
            '✗ command exited with code ${result.exitCode}');
        failures
          ..writeln('Command failed (exit ${result.exitCode}): ${cmd.raw}')
          ..writeln(_tail(captured, 40))
          ..writeln();
      }
    }

    // --- Verify against the Handoff checklist ---
    if (brief.checklist.isNotEmpty) {
      _phase(RunPhase.verifying);
      _log(ConsoleLineKind.narration, 'Verifying against the Handoff checklist…');
      final results = await ImplWorkspace.verify(
        repoPath: brief.repoPath,
        checklist: brief.checklist,
      );
      for (final r in results) {
        _log(r.passed ? ConsoleLineKind.success : ConsoleLineKind.stderr,
            '${r.passed ? '✓' : '•'} ${r.requirement} — ${r.note}');
        if (!r.passed) {
          failures.writeln('Check not passing: ${r.requirement} — ${r.note}');
        }
      }
      state = state.copyWith(verifications: results);
    }

    // --- Completion guard: a deterministic honesty check on the diff ---
    // The NO FAKE COMPLETIONS prompt tells the agent not to fake a build; this
    // catches it when the model does anyway. If the applied diff is only
    // docs/config or only stubs, flag it so the run isn't passed off as done.
    final appliedEdits = <ProposedEdit>[
      for (var i = 0; i < plan.edits.length; i++)
        if (!state.skippedEdits.contains(i) &&
            state.appliedEditPaths.contains(plan.edits[i].path))
          plan.edits[i],
    ];
    final verdict = CompletionGuard.inspect(appliedEdits);
    if (verdict.suspicious) {
      _log(ConsoleLineKind.error, '⚠ Completion check: ${verdict.reason}');
    }
    // Behavioral-substitution guard: flag a silent format/encoding swap (e.g.
    // JPEG→PNG) so it can't ship without the user confirming the change.
    final substitution = CompletionGuard.detectSubstitutions(appliedEdits);
    if (substitution != null) {
      _log(ConsoleLineKind.error, '⚠ Format change: $substitution');
    }
    final warnings = <String>[
      if (verdict.suspicious) verdict.reason,
      if (substitution != null) substitution,
    ];

    final report = failures.toString().trim();
    _fixContext = report.isEmpty ? null : report;
    _log(
        report.isEmpty ? ConsoleLineKind.narration : ConsoleLineKind.error,
        report.isEmpty
            ? 'Run complete.'
            : 'Run finished with issues — you can ask the AI to fix them.');
    state = state.copyWith(
      canFix: report.isNotEmpty,
      completionWarning: warnings.isEmpty ? null : warnings.join('\n\n'),
      clearCompletionWarning: warnings.isEmpty,
    );
    _phase(RunPhase.done);
  }

  /// Auto-cleans the cosmetic debris AI edits leave behind: runs `dart fix
  /// --apply` (safe automated lint fixes — unused imports, `const`, …) then
  /// `dart format` on the edited files. Never fails the run — tidy is
  /// best-effort; unavailable tooling or a non-zero exit is just logged.
  Future<void> _tidy(ImplBrief brief) async {
    final pubspec =
        await ImplWorkspace.readRepoFile(brief.repoPath, 'pubspec.yaml');
    if (pubspec.trim().isEmpty) return; // Dart/Flutter repos only
    _log(ConsoleLineKind.narration, 'Tidying up (dart fix + format)…');
    // dart fix across the package (safe, only touches diagnosable issues);
    // format only the files we actually edited, to avoid noisy repo-wide diffs.
    final edited = state.appliedEditPaths
        .where((p) => p.endsWith('.dart'))
        .toList();
    final steps = <String>[
      'dart fix --apply',
      if (edited.isNotEmpty) 'dart format ${edited.join(' ')}',
    ];
    for (final cmd in steps) {
      final out = <String>[];
      final result = await _runner.run(
        cmd,
        workingDirectory: brief.repoPath,
        onOutput: (o) => out.add(o.text),
      );
      if (result.exitCode == -1 || result.exitCode == -2) {
        _log(ConsoleLineKind.info, 'Skipped `$cmd` (unavailable).');
      } else {
        final summary = out.isEmpty ? '' : ' — ${out.last.trim()}';
        _log(result.ok ? ConsoleLineKind.success : ConsoleLineKind.info,
            '${result.ok ? '✓' : '•'} $cmd$summary');
      }
    }
  }

  /// Runs the project's static analyzer after edits and folds any compile-level
  /// errors into [failures] (which drives canFix / "Fix it"). Only gates
  /// Dart/Flutter repos; treats analyzer-unavailable/timeout as "skip", and
  /// ignores warning/info-level lints so it fails only on real errors.
  Future<void> _analyzeGate(ImplBrief brief, StringBuffer failures) async {
    final pubspec =
        await ImplWorkspace.readRepoFile(brief.repoPath, 'pubspec.yaml');
    if (pubspec.trim().isEmpty) return; // only gate Dart/Flutter repos
    final isFlutter =
        pubspec.contains('sdk: flutter') || pubspec.contains('\nflutter:');
    final cmd = isFlutter ? 'flutter analyze' : 'dart analyze';
    _phase(RunPhase.verifying);
    _log(ConsoleLineKind.narration, 'Checking the code compiles…');
    _log(ConsoleLineKind.command, '\$ $cmd');
    final captured = <String>[];
    final result = await _runner.run(
      cmd,
      workingDirectory: brief.repoPath,
      onOutput: (o) {
        captured.add(o.text);
        _log(o.isError ? ConsoleLineKind.stderr : ConsoleLineKind.stdout,
            o.text);
      },
    );
    // -1 timeout / -2 blocked / spawn failure → analyzer unavailable; don't
    // block the run on tooling we couldn't execute.
    if (result.exitCode == -1 || result.exitCode == -2) {
      _log(ConsoleLineKind.info, 'Skipped analyze ($cmd unavailable).');
      return;
    }
    final errs =
        captured.where((l) => l.contains('error •')).toList();
    if (errs.isEmpty) {
      _log(ConsoleLineKind.success, '✓ analyze clean (no compile errors)');
    } else {
      _log(ConsoleLineKind.error, '✗ analyze found ${errs.length} error(s)');
      failures
        ..writeln('Static analysis errors ($cmd):')
        ..writeln(errs.take(60).map((l) => '  $l').join('\n'))
        ..writeln();
    }
  }

  static String _tail(List<String> lines, int n) {
    final t = lines.length > n ? lines.sublist(lines.length - n) : lines;
    return t.map((l) => '  $l').join('\n');
  }

  /// Feeds the last run's failures back to the agent for a corrective plan.
  Future<void> fix() async {
    final ctx = _fixContext;
    if (ctx == null || _brief == null) return;
    _log(ConsoleLineKind.command, '⛑ Fix the failures from the last run');
    await _plan(
      previousPlan: state.plan,
      feedback: 'The previous attempt applied but had problems. Fix them:\n$ctx',
    );
  }

  /// Hand-edit a proposed command's text before it runs.
  void editProposedCommand(int index, String raw, String human) {
    final plan = state.plan;
    if (plan == null || index < 0 || index >= plan.commands.length) return;
    final commands = [...plan.commands];
    commands[index] = ProposedCommand(
      human: human.trim().isEmpty ? raw.trim() : human.trim(),
      raw: raw.trim(),
    );
    state = state.copyWith(
      plan: AgentPlan(
        summary: plan.summary,
        rationale: plan.rationale,
        edits: plan.edits,
        commands: commands,
      ),
    );
  }

  /// Reverses one applied edit from its backup.
  Future<void> undo(String path) async {
    final brief = _brief;
    if (brief == null || !state.appliedEditPaths.contains(path)) return;
    await ImplWorkspace.undoEdit(
      repoPath: brief.repoPath,
      projectPath: brief.projectPath,
      runId: state.runId,
      rel: path,
    );
    final applied = {...state.appliedEditPaths}..remove(path);
    state = state.copyWith(appliedEditPaths: applied);
    _log(ConsoleLineKind.info, 'Reverted $path');
  }

  /// Ships the feature: first records a durable "what we built + why" memory
  /// into the project's build-memory pool (so future builds on this project
  /// read it back in [_plan] — context that's gained and remains), then flags
  /// the run shipped. Safe with no plan (nothing to record — just flags).
  Future<void> shipFeature() async {
    // In-session guard: don't re-run the whole doc+commit flow if this window
    // already shipped its feature (a double-click or re-entry). The durable
    // cross-session guard is the gitHasChanges check in _documentAndCommit.
    if (state.featureShipped) return;
    final brief = _brief;
    final plan = state.plan;
    if (brief != null && plan != null) {
      final paths = state.appliedEditPaths.isNotEmpty
          ? state.appliedEditPaths.toList()
          : plan.edits.map((e) => e.path).toList();
      try {
        await ref.read(projectFileRepositoryProvider).writeBuildMemory(
            brief.projectPath, brief.featureId, buildMemoryRecord(brief, plan, paths));
        _log(ConsoleLineKind.success,
            'Saved to build memory — future features on this project will see this.');
      } catch (e) {
        _log(ConsoleLineKind.info, 'Could not save build memory: $e');
      }
      // Document the change in the code repo, then commit + push — the same
      // "docs ship with code" discipline The Forge holds itself to, applied to
      // the app being built.
      await _documentAndCommit(brief, plan, paths);
      // Durably mark the tracked feature shipped — the source-of-truth write.
      // Previously the only shipped→DB write lived in the tracker screen's
      // post-window callback, gated on the board being `mounted`; navigating
      // away while the build window was open silently skipped it, leaving the
      // feature stuck at in_progress until a restart exposed it. Writing here
      // makes shipping persist regardless of navigation.
      await _persistShipped(brief);
    }
    state = state.copyWith(featureShipped: true);
  }

  /// Persists the tracked feature's status to `shipped` in the DB (+ JSON
  /// mirror) and refreshes the board. Best-effort — never blocks the ship.
  Future<void> _persistShipped(ImplBrief brief) async {
    try {
      final db = ref.read(forgeDatabaseProvider);
      final feature = await db.getFeatureById(brief.featureId);
      if (feature == null) return;
      if (FeatureStatus.fromWire(feature.status) == FeatureStatus.shipped) {
        return; // already shipped — nothing to do
      }
      await ref.read(trackerRepositoryProvider).saveFeature(
            feature.copyWith(
              status: FeatureStatus.shipped.wire,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
            projectPath: brief.projectPath,
          );
      ref.invalidate(featureListProvider(feature.projectId));
      _log(ConsoleLineKind.success, '✓ marked shipped on the board');
    } catch (e) {
      _log(ConsoleLineKind.info, 'Could not persist shipped status: $e');
    }
  }

  /// On ship: update the linked repo's docs (CHANGELOG + development log + a
  /// best-effort ARCHITECTURE refresh), then stage/commit/push. Best-effort
  /// throughout — a docs or git hiccup never blocks marking the feature shipped.
  Future<void> _documentAndCommit(
      ImplBrief brief, AgentPlan plan, List<String> paths) async {
    final repoPath = brief.repoPath;
    if (repoPath.isEmpty || !Directory(repoPath).existsSync()) {
      _log(ConsoleLineKind.info, 'No linked repo — skipping docs + commit.');
      return;
    }
    _log(ConsoleLineKind.narration, 'Updating docs (changelog, dev log, architecture)…');

    // --- Deterministic docs (always reliable) ---
    final today = _todayStamp();
    try {
      _prepend(File(p.join(repoPath, 'CHANGELOG.md')),
          _changelogEntry(brief, plan, paths, today),
          header: '# Changelog\n');
      _log(ConsoleLineKind.success, '✓ CHANGELOG.md');
    } catch (e) {
      _log(ConsoleLineKind.info, 'Could not update CHANGELOG.md: $e');
    }
    try {
      final devlog = File(p.join(repoPath, 'docs', 'DEVELOPMENT_LOG.md'));
      devlog.parent.createSync(recursive: true);
      _prepend(devlog, _devLogEntry(brief, plan, paths, today),
          header: '# Development Log\n\nWhat The Forge built, and why. Newest first.\n');
      _log(ConsoleLineKind.success, '✓ docs/DEVELOPMENT_LOG.md');
    } catch (e) {
      _log(ConsoleLineKind.info, 'Could not update development log: $e');
    }

    // Redundant-ship guard: if, after the deterministic doc updates, the tree
    // has nothing to commit (code already committed, CHANGELOG/dev-log entries
    // deduped), this is a repeat ship of an already-shipped feature. Stop here —
    // do NOT run the ARCHITECTURE refresh, which rewrites the whole doc via the
    // LLM and would otherwise manufacture a spurious "docs-only" commit with a
    // duplicate title. (BUG-IMPL-010.) Checked before the refresh so its
    // churn can't mask an otherwise-clean tree.
    if (!await ProjectFileRepository.gitHasChanges(repoPath)) {
      _log(ConsoleLineKind.info,
          'Already shipped & documented — nothing new to commit (skipping duplicate commit).');
      return;
    }

    // --- Best-effort architecture refresh via the architect model ---
    await _updateArchitectureDoc(brief, plan, paths);

    // --- Commit + push ---
    final msg = 'feat: ${brief.featureTitle}'
        '${(brief.targetVersion?.isNotEmpty ?? false) ? ' (${brief.targetVersion})' : ''}'
        ' + docs';
    _log(ConsoleLineKind.command, '\$ git add -A && git commit && git push');
    final committed = await ProjectFileRepository.gitCommitAll(repoPath, msg);
    if (!committed) {
      _log(ConsoleLineKind.info, 'Nothing to commit (or not a git repo).');
      return;
    }
    _log(ConsoleLineKind.success, '✓ committed: $msg');
    final pushed = await ProjectFileRepository.gitPush(repoPath);
    _log(pushed ? ConsoleLineKind.success : ConsoleLineKind.info,
        pushed ? '✓ pushed to origin' : '• not pushed (no remote / auth) — committed locally');
  }

  /// Asks the architect model to fold this feature into the repo's ARCHITECTURE
  /// doc (prose out → no fragile JSON). Best-effort: skipped on any error.
  Future<void> _updateArchitectureDoc(
      ImplBrief brief, AgentPlan plan, List<String> paths) async {
    try {
      final file = File(p.join(brief.repoPath, 'docs', 'ARCHITECTURE.md'));
      final current = file.existsSync() ? await file.readAsString() : '';
      final llm = ref.read(llmServiceProvider);
      final updated = await llm.complete(
        role: LlmRole.architect,
        temperature: 0.2,
        maxTokens: 4000,
        systemPrompt:
            'You maintain a concise ARCHITECTURE.md for a software project. '
            'Given the current doc and a newly shipped feature, return the '
            'FULL updated ARCHITECTURE.md in Markdown — integrate the feature '
            '(components, data flow, key files) without bloating it or dropping '
            'existing content. Output ONLY the Markdown, no code fences.',
        userPrompt: 'Project: ${brief.projectName}\n\n'
            '## Current ARCHITECTURE.md\n${current.isEmpty ? '(none yet)' : current}\n\n'
            '## Newly shipped feature: ${brief.featureTitle}\n'
            '${plan.summary}\n${plan.rationale}\n'
            'Files changed: ${paths.join(', ')}',
      );
      final text = updated.trim();
      if (text.isEmpty) return;
      file.parent.createSync(recursive: true);
      await file.writeAsString(text.endsWith('\n') ? text : '$text\n');
      _log(ConsoleLineKind.success, '✓ docs/ARCHITECTURE.md');
    } catch (e) {
      _log(ConsoleLineKind.info, 'Skipped ARCHITECTURE.md refresh: $e');
    }
  }

  /// Prepends [entry] to [file], keeping an optional one-time [header] at top.
  static void _prepend(File file, String entry, {required String header}) {
    final existing = file.existsSync() ? file.readAsStringSync() : '';
    // Dedup: don't add an entry that's already present (e.g. re-shipping the
    // same feature would otherwise repeat an identical block).
    if (entry.trim().isNotEmpty && existing.contains(entry.trim())) return;
    if (existing.isEmpty) {
      file.writeAsStringSync('$header\n$entry\n');
      return;
    }
    // Insert the new entry just under the header (or at the very top).
    if (existing.startsWith(header)) {
      final rest = existing.substring(header.length);
      file.writeAsStringSync('$header\n$entry\n$rest');
    } else {
      file.writeAsStringSync('$entry\n\n$existing');
    }
  }

  static String _todayStamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}';
  }

  static String _changelogEntry(
      ImplBrief brief, AgentPlan plan, List<String> paths, String date) {
    final v = brief.targetVersion?.trim();
    final b = StringBuffer()
      ..writeln('## $date — ${brief.featureTitle}'
          '${v != null && v.isNotEmpty ? ' ($v)' : ''}');
    if (plan.summary.isNotEmpty) b.writeln(plan.summary);
    if (paths.isNotEmpty) {
      b.writeln();
      for (final path in paths) {
        b.writeln('- $path');
      }
    }
    return b.toString().trimRight();
  }

  static String _devLogEntry(
      ImplBrief brief, AgentPlan plan, List<String> paths, String date) {
    final b = StringBuffer()..writeln('## ${brief.featureTitle} — $date');
    if ((brief.featureDescription ?? '').trim().isNotEmpty) {
      b.writeln('**Feature:** ${brief.featureDescription!.trim()}');
    }
    if (plan.summary.isNotEmpty) b.writeln('**What was built:** ${plan.summary}');
    if (plan.rationale.isNotEmpty) b.writeln('**Why / approach:** ${plan.rationale}');
    if (paths.isNotEmpty) b.writeln('**Files changed:** ${paths.join(', ')}');
    if (plan.commands.isNotEmpty) {
      b.writeln('**Commands:** ${plan.commands.map((c) => c.raw).join('; ')}');
    }
    return b.toString().trimRight();
  }

  /// One concise markdown record of a shipped feature for the build-memory pool.
  /// Public + static so it can be unit-tested without a filesystem or notifier.
  static String buildMemoryRecord(
      ImplBrief brief, AgentPlan plan, List<String> paths) {
    final version = brief.targetVersion?.trim();
    final b = StringBuffer()
      ..writeln('### ${brief.featureTitle}'
          '${version != null && version.isNotEmpty ? ' ($version)' : ''}');
    if (plan.summary.isNotEmpty) {
      b.writeln('**What was built:** ${plan.summary}');
    }
    if (plan.rationale.isNotEmpty) {
      b.writeln('**Why / approach:** ${plan.rationale}');
    }
    if (paths.isNotEmpty) {
      b.writeln('**Files changed:** ${paths.join(', ')}');
    }
    return b.toString().trim();
  }

  /// Makes a generated Flutter app actually runnable by creating the platform
  /// folders (`flutter create .`) it's missing — the common gap where Build-with-AI
  /// writes lib/pubspec but never scaffolds android/ios. Backs up and restores
  /// the Info.plist / AndroidManifest so permission edits aren't lost to the
  /// regenerated defaults.
  Future<void> scaffoldFlutter(ImplBrief brief) async {
    // Use the window's brief directly (don't require a build to have started —
    // `_brief` is only set by start(), so on a freshly-opened feature it's null).
    _brief ??= brief;
    if (!(state.phase == RunPhase.idle || state.phase.isTerminal)) return;
    final repoPath = brief.repoPath;
    if (repoPath.isEmpty || !Directory(repoPath).existsSync()) {
      _log(ConsoleLineKind.info, 'No linked repo to set up.');
      return;
    }
    final pubspec = await ImplWorkspace.readRepoFile(repoPath, 'pubspec.yaml');
    if (!pubspec.contains('sdk: flutter')) {
      _log(ConsoleLineKind.info, 'Not a Flutter project — nothing to scaffold.');
      return;
    }
    final alreadySetUp =
        Directory(p.join(repoPath, 'ios', 'Runner.xcodeproj')).existsSync() ||
            File(p.join(repoPath, 'android', 'build.gradle')).existsSync() ||
            File(p.join(repoPath, 'android', 'build.gradle.kts')).existsSync();
    if (alreadySetUp) {
      _log(ConsoleLineKind.success, 'Platform folders are already set up.');
      return;
    }

    final prior = state.phase;
    _phase(RunPhase.running);
    _log(ConsoleLineKind.narration,
        'Setting up platform folders (flutter create)…');
    // Back up files flutter create would overwrite with defaults.
    final backups = <String, String>{};
    for (final rel in const [
      'ios/Runner/Info.plist',
      'android/app/src/main/AndroidManifest.xml',
    ]) {
      final f = File(p.join(repoPath, rel));
      if (f.existsSync()) backups[rel] = f.readAsStringSync();
    }
    _log(ConsoleLineKind.command, '\$ flutter create .');
    final res = await _runner.run(
      'flutter create .',
      workingDirectory: repoPath,
      onOutput: (o) => _log(
          o.isError ? ConsoleLineKind.stderr : ConsoleLineKind.stdout, o.text),
    );
    if (!res.ok) {
      _log(ConsoleLineKind.error,
          '✗ flutter create failed (exit ${res.exitCode}).');
      _phase(prior);
      return;
    }
    // Restore complete manifests so permission/keys the AI added survive.
    backups.forEach((rel, content) {
      final complete = (rel.endsWith('.plist') && content.contains('</dict>')) ||
          (rel.endsWith('.xml') && content.contains('</manifest>'));
      if (complete) {
        File(p.join(repoPath, rel)).writeAsStringSync(content);
        _log(ConsoleLineKind.info, 'Restored your $rel (kept its keys/permissions).');
      }
    });
    // Xcode 27 rejects iOS deployment targets below 15.0; raise the scaffolded
    // defaults so the app runs on device/simulator without a build error.
    final bumped = await applyMinIosDeploymentTarget(repoPath);
    if (bumped.isNotEmpty) {
      _log(ConsoleLineKind.info,
          'Set iOS deployment target to $kMinIosDeploymentTarget (Xcode 27).');
    }
    _log(ConsoleLineKind.success,
        '✓ Platform folders created — the app can now build/run on a device.');
    _phase(prior);
  }

  void stop() {
    _gen++; // invalidate any in-flight planning stream
    _waitTimer?.cancel();
    _runner.cancel();
    if (!state.phase.isTerminal) {
      _log(ConsoleLineKind.info, 'Stopped by user.');
      _phase(RunPhase.stopped);
    }
  }

  /// Clears a finished/stopped/failed run so the user can build the feature
  /// again from scratch.
  void reset() {
    if (!state.phase.isTerminal) return;
    _gen++; // invalidate any stale stream before a fresh start
    _waitTimer?.cancel();
    _brief = null;
    _partial = '';
    _streamStarted = false;
    _fixContext = null;
    ref.read(implActiveRunsProvider.notifier).set(arg, RunPhase.idle);
    state = ImplRunState.initial(state.runId);
  }
}
