import 'dart:convert';

import 'package:http/http.dart' as http;

import '../ci_outcome_provider.dart';

class GitHubCIProvider implements CIOutcomeProvider {
  const GitHubCIProvider();

  @override
  String get providerName => 'github';

  @override
  Future<List<CIRun>> fetchRuns({
    required String org,
    required List<String> repos,
    required String token,
    required int lookbackDays,
  }) async {
    if (token.isEmpty || repos.isEmpty) return const [];
    final since = DateTime.now().subtract(Duration(days: lookbackDays));
    final sinceIso = _formatDate(since);

    final results = <CIRun>[];
    try {
      final perRepo = await Future.wait(
        repos.map((repo) => _fetchRepoRuns(
              org: org,
              repo: repo,
              token: token,
              sinceIso: sinceIso,
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

  Future<List<CIRun>> _fetchRepoRuns({
    required String org,
    required String repo,
    required String token,
    required String sinceIso,
  }) async {
    final response = await http.get(
      Uri.parse(
        'https://api.github.com/repos/$org/$repo/actions/runs'
        '?per_page=100&created>=$sinceIso',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github.v3+json',
      },
    );
    if (response.statusCode != 200) return const [];
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final runs = data['workflow_runs'] as List<dynamic>? ?? const [];
    final out = <CIRun>[];
    for (final r in runs) {
      final map = r as Map<String, dynamic>;
      final conclusion = map['conclusion'] as String?;
      final outcome = _mapOutcome(conclusion);
      if (outcome == null) continue; // skip cancelled/skipped/neutral
      final id = map['id'];
      final runId = id == null ? '' : id.toString();
      final headSha = (map['head_sha'] as String?) ?? '';
      final headCommit = map['head_commit'] as Map<String, dynamic>?;
      final authorEmail = (headCommit?['author']?['email'] as String?) ?? '';
      final createdAtStr = map['created_at'] as String?;
      final updatedAtStr = map['updated_at'] as String?;
      if (createdAtStr == null || updatedAtStr == null) continue;
      final createdAt = DateTime.tryParse(createdAtStr);
      final updatedAt = DateTime.tryParse(updatedAtStr);
      if (createdAt == null || updatedAt == null) continue;
      final duration = updatedAt.difference(createdAt).inSeconds.abs();
      out.add(CIRun(
        runId: runId,
        triggeringCommitSha: headSha,
        authorLogin: authorEmail,
        outcome: outcome,
        triggeredAt: createdAt,
        durationSeconds: duration,
        repo: repo,
      ));
    }
    return out;
  }

  static CIOutcome? _mapOutcome(String? conclusion) {
    switch (conclusion) {
      case 'success':
        return CIOutcome.pass;
      case 'failure':
        return CIOutcome.fail;
      case 'timed_out':
        return CIOutcome.timeout;
      default:
        return null; // cancelled, skipped, neutral → skip
    }
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T00:00:00Z';
}