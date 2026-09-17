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
  FeatureScanException(this.message, {this.raw});
  final String message;

  /// The raw model output that couldn't be parsed — surfaced to diag.log so the
  /// actual response can be inspected.
  final String? raw;

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

    final user = _userPrompt(projectPath, docs, readme, fileList, repoPath);
    return _parseWithRetry(_systemPrompt, user, 0.3, 2000, _parse);
  }

  /// Analyzes the repo AS IT IS RIGHT NOW and returns a plain-language markdown
  /// overview of what the app can currently do — grounded in the actual source
  /// (not just the file list) plus the project docs and tracked features. This
  /// is a read-only narrative (no JSON, no tracker import), the automated
  /// version of "give me an overview of this app's capabilities".
  Future<String> describeCapabilities({
    required String projectPath,
    String? repoPath,
    List<Feature> features = const [],
  }) async {
    final docs = await _readProjectDocs(projectPath);
    String? readme;
    String? code;
    List<String> fileList = const [];
    if (repoPath != null && Directory(repoPath).existsSync()) {
      readme = await _readReadme(repoPath);
      fileList = await _listFiles(repoPath);
      code = await _readKeyCode(repoPath);
    }
    if (docs == null && readme == null && fileList.isEmpty) {
      throw FeatureScanException(
          'Nothing to analyze yet — link a repo or generate a spec first.');
    }
    final user = _capabilityUserPrompt(
        projectPath, docs, readme, code, fileList, repoPath, features);
    final md = await _llm.complete(
      role: LlmRole.architect,
      temperature: 0.3,
      maxTokens: 2200,
      systemPrompt: _capabilitySystemPrompt,
      userPrompt: user,
      jsonMode: false,
      think: false,
    );
    final out = md.trim();
    if (out.isEmpty) {
      throw FeatureScanException(
          'The Architect model returned an empty summary. Try again, or switch '
          'to a different Architect model in Settings.',
          raw: md);
    }
    return out;
  }

  /// Reads the most telling source files under `lib/` (main + screens + widgets
  /// first) within a size budget, so the capability summary reflects real code
  /// rather than guessing from file names.
  Future<String?> _readKeyCode(String repoPath) async {
    final libDir = Directory(p.join(repoPath, 'lib'));
    if (!libDir.existsSync()) return null;
    final files = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    int rank(File f) {
      final n = p.basename(f.path).toLowerCase();
      if (n == 'main.dart') return 0;
      if (f.path.contains('${p.separator}screens${p.separator}') ||
          n.contains('screen')) return 1;
      if (f.path.contains('${p.separator}widgets${p.separator}')) return 2;
      return 3;
    }

    files.sort((a, b) => rank(a).compareTo(rank(b)));
    final buf = StringBuffer();
    var budget = 10000;
    for (final f in files) {
      if (budget <= 0) break;
      try {
        var c = await f.readAsString();
        final rel = p.relative(f.path, from: repoPath);
        if (c.length > 3000) c = '${c.substring(0, 3000)}\n…(truncated)';
        if (c.length > budget) c = c.substring(0, budget);
        buf..writeln('// $rel')..writeln(c)..writeln();
        budget -= c.length;
      } catch (_) {}
    }
    return buf.isEmpty ? null : buf.toString();
  }

  String _capabilityUserPrompt(String projectPath, String? docs, String? readme,
      String? code, List<String> files, String? repoPath, List<Feature> features) {
    final buffer = StringBuffer();
    buffer.writeln('# Project: ${p.basename(projectPath)}');
    buffer.writeln();
    if (features.isNotEmpty) {
      buffer.writeln('## Tracked features (status hints — verify against code)');
      for (final f in features) {
        buffer.writeln('- ${f.title} (${f.status})');
      }
      buffer.writeln();
    }
    if (docs != null) {
      buffer..writeln('## Project documents')..writeln(docs)..writeln();
    }
    if (repoPath != null && (readme != null || files.isNotEmpty)) {
      buffer.writeln('## Linked codebase: ${p.basename(repoPath)}');
      if (readme != null) buffer..writeln('### README')..writeln(readme);
      if (code != null) {
        buffer..writeln('### Source code (key files)')..writeln(code);
      }
      if (files.isNotEmpty) {
        buffer.writeln('### File tree');
        for (final f in files.take(200)) {
          buffer.writeln('- $f');
        }
      }
    }
    return buffer.toString();
  }

  /// Runs a JSON completion and parses it; on a parse failure retries ONCE with
  /// a firm JSON-only reminder (some models — esp. glm on Ollama Cloud — ignore
  /// JSON mode on the first pass and return prose).
  Future<T> _parseWithRetry<T>(String system, String user, double temperature,
      int maxTokens, T Function(String) parse) async {
    final raw = await _llm.complete(
      role: LlmRole.architect,
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: system,
      userPrompt: user,
      jsonMode: true,
      // Thinking OFF: a reasoning model with thinking on can burn the whole
      // budget reasoning and return empty content (diag.log: empty Raw).
      think: false,
    );
    try {
      return parse(raw);
    } on FeatureScanException {
      final retry = await _llm.complete(
        role: LlmRole.architect,
        temperature: 0.1,
        maxTokens: maxTokens,
        systemPrompt: system,
        userPrompt: '$user\n\nIMPORTANT: your previous reply was not usable. '
            'Output ONLY the JSON now — no prose, no explanation, no code fences.',
        jsonMode: true,
        think: false,
      );
      try {
        return parse(retry);
      } on FeatureScanException {
        // Twice unparseable → almost certainly the model doesn't produce JSON
        // reliably (glm-5.3 & co. ignore JSON mode on Ollama Cloud). Point the
        // user at the real fix, and carry the raw output for diag.log.
        throw FeatureScanException(
            'The Architect model didn\'t return valid JSON (even after a retry). '
            'Some models (e.g. glm-5.3) don\'t support JSON output on Ollama '
            'Cloud. Switch the Architect model to a JSON-clean one like '
            'qwen3.5:cloud in Settings, then try again.',
            raw: retry);
      }
    }
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
    final user =
        _recommendUserPrompt(projectPath, docs, readme, fileList, repoPath, existing);
    return _parseWithRetry(_recommendSystemPrompt, user, 0.4, 2500, _parse);
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

  static const _capabilitySystemPrompt = '''
You are a senior engineer writing a concise, accurate "What this app can do right
now" overview for the product owner (non-technical). Base it ONLY on the actual
source code, README, and documents provided — describe real, current
capabilities, not aspirations.

Rules:
- Ground every claim in the code. If a feature is only in the docs or tracked
  list but there is no code implementing it, do NOT list it as working.
- Be honest about gaps: if something is scaffolded but not functional (an empty
  handler, a TODO, a hardcoded/placeholder value, a stubbed branch), call it out
  under a short "Not yet functional / in progress" section.
- Do not invent features, libraries, or screens that aren't in the material.

Output GitHub-flavored markdown, structured as:
- A one-sentence description of what the app is.
- "## What it can do now" — grouped bullets of working capabilities.
- "## Not yet functional / in progress" — honest gaps (omit if none evident).
- "## In one line" — a single summary sentence.
No preamble, no code fences around the whole response.''';

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
    final user =
        _roadmapUserPrompt(projectPath, docs, readme, fileList, repoPath, features);
    return _parseWithRetry(_roadmapSystemPrompt, user, 0.2, 2500, _parseRoadmap);
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
    final list = _extractList(raw);
    if (list == null) {
      throw FeatureScanException('Could not parse scan result as JSON.');
    }
    final out = <ProposedFeature>[];
    for (final item in list) {
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

  /// Robustly pulls a JSON list of feature objects out of a model response —
  /// tolerant of code fences, surrounding prose, and the array being wrapped in
  /// an object (e.g. `{"features":[…]}`), which JSON-mode models often produce.
  /// Returns null only if no list can be found.
  List? _extractList(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\n'), '');
      final end = text.lastIndexOf('```');
      if (end != -1) text = text.substring(0, end);
    }
    // Candidate substrings to try decoding: the [...] slice, the {...} slice,
    // and the whole thing.
    final candidates = <String>[];
    final ai = text.indexOf('['), aj = text.lastIndexOf(']');
    if (ai != -1 && aj > ai) candidates.add(text.substring(ai, aj + 1));
    final oi = text.indexOf('{'), oj = text.lastIndexOf('}');
    if (oi != -1 && oj > oi) candidates.add(text.substring(oi, oj + 1));
    candidates.add(text);
    for (final c in candidates) {
      try {
        final d = jsonDecode(c);
        if (d is List) return d;
        if (d is Map) {
          for (final k in const [
            'features', 'items', 'list', 'results', 'data', 'recommendations'
          ]) {
            if (d[k] is List) return d[k] as List;
          }
          for (final v in d.values) {
            if (v is List) return v;
          }
        }
      } catch (_) {}
    }
    return null;
  }
}

final featureScannerProvider = Provider<FeatureScanner>(
  (ref) => FeatureScanner(ref.watch(llmServiceProvider)),
);
