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
      throw Exception('Gemini response missing candidates: ${response.body}');
    }
    final content =
        (candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini response missing parts: ${response.body}');
    }
    return (parts.first as Map<String, dynamic>)['text'] as String;
  }

  static String _truncate(String s) =>
      s.length > 200 ? '${s.substring(0, 200)}…' : s;
}
