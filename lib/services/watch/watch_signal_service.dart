import 'package:flutter/foundation.dart';

import '../../features/settings/engineer_roster_notifier.dart';
import 'alert_engine.dart';
import 'ci_correlator.dart';
import 'ci_outcome_provider.dart';
import 'failure_signal_engine.dart';
import 'git_activity_provider.dart';
import 'project_status_aggregator.dart';
import 'usage_provider.dart';

@immutable
class WatchSignalResult {
  final List<FailureSignal> signals;
  final List<AlertEntry> newAlerts;
  final WorkspaceStatus workspaceStatus;

  const WatchSignalResult({
    required this.signals,
    required this.newAlerts,
    required this.workspaceStatus,
  });
}

class WatchSignalService {
  const WatchSignalService();

  WatchSignalResult evaluate({
    required List<EngineerCorrelation> correlations,
    required List<EngineerUsage> tokenUsage,
    required List<EngineerRosterEntry> roster,
    required List<GitCommit> commits,
    required List<CIRun> ciRuns,
    required List<AlertEntry> existingLog,
  }) {
    final signals = const FailureSignalEngine().evaluate(
      correlations: correlations,
      tokenUsage: tokenUsage,
      roster: roster,
      commits: commits,
      ciRuns: ciRuns,
    );
    final newAlerts = const AlertEngine().evaluate(
      signals: signals,
      existingLog: existingLog,
    );
    final workspaceStatus = const ProjectStatusAggregator().aggregate(
      commits: commits,
      ciRuns: ciRuns,
    );
    return WatchSignalResult(
      signals: signals,
      newAlerts: newAlerts,
      workspaceStatus: workspaceStatus,
    );
  }
}