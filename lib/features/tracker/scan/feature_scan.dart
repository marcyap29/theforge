import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service.dart';
import '../../../services/llm/llm_service_provider.dart';
import '../models/tracker_enums.dart';

/// One feature slotted into a roadmap phase, in build order.
class RoadmapEntry {
  RoadmapEntry({required this.title, required this.reason});
  final String title; // must match an existing tracked feature title
  final String reason;
}

/// One phase of a phased build roadmap (e.g. "Foundation" → v1).
class RoadmapPhase {
  RoadmapPhase(
      {required this.name, required this.version, required this.entries});
  final String name;
  final String version; // target version for the whole phase, e.g. "v1"
  final List<RoadmapEntry> entries;
}

/// A feature proposed by the repo scanner, pending user review/import.
class ProposedFeature {
  ProposedFeature({
    required this.title,
    this.description,
    required this.status,
    this.targetVersion,
    this.selected = true,
  });

  final String title;
  final String? description;
  FeatureStatus status;
  final String? targetVersion;
  bool selected;
}

class FeatureScanException implements Exception {
  FeatureScanException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Scans an existing repository and asks the LLM to infer a feature list with
/// inferred status (built code → shipped, TODOs → planned). Reuses the shared
/// [LlmService] (architect role) — same one-shot synthesis pattern as the Watch
/// briefing generator.
class FeatureScanner {
  FeatureScanner(this._llm);

  final LlmService _llm;

  /// Derives features from a project's own Forge documents (spec, handoff,
  /// goal, seeds…) AND/OR a linked code repo. Either source alone is enough —
  /// a doc-only project (no code) still yields a feature list.
  Future<List<ProposedFeature>> scan({
    required String projectPath,
    String? repoPath,
  }) async {
    final docs = await _readProjectDocs(projectPath);

    String? readme;
    List<String> fileList = const [];
    if (repoPath != null && Directory(repoPath).existsSync()) {
      readme = await _readReadme(repoPath);
      fileList = await _listFiles(repoPath);
    }

    if (docs == null && readme == null && fileList.isEmpty) {
      throw FeatureScanException(
          'No documents or repo found to derive features from. Generate a spec '
          'first, or link a repo.');
    }

    final raw = await _llm.complete(
      role: LlmRole.architect,
      temperature: 0.3,
      maxTokens: 2000,
      systemPrompt: _systemPrompt,
      userPrompt: _userPrompt(projectPath, docs, readme, fileList, repoPath),
      jsonMode: true,
    );

    return _parse(raw);
  }

  /// Looks at what's ALREADY built/tracked (plus the docs + code) and recommends
  /// NEW features, enhancements, and improvements to build next — the forward-
  /// looking counterpart to [scan] (which infers what already exists). Excludes
  /// anything already in [existing].
  Future<List<ProposedFeature>> recommend({
    required String projectPath,
    String? repoPath,
    required List<Feature> existing,
  }) async {
    final docs = await _readProjectDocs(projectPath);
    String? readme;
    List<String> fileList = const [];
    if (repoPath != null && Directory(repoPath).existsSync()) {
      readme = await _readReadme(repoPath);
      fileList = await _listFiles(repoPath);
    }
    if (docs == null && readme == null && fileList.isEmpty && existing.isEmpty) {
      throw FeatureScanException(
          'Nothing to analyze yet — build or track some features first, or link '
          'a repo.');
    }
    final raw = await _llm.complete(
      role: LlmRole.architect,
      temperature: 0.4,
      maxTokens: 2500,
      systemPrompt: _recommendSystemPrompt,
      userPrompt:
          _recommendUserPrompt(projectPath, docs, readme, fileList, repoPath, existing),
      jsonMode: true,
    );
    return _parse(raw);
  }

  /// Concatenates the project's README + `.forge` deliverables (spec/handoff/
  /// goal/seeds/worksheet…), spec-first, within a size budget.
  Future<String?> _readProjectDocs(String projectPath) async {
    final buffer = StringBuffer();
    var budget = 12000;

    Future<void> add(File f, String label) async {
      if (budget <= 0 || !f.existsSync()) return;
      try {
        var c = await f.readAsString();
        if (c.length > 3000) c = '${c.substring(0, 3000)}\n…(truncated)';
        if (c.length > budget) c = c.substring(0, budget);
        buffer..writeln('### $label')..writeln(c)..writeln();
        budget -= c.length;
      } catch (_) {}
    }

    await add(File(p.join(projectPath, 'README.md')), 'README.md');

    final forge =
        Directory(p.join(projectPath, ProjectFileRepository.forgeDirName));
    if (forge.existsSync()) {
      final files = forge
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) {
            final n = p.basename(f.path).toLowerCase();
            return n.endsWith('.md') || n.endsWith('.txt') || n.endsWith('.json');
          })
          .toList();
      int rank(File f) {
        final n = p.basename(f.path).toLowerCase();
        if (n.contains('lockedspec')) return 0;
        if (n.contains('handoff') || n.contains('goal')) return 1;
        if (n.contains('seed')) return 2;
        if (n.contains('worksheet') || n.contains('decision')) return 3;
        return 4;
      }
      files.sort((a, b) => rank(a).compareTo(rank(b)));
      final seenSpec = <bool>{}; // include only the first LockedSpec (dedup copy)
      for (final f in files) {
        final name = p.basename(f.path);
        if (name.toLowerCase().contains('lockedspec')) {
          if (seenSpec.isNotEmpty) continue;
          seenSpec.add(true);
        }
        await add(f, name);
      }
    }

    final s = buffer.toString().trim();
    return s.isEmpty ? null : s;
  }

  Future<String?> _readReadme(String repoPath) async {
    for (final name in ['README.md', 'readme.md', 'README.MD', 'Readme.md']) {
      final f = File(p.join(repoPath, name));
      if (f.existsSync()) {
        final content = await f.readAsString();
        return content.length > 6000 ? content.substring(0, 6000) : content;
      }
    }
    return null;
  }

  /// Prefers `git ls-files`; falls back to a filesystem walk. Caps the list.
  Future<List<String>> _listFiles(String repoPath) async {
    try {
      final res = await Process.run('git', ['ls-files'],
          workingDirectory: repoPath);
      if (res.exitCode == 0) {
        final lines = res.stdout
            .toString()
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        if (lines.isNotEmpty) return _cap(lines);
      }
    } catch (_) {}

    // Fallback: walk the directory, skipping noise.
    final skip = {
      '.git', 'node_modules', 'build', '.dart_tool', 'dist', '.idea',
      'Pods', '.gradle', 'vendor', '__pycache__', '.next', 'target',
    };
    final out = <String>[];
    try {
      await for (final entity in dir(repoPath).list(recursive: true)) {
        if (entity is! File) continue;
        final rel = p.relative(entity.path, from: repoPath);
        if (rel.split(p.separator).any(skip.contains)) continue;
        out.add(rel);
        if (out.length >= 500) break;
      }
    } catch (_) {}
    return _cap(out);
  }

  Directory dir(String path) => Directory(path);

  List<String> _cap(List<String> list) =>
      list.length > 400 ? list.sublist(0, 400) : list;

  static const _systemPrompt = '''
You are a senior product analyst. Given a project's DOCUMENTS (its locked spec,
handoff, goal, seeds) and/or its CODEBASE (README + file listing), infer the
discrete product FEATURES. A "feature" is a user-facing capability or a
significant subsystem — not a single file.

Rules:
- Infer status from evidence:
  • Code clearly implements it → "shipped".
  • Specified in the docs but no code evidence it's built → "planned".
  • Partially built → "in_progress".
  • Deferred / V2 seeds → "idea" (set targetVersion "v2" where stated).
  • Only vague aspirations → "idea".
- Prefer 8–18 features. Be specific and concise in titles (max ~6 words).
- Description: one sentence on what the feature does.

Respond with ONLY a JSON array, no prose, no code fences. Each element:
{"title": string, "description": string, "status": "idea|planned|in_progress|blocked|shipped", "targetVersion": string|null}
''';

  /// Sequences the not-yet-shipped [features] into a dependency-aware, phased
  /// build roadmap (Foundation → Core → … → Later), each phase with a target
  /// version, using the docs + code for context. The returned entries reference
  /// existing feature titles verbatim so the caller can map them back.
  Future<List<RoadmapPhase>> planRoadmap({
    required String projectPath,
    String? repoPath,
    required List<Feature> features,
  }) async {
    final docs = await _readProjectDocs(projectPath);
    String? readme;
    List<String> fileList = const [];
    if (repoPath != null && Directory(repoPath).existsSync()) {
      readme = await _readReadme(repoPath);
      fileList = await _listFiles(repoPath);
    }
    final raw = await _llm.complete(
      role: LlmRole.architect,
      temperature: 0.2,
      maxTokens: 2500,
      systemPrompt: _roadmapSystemPrompt,
      userPrompt:
          _roadmapUserPrompt(projectPath, docs, readme, fileList, repoPath, features),
      jsonMode: true,
    );
    return _parseRoadmap(raw);
  }

  List<RoadmapPhase> _parseRoadmap(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(_extractJsonObject(raw));
    } catch (_) {
      throw FeatureScanException('Could not parse the roadmap as JSON.');
    }
    final phasesRaw = (decoded is Map) ? decoded['phases'] : null;
    if (phasesRaw is! List) {
      throw FeatureScanException('The roadmap had no phases.');
    }
    final out = <RoadmapPhase>[];
    for (final ph in phasesRaw) {
      if (ph is! Map) continue;
      final name = (ph['name'] ?? '').toString().trim();
      final version = (ph['version'] ?? '').toString().trim();
      final feats = ph['features'];
      final entries = <RoadmapEntry>[];
      if (feats is List) {
        for (final f in feats) {
          if (f is! Map) continue;
          final title = (f['title'] ?? '').toString().trim();
          if (title.isEmpty) continue;
          entries.add(RoadmapEntry(
              title: title, reason: (f['reason'] ?? '').toString().trim()));
        }
      }
      if (name.isEmpty && entries.isEmpty) continue;
      out.add(RoadmapPhase(
          name: name.isEmpty ? 'Phase' : name, version: version, entries: entries));
    }
    if (out.isEmpty) throw FeatureScanException('The roadmap was empty.');
    return out;
  }

  /// Strips fences/prose and returns the JSON object text.
  String _extractJsonObject(String raw) {
    var t = raw.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\n'), '');
      final end = t.lastIndexOf('```');
      if (end != -1) t = t.substring(0, end);
    }
    final s = t.indexOf('{');
    final e = t.lastIndexOf('}');
    if (s != -1 && e != -1 && e > s) return t.substring(s, e + 1);
    return t.trim();
  }

  static const _roadmapSystemPrompt = '''
You are a technical product manager sequencing an app's backlog into a phased
build roadmap. Given the tracked FEATURES (with status), plus the DOCS and CODE,
order the features that are NOT yet shipped into implementation PHASES.

Rules:
- Respect dependencies: a feature others depend on comes FIRST (foundational
  first). Then order by user value and risk.
- Group into a few phases (e.g. Foundation, Core, Enhancements, Later). Give each
  phase a short name and a target version ("v1", "v1", "v2", …).
- Within each phase, list features in build order, each with a ONE-LINE reason
  (what it enables / why it belongs here).
- Use ONLY the exact feature titles provided (copy them verbatim). Do not invent
  features. Skip anything already "shipped" or "archived".

Respond with ONLY this JSON, no prose, no code fences:
{"phases":[{"name":"Foundation","version":"v1","features":[{"title":"exact title","reason":"why here"}]}]}
''';

  String _roadmapUserPrompt(String projectPath, String? docs, String? readme,
      List<String> files, String? repoPath, List<Feature> features) {
    final buffer = StringBuffer()
      ..writeln('# Project: ${p.basename(projectPath)}')
      ..writeln()
      ..writeln('## Tracked features (sequence the not-yet-shipped ones)');
    for (final f in features) {
      buffer.writeln('- [${f.status}] ${f.title}'
          '${(f.description ?? '').trim().isEmpty ? '' : ' — ${f.description!.trim()}'}');
    }
    buffer.writeln();
    if (docs != null) {
      buffer..writeln('## Project documents')..writeln(docs)..writeln();
    }
    if (repoPath != null && (readme != null || files.isNotEmpty)) {
      buffer.writeln('## Linked codebase: ${p.basename(repoPath)}');
      if (readme != null) buffer..writeln('### README')..writeln(readme)..writeln();
      buffer..writeln('### Files (${files.length})')..writeln(files.join('\n'));
    }
    return buffer.toString();
  }

  static const _recommendSystemPrompt = '''
You are a senior product manager reviewing an EXISTING app to recommend what to
build NEXT. Given the app's DOCUMENTS, its CODEBASE, and the features ALREADY
tracked/built, propose NEW, high-value features, enhancements, and improvements
that are NOT already present.

Rules:
- Do NOT repeat anything in the "already tracked" list, and don't restate what's
  clearly already built.
- Mix categories: new user-facing features, enhancements to existing ones,
  UX/quality/reliability improvements, and notable hardening/tech-debt.
- Prioritize by user value and the natural next steps for THIS app specifically.
- 6–12 recommendations. Title max ~6 words. Description: one sentence covering
  what it is AND why it's worth doing.
- status: "idea" for exploratory/future, "planned" for clear next steps.
  targetVersion optional (e.g. "v2").

Respond with ONLY a JSON array, no prose, no code fences. Each element:
{"title": string, "description": string, "status": "idea|planned", "targetVersion": string|null}
''';

  String _recommendUserPrompt(String projectPath, String? docs, String? readme,
      List<String> files, String? repoPath, List<Feature> existing) {
    final buffer = StringBuffer()
      ..writeln('# Project: ${p.basename(projectPath)}')
      ..writeln();
    if (existing.isNotEmpty) {
      buffer.writeln('## Already tracked / built features (do NOT repeat these)');
      for (final f in existing) {
        buffer.writeln('- [${f.status}] ${f.title}'
            '${(f.description ?? '').trim().isEmpty ? '' : ' — ${f.description!.trim()}'}');
      }
      buffer.writeln();
    }
    if (docs != null) {
      buffer..writeln('## Project documents')..writeln(docs)..writeln();
    }
    if (repoPath != null && (readme != null || files.isNotEmpty)) {
      buffer.writeln('## Linked codebase: ${p.basename(repoPath)}');
      if (readme != null) {
        buffer..writeln('### README')..writeln(readme)..writeln();
      }
      buffer
        ..writeln('### Files (${files.length})')
        ..writeln(files.join('\n'));
    }
    return buffer.toString();
  }

  String _userPrompt(String projectPath, String? docs, String? readme,
      List<String> files, String? repoPath) {
    final buffer = StringBuffer()
      ..writeln('# Project: ${p.basename(projectPath)}')
      ..writeln();
    if (docs != null) {
      buffer
        ..writeln('## Project documents')
        ..writeln(docs)
        ..writeln();
    }
    if (repoPath != null && (readme != null || files.isNotEmpty)) {
      buffer.writeln('## Linked codebase: ${p.basename(repoPath)}');
      if (readme != null) {
        buffer..writeln('### README')..writeln(readme)..writeln();
      }
      buffer
        ..writeln('### Files (${files.length})')
        ..writeln(files.join('\n'));
    }
    return buffer.toString();
  }

  List<ProposedFeature> _parse(String raw) {
    final jsonText = _extractJson(raw);
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (e) {
      throw FeatureScanException('Could not parse scan result as JSON.');
    }
    if (decoded is! List) {
      throw FeatureScanException('Scan result was not a JSON array.');
    }
    final out = <ProposedFeature>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final title = (item['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final desc = item['description']?.toString().trim();
      final version = item['targetVersion']?.toString().trim();
      out.add(ProposedFeature(
        title: title,
        description: (desc == null || desc.isEmpty) ? null : desc,
        status: FeatureStatus.fromWire(item['status']?.toString()),
        targetVersion: (version == null || version.isEmpty) ? null : version,
      ));
    }
    if (out.isEmpty) {
      throw FeatureScanException('The scan did not return any features.');
    }
    return out;
  }

  /// Strips code fences / surrounding prose and returns the JSON array text.
  String _extractJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\n'), '');
      final end = text.lastIndexOf('```');
      if (end != -1) text = text.substring(0, end);
    }
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return text.trim();
  }
}

final featureScannerProvider = Provider<FeatureScanner>(
  (ref) => FeatureScanner(ref.watch(llmServiceProvider)),
);
