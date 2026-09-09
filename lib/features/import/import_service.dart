import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../services/llm/llm_provider.dart';
import '../../services/llm/llm_service.dart';
import '../../services/llm/llm_service_provider.dart';

/// Turns imported material (a description, a doc, a chat transcript, and/or a
/// linked repo) into the interview's structured `extracted` state in one LLM
/// call — so the existing spec/worksheet/handoff generators can produce the
/// same deliverables an interview would.
class ImportService {
  ImportService(this._llm);
  final LlmService _llm;

  /// Optional repo digest (README + tracked file list) appended to the source.
  Future<String> repoDigest(String repoPath) async {
    final buffer = StringBuffer()..writeln('## Linked repository digest');
    for (final name in const ['README.md', 'readme.md', 'README.MD']) {
      final f = File(p.join(repoPath, name));
      if (f.existsSync()) {
        final c = await f.readAsString();
        buffer
          ..writeln('### README')
          ..writeln(c.length > 6000 ? c.substring(0, 6000) : c);
        break;
      }
    }
    try {
      final res = await Process.run('git', ['ls-files'], workingDirectory: repoPath);
      if (res.exitCode == 0) {
        final files = res.stdout
            .toString()
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .take(300)
            .toList();
        buffer
          ..writeln('### Files (${files.length})')
          ..writeln(files.join('\n'));
      }
    } catch (_) {}
    return buffer.toString();
  }

  Future<Map<String, dynamic>> extract(String source) async {
    final trimmed =
        source.length > 14000 ? source.substring(0, 14000) : source;
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
chat transcript, and/or repository digest) and distill it into a single JSON
object capturing what a product-scoping interview would establish. Infer
sensible values; if something is genuinely unknowable, use null or an empty list.

Respond with ONLY this JSON object, no prose, no code fences:
{
  "outcome": string,                       // the single primary thing this product does
  "primaryUser": string,                   // who it is for
  "capabilities": [string],                // 3-6 capabilities needed to deliver the outcome
  "chosenCapability": string,              // the one capability that proves the concept (V1)
  "userStories": [string],                 // key user stories
  "v1UserStories": [string],               // the stories committed to V1
  "demoScript": [string],                  // ordered steps that demo the full V1 flow
  "v2Seeds": [string],                     // deferred ideas for later
  "platform": string,                      // e.g. "macOS desktop", "web", "iOS"
  "identityModel": string,                 // auth/identity approach, or "none"
  "inputModel": string,                    // how users provide input
  "outputModel": string,                   // how results are delivered
  "externalServices": [{"name": string, "purpose": string}]
}
''';

  Map<String, dynamic> _parse(String raw) {
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

    return {
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
    };
  }
}

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(ref.watch(llmServiceProvider)),
);
