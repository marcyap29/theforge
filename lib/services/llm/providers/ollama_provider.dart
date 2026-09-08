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
        'options': {'temperature': temperature},
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
