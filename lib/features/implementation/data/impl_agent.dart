import 'dart:convert';

import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service.dart';
import '../models/run_session.dart';
import 'impl_workspace.dart';

class ImplAgentException implements Exception {
  ImplAgentException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The "brains" of the implementation agent. Given one tracked feature plus the
/// project's spec/handoff as context and the linked repo's file list, it asks
/// the LLM for a concrete, approvable plan: full file contents to write and
/// shell commands to run. Reuses the shared [LlmService] (executor role) — the
/// same one-shot pattern as the rest of the app (no streaming/tool-calling yet).
class ImplAgent {
  ImplAgent(this._llm);

  final LlmService _llm;

  Future<AgentPlan> proposePlan({
    required String featureTitle,
    String? featureDescription,
    String? targetVersion,
    required String repoPath,
    String? lockedSpec,
    String? goalStatement,
    List<String> components = const [],
    AgentPlan? previousPlan,
    String? feedback,
    void Function(String text, bool thinking)? onDelta,
    void Function(String status)? onStatus,
  }) async {
    final files = await ImplWorkspace.gatherRepoFiles(repoPath);
    final keyDocs = await ImplWorkspace.gatherKeyDocs(repoPath);
    var context = _userPrompt(
      featureTitle: featureTitle,
      featureDescription: featureDescription,
      targetVersion: targetVersion,
      lockedSpec: lockedSpec,
      goalStatement: goalStatement,
      components: components,
      files: files,
      keyDocs: keyDocs,
    );
    // Revision: fold the previous plan + the user's steering into the context
    // so both passes take it into account.
    if (feedback != null && feedback.trim().isNotEmpty) {
      context += _revisionBlock(previousPlan, feedback.trim());
    }

    // --- Pass 1 — Scout: which existing files does it need to read? ---
    onStatus?.call('Choosing which files to read…');
    final scoutRaw = await _stream(
      system: _scoutSystemPrompt,
      user: '$context\n\nReturn ONLY: '
          '{"files": ["repo/relative/path", …]} (at most 12 files).',
      temperature: 0.1,
      maxTokens: 1200,
      onDelta: onDelta,
    );
    final wanted = _parseFileList(scoutRaw);

    // Read the chosen files (bounded) so Pass 2 edits real code, not guesses.
    final readFiles = <String, String>{};
    var budget = 40000;
    for (final rel in wanted) {
      if (readFiles.length >= 12 || budget <= 0) break;
      final content = await ImplWorkspace.readRepoFile(repoPath, rel);
      if (content.isEmpty) continue;
      var c = content;
      if (c.length > 6000) c = '${c.substring(0, 6000)}\n…(truncated)';
      if (c.length > budget) c = c.substring(0, budget);
      readFiles[rel] = c;
      budget -= c.length;
    }
    onStatus?.call(readFiles.isEmpty
        ? 'No matching files to read — planning from docs…'
        : 'Read ${readFiles.length} file(s): ${readFiles.keys.join(', ')}');

    // --- Pass 2 — Plan: propose edits/commands grounded in the file bodies. ---
    onStatus?.call('Writing the plan…');
    final planUser = StringBuffer(context);
    if (readFiles.isNotEmpty) {
      planUser.writeln('\n\n## Current file contents (edit these accurately)');
      readFiles.forEach((path, content) {
        planUser
          ..writeln('### $path')
          ..writeln('```')
          ..writeln(content)
          ..writeln('```')
          ..writeln();
      });
    }
    final planRaw = await _stream(
      system: _systemPrompt,
      user: planUser.toString(),
      temperature: 0.2,
      maxTokens: 4000,
      onDelta: onDelta,
    );
    return _parse(planRaw, repoPath);
  }

  /// Streams one completion, forwarding deltas for live display and returning
  /// the accumulated CONTENT (reasoning is shown but not part of the answer).
  Future<String> _stream({
    required String system,
    required String user,
    required double temperature,
    required int maxTokens,
    void Function(String text, bool thinking)? onDelta,
  }) async {
    final buffer = StringBuffer();
    await for (final delta in _llm.completeStream(
      role: LlmRole.executor,
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: system,
      userPrompt: user,
    )) {
      if (!delta.thinking) buffer.write(delta.text);
      onDelta?.call(delta.text, delta.thinking);
    }
    return buffer.toString();
  }

  String _revisionBlock(AgentPlan? prev, String feedback) {
    final b = StringBuffer()
      ..writeln()
      ..writeln('## Revise the previous plan');
    if (prev != null) {
      b.writeln('Your previous plan was:');
      if (prev.summary.isNotEmpty) b.writeln('- summary: ${prev.summary}');
      for (final e in prev.edits) {
        b.writeln('- edit: ${e.path}');
      }
      for (final c in prev.commands) {
        b.writeln('- command: ${c.raw}');
      }
    }
    b
      ..writeln()
      ..writeln('The user wants you to change it. Their instruction:')
      ..writeln('"$feedback"')
      ..writeln('Produce a NEW complete plan that follows this instruction. '
          'Keep the parts that were fine; change what they asked.');
    return b.toString();
  }

  List<String> _parseFileList(String raw) {
    try {
      final obj = jsonDecode(_extractJsonObject(raw));
      if (obj is Map && obj['files'] is List) {
        return (obj['files'] as List)
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  static const _scoutSystemPrompt = '''
You are preparing to implement ONE feature in an existing repo. Before writing
any code, decide which EXISTING files you need to read to do it well — the files
you will likely edit, plus any you must understand (models, providers, related
widgets). Use the DOCUMENTATION, SPEC, and the repo FILE LIST to choose.

Respond with ONLY a JSON object, no prose, no code fences:
{"files": ["lib/path/one.dart", "lib/path/two.dart"]}
Choose real paths from the file list. Return at most 12, fewest that suffice.
''';

  static const _systemPrompt = '''
You are an implementation agent working INSIDE a desktop app, on behalf of a
non-technical builder. You implement ONE feature at a time in an existing code
repository. You cannot run commands freely — you PROPOSE a plan the user
approves step by step, so keep it small, safe, and concrete.

Given the FEATURE and the project CONTEXT (spec/handoff) and the repo FILE LIST,
produce a plan to implement just that feature. For each file you change, return
the COMPLETE new content of that file (not a diff) so it can be written
directly. Only include files you actually change. Prefer the smallest set of
edits that implements the feature. Commands should be limited to safe,
non-interactive build/test/dependency steps (e.g. install deps, run tests).
Never propose destructive commands (rm -rf, git reset --hard, force-push).

Use the provided project DOCUMENTATION (README, architecture, agent guide) and
the SPEC to follow the codebase's existing structure and conventions. When
CURRENT FILE CONTENTS are provided, base your edits on that exact code —
preserve everything you are not intentionally changing (do not drop imports,
methods, or unrelated code); return the COMPLETE updated file.

First, briefly narrate your plan in 1-3 short sentences of plain English so the
user can follow your thinking. THEN output the JSON object (and nothing after
it). The JSON must be a single top-level object with no code fences:
{
  "summary": "ONE short sentence telling the user what you will do",
  "rationale": "one short paragraph on your approach",
  "edits": [
    {"path": "repo/relative/path.ext", "rationale": "why", "content": "FULL new file content"}
  ],
  "commands": [
    {"human": "plain-English description", "raw": "exact command line"}
  ]
}
''';

  String _userPrompt({
    required String featureTitle,
    String? featureDescription,
    String? targetVersion,
    String? lockedSpec,
    String? goalStatement,
    List<String> components = const [],
    required List<String> files,
    String? keyDocs,
  }) {
    final b = StringBuffer()
      ..writeln('# Feature to implement')
      ..writeln('Title: $featureTitle');
    if (featureDescription != null && featureDescription.trim().isNotEmpty) {
      b.writeln('Description: $featureDescription');
    }
    if (targetVersion != null && targetVersion.trim().isNotEmpty) {
      b.writeln('Target version: $targetVersion');
    }
    b.writeln();
    if (goalStatement != null && goalStatement.trim().isNotEmpty) {
      b..writeln('## Project goal')..writeln(goalStatement.trim())..writeln();
    }
    if (components.isNotEmpty) {
      b
        ..writeln('## Known components')
        ..writeln(components.join(', '))
        ..writeln();
    }
    if (lockedSpec != null && lockedSpec.trim().isNotEmpty) {
      var spec = lockedSpec.trim();
      if (spec.length > 6000) spec = '${spec.substring(0, 6000)}\n…(truncated)';
      b..writeln('## Locked spec (context)')..writeln(spec)..writeln();
    }
    if (keyDocs != null && keyDocs.trim().isNotEmpty) {
      b
        ..writeln('## Project documentation (context)')
        ..writeln(keyDocs.trim())
        ..writeln();
    }
    b
      ..writeln('## Repo files (${files.length})')
      ..writeln(files.join('\n'));
    return b.toString();
  }

  Future<AgentPlan> _parse(String raw, String repoPath) async {
    final jsonText = _extractJsonObject(raw);
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      throw ImplAgentException('The agent did not return valid JSON.');
    }
    if (decoded is! Map) {
      throw ImplAgentException('The agent response was not a JSON object.');
    }

    final rationale = (decoded['rationale'] ?? '').toString().trim();
    final summary = (decoded['summary'] ?? '').toString().trim();

    final edits = <ProposedEdit>[];
    for (final e in (decoded['edits'] as List?) ?? const []) {
      if (e is! Map) continue;
      final path = (e['path'] ?? '').toString().trim();
      final content = e['content']?.toString();
      if (path.isEmpty || content == null) continue;
      final oldContent = await ImplWorkspace.readRepoFile(repoPath, path);
      edits.add(ProposedEdit(
        path: path,
        rationale: (e['rationale'] ?? '').toString().trim(),
        oldContent: oldContent,
        newContent: content,
      ));
    }

    final commands = <ProposedCommand>[];
    for (final c in (decoded['commands'] as List?) ?? const []) {
      if (c is! Map) continue;
      final rawCmd = (c['raw'] ?? '').toString().trim();
      if (rawCmd.isEmpty) continue;
      commands.add(ProposedCommand(
        human: (c['human'] ?? rawCmd).toString().trim(),
        raw: rawCmd,
      ));
    }

    if (edits.isEmpty && commands.isEmpty) {
      throw ImplAgentException(
          'The agent proposed no changes. Try refining the feature description.');
    }
    return AgentPlan(
      summary: summary.isNotEmpty ? summary : rationale,
      rationale: rationale,
      edits: edits,
      commands: commands,
    );
  }

  /// Extracts the first balanced JSON object from a possibly fenced response.
  static String _extractJsonObject(String raw) {
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
