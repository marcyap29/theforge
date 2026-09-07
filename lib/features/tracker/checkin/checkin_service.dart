import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service.dart';
import '../../../services/llm/llm_service_provider.dart';
import '../models/tracker_enums.dart';
import '../scan/feature_scan.dart' show ProposedFeature;

/// A proposed status change to an existing feature, produced by a check-in.
class FeatureStatusChange {
  FeatureStatusChange({
    required this.feature,
    required this.proposed,
    required this.reason,
    this.accepted = true,
  });

  final Feature feature;
  final FeatureStatus proposed;
  final String reason;
  bool accepted;

  FeatureStatus get current => FeatureStatus.fromWire(feature.status);
}

/// The full output of a virtual-PM check-in, pending user review.
class CheckinProposal {
  CheckinProposal({
    required this.narrative,
    required this.changes,
    required this.newFeatures,
    required this.flags,
    required this.head,
    required this.commitCount,
  });

  final String narrative;
  final List<FeatureStatusChange> changes;
  final List<ProposedFeature> newFeatures;
  final List<String> flags;

  /// Git HEAD at check-in time — stored on apply so staleness resets.
  final String? head;
  final int commitCount;

  bool get isEmpty =>
      changes.isEmpty && newFeatures.isEmpty && flags.isEmpty;
}

/// Runs a virtual project-manager check-in: it diffs recent git activity since
/// the last review and asks the LLM to reconcile it against the tracked feature
/// list — proposing status changes, new features, and flags. Uses the shared
/// [LlmService] (architect role), mirroring the Watch briefing pattern.
class CheckinService {
  CheckinService(this._llm);

  final LlmService _llm;

  /// Lightweight staleness check for the on-open banner: has the repo advanced
  /// past the last-reviewed HEAD?
  Future<StalenessInfo> checkStaleness({
    required String? repoPath,
    required String? lastReviewHead,
    required int? lastReviewedAt,
  }) async {
    if (repoPath == null) return const StalenessInfo(stale: false);
    final head = await ProjectFileRepository.getGitHead(repoPath);
    if (head == null) return const StalenessInfo(stale: false);
    if (lastReviewHead == null) {
      // Never reviewed but repo linked — offer a first check-in.
      return const StalenessInfo(stale: true, neverReviewed: true);
    }
    if (head == lastReviewHead) return StalenessInfo(stale: false, head: head);
    final commits = await ProjectFileRepository.getGitCommitMessages(
        repoPath,
        since: _sinceArg(lastReviewedAt));
    return StalenessInfo(stale: true, head: head, newCommits: commits.length);
  }

  Future<CheckinProposal> run({
    required String? repoPath,
    required List<Feature> features,
    required int? lastReviewedAt,
  }) async {
    final head =
        repoPath == null ? null : await ProjectFileRepository.getGitHead(repoPath);
    final commits = repoPath == null
        ? <String>[]
        : await ProjectFileRepository.getGitCommitMessages(repoPath,
            since: _sinceArg(lastReviewedAt));
    final changed = repoPath == null
        ? <String>{}
        : await ProjectFileRepository.getGitChangedFiles(repoPath,
            since: _sinceArg(lastReviewedAt));

    final raw = await _llm.complete(
      role: LlmRole.architect,
      temperature: 0.3,
      maxTokens: 2000,
      systemPrompt: _systemPrompt,
      userPrompt: _userPrompt(features, commits, changed),
    );

    return _parse(raw, features, head, commits.length);
  }

  static String _sinceArg(int? lastReviewedAt) {
    if (lastReviewedAt == null) return '30 days ago';
    final dt = DateTime.fromMillisecondsSinceEpoch(lastReviewedAt);
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static const _systemPrompt = '''
You are a virtual project manager reviewing a software project. You are given
the current tracked FEATURES (each with an id and status) and recent GIT ACTIVITY
(commit messages + changed files) since the last review.

Your job — reconcile the two:
1. For any feature whose real status likely changed based on the commits, propose
   an updated status with a one-line reason grounded in a specific commit/file.
2. Identify NEW features implied by the commits that are not in the tracked list.
3. Flag anything concerning: features that look stalled (in_progress but no related
   commits), blocked work, or scope creep.
4. Write a 2–3 sentence narrative summarizing what happened since last review.

Only propose a status change when the git evidence supports it. Do not restate
unchanged features. Reference features by their exact given id.

Respond with ONLY JSON, no prose, no code fences:
{
  "narrative": string,
  "updates": [{"id": string, "proposedStatus": "idea|planned|in_progress|blocked|shipped|archived", "reason": string}],
  "newFeatures": [{"title": string, "description": string, "status": "idea|planned|in_progress|blocked|shipped"}],
  "flags": [string]
}
''';

  String _userPrompt(
    List<Feature> features,
    List<String> commits,
    Set<String> changedFiles,
  ) {
    final buffer = StringBuffer()..writeln('## Tracked features');
    if (features.isEmpty) {
      buffer.writeln('(none yet)');
    } else {
      for (final f in features) {
        buffer.writeln(
            '- id=${f.id} | status=${f.status} | ${f.title}${f.description != null ? ' — ${f.description}' : ''}');
      }
    }
    buffer
      ..writeln()
      ..writeln('## Recent commits (${commits.length})');
    buffer.writeln(commits.isEmpty ? '(none)' : commits.take(80).join('\n'));

    final files = changedFiles.take(120).toList();
    buffer
      ..writeln()
      ..writeln('## Changed files (${files.length})')
      ..writeln(files.isEmpty ? '(none)' : files.join('\n'));
    return buffer.toString();
  }

  CheckinProposal _parse(
    String raw,
    List<Feature> features,
    String? head,
    int commitCount,
  ) {
    final byId = {for (final f in features) f.id: f};
    final text = _extractJson(raw);
    Map<String, dynamic> obj;
    try {
      final decoded = jsonDecode(text);
      obj = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      obj = <String, dynamic>{};
    }

    final narrative = (obj['narrative'] ?? '').toString().trim();

    final changes = <FeatureStatusChange>[];
    for (final u in (obj['updates'] as List? ?? const [])) {
      if (u is! Map) continue;
      final id = u['id']?.toString();
      final feature = id == null ? null : byId[id];
      if (feature == null) continue;
      final proposed = FeatureStatus.fromWire(u['proposedStatus']?.toString());
      if (proposed.wire == feature.status) continue; // no-op
      changes.add(FeatureStatusChange(
        feature: feature,
        proposed: proposed,
        reason: (u['reason'] ?? '').toString().trim(),
      ));
    }

    final newFeatures = <ProposedFeature>[];
    for (final n in (obj['newFeatures'] as List? ?? const [])) {
      if (n is! Map) continue;
      final title = (n['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final desc = n['description']?.toString().trim();
      newFeatures.add(ProposedFeature(
        title: title,
        description: (desc == null || desc.isEmpty) ? null : desc,
        status: FeatureStatus.fromWire(n['status']?.toString()),
      ));
    }

    final flags = <String>[];
    for (final f in (obj['flags'] as List? ?? const [])) {
      final s = f?.toString().trim();
      if (s != null && s.isNotEmpty) flags.add(s);
    }

    return CheckinProposal(
      narrative: narrative.isEmpty
          ? 'No significant changes detected since the last review.'
          : narrative,
      changes: changes,
      newFeatures: newFeatures,
      flags: flags,
      head: head,
      commitCount: commitCount,
    );
  }

  String _extractJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\n'), '');
      final end = text.lastIndexOf('```');
      if (end != -1) text = text.substring(0, end);
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return text.trim();
  }
}

class StalenessInfo {
  const StalenessInfo({
    required this.stale,
    this.head,
    this.newCommits = 0,
    this.neverReviewed = false,
  });

  final bool stale;
  final String? head;
  final int newCommits;
  final bool neverReviewed;
}

final checkinServiceProvider = Provider<CheckinService>(
  (ref) => CheckinService(ref.watch(llmServiceProvider)),
);
