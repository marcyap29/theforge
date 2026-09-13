import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local_db/forge_database.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service.dart';
import '../../../services/llm/llm_service_provider.dart';

/// One set of features judged to be the same capability: [keeper] is the copy
/// to keep, [duplicates] are the redundant ones proposed for deletion.
class DuplicateGroup {
  DuplicateGroup({required this.keeper, required this.duplicates});
  final Feature keeper;
  final List<Feature> duplicates;
}

/// Finds duplicate features so the board can be cleaned up. Combines a
/// deterministic exact-title pass (certain) with an LLM semantic pass that
/// catches the same feature worded differently across re-scans (e.g.
/// "Multi‑Part Highlighting" vs "Highlighting of Parts & Motion").
class FeatureDeduplicator {
  FeatureDeduplicator(this._llm);

  final LlmService _llm;

  /// Normalized title used for the exact pass — case-/punctuation-insensitive.
  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  /// Keep-priority by status: prefer the most-progressed copy, never archived.
  static int _statusRank(String wire) => switch (wire) {
        'shipped' => 5,
        'in_progress' => 4,
        'blocked' => 3,
        'planned' => 2,
        'idea' => 1,
        _ => 0, // archived / unknown
      };

  /// The copy to keep from a duplicate set: most-progressed status, then the
  /// most-recently-updated (preserves manual status changes).
  static Feature pickKeeper(List<Feature> group) {
    final sorted = [...group]..sort((a, b) {
        final r = _statusRank(b.status).compareTo(_statusRank(a.status));
        if (r != 0) return r;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return sorted.first;
  }

  /// Returns resolved duplicate groups (keeper + duplicates), or empty if none.
  Future<List<DuplicateGroup>> findDuplicates(List<Feature> features) async {
    if (features.length < 2) return const [];
    final byId = {for (final f in features) f.id: f};

    // 1) Exact pass — group by normalized title.
    final exact = <String, List<String>>{};
    for (final f in features) {
      exact.putIfAbsent(_norm(f.title), () => []).add(f.id);
    }
    final groups = exact.values
        .where((g) => g.length > 1)
        .map((g) => g.toList())
        .toList();

    // 2) Semantic pass — LLM clusters same-capability entries (best-effort).
    try {
      groups.addAll(await _llmGroups(features));
    } catch (_) {}

    // 3) Merge overlapping groups (union-find), drop singletons.
    final merged = _mergeGroups(groups);

    final result = <DuplicateGroup>[];
    for (final ids in merged) {
      final feats =
          ids.map((id) => byId[id]).whereType<Feature>().toList();
      if (feats.length < 2) continue;
      final keeper = pickKeeper(feats);
      result.add(DuplicateGroup(
        keeper: keeper,
        duplicates: feats.where((f) => f.id != keeper.id).toList(),
      ));
    }
    return result;
  }

  /// Asks the model to cluster same-feature entries. Uses 1-based entry NUMBERS
  /// (not UUIDs) to keep the prompt small and parsing robust.
  Future<List<List<String>>> _llmGroups(List<Feature> features) async {
    final buf = StringBuffer();
    for (var i = 0; i < features.length; i++) {
      final f = features[i];
      final desc = (f.description ?? '').trim();
      buf.writeln('${i + 1}. ${f.title}${desc.isEmpty ? '' : ' — $desc'} '
          '(${f.status})');
    }
    final raw = await _llm.complete(
      role: LlmRole.architect,
      temperature: 0.1,
      maxTokens: 1500,
      systemPrompt: _systemPrompt,
      userPrompt: 'Features:\n$buf',
    );
    final obj = jsonDecode(_extractJsonObject(raw));
    final out = <List<String>>[];
    if (obj is Map && obj['groups'] is List) {
      for (final g in obj['groups'] as List) {
        if (g is! List) continue;
        final ids = <String>[];
        for (final n in g) {
          final idx = (n is num) ? n.toInt() : int.tryParse(n.toString());
          if (idx == null || idx < 1 || idx > features.length) continue;
          ids.add(features[idx - 1].id);
        }
        if (ids.length > 1) out.add(ids);
      }
    }
    return out;
  }

  /// Union-find merge so overlapping/transitive groups collapse into one.
  List<List<String>> _mergeGroups(List<List<String>> groups) {
    final parent = <String, String>{};
    String find(String x) {
      parent.putIfAbsent(x, () => x);
      var root = x;
      while (parent[root] != root) {
        root = parent[root]!;
      }
      parent[x] = root;
      return root;
    }

    void union(String a, String b) => parent[find(a)] = find(b);

    for (final g in groups) {
      for (var i = 1; i < g.length; i++) {
        union(g[0], g[i]);
      }
    }
    final clusters = <String, List<String>>{};
    for (final id in parent.keys) {
      clusters.putIfAbsent(find(id), () => []).add(id);
    }
    return clusters.values.where((c) => c.length > 1).toList();
  }

  String _extractJsonObject(String raw) {
    var t = raw.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\n'), '');
      final end = t.lastIndexOf('```');
      if (end != -1) t = t.substring(0, end);
    }
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return t.substring(start, end + 1);
    }
    return t.trim();
  }

  static const _systemPrompt = '''
You are deduplicating a product feature list. Re-scans often add the SAME
feature worded differently. Group entries that describe the same core capability
or that heavily overlap — even if one is phrased more broadly or specifically.

Examples of duplicates to group:
- "Multi-Part Highlighting" ~ "Highlighting of Parts & Motion"
- "Settings Screen" ~ "Simple Settings Panel"
- "Camera Permission & Live Feed" ~ "Camera Permission Management"
  (both are the camera-permission feature)

Rules:
- Use the entry NUMBERS shown in the list.
- Only include groups with 2 or more members; omit features that are unique.
- A human REVIEWS and confirms every deletion, so prefer surfacing a likely
  duplicate over missing one. When two entries clearly overlap, group them.
- Do NOT group features that address genuinely different capabilities (e.g.
  "Oil Cap Detection" vs "AR Bounding Box Overlay").

Respond with ONLY this JSON, no prose, no code fences:
{"groups": [[1,4],[7,9,12]]}
''';
}

final featureDeduplicatorProvider = Provider<FeatureDeduplicator>(
  (ref) => FeatureDeduplicator(ref.watch(llmServiceProvider)),
);
