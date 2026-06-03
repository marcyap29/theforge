import 'llm_model_config.dart';
import 'llm_provider.dart';
import 'providers/claude_provider.dart';
import 'providers/gemini_provider.dart';
import 'providers/ollama_provider.dart';
import 'providers/openai_provider.dart';

class LlmService {
  const LlmService(this.settings);
  final LlmSettings settings;

  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required LlmRole role,
    int? maxTokens,
  }) async {
    final assignment = settings.roleAssignments[role];
    if (assignment == null) {
      throw Exception('No role assignment for ${role.name}.');
    }
    if (assignment.modelId.isEmpty) {
      throw Exception(
        'No model selected for ${role.name} role. Open Settings to configure.',
      );
    }
    final provider = _buildProvider(assignment.providerType);
    return provider.complete(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      modelId: assignment.modelId,
      maxTokens: maxTokens,
    );
  }

  LlmProvider _buildProvider(LlmProviderType type) {
    switch (type) {
      case LlmProviderType.ollama:
        return OllamaProvider(baseUrl: settings.ollamaBaseUrl);
      case LlmProviderType.claude:
        final key = settings.apiKeys[LlmProviderType.claude];
        if (key == null) {
          throw Exception('Claude API key not configured. Open Settings.');
        }
        return ClaudeProvider(apiKey: key);
      case LlmProviderType.openai:
        final key = settings.apiKeys[LlmProviderType.openai];
        if (key == null) {
          throw Exception('OpenAI API key not configured. Open Settings.');
        }
        return OpenAiProvider(apiKey: key);
      case LlmProviderType.gemini:
        final key = settings.apiKeys[LlmProviderType.gemini];
        if (key == null) {
          throw Exception('Gemini API key not configured. Open Settings.');
        }
        return GeminiProvider(apiKey: key);
    }
  }
}
