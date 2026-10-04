import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_provider.dart';

/// Google **Gemini** (Generative Language API) provider. BYOK key from
/// aistudio.google.com. One `generateContent` call per [complete]; streaming
/// falls back to the base single-chunk behaviour (no token streaming yet).
class GeminiProvider extends LlmProvider {
  GeminiProvider({required this.apiKey});
  final String apiKey;

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required String modelId,
    int? maxTokens,
    bool? think, // parity — Gemini has no separate thinking toggle here
    bool jsonMode = false,
  }) async {
    final gen = <String, dynamic>{
      'temperature': temperature,
      if (maxTokens != null) 'maxOutputTokens': maxTokens,
      if (jsonMode) 'responseMimeType': 'application/json',
    };
    final body = <String, dynamic>{
      if (systemPrompt.trim().isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userPrompt},
          ],
        },
      ],
      'generationConfig': gen,
    };

    final res = await http.post(
      Uri.parse('$_base/models/$modelId:generateContent?key=$apiKey'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('Gemini error ${res.statusCode}: ${_errorMessage(res.body)}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      final blocked = (data['promptFeedback'] as Map?)?['blockReason'];
      throw Exception(blocked != null
          ? 'Gemini blocked the request ($blocked). Try a different prompt/model.'
          : 'Gemini returned no candidates: ${_truncate(res.body)}');
    }
    final parts = (((candidates.first as Map)['content'] as Map?)?['parts']
            as List<dynamic>?) ??
        const [];
    final text = parts
        .map((p) => (p is Map ? (p['text'] ?? '') : '').toString())
        .join()
        .trim();
    if (text.isEmpty) {
      throw Exception('Gemini returned no text. If the model name ends in '
          '"-image"/imagen/tts/veo it generates media, not text — pick a Flash '
          'or Pro model.');
    }
    return text;
  }

  /// Fetches the live list of Gemini models available to [apiKey] from the
  /// Generative Language API (`GET /v1beta/models`). Filters to models that
  /// support `generateContent` (text generation) and excludes media-only names
  /// (`-image`, `imagen`, `tts`, `veo`, `aqa`, `embedding`). Results are
  /// sorted newest-first (higher version numbers first). Never throws — a
  /// network or auth failure returns an empty list so callers fall back to the
  /// static [geminiModels] seed list.
  static Future<List<({String id, String displayName})>> fetchModels(
      String apiKey) async {
    if (apiKey.isEmpty) return const [];
    try {
      // The API returns at most 50 models by default; page if needed.
      final all = <({String id, String displayName})>[];
      String? pageToken;
      do {
        final uri = Uri.parse('$_base/models').replace(queryParameters: {
          'key': apiKey,
          'pageSize': '50',
          if (pageToken != null) 'pageToken': pageToken,
        });
        final res = await http.get(uri);
        if (res.statusCode != 200) return const [];
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        pageToken = body['nextPageToken'] as String?;
        final models = (body['models'] as List<dynamic>?) ?? const [];
        for (final raw in models) {
          final m = raw as Map<String, dynamic>;
          final name = (m['name'] as String?) ?? '';
          final methods = (m['supportedGenerationMethods'] as List<dynamic>?)
                  ?.cast<String>() ??
              const [];
          if (!methods.contains('generateContent')) continue;
          // Strip 'models/' prefix → bare id (e.g. 'gemini-2.5-pro').
          final id = name.startsWith('models/') ? name.substring(7) : name;
          // Exclude non-text models: image generators, embeddings, etc.
          final lower = id.toLowerCase();
          if (['imagen', '-image', 'veo', 'tts', 'aqa', 'embedding']
              .any(lower.contains)) continue;
          final display = (m['displayName'] as String?)?.isNotEmpty == true
              ? m['displayName'] as String
              : id;
          all.add((id: id, displayName: display));
        }
      } while (pageToken != null && all.length < 200);

      // Sort newest-first: parse the version out of the id
      // (e.g. gemini-3.8-pro → 3.8, gemini-2.5-flash-exp → 2.5).
      double _ver(String id) {
        final m = RegExp(r'gemini-(\d+\.\d+)').firstMatch(id.toLowerCase());
        return m != null ? double.tryParse(m.group(1)!) ?? 0 : 0;
      }

      all.sort((a, b) {
        final vb = _ver(b.id), va = _ver(a.id);
        if (vb != va) return vb.compareTo(va);
        return a.id.compareTo(b.id);
      });
      return all;
    } catch (_) {
      return const [];
    }
  }

  static String _errorMessage(String body) {
    try {
      final d = jsonDecode(body);
      return (d['error']?['message'] ?? _truncate(body)).toString();
    } catch (_) {
      return _truncate(body);
    }
  }

  static String _truncate(String s) =>
      s.length > 200 ? '${s.substring(0, 200)}…' : s;
}
