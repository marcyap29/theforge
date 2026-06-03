enum LlmRole { architect, executor }

abstract class LlmProvider {
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required String modelId,
    int? maxTokens,
  });
}
