import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_model_config.dart';
import '../llm_provider.dart';

class OllamaProvider extends LlmProvider {
  OllamaProvider({required this.baseUrl});
  final String baseUrl;

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
      headers: const {'Content-Type': 'application/json'},
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

  static Future<List<ModelInfo>> fetchModels(String baseUrl) async {
    final response = await http.get(Uri.parse('$baseUrl/api/tags'));
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
