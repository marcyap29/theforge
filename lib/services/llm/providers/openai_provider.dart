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

  @override
  Stream<LlmDelta> completeStream({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required String modelId,
    int? maxTokens,
  }) async* {
    final client = http.Client();
    try {
      final request = http.Request(
          'POST', Uri.parse('https://api.openai.com/v1/chat/completions'))
        ..headers.addAll({
          'Authorization': 'Bearer $apiKey',
          'content-type': 'application/json',
        })
        ..body = jsonEncode({
          'model': modelId,
          'temperature': temperature,
          'stream': true,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
        });
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('OpenAI error ${response.statusCode}: ${_truncate(body)}');
      }
      // OpenAI SSE: `data: {...}` lines; delta text in choices[0].delta.content;
      // terminated by `data: [DONE]`.
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;
        if (payload == '[DONE]') break;
        try {
          final obj = jsonDecode(payload) as Map<String, dynamic>;
          final choices = obj['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) continue;
          final delta =
              (choices.first as Map<String, dynamic>)['delta'] as Map<String, dynamic>?;
          final text = delta?['content'] as String?;
          if (text != null && text.isNotEmpty) yield LlmDelta(text);
        } catch (_) {
          // Ignore non-JSON lines.
        }
      }
    } finally {
      client.close();
    }
  }

  static String _truncate(String s) =>
      s.length > 200 ? '${s.substring(0, 200)}…' : s;
}
