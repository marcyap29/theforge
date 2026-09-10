enum LlmRole { architect, executor }

/// One streamed chunk. Reasoning models emit their chain-of-thought as
/// [thinking] deltas (shown live but NOT part of the final answer) before the
/// real answer arrives as content deltas ([thinking] == false).
class LlmDelta {
  const LlmDelta(this.text, {this.thinking = false});
  final String text;
  final bool thinking;
}

abstract class LlmProvider {
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required String modelId,
    int? maxTokens,
  });

  /// Streams the completion as incremental deltas. The default falls back to a
  /// single [complete] call yielded as one content chunk (no real streaming);
  /// providers override this to stream token-by-token.
  Stream<LlmDelta> completeStream({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required String modelId,
    int? maxTokens,
  }) async* {
    yield LlmDelta(await complete(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      modelId: modelId,
      maxTokens: maxTokens,
    ));
  }
}
