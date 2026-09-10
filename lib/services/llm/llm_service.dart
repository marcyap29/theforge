import 'llm_model_config.dart';
import 'llm_provider.dart';
import 'providers/claude_provider.dart';
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
    // Defensive: if a role somehow has a provider but no model, fall back to
    // that provider's first model rather than failing the whole call.
    var modelId = assignment.modelId;
    if (modelId.isEmpty) {
      modelId = modelsFor(assignment.providerType).firstOrNull?.id ?? '';
    }
    if (modelId.isEmpty) {
      throw Exception(
        'No model selected for ${role.name} role. Open Settings to configure.',
      );
    }
    final provider = _buildProvider(assignment.providerType);
    return provider.complete(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      modelId: modelId,
      maxTokens: maxTokens,
    );
  }

  /// Streaming variant of [complete]: yields deltas as they arrive. Same
  /// role → provider → model resolution.
  Stream<LlmDelta> completeStream({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required LlmRole role,
    int? maxTokens,
  }) {
    final assignment = settings.roleAssignments[role];
    if (assignment == null) {
      throw Exception('No role assignment for ${role.name}.');
    }
    var modelId = assignment.modelId;
    if (modelId.isEmpty) {
      modelId = modelsFor(assignment.providerType).firstOrNull?.id ?? '';
    }
    if (modelId.isEmpty) {
      throw Exception(
        'No model selected for ${role.name} role. Open Settings to configure.',
      );
    }
    final provider = _buildProvider(assignment.providerType);
    return provider.completeStream(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      modelId: modelId,
      maxTokens: maxTokens,
    );
  }

  /// The provider + model that will service a given role — for surfacing the
  /// active model in the UI.
  ({LlmProviderType provider, String modelId})? resolve(LlmRole role) {
    final assignment = settings.roleAssignments[role];
    if (assignment == null) return null;
    var modelId = assignment.modelId;
    if (modelId.isEmpty) {
      modelId = modelsFor(assignment.providerType).firstOrNull?.id ?? '';
    }
    return (provider: assignment.providerType, modelId: modelId);
  }

  LlmProvider _buildProvider(LlmProviderType type) {
    switch (type) {
      case LlmProviderType.ollama:
        return OllamaProvider(
          baseUrl: settings.ollamaBaseUrl,
          apiKey: settings.apiKeys[LlmProviderType.ollama],
        );
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
    }
  }
}
