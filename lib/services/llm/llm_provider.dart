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
    bool? think,
  });

  /// Streams the completion as incremental deltas. The default falls back to a
  /// single [complete] call yielded as one content chunk (no real streaming);
  /// providers override this to stream token-by-token.
  ///
  /// [think] controls a reasoning model's chain-of-thought: `false` disables it
  /// so the whole output budget goes to the answer (used for JSON passes that
  /// must not be truncated by thinking); null leaves the model default.
  Stream<LlmDelta> completeStream({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required String modelId,
    int? maxTokens,
    bool? think,
  }) async* {
    yield LlmDelta(await complete(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      modelId: modelId,
      maxTokens: maxTokens,
      think: think,
    ));
  }
}
