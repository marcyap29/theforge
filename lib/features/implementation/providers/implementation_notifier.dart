import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service_provider.dart';
import '../data/command_runner.dart';
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

/// One implementation run per feature. AutoDispose so state resets and the
/// backups/console are released when the window closes.
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
  final _contentBuf = StringBuffer(); // the answer text (used to find the JSON)
  String _partial = ''; // current unfinished streamed line
  bool _streamStarted = false;
  bool _jsonSeen = false;
  Timer? _waitTimer;

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

  void _log(ConsoleLineKind kind, String text) {
    state = state.copyWith(
      console: [...state.console, ConsoleLine(kind, text, DateTime.now())],
    );
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
  /// the full thought process as real, scrollable lines (no truncation).
  void _appendStream(String text) {
    if (text.isEmpty) return;
    final combined = (_streamStarted ? _partial : '') + text;
    final segs = combined.split('\n');
    final console = [...state.console];
    if (_streamStarted && console.isNotEmpty) {
      console.removeLast(); // drop the old partial line; we re-add it updated
    }
    for (var i = 0; i < segs.length - 1; i++) {
      console.add(ConsoleLine(ConsoleLineKind.stdout, segs[i], DateTime.now()));
    }
    console.add(ConsoleLine(ConsoleLineKind.stdout, segs.last, DateTime.now()));
    _partial = segs.last;
    _streamStarted = true;
    state = state.copyWith(console: console);
  }

  /// Handles one streamed delta. Reasoning models stream their chain-of-thought
  /// as [thinking] deltas — shown live so you watch it think — while the real
  /// answer (the JSON plan) arrives as content deltas, which we hide behind a
  /// "Writing the plan…" indicator (and the agent parses).
  void _onDelta(String text, bool thinking, int gen) {
    if (gen != _gen) return; // stale stream from a stopped/reset run
    _waitTimer?.cancel();
    if (thinking) {
      _appendStream(text);
      return;
    }
    if (_jsonSeen) return;
    final before = _contentBuf.length;
    _contentBuf.write(text);
    final brace = _contentBuf.toString().indexOf('{');
    if (brace >= 0) {
      _jsonSeen = true;
      // Show only the preamble that arrived before the JSON began.
      final visible = (brace - before).clamp(0, text.length);
      if (visible > 0) _appendStream(text.substring(0, visible));
      _log(ConsoleLineKind.info, 'Writing the plan…');
    } else {
      _appendStream(text);
    }
  }

  /// Kicks off the run: streams the agent's plan, then waits for approval.
  Future<void> start(ImplBrief brief) async {
    if (state.phase != RunPhase.idle) return;
    final gen = ++_gen;
    _brief = brief;
    _contentBuf.clear();
    _partial = '';
    _streamStarted = false;
    _jsonSeen = false;
    state = state.copyWith(startedAt: DateTime.now(), error: null);
    _phase(RunPhase.planning);
    _log(ConsoleLineKind.narration, 'Planning: "${brief.featureTitle}"');
    _log(ConsoleLineKind.info, 'Repo: ${brief.repoPath}');
    final resolved = ref.read(llmServiceProvider).resolve(LlmRole.executor);
    if (resolved != null) {
      _log(ConsoleLineKind.info,
          'Model: ${resolved.provider.name} · ${resolved.modelId}');
    }
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
        onDelta: (t, thinking) => _onDelta(t, thinking, gen),
      );
      // Ignore a stream that finished after the user stopped or restarted.
      if (gen != _gen || state.phase == RunPhase.stopped) return;
      _log(
        ConsoleLineKind.info,
        'Proposed ${plan.edits.length} file change'
        '${plan.edits.length == 1 ? '' : 's'} and ${plan.commands.length} '
        'command${plan.commands.length == 1 ? '' : 's'}.',
      );
      state = state.copyWith(plan: plan);
      _phase(RunPhase.awaitingApproval);
    } catch (e) {
      if (gen != _gen || state.phase == RunPhase.stopped) return;
      _log(ConsoleLineKind.error, 'Planning failed: $e');
      state = state.copyWith(error: e.toString());
      _phase(RunPhase.failed);
    } finally {
      if (gen == _gen) _waitTimer?.cancel();
    }
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

    // --- Run commands (streamed) ---
    _phase(RunPhase.running);
    for (var i = 0; i < plan.commands.length; i++) {
      if (state.skippedCommands.contains(i)) continue;
      final cmd = plan.commands[i];
      _log(ConsoleLineKind.command, '\$ ${cmd.raw}');
      final result = await _runner.run(
        cmd.raw,
        workingDirectory: brief.repoPath,
        onOutput: (o) => _log(
          o.isError ? ConsoleLineKind.stderr : ConsoleLineKind.stdout,
          o.text,
        ),
      );
      if (result.ok) {
        _log(ConsoleLineKind.success, '✓ command succeeded');
      } else {
        _log(ConsoleLineKind.error,
            '✗ command exited with code ${result.exitCode}');
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
      }
      state = state.copyWith(verifications: results);
    }

    _log(ConsoleLineKind.narration, 'Run complete.');
    _phase(RunPhase.done);
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
    _contentBuf.clear();
    _partial = '';
    _streamStarted = false;
    _jsonSeen = false;
    ref.read(implActiveRunsProvider.notifier).set(arg, RunPhase.idle);
    state = ImplRunState.initial(state.runId);
  }
}
