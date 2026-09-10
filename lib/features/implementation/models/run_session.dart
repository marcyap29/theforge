import 'package:flutter/material.dart';

/// The phase of an implementation run, driving the header status and timeline.
enum RunPhase {
  idle,
  planning,
  awaitingApproval,
  applying,
  running,
  verifying,
  done,
  failed,
  stopped;

  String get label => switch (this) {
        RunPhase.idle => 'Ready',
        RunPhase.planning => 'Planning',
        RunPhase.awaitingApproval => 'Review',
        RunPhase.applying => 'Applying edits',
        RunPhase.running => 'Running commands',
        RunPhase.verifying => 'Verifying',
        RunPhase.done => 'Done',
        RunPhase.failed => 'Failed',
        RunPhase.stopped => 'Stopped',
      };

  bool get isBusy =>
      this == RunPhase.planning ||
      this == RunPhase.applying ||
      this == RunPhase.running ||
      this == RunPhase.verifying;

  bool get isTerminal =>
      this == RunPhase.done ||
      this == RunPhase.failed ||
      this == RunPhase.stopped;
}

/// The kind of a single console line, used for color-coding the activity log.
enum ConsoleLineKind { narration, command, stdout, stderr, success, error, info }

/// One line in the activity console.
@immutable
class ConsoleLine {
  const ConsoleLine(this.kind, this.text, this.at);

  final ConsoleLineKind kind;
  final String text;
  final DateTime at;

  Color get color => switch (kind) {
        ConsoleLineKind.narration => const Color(0xFFE8A04C), // Forge amber
        ConsoleLineKind.command => const Color(0xFFE5E5E7),
        ConsoleLineKind.stdout => const Color(0xFF9CA3AF),
        ConsoleLineKind.stderr => const Color(0xFFE57373),
        ConsoleLineKind.success => const Color(0xFF81C784),
        ConsoleLineKind.error => const Color(0xFFFF453A),
        ConsoleLineKind.info => const Color(0xFF6B7280),
      };

  String get timestamp {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }
}

/// A single file edit the agent proposes. Carries both the old and new content
/// so the approval card can render a diff and the applier can back up + restore.
@immutable
class ProposedEdit {
  const ProposedEdit({
    required this.path,
    required this.rationale,
    required this.oldContent,
    required this.newContent,
  });

  /// Repo-relative path.
  final String path;
  final String rationale;

  /// Existing file content at propose time (empty string for a new file).
  final String oldContent;
  final String newContent;

  bool get isNewFile => oldContent.isEmpty;
}

/// A shell command the agent proposes to run in the linked repo.
@immutable
class ProposedCommand {
  const ProposedCommand({required this.human, required this.raw});

  /// Plain-English description of what the command does.
  final String human;

  /// The exact command line to execute.
  final String raw;
}

/// The agent's full proposal for one feature: why, what to edit, what to run.
@immutable
class AgentPlan {
  const AgentPlan({
    required this.rationale,
    required this.edits,
    required this.commands,
  });

  final String rationale;
  final List<ProposedEdit> edits;
  final List<ProposedCommand> commands;
}

/// Result of one verification-checklist item.
@immutable
class VerifyResult {
  const VerifyResult({
    required this.requirement,
    required this.passed,
    required this.note,
  });

  final String requirement;
  final bool passed;
  final String note;
}

/// The full observable state of an implementation run, rendered by the window.
@immutable
class ImplRunState {
  const ImplRunState({
    required this.runId,
    required this.phase,
    required this.console,
    this.plan,
    this.skippedEdits = const {},
    this.skippedCommands = const {},
    this.appliedEditPaths = const {},
    this.verifications = const [],
    this.error,
    this.featureShipped = false,
  });

  factory ImplRunState.initial(String runId) => ImplRunState(
        runId: runId,
        phase: RunPhase.idle,
        console: const [],
      );

  final String runId;
  final RunPhase phase;
  final List<ConsoleLine> console;
  final AgentPlan? plan;

  /// Indices of proposed edits/commands the user chose to skip.
  final Set<int> skippedEdits;
  final Set<int> skippedCommands;

  /// Repo-relative paths that were applied this run (Undo available).
  final Set<String> appliedEditPaths;
  final List<VerifyResult> verifications;
  final String? error;
  final bool featureShipped;

  int get approvedEditCount =>
      (plan?.edits.length ?? 0) - skippedEdits.length;
  int get approvedCommandCount =>
      (plan?.commands.length ?? 0) - skippedCommands.length;

  ImplRunState copyWith({
    RunPhase? phase,
    List<ConsoleLine>? console,
    AgentPlan? plan,
    Set<int>? skippedEdits,
    Set<int>? skippedCommands,
    Set<String>? appliedEditPaths,
    List<VerifyResult>? verifications,
    String? error,
    bool? featureShipped,
  }) {
    return ImplRunState(
      runId: runId,
      phase: phase ?? this.phase,
      console: console ?? this.console,
      plan: plan ?? this.plan,
      skippedEdits: skippedEdits ?? this.skippedEdits,
      skippedCommands: skippedCommands ?? this.skippedCommands,
      appliedEditPaths: appliedEditPaths ?? this.appliedEditPaths,
      verifications: verifications ?? this.verifications,
      error: error,
      featureShipped: featureShipped ?? this.featureShipped,
    );
  }
}
