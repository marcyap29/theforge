import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service.dart';
import '../../../services/llm/llm_service_provider.dart';
import '../models/tracker_enums.dart';

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

  Future<List<ProposedFeature>> scan(String repoPath) async {
    final dir = Directory(repoPath);
    if (!dir.existsSync()) {
      throw FeatureScanException('Repository path does not exist: $repoPath');
    }

    final readme = await _readReadme(repoPath);
    final fileList = await _listFiles(repoPath);
    if (fileList.isEmpty && readme == null) {
      throw FeatureScanException(
          'No files or README found to scan in $repoPath');
    }

    final raw = await _llm.complete(
      role: LlmRole.architect,
      temperature: 0.3,
      maxTokens: 2000,
      systemPrompt: _systemPrompt,
      userPrompt: _userPrompt(repoPath, readme, fileList),
    );

    return _parse(raw);
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
You are a senior product analyst. Given a codebase's README and file listing,
infer the discrete product FEATURES the project has or plans. A "feature" is a
user-facing capability or a significant subsystem — not a single file.

Rules:
- Infer status from evidence: if code implementing it clearly exists → "shipped".
  If the README/TODOs mention it as planned/future → "planned". If it looks
  partially built → "in_progress". Use "idea" only for vague aspirations.
- Prefer 8–18 features. Be specific and concise in titles (max ~6 words).
- Description: one sentence on what the feature does.

Respond with ONLY a JSON array, no prose, no code fences. Each element:
{"title": string, "description": string, "status": "idea|planned|in_progress|blocked|shipped", "targetVersion": string|null}
''';

  String _userPrompt(String repoPath, String? readme, List<String> files) {
    final buffer = StringBuffer()
      ..writeln('# Repository: ${p.basename(repoPath)}')
      ..writeln();
    if (readme != null) {
      buffer
        ..writeln('## README')
        ..writeln(readme)
        ..writeln();
    }
    buffer
      ..writeln('## Files (${files.length})')
      ..writeln(files.join('\n'));
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
