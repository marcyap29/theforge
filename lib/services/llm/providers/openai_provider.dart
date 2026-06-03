import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_provider.dart';

class OpenAiProvider extends LlmProvider {
  OpenAiProvider({required this.apiKey});
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
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': modelId,
        'temperature': temperature,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI error ${response.statusCode}: ${_truncate(response.body)}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('OpenAI response missing choices: ${response.body}');
    }
    final message =
        (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
    if (message == null) {
      throw Exception('OpenAI response missing message: ${response.body}');
    }
    return message['content'] as String;
  }

  static String _truncate(String s) =>
      s.length > 200 ? '${s.substring(0, 200)}…' : s;
}
