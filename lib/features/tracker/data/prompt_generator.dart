import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../data/local_db/forge_database.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service.dart';

class PromptGeneratorResult {
  const PromptGeneratorResult({
    required this.impactSummary,
    required this.affectedFiles,
    required this.outOfScopeFiles,
    required this.acceptanceCriteria,
    required this.securityConsiderations,
    required this.prompt,
  });

  final String impactSummary;
  final List<String> affectedFiles;
  final List<String> outOfScopeFiles;
  final String acceptanceCriteria;
  final List<String> securityConsiderations;
  final String prompt;
}

/// 3-phase LLM pipeline that turns a feature card into a Claude Code prompt:
/// impact analysis → acceptance criteria → prompt writing.
class PromptGenerator {
  const PromptGenerator(this._llm);
  final LlmService _llm;

  Future<PromptGeneratorResult> generate({
    required Feature feature,
    required String projectPath,
    required String projectName,
    String? repoPath,
    void Function(int phase, String label)? onProgress,
  }) async {
    final effectiveRepo =
        (repoPath != null && repoPath.isNotEmpty) ? repoPath : projectPath;

    onProgress?.call(1, 'Analyzing impact…');
    final fileList = await _listRepoFiles(effectiveRepo);
    final (affectedFiles, outOfScopeFiles, impactSummary) =
        await _analyzeImpact(feature: feature, fileList: fileList);

    onProgress?.call(2, 'Writing acceptance criteria…');
    final (acceptanceCriteria, securityConsiderations) =
        await _generateAcceptanceCriteria(
      feature: feature,
      affectedFiles: affectedFiles,
      impactSummary: impactSummary,
    );

    onProgress?.call(3, 'Writing Claude Code prompt…');
    final prompt = await _writePrompt(
      feature: feature,
      projectName: projectName,
      affectedFiles: affectedFiles,
      impactSummary: impactSummary,
      acceptanceCriteria: acceptanceCriteria,
      securityConsiderations: securityConsiderations,
    );

    return PromptGeneratorResult(
      impactSummary: impactSummary,
      affectedFiles: affectedFiles,
      outOfScopeFiles: outOfScopeFiles,
      acceptanceCriteria: acceptanceCriteria,
      securityConsiderations: securityConsiderations,
      prompt: prompt,
    );
  }

  // ── Phase 1: Impact Analysis ────────────────────────────────────────────────

  Future<(List<String>, List<String>, String)> _analyzeImpact({
    required Feature feature,
    required List<String> fileList,
  }) async {
    const sys = '''
You are a senior engineer performing a precise impact analysis.
Given a feature request and a list of repository files, identify which files
need modification, which should stay untouched, and summarise the change in
one sentence.

Respond with ONLY this JSON (no prose, no fences):
{"affectedFiles":["path/to/file.dart"],"outOfScopeFiles":["path/to/other.dart"],"impactSummary":"one sentence"}
''';
    final user = 'Feature: ${feature.title}\n'
        '${feature.description != null ? "Description: ${feature.description}\n" : ""}'
        'Repository files (${fileList.length} total, showing ${fileList.take(200).length}):\n'
        '${fileList.take(200).join('\n')}';

    try {
      final raw = await _llm.complete(
        systemPrompt: sys,
        userPrompt: user,
        temperature: 0.2,
        role: LlmRole.architect,
        think: false,
        jsonMode: true,
      );
      final decoded = jsonDecode(_extractJson(raw)) as Map<String, dynamic>;
      final affected = (decoded['affectedFiles'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final outOfScope = (decoded['outOfScopeFiles'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final summary = (decoded['impactSummary'] as String?) ?? '';
      return (affected, outOfScope, summary);
    } catch (_) {
      return (const <String>[], const <String>[], '');
    }
  }

  // ── Phase 2: Acceptance Criteria ───────────────────────────────────────────

  Future<(String, List<String>)> _generateAcceptanceCriteria({
    required Feature feature,
    required List<String> affectedFiles,
    required String impactSummary,
  }) async {
    const sys = '''
You are a senior engineer writing acceptance criteria for a feature.
Produce a concise, testable bulleted list and flag any security considerations
(input validation, auth, data exposure, etc.).

Respond with ONLY this JSON (no prose, no fences):
{"acceptanceCriteria":"- criterion one\\n- criterion two","securityConsiderations":["consideration"]}
''';
    final user = 'Feature: ${feature.title}\n'
        '${feature.description != null ? "Description: ${feature.description}\n" : ""}'
        'Impact: $impactSummary\n'
        'Affected files: ${affectedFiles.take(20).join(", ")}';

    try {
      final raw = await _llm.complete(
        systemPrompt: sys,
        userPrompt: user,
        temperature: 0.3,
        role: LlmRole.architect,
        think: false,
        jsonMode: true,
      );
      final decoded = jsonDecode(_extractJson(raw)) as Map<String, dynamic>;
      final ac = (decoded['acceptanceCriteria'] as String?) ?? '';
      final security = (decoded['securityConsiderations'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      return (ac, security);
    } catch (_) {
      return ('', const <String>[]);
    }
  }

  // ── Phase 3: Prompt Writing ─────────────────────────────────────────────────

  Future<String> _writePrompt({
    required Feature feature,
    required String projectName,
    required List<String> affectedFiles,
    required String impactSummary,
    required String acceptanceCriteria,
    required List<String> securityConsiderations,
  }) async {
    const sys = '''
You are an expert at writing Claude Code implementation prompts.
Write a complete, paste-ready Markdown prompt for Claude Code to implement the
described feature. The prompt must:
- Open with a clear one-sentence goal
- List files to read first (in order), if any
- Specify acceptance criteria as a checklist
- Include security considerations if non-empty
- Close with: run `dart analyze lib/` and confirm zero new warnings

Return ONLY the Markdown prompt. No JSON, no preamble, no trailing note.
''';
    final filesBlock = affectedFiles.isEmpty
        ? ''
        : '\nAffected files: ${affectedFiles.take(20).join(", ")}';
    final secBlock = securityConsiderations.isEmpty
        ? ''
        : '\nSecurity considerations: ${securityConsiderations.join("; ")}';
    final user = 'Project: $projectName\n'
        'Feature: ${feature.title}\n'
        '${feature.description != null ? "Description: ${feature.description}\n" : ""}'
        'Impact: $impactSummary$filesBlock\n'
        'Acceptance criteria:\n$acceptanceCriteria$secBlock';

    try {
      return await _llm.complete(
        systemPrompt: sys,
        userPrompt: user,
        temperature: 0.2,
        role: LlmRole.promptWriter,
      );
    } catch (_) {
      return _buildFallbackPrompt(
        feature: feature,
        projectName: projectName,
        affectedFiles: affectedFiles,
        acceptanceCriteria: acceptanceCriteria,
        securityConsiderations: securityConsiderations,
      );
    }
  }

  String _buildFallbackPrompt({
    required Feature feature,
    required String projectName,
    required List<String> affectedFiles,
    required String acceptanceCriteria,
    required List<String> securityConsiderations,
  }) {
    final sb = StringBuffer()
      ..writeln('# Implement: ${feature.title}')
      ..writeln()
      ..writeln('**Project:** $projectName')
      ..writeln();
    if (feature.description != null) {
      sb
        ..writeln('## Description')
        ..writeln(feature.description)
        ..writeln();
    }
    if (affectedFiles.isNotEmpty) {
      sb.writeln('## Files to read first');
      for (final f in affectedFiles.take(20)) {
        sb.writeln('- `$f`');
      }
      sb.writeln();
    }
    if (acceptanceCriteria.isNotEmpty) {
      sb
        ..writeln('## Acceptance criteria')
        ..writeln(acceptanceCriteria)
        ..writeln();
    }
    if (securityConsiderations.isNotEmpty) {
      sb.writeln('## Security considerations');
      for (final s in securityConsiderations) {
        sb.writeln('- $s');
      }
      sb.writeln();
    }
    sb.writeln(
        'After implementing, run `dart analyze lib/` and confirm zero new warnings.');
    return sb.toString();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

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
