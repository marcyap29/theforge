import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service_provider.dart';
import '../data/command_runner.dart';
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

  /// A quick preset action (Run checks, Fix errors, …) or the prompt box:
  /// starts a fresh build with [instruction] when idle, otherwise steers the
  /// current plan with it.
  Future<void> action(String instruction) async {
    if (state.phase.isBusy) return;
    if (state.phase == RunPhase.idle) {
      if (_brief != null) await start(_brief!, instruction: instruction);
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
      _log(ConsoleLineKind.error, 'Planning failed: $e');
      state = state.copyWith(error: e.toString());
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
      _log(ConsoleLineKind.error, 'Run failed: $e');
      state = state.copyWith(error: e.toString());
      _phase(RunPhase.failed);
    }
  }

  Future<void> _applyAndRun(ImplBrief brief, AgentPlan plan) async {
    // --- Apply edits ---
    _phase(RunPhase.applying);
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

    final report = failures.toString().trim();
    _fixContext = report.isEmpty ? null : report;
    _log(
        report.isEmpty ? ConsoleLineKind.narration : ConsoleLineKind.error,
        report.isEmpty
            ? 'Run complete.'
            : 'Run finished with issues — you can ask the AI to fix them.');
    state = state.copyWith(canFix: report.isNotEmpty);
    _phase(RunPhase.done);
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

  void markFeatureShipped() =>
      state = state.copyWith(featureShipped: true);

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
