import 'package:flutter/foundation.dart';

import '../../features/settings/github_config_notifier.dart';
import 'ci_outcome_provider.dart';
import 'git_activity_provider.dart';
import 'usage_provider.dart';

// v1 CORRELATION PROXY — commit timestamp as session timestamp.
//
// The Anthropic usage API returns daily aggregates, not sub-hour session
// timestamps. The 4-hour lookback window correlation described in the
// SuperSpec is therefore not possible at v1 resolution. Instead, v1
// correlates an engineer's daily token spend (§W1 DailyUsage.date) to CI
// runs triggered by that engineer's commits on the same calendar day.
//
// Upgrade path: if daily-granularity session data becomes available
// (e.g. via a proxy/sidecar or a richer provider API), replace the
// date-equality check in _correlateDay() with a time-window query that
// matches a token session to CI runs within ±4h of the session timestamp.

@immutable
class DailyCorrelation {
  final DateTime date;
  final double tokenSpend;
  final int ciPasses;
  final int ciFails;
  final int ciTimeouts;
  final double tokenPerPass;
  final double tokenPerFail;
  final double passRate;

  const DailyCorrelation({
    required this.date,
    required this.tokenSpend,
    required this.ciPasses,
    required this.ciFails,
    required this.ciTimeouts,
    required this.tokenPerPass,
    required this.tokenPerFail,
    required this.passRate,
  });
}

@immutable
class EngineerCorrelation {
  final String engineerHandle;
  final List<DailyCorrelation> dailyCorrelations;
  final double tokenToFailRatio7d;
  final double tokenToFailRatio30d;
  final int totalCIRuns30d;
  final double overallPassRate30d;
  final EngineerGitActivity gitActivity;

  const EngineerCorrelation({
    required this.engineerHandle,
    required this.dailyCorrelations,
    required this.tokenToFailRatio7d,
    required this.tokenToFailRatio30d,
    required this.totalCIRuns30d,
    required this.overallPassRate30d,
    required this.gitActivity,
  });
}

class CICorrelator {
  const CICorrelator();

  List<EngineerCorrelation> correlate({
    required List<EngineerUsage> tokenUsage,
    required List<GitCommit> commits,
    required List<CIRun> ciRuns,
    required List<GitHubEngineerMapping> mappings,
  }) {
    final shaToRuns = <String, List<CIRun>>{};
    for (final run in ciRuns) {
      shaToRuns.putIfAbsent(run.triggeringCommitSha, () => []).add(run);
    }

    final byHandleCommits = <String, List<GitCommit>>{};
    for (final c in commits) {
      byHandleCommits.putIfAbsent(c.authorHandle, () => []).add(c);
    }

    final loginToHandle = <String, String>{};
    for (final m in mappings) {
      loginToHandle[m.githubLogin] = m.handle;
    }

    final out = <EngineerCorrelation>[];
    for (final usage in tokenUsage) {
      final handle = usage.engineerHandle;
      final myCommits = byHandleCommits[handle] ?? const <GitCommit>[];

      final daily = <DailyCorrelation>[];
      for (final du in usage.dailyBreakdown) {
        final day = DateTime(du.date.year, du.date.month, du.date.day);
        final dayCommits = myCommits.where((c) =>
            DateTime(c.committedAt.year, c.committedAt.month, c.committedAt.day)
                == day);
        final dayShas = dayCommits.map((c) => c.sha).toSet();
        int passes = 0, fails = 0, timeouts = 0;
        for (final sha in dayShas) {
          final runs = shaToRuns[sha] ?? const <CIRun>[];
          for (final r in runs) {
            switch (r.outcome) {
              case CIOutcome.pass:
                passes++;
              case CIOutcome.fail:
                fails++;
              case CIOutcome.timeout:
                timeouts++;
            }
          }
        }
        final totalRuns = passes + fails + timeouts;
        daily.add(DailyCorrelation(
          date: day,
          tokenSpend: du.costUSD,
          ciPasses: passes,
          ciFails: fails,
          ciTimeouts: timeouts,
          tokenPerPass: passes == 0 ? 0 : du.costUSD / passes,
          tokenPerFail: fails == 0 ? 0 : du.costUSD / fails,
          passRate: totalRuns == 0 ? 0 : passes / totalRuns,
        ));
      }

      final totalRuns = daily.fold<int>(0, (s, d) => s + d.ciPasses + d.ciFails + d.ciTimeouts);
      final totalPass = daily.fold<int>(0, (s, d) => s + d.ciPasses);
      final ratio7 = _rollingTokenToFailRatio(daily, 7);
      final ratio30 = _rollingTokenToFailRatio(daily, 30);
      final agentCount = myCommits.where((c) => c.isAgentAuthored).length;
      final activity = EngineerGitActivity(
        engineerHandle: handle,
        commits: myCommits,
        prsMerged: 0,
        agentAttributionRate:
            myCommits.isEmpty ? 0 : agentCount / myCommits.length,
      );
      out.add(EngineerCorrelation(
        engineerHandle: handle,
        dailyCorrelations: daily,
        tokenToFailRatio7d: ratio7,
        tokenToFailRatio30d: ratio30,
        totalCIRuns30d: totalRuns,
        overallPassRate30d: totalRuns == 0 ? 0 : totalPass / totalRuns,
        gitActivity: activity,
      ));
    }
    return out;
  }

  double _rollingTokenToFailRatio(
    List<DailyCorrelation> days,
    int lookbackDays,
  ) {
    if (days.isEmpty) return 0;
    final cutoff = DateTime.now().subtract(Duration(days: lookbackDays));
    final withFails = days
        .where((d) => !d.date.isBefore(cutoff) && d.ciFails > 0)
        .toList();
    if (withFails.isEmpty) return 0;
    final sum = withFails.fold<double>(0, (s, d) => s + d.tokenPerFail);
    return sum / withFails.length;
  }
}