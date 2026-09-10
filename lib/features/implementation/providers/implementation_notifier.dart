import 'package:flutter_riverpod/flutter_riverpod.dart';

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
final implRunProvider = NotifierProvider.autoDispose
    .family<ImplRunNotifier, ImplRunState, String>(ImplRunNotifier.new);

class ImplRunNotifier extends AutoDisposeFamilyNotifier<ImplRunState, String> {
  ImplBrief? _brief;
  final _runner = CommandRunner();

  @override
  ImplRunState build(String featureId) {
    ref.onDispose(_runner.cancel);
    final runId = '${featureId.substring(0, featureId.length.clamp(0, 8))}'
        '-${DateTime.now().millisecondsSinceEpoch}';
    return ImplRunState.initial(runId);
  }

  void _log(ConsoleLineKind kind, String text) {
    state = state.copyWith(
      console: [...state.console, ConsoleLine(kind, text, DateTime.now())],
    );
  }

  /// Kicks off the run: asks the agent for a plan, then waits for approval.
  Future<void> start(ImplBrief brief) async {
    if (state.phase != RunPhase.idle) return;
    _brief = brief;
    state = state.copyWith(phase: RunPhase.planning, error: null);
    _log(ConsoleLineKind.narration, 'Planning: "${brief.featureTitle}"');
    _log(ConsoleLineKind.info, 'Repo: ${brief.repoPath}');
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
      );
      _log(ConsoleLineKind.narration, plan.rationale);
      _log(
        ConsoleLineKind.info,
        'Proposed ${plan.edits.length} file change'
        '${plan.edits.length == 1 ? '' : 's'} and ${plan.commands.length} '
        'command${plan.commands.length == 1 ? '' : 's'}.',
      );
      state = state.copyWith(plan: plan, phase: RunPhase.awaitingApproval);
    } catch (e) {
      _log(ConsoleLineKind.error, 'Planning failed: $e');
      state = state.copyWith(phase: RunPhase.failed, error: e.toString());
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
    state = state.copyWith(phase: RunPhase.applying);
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
    state = state.copyWith(phase: RunPhase.running);
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
      state = state.copyWith(phase: RunPhase.verifying);
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
    state = state.copyWith(phase: RunPhase.done);
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
    _runner.cancel();
    if (!state.phase.isTerminal) {
      _log(ConsoleLineKind.info, 'Stopped by user.');
      state = state.copyWith(phase: RunPhase.stopped);
    }
  }
}
