import 'dart:convert';

import 'package:http/http.dart' as http;

import '../git_activity_provider.dart';

class GitHubGitProvider implements GitActivityProvider {
  const GitHubGitProvider();

  @override
  String get providerName => 'github';

  @override
  Future<List<GitCommit>> fetchCommits({
    required String org,
    required List<String> repos,
    required String token,
    required int lookbackDays,
    required List<({String handle, String githubLogin})> engineerMappings,
  }) async {
    if (token.isEmpty || repos.isEmpty) return const [];
    final until = DateTime.now();
    final since = until.subtract(Duration(days: lookbackDays));
    final sinceIso = since.toUtc().toIso8601String();
    final untilIso = until.toUtc().toIso8601String();

    final results = <GitCommit>[];
    try {
      final perRepo = await Future.wait(
        repos.map((repo) => _fetchRepoCommits(
              org: org,
              repo: repo,
              token: token,
              sinceIso: sinceIso,
              untilIso: untilIso,
              engineerMappings: engineerMappings,
            )),
      );
      for (final list in perRepo) {
        results.addAll(list);
      }
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
    return results;
  }

  Future<List<GitCommit>> _fetchRepoCommits({
    required String org,
    required String repo,
    required String token,
    required String sinceIso,
    required String untilIso,
    required List<({String handle, String githubLogin})> engineerMappings,
  }) async {
    const query = '''
query(\$owner: String!, \$name: String!, \$since: GitTimestamp!, \$until: GitTimestamp!) {
  repository(owner: \$owner, name: \$name) {
    defaultBranchRef {
      target {
        ... on Commit {
          history(since: \$since, until: \$until, first: 100) {
            nodes {
              oid
              committedDate
              author { email name user { login } }
              message
              changedFilesIfAvailable
            }
          }
        }
      }
    }
  }
}''';
    final response = await http.post(
      Uri.parse('https://api.github.com/graphql'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'query': query,
        'variables': {
          'owner': org,
          'name': repo,
          'since': sinceIso,
          'until': untilIso,
        },
      }),
    );
    if (response.statusCode != 200) return const [];
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) return const [];
    final repository = data['repository'] as Map<String, dynamic>?;
    if (repository == null) return const [];
    final defaultBranch = repository['defaultBranchRef'] as Map<String, dynamic>?;
    if (defaultBranch == null) return const [];
    final target = defaultBranch['target'] as Map<String, dynamic>?;
    if (target == null) return const [];
    final history = target['history'] as Map<String, dynamic>?;
    if (history == null) return const [];
    final nodes = history['nodes'] as List<dynamic>? ?? const [];

    final commits = <GitCommit>[];
    for (final node in nodes) {
      final map = node as Map<String, dynamic>;
      final sha = map['oid'] as String;
      final dateStr = map['committedDate'] as String;
      final committedAt = DateTime.parse(dateStr);
      final author = map['author'] as Map<String, dynamic>? ?? const {};
      final email = (author['email'] as String?) ?? '';
      final name = (author['name'] as String?) ?? '';
      final user = author['user'] as Map<String, dynamic>?;
      final login = (user?['login'] as String?) ?? name;
      final message = (map['message'] as String?) ?? '';
      final changedFiles = (map['changedFilesIfAvailable'] as num?)?.toInt() ?? 0;
      final handle = _resolveHandle(login: login, mappings: engineerMappings);
      commits.add(GitCommit(
        sha: sha,
        authorHandle: handle,
        authorLogin: login,
        authorEmail: email,
        committedAt: committedAt,
        filesChangedCount: changedFiles,
        message: message,
        isAgentAuthored: isAgentCommit(message),
      ));
    }
    return commits;
  }

  @override
  Future<int> fetchMergedPRCount({
    required String org,
    required List<String> repos,
    required String githubLogin,
    required String token,
    required int lookbackDays,
  }) async {
    if (token.isEmpty || repos.isEmpty || githubLogin.isEmpty) return 0;
    final since = DateTime.now().subtract(Duration(days: lookbackDays));
    final sinceIso = since.toUtc().toIso8601String();
    try {
      final perRepo = await Future.wait(
        repos.map((repo) => _fetchRepoMergedPRs(
              org: org,
              repo: repo,
              token: token,
              githubLogin: githubLogin,
              sinceIso: sinceIso,
            )),
      );
      return perRepo.fold<int>(0, (s, n) => s + n);
    } on FormatException {
      return 0;
    } on TypeError {
      return 0;
    }
  }

  Future<int> _fetchRepoMergedPRs({
    required String org,
    required String repo,
    required String token,
    required String githubLogin,
    required String sinceIso,
  }) async {
    const query = '''
query(\$owner: String!, \$name: String!) {
  repository(owner: \$owner, name: \$name) {
    pullRequests(states: MERGED, first: 100, orderBy: {field: UPDATED_AT, direction: DESC}) {
      nodes { mergedAt author { login } }
    }
  }
}''';
    final response = await http.post(
      Uri.parse('https://api.github.com/graphql'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'query': query,
        'variables': {'owner': org, 'name': repo},
      }),
    );
    if (response.statusCode != 200) return 0;
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) return 0;
    final repository = data['repository'] as Map<String, dynamic>?;
    if (repository == null) return 0;
    final prs = repository['pullRequests'] as Map<String, dynamic>?;
    if (prs == null) return 0;
    final nodes = prs['nodes'] as List<dynamic>? ?? const [];
    int count = 0;
    for (final node in nodes) {
      final map = node as Map<String, dynamic>;
      final mergedAtStr = map['mergedAt'] as String?;
      if (mergedAtStr == null) continue;
      final mergedAt = DateTime.tryParse(mergedAtStr);
      if (mergedAt == null) continue;
      if (mergedAt.toUtc().isBefore(DateTime.parse(sinceIso))) continue;
      final author = map['author'] as Map<String, dynamic>?;
      final login = author?['login'] as String?;
      if (login == githubLogin) count++;
    }
    return count;
  }

  static String _resolveHandle({
    required String login,
    required List<({String handle, String githubLogin})> mappings,
  }) {
    for (final m in mappings) {
      if (m.githubLogin == login) return m.handle;
    }
    return login;
  }
}

bool isAgentCommit(String message) {
  final lower = message.toLowerCase();
  return lower.contains('co-authored-by: claude') ||
      lower.contains('co-authored-by: github copilot') ||
      lower.contains('generated with claude code') ||
      lower.contains('generated by claude') ||
      lower.contains('authored by openhands') ||
      message.contains('🤖') ||
      lower.contains('[ai]') ||
      lower.contains('[claude]');
}