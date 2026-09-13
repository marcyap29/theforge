import 'dart:convert';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service.dart';
import '../models/run_session.dart';
import 'impl_workspace.dart';

class ImplAgentException implements Exception {
  ImplAgentException(this.message, {this.raw});
  final String message;

  /// The raw model output that couldn't be parsed — surfaced to the console so
  /// the user can see (and copy) exactly what the model returned.
  final String? raw;

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
    String? ingestedContext,
    String? buildMemory,
    List<DocPoolEntry> docManifest = const [],
    Future<String> Function(String id)? readDoc,
    List<String> components = const [],
    AgentPlan? previousPlan,
    String? feedback,
    void Function(String text, bool thinking)? onDelta,
    void Function(String status)? onStatus,
  }) async {
    final files = await ImplWorkspace.gatherRepoFiles(repoPath);
    final keyDocs = await ImplWorkspace.gatherKeyDocs(repoPath);
    var context = buildUserContext(
      featureTitle: featureTitle,
      featureDescription: featureDescription,
      targetVersion: targetVersion,
      lockedSpec: lockedSpec,
      goalStatement: goalStatement,
      ingestedContext: ingestedContext,
      buildMemory: buildMemory,
      components: components,
      files: files,
      keyDocs: keyDocs,
    );
    // Fold the user's instruction into the context. A first build frames it as
    // "what the user asked for"; a later one as a revision of the prior plan.
    if (feedback != null && feedback.trim().isNotEmpty) {
      context += previousPlan != null
          ? _revisionBlock(previousPlan, feedback.trim())
          : '\n\n## What the user asked you to build\n${feedback.trim()}\n';
    }

    // Offer the scout the doc pool ONLY for pools too big to sit fully in the
    // always-on context above — a small pool is already shown in full, so there
    // is nothing to fetch. This is "always-on core + scouted extras" applied to
    // the reference-doc and build-memory pools: they become scoutable exactly
    // when they overflow their cap and get trimmed above.
    final refOverflow = (ingestedContext?.length ?? 0) > _refCap;
    final memOverflow = (buildMemory?.length ?? 0) > _memCap;
    final offered = docManifest
        .where((e) =>
            (e.kind == 'reference' && refOverflow) ||
            (e.kind == 'build-memory' && memOverflow))
        .toList();
    final manifestBlock = offered.isEmpty
        ? ''
        : '\n\n## Extra reference material available'
            '\nThese are NOT fully shown above. Request any you need by "id".\n'
            '${offered.map((e) => '- ${e.id} — ${e.title}: ${e.preview}').join('\n')}';

    // --- Pass 1 — Scout: which existing files does it need to read? ---
    onStatus?.call('Choosing which files to read…');
    final scoutRaw = await _stream(
      system: _scoutSystemPrompt,
      user: '$context$manifestBlock\n\nReturn ONLY: '
          '{"files": ["repo/relative/path", …], "docs": ["ref:…", "mem:…"]} '
          '(at most 12 files; "docs" only from the ids listed above, [] if '
          'none). Always include any data-model / schema / drift database file '
          'the feature touches.',
      temperature: 0.1,
      maxTokens: 4000,
      onDelta: onDelta,
    );
    final wanted = _parseKeyList(scoutRaw, 'files');
    final wantedDocs = offered.isEmpty
        ? const <String>[]
        : _parseKeyList(scoutRaw, 'docs')
            .where((id) => offered.any((e) => e.id == id))
            .toList();

    // Read the chosen files (bounded) so Pass 2 edits real code, not guesses.
    // Files are given whole up to a generous cap — a truncated file makes the
    // model's find/replace hunks miss (or, worse under full-file mode, drop
    // code), so we keep as much as the budget allows.
    final readFiles = <String, String>{};
    var budget = 90000;
    for (final rel in wanted) {
      if (readFiles.length >= 12 || budget <= 0) break;
      final content = await ImplWorkspace.readRepoFile(repoPath, rel);
      if (content.isEmpty) continue;
      var c = content;
      if (c.length > 24000) c = '${c.substring(0, 24000)}\n…(truncated)';
      if (c.length > budget) c = c.substring(0, budget);
      readFiles[rel] = c;
      budget -= c.length;
    }
    // Pull the doc-pool entries the scout asked for (bounded), skipping any
    // whose text is already present in the always-on context above (dedupe —
    // an entry that survived the trim is already there).
    final readDocs = <String, String>{};
    if (readDoc != null && wantedDocs.isNotEmpty) {
      var docBudget = 40000;
      for (final id in wantedDocs) {
        if (readDocs.length >= 8 || docBudget <= 0) break;
        final text = (await readDoc(id)).trim();
        if (text.isEmpty || context.contains(text)) continue;
        var t = text;
        if (t.length > 12000) t = '${t.substring(0, 12000)}\n…(truncated)';
        if (t.length > docBudget) t = t.substring(0, docBudget);
        readDocs[id] = t;
        docBudget -= t.length;
      }
    }

    final readSummary = StringBuffer();
    if (readFiles.isNotEmpty) {
      readSummary.write(
          'Read ${readFiles.length} file(s): ${readFiles.keys.join(', ')}');
    }
    if (readDocs.isNotEmpty) {
      if (readSummary.isNotEmpty) readSummary.write(' · ');
      readSummary
          .write('${readDocs.length} reference doc(s): ${readDocs.keys.join(', ')}');
    }
    onStatus?.call(readSummary.isEmpty
        ? 'No matching files to read — planning from docs…'
        : readSummary.toString());

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
    if (readDocs.isNotEmpty) {
      planUser.writeln('\n\n## Retrieved reference material');
      readDocs.forEach((id, content) {
        planUser
          ..writeln('### $id')
          ..writeln(content)
          ..writeln();
      });
    }
    final planUserStr = planUser.toString();
    final planRaw = await _stream(
      system: _systemPrompt,
      user: planUserStr,
      temperature: 0.2,
      maxTokens: 16000,
      onDelta: onDelta,
    );
    try {
      return _parse(planRaw, repoPath);
    } on ImplAgentException {
      // Reasoning models sometimes spend the turn thinking and never emit a
      // clean JSON object. Ask once more, firmly, for JSON only.
      onStatus?.call('Tidying the plan into valid JSON…');
      final retry = await _stream(
        system: _systemPrompt,
        user: '$planUserStr\n\nIMPORTANT: your previous reply was NOT a single '
            'valid JSON object. Output ONLY the JSON object now — no prose, no '
            'code fences, and do not ask to open more files. Use what you have.',
        temperature: 0.1,
        maxTokens: 16000,
        onDelta: onDelta,
      );
      return _parse(retry, repoPath);
    }
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

  /// Reads a JSON string array under [key] from a possibly-fenced scout reply.
  List<String> _parseKeyList(String raw, String key) {
    try {
      final obj = jsonDecode(_extractJsonObject(raw));
      if (obj is Map && obj[key] is List) {
        return (obj[key] as List)
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

If an "Extra reference material available" list is present, also pick the "id"s
of any entries whose full text you need (e.g. a reference doc or a prior feature
you should follow). Only pick ids from that list; if none apply, use [].

Respond with ONLY a JSON object, no prose, no code fences:
{"files": ["lib/path/one.dart", "lib/path/two.dart"], "docs": ["ref:Foo.facts.md"]}
Choose real paths from the file list. Return at most 12 files, fewest that suffice.
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
the SPEC to follow the codebase's existing structure and conventions.

HOW TO EDIT — do NOT rewrite whole files. For each EXISTING file you change,
return a small set of "hunks". Each hunk's "find" is an EXACT, verbatim copy of
a snippet that currently exists in that file (copy it character-for-character,
including whitespace, and include enough surrounding lines to be UNIQUE within
the file); "replace" is the new text that should take its place. Change only
what is needed. For a brand-NEW file, return "content" (the whole file) instead
of hunks. Never return whole-file "content" for a file that already exists.

You already have all the files you are going to get (their CURRENT contents are
provided below). Do NOT ask to open more files and do NOT stop to explain — if a
detail is uncertain, make your best reasonable choice and proceed. Your entire
final answer MUST be the JSON object.

First, briefly narrate your plan in 1-3 short sentences of plain English so the
user can follow your thinking. THEN output the JSON object (and nothing after
it). The JSON must be a single top-level object with no code fences:
{
  "summary": "ONE short sentence telling the user what you will do",
  "rationale": "one short paragraph on your approach",
  "edits": [
    {"path": "lib/existing.dart", "rationale": "why",
     "hunks": [{"find": "exact snippet copied from the file", "replace": "new snippet"}]},
    {"path": "lib/brand_new_file.dart", "rationale": "why",
     "content": "FULL content of the NEW file"}
  ],
  "commands": [
    {"human": "plain-English description", "raw": "exact command line"}
  ]
}
''';

  /// Always-on char caps for the reference-doc and build-memory slots. The same
  /// values gate the doc-aware scout: a pool over its cap is trimmed above and
  /// therefore offered to the scout for on-demand retrieval. Keep the slot and
  /// the overflow check reading the SAME constant so they never drift.
  static const _refCap = 12000;
  static const _memCap = 8000;

  /// Trims [s] to [cap] characters, appending a VISIBLE marker when it must cut
  /// so the user (and the model) can see context was dropped, rather than losing
  /// it silently. The old code hard-cut the spec at 6k chars with no signal.
  static String _cap(String s, int cap, {required String what}) {
    if (s.length <= cap) return s;
    final dropped = s.length - cap;
    return '${s.substring(0, cap)}\n'
        '…($what trimmed — $dropped chars dropped; move the load-bearing detail '
        'to the top of the spec or a reference doc)';
  }

  /// Builds the always-on context block the plan is grounded in: the feature,
  /// project goal, locked spec, ingested reference docs, project documentation,
  /// and the repo file list. Public + static so it can be unit-tested directly.
  static String buildUserContext({
    required String featureTitle,
    String? featureDescription,
    String? targetVersion,
    String? lockedSpec,
    String? goalStatement,
    String? ingestedContext,
    String? buildMemory,
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
      b
        ..writeln('## Locked spec (context)')
        ..writeln(_cap(lockedSpec.trim(), 12000, what: 'spec'))
        ..writeln();
    }
    // The ingested reference pool — the SAME context the interview and spec
    // stages already use. Wiring it in here is what stops the builder from
    // starting cold on every feature.
    if (ingestedContext != null && ingestedContext.trim().isNotEmpty) {
      b
        ..writeln('## Reference context (ingested documents)')
        ..writeln(_cap(ingestedContext.trim(), _refCap, what: 'reference context'))
        ..writeln();
    }
    // Durable memory of what already shipped on this project — so the model
    // follows established patterns and file layout instead of reinventing them.
    // Grows one record per shipped feature (ProjectFileRepository.writeBuildMemory).
    if (buildMemory != null && buildMemory.trim().isNotEmpty) {
      b
        ..writeln('## Prior builds on this project '
            '(what shipped before — reuse these patterns and files)')
        ..writeln(_cap(buildMemory.trim(), _memCap, what: 'build memory'))
        ..writeln();
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
      throw ImplAgentException('The agent did not return valid JSON.', raw: raw);
    }
    if (decoded is! Map) {
      throw ImplAgentException('The agent response was not a JSON object.',
          raw: raw);
    }

    final rationale = (decoded['rationale'] ?? '').toString().trim();
    final summary = (decoded['summary'] ?? '').toString().trim();

    final edits = <ProposedEdit>[];
    for (final e in (decoded['edits'] as List?) ?? const []) {
      if (e is! Map) continue;
      final path = (e['path'] ?? '').toString().trim();
      if (path.isEmpty) continue;
      // Never let the model write outside the linked repo.
      if (!ImplWorkspace.isPathSafe(repoPath, path)) continue;
      final oldContent = await ImplWorkspace.readRepoFile(repoPath, path);
      var rationale = (e['rationale'] ?? '').toString().trim();
      final content = e['content']?.toString();
      final hunks = e['hunks'] as List?;

      String newContent;
      if (oldContent.isEmpty) {
        // New file: full content required.
        if (content == null || content.isEmpty) continue;
        newContent = content;
      } else if (hunks != null && hunks.isNotEmpty) {
        // Existing file: apply exact-match find/replace hunks.
        newContent = oldContent;
        var missed = 0;
        for (final h in hunks) {
          if (h is! Map) continue;
          final find = h['find']?.toString();
          final replace = h['replace']?.toString() ?? '';
          if (find == null || find.isEmpty) continue;
          if (newContent.contains(find)) {
            newContent = newContent.replaceFirst(find, replace);
          } else {
            missed++;
          }
        }
        if (newContent == oldContent) continue; // nothing applied — drop it
        if (missed > 0) {
          rationale = rationale.isEmpty
              ? '$missed change(s) could not be located and were skipped'
              : '$rationale (note: $missed change(s) could not be located)';
        }
      } else if (content != null && content.isNotEmpty) {
        // Fallback: the model returned whole-file content for an existing file.
        newContent = content;
      } else {
        continue;
      }

      edits.add(ProposedEdit(
        path: path,
        rationale: rationale,
        oldContent: oldContent,
        newContent: newContent,
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
          'The agent proposed no changes. Try refining the feature description.',
          raw: raw);
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
