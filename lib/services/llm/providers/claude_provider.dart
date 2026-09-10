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
      final request =
          http.Request('POST', Uri.parse('https://api.anthropic.com/v1/messages'))
            ..headers.addAll({
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            })
            ..body = jsonEncode({
              'model': modelId,
              'max_tokens': maxTokens ?? 2048,
              'system': systemPrompt,
              'messages': [
                {'role': 'user', 'content': userPrompt},
              ],
              'temperature': temperature,
              'stream': true,
            });
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('Claude error ${response.statusCode}: ${_truncate(body)}');
      }
      // Anthropic SSE: `data: {...}` lines; text arrives as
      // content_block_delta events with a text_delta.
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;
        try {
          final obj = jsonDecode(payload) as Map<String, dynamic>;
          if (obj['type'] == 'content_block_delta') {
            final delta = obj['delta'] as Map<String, dynamic>?;
            final type = delta?['type'] as String?;
            if (type == 'thinking_delta') {
              final t = delta?['thinking'] as String?;
              if (t != null && t.isNotEmpty) yield LlmDelta(t, thinking: true);
            } else {
              final text = delta?['text'] as String?;
              if (text != null && text.isNotEmpty) yield LlmDelta(text);
            }
          }
        } catch (_) {
          // Ignore ping / non-JSON lines.
        }
      }
    } finally {
      client.close();
    }
  }

  static String _truncate(String s) =>
      s.length > 200 ? '${s.substring(0, 200)}…' : s;
}
