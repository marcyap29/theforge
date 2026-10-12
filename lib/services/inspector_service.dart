import 'dart:convert';

import 'llm/llm_provider.dart';
import 'llm/llm_service.dart';

class InspectorVerdict {
  const InspectorVerdict({
    required this.passes,
    this.concern,
    this.suggestion,
  });

  final bool passes;

  /// Plain-English concern when [passes] is false.
  final String? concern;

  /// Concrete fix suggestion when [passes] is false.
  final String? suggestion;

  static const passing = InspectorVerdict(passes: true);
}

/// Evaluates AI-generated outputs (build briefs, goal statements) against
/// quality criteria, using a fresh independent context window. The Inspector
/// runs on the [LlmRole.inspector] role so it can be a different model than
/// the one that generated the content — key to avoiding self-rationalization.
class InspectorService {
  const InspectorService(this._llm);

  final LlmService _llm;

  static const _system = '''
You are a quality inspector for AI-generated build briefs.

A GOOD build brief:
1. Names a specific, user-visible success criterion (not vague like "make it better")
2. Is scoped to a single screen or capability — completable in one build session
3. States at least one thing it should NOT do (scope boundary)
4. Does not rely on fictional data, mocks, or simulated behavior

A FAILING brief:
- Is vague or unmeasurable ("improve the UI", "add some features")
- Tries to build an entire app in one pass
- Has no clear done-state

Be lenient: only fail a brief that would genuinely cause a wasted build run.
A brief that is slightly rough but actionable should PASS.

Respond with ONLY valid JSON, no prose:
{"passes": true|false, "concern": "string or null", "suggestion": "string or null"}
''';

  /// Evaluates [brief] for quality. If [exampleBrief] is provided (from
  /// Forge/examples/build_brief.md), the inspector uses it as a format anchor.
  Future<InspectorVerdict> inspectBrief({
    required String featureTitle,
    required String brief,
    String? exampleBrief,
  }) async {
    final exampleBlock = exampleBrief != null && exampleBrief.trim().isNotEmpty
        ? '\n\nExample of a well-formed brief for this project:\n$exampleBrief'
        : '';

    final userPrompt = 'Feature: $featureTitle\n\nBrief:\n$brief$exampleBlock';

    try {
      final raw = await _llm.complete(
        systemPrompt: _system,
        userPrompt: userPrompt,
        temperature: 0.0,
        role: LlmRole.inspector,
        maxTokens: 300,
        think: false,
        jsonMode: true,
      );
      return _parse(raw);
    } catch (_) {
      // Inspector failure is non-blocking — pass through on error.
      return InspectorVerdict.passing;
    }
  }

  static InspectorVerdict _parse(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final passes = (json['passes'] as bool?) ?? true;
      final concern = json['concern'] as String?;
      final suggestion = json['suggestion'] as String?;
      return InspectorVerdict(
        passes: passes,
        concern: (concern?.isEmpty ?? true) ? null : concern,
        suggestion: (suggestion?.isEmpty ?? true) ? null : suggestion,
      );
    } catch (_) {
      return InspectorVerdict.passing;
    }
  }
}
