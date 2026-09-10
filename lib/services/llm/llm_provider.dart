enum LlmRole { architect, executor }

abstract class LlmProvider {
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required String modelId,
    int? maxTokens,
  });

  /// Streams the completion as incremental text deltas. The default falls back
  /// to a single [complete] call yielded as one chunk (no real streaming);
  /// providers override this to stream token-by-token.
  Stream<String> completeStream({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required String modelId,
    int? maxTokens,
  }) async* {
    yield await complete(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      modelId: modelId,
      maxTokens: maxTokens,
    );
  }
}
