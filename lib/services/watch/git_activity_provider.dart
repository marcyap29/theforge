import 'package:flutter/foundation.dart';

@immutable
class GitCommit {
  final String sha;
  final String authorHandle;
  final String authorLogin;
  final String authorEmail;
  final DateTime committedAt;
  final int filesChangedCount;
  final String message;
  final bool isAgentAuthored;

  const GitCommit({
    required this.sha,
    required this.authorHandle,
    required this.authorLogin,
    required this.authorEmail,
    required this.committedAt,
    required this.filesChangedCount,
    required this.message,
    required this.isAgentAuthored,
  });
}

@immutable
class EngineerGitActivity {
  final String engineerHandle;
  final List<GitCommit> commits;
  final int prsMerged;
  final double agentAttributionRate;

  const EngineerGitActivity({
    required this.engineerHandle,
    required this.commits,
    required this.prsMerged,
    required this.agentAttributionRate,
  });
}

abstract class GitActivityProvider {
  String get providerName;

  Future<List<GitCommit>> fetchCommits({
    required String org,
    required List<String> repos,
    required String token,
    required int lookbackDays,
    required List<({String handle, String githubLogin})> engineerMappings,
  });

  Future<int> fetchMergedPRCount({
    required String org,
    required List<String> repos,
    required String githubLogin,
    required String token,
    required int lookbackDays,
  });
}