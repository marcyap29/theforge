import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/watch/alert_log_notifier.dart';
import '../../services/watch/ci_correlator.dart';
import '../../services/watch/failure_signal_engine.dart';
import '../../services/watch/git_activity_provider.dart';
import '../../services/watch/git_activity_service_provider.dart';
import '../../services/watch/spec_drift_engine.dart';
import '../../services/watch/spec_drift_service_provider.dart';
import '../../services/watch/usage_provider.dart';
import '../../services/watch/usage_service_provider.dart';
import '../../services/watch/watch_signal_service.dart';
import '../../services/watch/watch_signal_service_provider.dart';
import '../projects/providers/providers.dart';
import '../settings/engineer_roster_notifier.dart';

@immutable
class WatchData {
  final List<EngineerUsage> usage;
  final List<EngineerCorrelation> correlations;
  final WatchSignalResult signalResult;
  final bool hasGitHubConfig;
  final List<SpecDriftResult> specDrift;

  const WatchData({
    required this.usage,
    required this.correlations,
    required this.signalResult,
    required this.hasGitHubConfig,
    required this.specDrift,
  });

  List<GitCommit> get allCommits =>
      correlations.expand((c) => c.gitActivity.commits).toList();

  List<FailureSignal> signalsFor(String handle) =>
      signalResult.signals.where((s) => s.engineerHandle == handle).toList();

  List<FailureSignal> get workspaceSignals =>
      signalResult.signals.where((s) => s.engineerHandle == 'workspace').toList();
}

class WatchDataNotifier extends AsyncNotifier<WatchData> {
  @override
  Future<WatchData> build() async => _fetch();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<WatchData> _fetch() async {
    final usageService = ref.read(usageServiceProvider);
    final gitService = ref.read(gitActivityServiceProvider);
    final roster = await ref.read(engineerRosterProvider.future);
    final alertLog = await ref.read(alertLogProvider.future);
    final specDriftService = ref.read(specDriftServiceProvider);

    final usage = usageService != null
        ? await usageService.fetchAllUsage()
        : const <EngineerUsage>[];

    final correlations = gitService != null
        ? await gitService.fetchCorrelations(tokenUsage: usage)
        : const <EngineerCorrelation>[];

    final commits = correlations.expand((c) => c.gitActivity.commits).toList();

    final projects = await ref.read(projectListProvider.future);
    final specDrift = await specDriftService.evaluate(projects);

    // v1: ciRuns not available post-correlation; WorkspaceStatus.ciPassRate30d
    // will be 0. Velocity trend and stall detection (commit-based) still work.
    // Upgrade path: expose ciRuns from GitActivityService.fetchCorrelations().
    final watchService = ref.read(watchSignalServiceProvider);
    final signalResult = watchService.evaluate(
      correlations: correlations,
      tokenUsage: usage,
      roster: roster,
      commits: commits,
      ciRuns: const [],
      existingLog: alertLog,
      specDrift: specDrift,
    );

    if (signalResult.newAlerts.isNotEmpty) {
      await ref.read(alertLogProvider.notifier).appendAlerts(signalResult.newAlerts);
    }

    return WatchData(
      usage: usage,
      correlations: correlations,
      signalResult: signalResult,
      hasGitHubConfig: gitService != null,
      specDrift: specDrift,
    );
  }
}

final watchDataProvider =
    AsyncNotifierProvider<WatchDataNotifier, WatchData>(
  WatchDataNotifier.new,
);