import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_model_config.dart';
import '../llm_provider.dart';

class OllamaProvider extends LlmProvider {
  OllamaProvider({required this.baseUrl, this.apiKey});
  final String baseUrl;

  /// When set, requests are authenticated as Ollama Cloud (https://ollama.com)
  /// via `Authorization: Bearer <apiKey>`. Null for a local Ollama server.
  final String? apiKey;

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey!.isNotEmpty)
          'Authorization': 'Bearer $apiKey',
      };

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required String modelId,
    int? maxTokens,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/chat'),
      headers: _headers(),
      body: jsonEncode({
        'model': modelId,
        'stream': false,
        'options': {
          'temperature': temperature,
          // Ensure the model has room to finish (thinking + answer); without
          // this a long reasoning phase can starve the actual response.
          if (maxTokens != null) 'num_predict': maxTokens,
        },
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Ollama error ${response.statusCode}: ${_truncate(response.body)}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final message = data['message'] as Map<String, dynamic>?;
    if (message == null) {
      throw Exception('Ollama response missing message: ${response.body}');
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
      final request = http.Request('POST', Uri.parse('$baseUrl/api/chat'))
        ..headers.addAll(_headers())
        ..body = jsonEncode({
          'model': modelId,
          'stream': true,
          'options': {
          'temperature': temperature,
          // Ensure the model has room to finish (thinking + answer); without
          // this a long reasoning phase can starve the actual response.
          if (maxTokens != null) 'num_predict': maxTokens,
        },
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
        });
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('Ollama error ${response.statusCode}: ${_truncate(body)}');
      }
      // Ollama streams newline-delimited JSON objects. Reasoning models put
      // their chain-of-thought in `message.thinking` (with empty `content`)
      // until the reasoning finishes, then stream the real answer in
      // `message.content`. Surface both — thinking as a thinking delta.
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        try {
          final obj = jsonDecode(line) as Map<String, dynamic>;
          final msg = obj['message'] as Map<String, dynamic>?;
          final thinking = msg?['thinking'] as String?;
          if (thinking != null && thinking.isNotEmpty) {
            yield LlmDelta(thinking, thinking: true);
          }
          final chunk = msg?['content'] as String?;
          if (chunk != null && chunk.isNotEmpty) yield LlmDelta(chunk);
          if (obj['done'] == true) break;
        } catch (_) {
          // Ignore any non-JSON keep-alive line.
        }
      }
    } finally {
      client.close();
    }
  }

  static Future<List<ModelInfo>> fetchModels(String baseUrl,
      {String? apiKey}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/tags'),
      headers: {
        if (apiKey != null && apiKey.isNotEmpty)
          'Authorization': 'Bearer $apiKey',
      },
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Ollama error ${response.statusCode}: ${_truncate(response.body)}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = (data['models'] as List<dynamic>?) ?? const [];
    return models
        .whereType<Map<String, dynamic>>()
        .map((m) {
          final name = m['name'] as String?;
          if (name == null) return null;
          return ModelInfo(id: name, displayName: name);
        })
        .whereType<ModelInfo>()
        .toList(growable: false);
  }

  static String _truncate(String s) =>
      s.length > 200 ? '${s.substring(0, 200)}…' : s;
}
