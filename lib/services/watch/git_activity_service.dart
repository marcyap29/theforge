import '../../features/settings/engineer_roster_notifier.dart';
import '../../features/settings/github_config_notifier.dart';
import 'ci_correlator.dart';
import 'ci_outcome_provider.dart';
import 'git_activity_provider.dart';
import 'providers/github_ci_provider.dart';
import 'providers/github_git_provider.dart';
import 'usage_provider.dart';

class GitActivityService {
  const GitActivityService({
    required this.config,
    required this.roster,
  });

  final GitHubConfig config;
  final List<EngineerRosterEntry> roster;

  Future<List<EngineerCorrelation>> fetchCorrelations({
    required List<EngineerUsage> tokenUsage,
    int lookbackDays = 30,
  }) async {
    if (!config.isConfigured) return const [];

    const gitProvider = GitHubGitProvider();
    const ciProvider = GitHubCIProvider();

    List<GitCommit> commits = const [];
    List<CIRun> ciRuns = const [];

    try {
      final results = await Future.wait([
        gitProvider.fetchCommits(
          org: config.org,
          repos: config.repos,
          token: config.token,
          lookbackDays: lookbackDays,
          engineerMappings: config.engineerMappings
              .map((m) => (handle: m.handle, githubLogin: m.githubLogin))
              .toList(),
        ),
        ciProvider.fetchRuns(
          org: config.org,
          repos: config.repos,
          token: config.token,
          lookbackDays: lookbackDays,
        ),
      ]);
      commits = results[0] as List<GitCommit>;
      ciRuns = results[1] as List<CIRun>;
    } catch (_) {
      return const [];
    }

    final correlations = const CICorrelator().correlate(
      tokenUsage: tokenUsage,
      commits: commits,
      ciRuns: ciRuns,
      mappings: config.engineerMappings,
    );

    if (config.engineerMappings.isEmpty) return correlations;

    final withPRs = <EngineerCorrelation>[];
    for (final c in correlations) {
      final mapping = config.engineerMappings
          .where((m) => m.handle == c.engineerHandle)
          .firstOrNull;
      if (mapping == null) {
        withPRs.add(c);
        continue;
      }
      int prs = 0;
      try {
        prs = await gitProvider.fetchMergedPRCount(
          org: config.org,
          repos: config.repos,
          githubLogin: mapping.githubLogin,
          token: config.token,
          lookbackDays: lookbackDays,
        );
      } catch (_) {
        prs = 0;
      }
      final oldActivity = c.gitActivity;
      final newActivity = EngineerGitActivity(
        engineerHandle: oldActivity.engineerHandle,
        commits: oldActivity.commits,
        prsMerged: prs,
        agentAttributionRate: oldActivity.agentAttributionRate,
      );
      withPRs.add(EngineerCorrelation(
        engineerHandle: c.engineerHandle,
        dailyCorrelations: c.dailyCorrelations,
        tokenToFailRatio7d: c.tokenToFailRatio7d,
        tokenToFailRatio30d: c.tokenToFailRatio30d,
        totalCIRuns30d: c.totalCIRuns30d,
        overallPassRate30d: c.overallPassRate30d,
        gitActivity: newActivity,
      ));
    }
    return withPRs;
  }
}