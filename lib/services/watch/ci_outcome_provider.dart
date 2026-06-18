import 'package:flutter/foundation.dart';

enum CIOutcome { pass, fail, timeout }

@immutable
class CIRun {
  final String runId;
  final String triggeringCommitSha;
  final String authorLogin;
  final CIOutcome outcome;
  final DateTime triggeredAt;
  final int durationSeconds;
  final String repo;

  const CIRun({
    required this.runId,
    required this.triggeringCommitSha,
    required this.authorLogin,
    required this.outcome,
    required this.triggeredAt,
    required this.durationSeconds,
    required this.repo,
  });
}

abstract class CIOutcomeProvider {
  String get providerName;

  Future<List<CIRun>> fetchRuns({
    required String org,
    required List<String> repos,
    required String token,
    required int lookbackDays,
  });
}