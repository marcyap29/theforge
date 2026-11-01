import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../data/local_db/forge_database.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service.dart';

class ArchitectureResult {
  const ArchitectureResult({
    required this.diagram,
    required this.componentMap,
  });

  /// Raw Mermaid source (flowchart TD / graph LR, etc.).
  final String diagram;

  /// Component → file list mapping, keyed by component name.
  final Map<String, List<String>> componentMap;
}

/// Reads a codebase and generates a Mermaid architecture diagram + component map.
/// Two LLM phases: diagram generation (architectureAnalyst) → component mapping
/// (architectureAnalyst). Both use the same repo file list for grounding.
class ArchitectureAnalyst {
  const ArchitectureAnalyst(this._llm);
  final LlmService _llm;

  Future<ArchitectureResult> analyze({
    required List<Feature> features,
    required String projectPath,
    String? repoPath,
    void Function(int phase, String label)? onProgress,
  }) async {
    final effectiveRepo =
        (repoPath != null && repoPath.isNotEmpty) ? repoPath : projectPath;

    onProgress?.call(1, 'Reading codebase…');
    final fileList = await _listRepoFiles(effectiveRepo);

    onProgress?.call(2, 'Generating architecture diagram…');
    final diagram = await _generateDiagram(features, fileList);

    onProgress?.call(3, 'Mapping components…');
    final componentMap = await _generateComponentMap(features, fileList, diagram);

    return ArchitectureResult(diagram: diagram, componentMap: componentMap);
  }

  // ── Phase 2: Mermaid diagram ─────────────────────────────────────────────

  Future<String> _generateDiagram(
      List<Feature> features, List<String> fileList) async {
    const sys = '''
You are a software architect. Given a list of tracked features and repository
files, generate a concise Mermaid flowchart (flowchart TD) of the system's
architecture. Show the main components, their relationships, and primary data
flows.

Rules:
- 8–15 nodes maximum — stay high-level, group low-level files into subsystems
- Use meaningful subsystem names (e.g. UI Layer, Data Layer, LLM Service)
- Arrow labels should be short (1–3 words) describing the flow
- Do NOT include individual file names as nodes
- Return ONLY the raw Mermaid source starting with "flowchart TD", no fences, no prose
''';
    final featureTitles = features.map((f) => '- ${f.title}').join('\n');
    final user = 'Tracked features:\n$featureTitles\n\n'
        'Repository files (${fileList.length} total, sample):\n'
        '${fileList.take(150).join('\n')}';

    try {
      final raw = await _llm.complete(
        systemPrompt: sys,
        userPrompt: user,
        temperature: 0.3,
        role: LlmRole.architectureAnalyst,
        think: false,
      );
      return _cleanDiagram(raw);
    } catch (_) {
      return _fallbackDiagram(features);
    }
  }

  // ── Phase 3: Component map ───────────────────────────────────────────────

  Future<Map<String, List<String>>> _generateComponentMap(
    List<Feature> features,
    List<String> fileList,
    String diagram,
  ) async {
    const sys = '''
You are a software architect. Given a Mermaid architecture diagram and a
repository file list, produce a JSON component map: which files belong to
which architectural component from the diagram.

Respond with ONLY this JSON (no prose, no fences):
{"components":{"ComponentName":["path/to/file.dart"]}}
''';
    final user = 'Architecture diagram:\n$diagram\n\n'
        'Repository files (${fileList.length} total, sample):\n'
        '${fileList.take(150).join('\n')}';

    try {
      final raw = await _llm.complete(
        systemPrompt: sys,
        userPrompt: user,
        temperature: 0.2,
        role: LlmRole.architectureAnalyst,
        think: false,
        jsonMode: true,
      );
      final decoded = jsonDecode(_extractJson(raw)) as Map<String, dynamic>;
      final components = decoded['components'] as Map<String, dynamic>?;
      if (components == null) return {};
      return components.map((k, v) => MapEntry(
            k,
            (v as List).map((e) => e.toString()).toList(),
          ));
    } catch (_) {
      return {};
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _cleanDiagram(String raw) {
    var t = raw.trim();
    // Strip code fences if present
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      final end = t.lastIndexOf('```');
      if (end != -1) t = t.substring(0, end).trim();
    }
    // If the model returned a JSON blob instead of Mermaid, use fallback
    if (t.startsWith('{') || t.startsWith('[')) return '';
    return t;
  }

  String _fallbackDiagram(List<Feature> features) {
    final nodes = features.take(8).map((f) {
      final id = f.id.replaceAll('-', '_').substring(0, 8);
      final label = f.title.length > 30
          ? '${f.title.substring(0, 27)}…'
          : f.title;
      return '    $id["$label"]';
    }).join('\n');
    return 'flowchart TD\n$nodes';
  }

  /// Uses `git ls-files` then falls back to a filesystem walk. Caps at 400.
  Future<List<String>> _listRepoFiles(String repoPath) async {
    try {
      final res =
          await Process.run('git', ['ls-files'], workingDirectory: repoPath);
      if (res.exitCode == 0) {
        final lines = res.stdout
            .toString()
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        if (lines.isNotEmpty) return _cap(lines);
      }
    } catch (_) {}

    const skip = {
      '.git', 'node_modules', 'build', '.dart_tool', 'dist', '.idea',
      'Pods', '.gradle', 'vendor', '__pycache__', '.next', 'target',
    };
    final out = <String>[];
    try {
      await for (final entity in Directory(repoPath).list(recursive: true)) {
        if (entity is! File) continue;
        final rel = p.relative(entity.path, from: repoPath);
        if (rel.split(p.separator).any(skip.contains)) continue;
        out.add(rel);
        if (out.length >= 500) break;
      }
    } catch (_) {}
    return _cap(out);
  }

  List<String> _cap(List<String> list) =>
      list.length > 400 ? list.sublist(0, 400) : list;

  String _extractJson(String raw) {
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
}
