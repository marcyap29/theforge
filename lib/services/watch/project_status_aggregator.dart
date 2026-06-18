import 'package:flutter/foundation.dart';

import 'ci_outcome_provider.dart';
import 'git_activity_provider.dart';

// NOTE: v1 aggregates across ALL repos combined. Per-repo breakdown
// requires GitCommit.repo which was not included in §W2. Upgrade path:
// add String repo field to GitCommit and group here by repo.

enum VelocityTrend { improving, stable, declining, stalled }

@immutable
class WorkspaceStatus {
  final int commitsLast7d;
  final int commitsPrior7d;
  final double commitChangePercent;
  final VelocityTrend velocityTrend;
  final DateTime? lastCommitAt;
  final int stalledDays;
  final bool isStalled;
  final int totalCIRuns30d;
  final double ciPassRate30d;

  const WorkspaceStatus({
    required this.commitsLast7d,
    required this.commitsPrior7d,
    required this.commitChangePercent,
    required this.velocityTrend,
    required this.lastCommitAt,
    required this.stalledDays,
    required this.isStalled,
    required this.totalCIRuns30d,
    required this.ciPassRate30d,
  });
}

class ProjectStatusAggregator {
  const ProjectStatusAggregator();

  WorkspaceStatus aggregate({
    required List<GitCommit> commits,
    required List<CIRun> ciRuns,
  }) {
    final now = DateTime.now();
    final day7Ago = now.subtract(const Duration(days: 7));
    final day14Ago = now.subtract(const Duration(days: 14));

    final last7 =
        commits.where((c) => c.committedAt.isAfter(day7Ago)).length;
    final prior7 = commits
        .where((c) =>
            c.committedAt.isAfter(day14Ago) && !c.committedAt.isAfter(day7Ago))
        .length;
    final changePercent = prior7 == 0
        ? (last7 > 0 ? 100.0 : 0.0)
        : (last7 - prior7) / prior7 * 100;

    final sortedCommits = [...commits]
      ..sort((a, b) => b.committedAt.compareTo(a.committedAt));
    final lastCommit =
        sortedCommits.isEmpty ? null : sortedCommits.first.committedAt;
    final stalledDays =
        lastCommit == null ? 999 : now.difference(lastCommit).inDays;

    final VelocityTrend trend;
    if (last7 == 0 && prior7 == 0) {
      trend = VelocityTrend.stalled;
    } else if (changePercent >= 20) {
      trend = VelocityTrend.improving;
    } else if (changePercent <= -20) {
      trend = VelocityTrend.declining;
    } else {
      trend = VelocityTrend.stable;
    }

    final totalRuns = ciRuns.length;
    final passes = ciRuns.where((r) => r.outcome == CIOutcome.pass).length;
    final passRate = totalRuns == 0 ? 0.0 : passes / totalRuns;

    return WorkspaceStatus(
      commitsLast7d: last7,
      commitsPrior7d: prior7,
      commitChangePercent: changePercent,
      velocityTrend: trend,
      lastCommitAt: lastCommit,
      stalledDays: stalledDays,
      isStalled: stalledDays > 7,
      totalCIRuns30d: totalRuns,
      ciPassRate30d: passRate,
    );
  }
}