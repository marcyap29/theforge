import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../services/llm/llm_provider.dart';
import '../../services/llm/llm_service.dart';
import '../../services/llm/llm_service_provider.dart';

/// Result of an import: the interview's structured `extracted` state, plus any
/// open questions the LLM couldn't answer from the material (the gaps).
class ImportResult {
  ImportResult({required this.extracted, required this.openQuestions});
  final Map<String, dynamic> extracted;
  final List<String> openQuestions;
}

/// Turns imported material (a description, a doc, a chat transcript, and/or a
/// scanned repo) into the interview's structured `extracted` state in one LLM
/// call — so the existing spec/worksheet/handoff generators produce the same
/// deliverables an interview would, and so gaps can be surfaced for the user.
class ImportService {
  ImportService(this._llm);
  final LlmService _llm;

  static const _docExts = {'.md', '.markdown', '.mdx', '.txt', '.rst'};
  static const _codeExts = {
    '.dart', '.ts', '.tsx', '.js', '.jsx', '.py', '.go', '.rs', '.swift',
    '.kt', '.java', '.rb', '.cs', '.cpp', '.c', '.h', '.php',
  };
  static const _manifests = {
    'pubspec.yaml', 'package.json', 'Cargo.toml', 'go.mod',
    'requirements.txt', 'pyproject.toml', 'build.gradle', 'Gemfile',
  };

  /// Gathers a repository into a text digest, docs-first so truncation drops
  /// the file list before the meaningful prose. [deep] additionally pulls in
  /// the content of key source files for higher fidelity on undocumented code.
  Future<String> repoDigest(String repoPath, {bool deep = false}) async {
    final files = await _listFiles(repoPath);
    final buf = StringBuffer()..writeln('# Repository: ${p.basename(repoPath)}');

    // README first, in full-ish.
    final readme = files.firstWhere(
      (f) => p.basename(f).toLowerCase() == 'readme.md',
      orElse: () => '',
    );
    if (readme.isNotEmpty) {
      buf..writeln('\n## README\n')..writeln(await _read(repoPath, readme, 6000));
    }

    // Other docs.
    final docs = files
        .where((f) =>
            _docExts.contains(p.extension(f).toLowerCase()) &&
            p.basename(f).toLowerCase() != 'readme.md')
        .take(deep ? 40 : 20)
        .toList();
    if (docs.isNotEmpty) {
      buf.writeln('\n## Documentation files');
      for (final d in docs) {
        buf..writeln('\n### $d\n')..writeln(await _read(repoPath, d, deep ? 3000 : 1500));
      }
    }

    // Manifests (dependencies / platform hints).
    final manifests = files.where((f) => _manifests.contains(p.basename(f)));
    for (final m in manifests) {
      buf..writeln('\n### $m\n')..writeln(await _read(repoPath, m, 1200));
    }

    // Deep: sample source files.
    if (deep) {
      final code = files
          .where((f) => _codeExts.contains(p.extension(f).toLowerCase()))
          .take(20)
          .toList();
      if (code.isNotEmpty) {
        buf.writeln('\n## Source samples');
        for (final c in code) {
          buf..writeln('\n### $c\n')..writeln(await _read(repoPath, c, 1200));
        }
      }
    }

    // File tree last (cheapest to truncate away).
    buf
      ..writeln('\n## Files (${files.length})')
      ..writeln(files.take(400).join('\n'));
    return buf.toString();
  }

  Future<List<String>> _listFiles(String repoPath) async {
    try {
      final res =
          await Process.run('git', ['ls-files'], workingDirectory: repoPath);
      if (res.exitCode == 0) {
        final lines = res.stdout
            .toString()
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        if (lines.isNotEmpty) return lines;
      }
    } catch (_) {}
    // Fallback walk.
    const skip = {
      '.git', 'node_modules', 'build', '.dart_tool', 'dist', 'Pods',
      '.gradle', 'vendor', '__pycache__', '.next', 'target',
    };
    final out = <String>[];
    try {
      await for (final e in Directory(repoPath).list(recursive: true)) {
        if (e is! File) continue;
        final rel = p.relative(e.path, from: repoPath);
        if (rel.split(p.separator).any(skip.contains)) continue;
        out.add(rel);
        if (out.length >= 600) break;
      }
    } catch (_) {}
    return out;
  }

  Future<String> _read(String repoPath, String rel, int cap) async {
    try {
      final c = await File(p.join(repoPath, rel)).readAsString();
      return c.length > cap ? '${c.substring(0, cap)}\n…(truncated)' : c;
    } catch (_) {
      return '(unreadable)';
    }
  }

  Future<ImportResult> extract(String source) async {
    final trimmed =
        source.length > 16000 ? source.substring(0, 16000) : source;
    final raw = await _llm.complete(
      role: LlmRole.architect,
      temperature: 0.3,
      maxTokens: 2500,
      systemPrompt: _systemPrompt,
      userPrompt: trimmed,
    );
    return _parse(raw);
  }

  static const _systemPrompt = '''
You are a product analyst. Read the provided material (a description, document,
chat transcript, and/or repository digest) and distill it into the state a
product-scoping interview would establish.

Fill only what the material actually supports. If a field is not clearly
determinable, leave it null / an empty list — do NOT guess — and instead add a
short, specific question to "openQuestions" so a human can fill that gap.

Respond with ONLY this JSON object, no prose, no code fences:
{
  "outcome": string|null,                  // the single primary thing this product does
  "primaryUser": string|null,              // who it is for
  "capabilities": [string],                // 3-6 capabilities needed to deliver the outcome
  "chosenCapability": string|null,         // the one capability that proves the concept (V1)
  "userStories": [string],
  "v1UserStories": [string],               // stories committed to V1
  "demoScript": [string],                  // ordered steps that demo the full V1 flow
  "v2Seeds": [string],                     // deferred ideas
  "platform": string|null,                 // e.g. "macOS desktop", "web"
  "identityModel": string|null,            // auth/identity approach, or "none"
  "inputModel": string|null,
  "outputModel": string|null,
  "externalServices": [{"name": string, "purpose": string}],
  "openQuestions": [string]                // specific gaps you could not determine
}
''';

  ImportResult _parse(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\n'), '');
      final end = text.lastIndexOf('```');
      if (end != -1) text = text.substring(0, end);
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      text = text.substring(start, end + 1);
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('Import did not return a JSON object.');
    }
    final m = decoded.cast<String, dynamic>();

    List<String> strList(dynamic v) => v is List
        ? v.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList()
        : <String>[];
    String? str(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty || s.toLowerCase() == 'null') ? null : s;
    }

    final services = <Map<String, dynamic>>[];
    if (m['externalServices'] is List) {
      for (final e in m['externalServices'] as List) {
        if (e is Map) {
          services.add({
            'name': e['name']?.toString() ?? '',
            'purpose': e['purpose']?.toString() ?? '',
          });
        } else if (e != null) {
          services.add({'name': e.toString(), 'purpose': ''});
        }
      }
    }

    return ImportResult(
      extracted: {
        'outcome': str(m['outcome']),
        'primaryUser': str(m['primaryUser']),
        'capabilities': strList(m['capabilities']),
        'chosenCapability': str(m['chosenCapability']),
        'userStories': strList(m['userStories']),
        'v1UserStories': strList(m['v1UserStories']),
        'demoScript': strList(m['demoScript']),
        'v2Seeds': strList(m['v2Seeds']),
        'platform': str(m['platform']),
        'identityModel': str(m['identityModel']),
        'inputModel': str(m['inputModel']),
        'outputModel': str(m['outputModel']),
        'externalServices': services,
      },
      openQuestions: strList(m['openQuestions']),
    );
  }
}

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(ref.watch(llmServiceProvider)),
);
