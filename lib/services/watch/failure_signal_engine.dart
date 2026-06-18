import 'package:flutter/foundation.dart';

import '../../features/settings/engineer_roster_notifier.dart';
import 'ci_correlator.dart';
import 'ci_outcome_provider.dart';
import 'git_activity_provider.dart';
import 'usage_provider.dart';

enum SignalType {
  highTokenToFailRatio,
  loopDetected,
  churnDetected,
  spendThreshold,
  runawayDay,
  stalledWorkspace,
}

enum SignalSeverity { info, warning, critical }

@immutable
class FailureSignal {
  final String engineerHandle;
  final SignalType type;
  final SignalSeverity severity;
  final String detail;
  final DateTime detectedAt;
  final Map<String, dynamic> metadata;

  const FailureSignal({
    required this.engineerHandle,
    required this.type,
    required this.severity,
    required this.detail,
    required this.detectedAt,
    this.metadata = const {},
  });
}

class FailureSignalEngine {
  const FailureSignalEngine();

  List<FailureSignal> evaluate({
    required List<EngineerCorrelation> correlations,
    required List<EngineerUsage> tokenUsage,
    required List<EngineerRosterEntry> roster,
    required List<GitCommit> commits,
    required List<CIRun> ciRuns,
  }) {
    final now = DateTime.now();
    final out = <FailureSignal>[];
    out.addAll(_highTokenToFailRatio(correlations, now));
    out.addAll(_loopDetected(correlations, now));
    out.addAll(_churnDetected(commits, now));
    out.addAll(_spendThreshold(tokenUsage, roster, now));
    out.addAll(_runawayDay(correlations, now));
    out.addAll(_stalledWorkspace(commits, tokenUsage, now));
    return out;
  }

  List<FailureSignal> _highTokenToFailRatio(
    List<EngineerCorrelation> correlations,
    DateTime now,
  ) {
    final out = <FailureSignal>[];
    for (final c in correlations) {
      final ratio = c.tokenToFailRatio7d;
      if (ratio <= 30.0) continue;
      final severity =
          ratio > 100.0 ? SignalSeverity.critical : SignalSeverity.warning;
      out.add(FailureSignal(
        engineerHandle: c.engineerHandle,
        type: SignalType.highTokenToFailRatio,
        severity: severity,
        detail:
            '${c.engineerHandle}: \$${ratio.toStringAsFixed(0)} per failed run (7d avg)',
        detectedAt: now,
        metadata: {
          'ratio7d': ratio,
          'ratio30d': c.tokenToFailRatio30d,
          'passRate': c.overallPassRate30d,
        },
      ));
    }
    return out;
  }

  List<FailureSignal> _loopDetected(
    List<EngineerCorrelation> correlations,
    DateTime now,
  ) {
    final out = <FailureSignal>[];
    for (final c in correlations) {
      final days = [...c.dailyCorrelations]
        ..sort((a, b) => a.date.compareTo(b.date));
      int longest = 0;
      int current = 0;
      double loopSpend = 0;
      double longestSpend = 0;
      for (final d in days) {
        final isLoopDay = d.tokenSpend > 15.0 &&
            (d.ciPasses + d.ciFails + d.ciTimeouts) == 0;
        if (isLoopDay) {
          current++;
          loopSpend += d.tokenSpend;
          if (current > longest) {
            longest = current;
            longestSpend = loopSpend;
          }
        } else {
          current = 0;
          loopSpend = 0;
        }
      }
      if (longest >= 2) {
        out.add(FailureSignal(
          engineerHandle: c.engineerHandle,
          type: SignalType.loopDetected,
          severity: SignalSeverity.warning,
          detail:
              '${c.engineerHandle}: $longest consecutive high-spend days with no CI output',
          detectedAt: now,
          metadata: {'loopDays': longest, 'totalSpendInLoop': longestSpend},
        ));
      }
    }
    return out;
  }

  List<FailureSignal> _churnDetected(
    List<GitCommit> commits,
    DateTime now,
  ) {
    final byHandle = <String, int>{};
    for (final c in commits) {
      if (c.message.toLowerCase().startsWith('revert')) {
        byHandle[c.authorHandle] = (byHandle[c.authorHandle] ?? 0) + 1;
      }
    }
    final out = <FailureSignal>[];
    for (final entry in byHandle.entries) {
      final n = entry.value;
      final severity = n >= 3 ? SignalSeverity.warning : SignalSeverity.info;
      out.add(FailureSignal(
        engineerHandle: entry.key,
        type: SignalType.churnDetected,
        severity: severity,
        detail: '${entry.key}: $n revert commit(s) in the lookback window',
        detectedAt: now,
        metadata: {'revertCount': n},
      ));
    }
    return out;
  }

  List<FailureSignal> _spendThreshold(
    List<EngineerUsage> tokenUsage,
    List<EngineerRosterEntry> roster,
    DateTime now,
  ) {
    final out = <FailureSignal>[];
    final thresholdByHandle = <String, double>{};
    for (final e in roster) {
      thresholdByHandle[e.handle] = e.alertThreshold;
    }
    for (final u in tokenUsage) {
      final threshold = thresholdByHandle[u.engineerHandle] ?? 200.0;
      final total = u.totalCostUSD30d;
      if (total <= threshold) continue;
      final severity = total > threshold * 2
          ? SignalSeverity.critical
          : SignalSeverity.warning;
      out.add(FailureSignal(
        engineerHandle: u.engineerHandle,
        type: SignalType.spendThreshold,
        severity: severity,
        detail:
            '${u.engineerHandle}: \$${total.toStringAsFixed(0)} in 30 days (threshold: \$${threshold.toStringAsFixed(0)})',
        detectedAt: now,
        metadata: {'total30d': total, 'threshold': threshold},
      ));
    }
    return out;
  }

  List<FailureSignal> _runawayDay(
    List<EngineerCorrelation> correlations,
    DateTime now,
  ) {
    final out = <FailureSignal>[];
    for (final c in correlations) {
      DailyCorrelation? peak;
      for (final d in c.dailyCorrelations) {
        if (d.tokenSpend > 100.0) {
          if (peak == null || d.tokenSpend > peak.tokenSpend) {
            peak = d;
          }
        }
      }
      if (peak != null) {
        out.add(FailureSignal(
          engineerHandle: c.engineerHandle,
          type: SignalType.runawayDay,
          severity: SignalSeverity.critical,
          detail:
              '${c.engineerHandle}: \$${peak.tokenSpend.toStringAsFixed(0)} on ${peak.date.toIso8601String()} (single-day runaway)',
          detectedAt: now,
          metadata: {
            'peakDay': peak.date.toIso8601String(),
            'peakSpend': peak.tokenSpend,
          },
        ));
      }
    }
    return out;
  }

  List<FailureSignal> _stalledWorkspace(
    List<GitCommit> commits,
    List<EngineerUsage> tokenUsage,
    DateTime now,
  ) {
    final workspaceSpend =
        tokenUsage.fold<double>(0, (s, u) => s + u.totalCostUSD30d);
    if (commits.isEmpty) {
      return [
        FailureSignal(
          engineerHandle: 'workspace',
          type: SignalType.stalledWorkspace,
          severity: SignalSeverity.warning,
          detail:
              'Workspace stalled: no commits, \$${workspaceSpend.toStringAsFixed(0)} still spent',
          detectedAt: now,
          metadata: {'stalledDays': 999, 'workspaceSpend30d': workspaceSpend},
        ),
      ];
    }
    final sorted = [...commits]
      ..sort((a, b) => b.committedAt.compareTo(a.committedAt));
    final last = sorted.first.committedAt;
    final stalledDays = now.difference(last).inDays;
    if (stalledDays < 7) return const [];
    if (workspaceSpend <= 10.0) return const [];
    return [
      FailureSignal(
        engineerHandle: 'workspace',
        type: SignalType.stalledWorkspace,
        severity: SignalSeverity.warning,
        detail:
            'Workspace stalled: no commits in $stalledDays days, \$${workspaceSpend.toStringAsFixed(0)} still spent',
        detectedAt: now,
        metadata: {'stalledDays': stalledDays, 'workspaceSpend30d': workspaceSpend},
      ),
    ];
  }
}