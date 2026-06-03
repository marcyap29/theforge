import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_provider.dart';

class ClaudeProvider extends LlmProvider {
  ClaudeProvider({required this.apiKey});
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
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': modelId,
        'max_tokens': maxTokens ?? 2048,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': temperature,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Claude error ${response.statusCode}: ${_truncate(response.body)}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>?;
    if (content == null || content.isEmpty) {
      throw Exception('Claude response missing content: ${response.body}');
    }
    final first = content.first as Map<String, dynamic>;
    return first['text'] as String;
  }

  static String _truncate(String s) =>
      s.length > 200 ? '${s.substring(0, 200)}…' : s;
}
