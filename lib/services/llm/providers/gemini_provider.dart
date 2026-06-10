import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_provider.dart';

class GeminiProvider extends LlmProvider {
  GeminiProvider({required this.apiKey});
  final String apiKey;

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required String modelId,
    int? maxTokens,
  }) async {
    final response = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$modelId:generateContent?key=$apiKey',
      ),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
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
        'generationConfig': {
          'temperature': temperature,
          'maxOutputTokens': maxTokens ?? 2048,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini error ${response.statusCode}: ${_truncate(response.body)}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      final promptFeedback = data['promptFeedback'] as Map<String, dynamic>?;
      final blockReason = promptFeedback?['blockReason'] as String?;
      throw Exception(
        blockReason != null
            ? 'Gemini request blocked: $blockReason'
            : 'Gemini returned no candidates',
      );
    }
    final candidate = candidates.first as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      final finishReason = candidate['finishReason'] as String? ?? 'UNKNOWN';
      throw Exception('Gemini candidate has no content (finishReason: $finishReason)');
    }
    final text = (parts.first as Map<String, dynamic>)['text'] as String?;
    if (text == null) {
      throw Exception('Gemini response part missing text field');
    }
    return text;
  }

  static String _truncate(String s) =>
      s.length > 200 ? '${s.substring(0, 200)}…' : s;
}
