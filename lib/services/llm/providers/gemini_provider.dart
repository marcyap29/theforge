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
