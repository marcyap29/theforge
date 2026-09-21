import 'llm_model_config.dart';

/// What a model is *best* at, inferred from its id. This is a heuristic — the
/// providers don't hand us a capability manifest and Ollama Cloud tags retire
/// fast — so it errs toward [unknown] and only commits when the name is a clear
/// signal. It exists to catch one recurring foot-gun: running the **Build**
/// (executor) role on a reasoning/vision model, which loops or stalls on the
/// long, exact code-edit hunks the builder needs.
enum ModelCapability {
  /// Instruction-following / coding-tuned — the right tool for Build.
  coder,

  /// Reasoning-first general model. Strong at planning/architecting, but prone
  /// to repetition loops when asked to emit large verbatim code edits.
  reasoning,

  /// Multimodal/vision model — the wrong tool for producing code.
  vision,

  /// Small speed-tuned variant (mini/flash/haiku). Usable, not flagged.
  fast,

  /// Not confidently classifiable — treated as fine (never flagged).
  unknown,
}

/// Classifies a model id into its best-fit [ModelCapability]. Pure + order
/// sensitive: vision → fast → coder → reasoning → unknown, so a small "mini"
/// variant is caught before its family and a "-coder" beats its base family.
///
/// Deliberately conservative: general-purpose models we're unsure about (e.g.
/// `gpt-oss`) stay [unknown] so the Build warning never nags on a reasonable
/// default — it fires only when we're confident the model is a poor Build fit.
ModelCapability classifyModel(String modelId) {
  final id = modelId.toLowerCase();
  bool has(List<String> needles) => needles.any(id.contains);

  // 1. Vision / multimodal — never for code.
  if (has(['vision', 'llava', 'moondream', '-vl', 'vl:', 'vl-'])) {
    return ModelCapability.vision;
  }

  // 2. Speed-tuned small variants. Checked before family so `gpt-4o-mini` and
  //    `claude-haiku` land here rather than in coder.
  if (has(['mini', 'nano', 'haiku', 'flash', 'lite', 'small', '-8b', '-4b',
      '-2b', '-1.5b', '1b-', ':1b', ':3b'])) {
    return ModelCapability.fast;
  }

  // 3. Coder / instruction-following — the models we want for Build.
  if (has([
    'code', // codestral, codellama, deepseek-coder, qwen*-coder, gpt-4.1…code
    'coder',
    'codestral',
    'codellama',
    'devstral',
    'kimi', // Kimi K2 — agentic/coding
    'opus', // Claude Opus — top-tier coder
    'sonnet', // Claude Sonnet — strong coder
    'gpt-4.1',
    'gpt-4o', // (mini already filtered above)
  ])) {
    return ModelCapability.coder;
  }

  // 4. Reasoning-first general models — capable, but weak at long verbatim
  //    code edits (the repetition-loop failure mode). These are what we warn on.
  if (has([
    'qwen',
    'glm',
    'deepseek-r', // deepseek reasoner / r1
    'reasoner',
    'magistral',
    'phi',
    'gemma',
    'o1',
    'o3',
  ])) {
    return ModelCapability.reasoning;
  }

  return ModelCapability.unknown;
}

/// Whether [cap] is a poor fit for the Build (executor) role and should raise
/// the in-window warning. Fires only when we're confident: a reasoning or
/// vision model. `fast` and `unknown` pass silently.
bool warnsForBuildRole(ModelCapability cap) =>
    cap == ModelCapability.reasoning || cap == ModelCapability.vision;

/// A short human noun for [cap], for the warning text ("looks like …").
String capabilityNoun(ModelCapability cap) => switch (cap) {
      ModelCapability.coder => 'a coding model',
      ModelCapability.reasoning => 'a reasoning model',
      ModelCapability.vision => 'a vision model',
      ModelCapability.fast => 'a lightweight model',
      ModelCapability.unknown => 'an unclassified model',
    };

/// A one-click Build-model upgrade: the assignment to apply plus a label to
/// show on the button.
typedef CoderUpgrade = ({ModelAssignment assignment, String displayName});

/// Picks the best *configured* coder model to offer as a one-click switch for
/// the Build role, or null if the user has none available (button is hidden).
///
/// Only considers models the user can actually run: the current Ollama catalog
/// (seed + live tags) always, and Claude/OpenAI only when their API key is set.
/// Prefers a coder in [currentProvider] (no provider switch needed), then a
/// curated quality order. Pure — [ollamaModels] is the live `/api/tags` list.
CoderUpgrade? pickBuildCoderUpgrade({
  required LlmProviderType currentProvider,
  required LlmSettings settings,
  required List<ModelInfo> ollamaModels,
}) {
  // Gather (model, provider) candidates from every configured provider.
  final candidates = <({ModelInfo model, LlmProviderType provider})>[];
  final seen = <String>{}; // dedup ollama seed vs live tags by id

  for (final m in [...ollamaCloudModels, ...ollamaModels]) {
    if (seen.add(m.id)) {
      candidates.add((model: m, provider: LlmProviderType.ollama));
    }
  }
  bool keyed(LlmProviderType t) => (settings.apiKeys[t] ?? '').isNotEmpty;
  if (keyed(LlmProviderType.claude)) {
    for (final m in claudeModels) {
      candidates.add((model: m, provider: LlmProviderType.claude));
    }
  }
  if (keyed(LlmProviderType.openai)) {
    for (final m in openAiModels) {
      candidates.add((model: m, provider: LlmProviderType.openai));
    }
  }

  final coders = candidates
      .where((c) => classifyModel(c.model.id) == ModelCapability.coder)
      .toList();
  if (coders.isEmpty) return null;

  // Rank: same provider first (avoid a surprise provider switch), then a
  // curated preference by model family, then stable.
  int familyRank(String id) {
    final l = id.toLowerCase();
    if (l.contains('kimi')) return 0;
    if (l.contains('opus')) return 1;
    if (l.contains('sonnet')) return 2;
    if (l.contains('gpt-4.1')) return 3;
    if (l.contains('coder') || l.contains('code')) return 4;
    return 5;
  }

  coders.sort((a, b) {
    final sa = a.provider == currentProvider ? 0 : 1;
    final sb = b.provider == currentProvider ? 0 : 1;
    if (sa != sb) return sa.compareTo(sb);
    final fa = familyRank(a.model.id), fb = familyRank(b.model.id);
    if (fa != fb) return fa.compareTo(fb);
    return a.model.id.compareTo(b.model.id);
  });

  final best = coders.first;
  return (
    // think:false — the executor is more reliable emitting JSON plans without
    // chain-of-thought (avoids thinking-driven truncation/loops).
    assignment: ModelAssignment(
      providerType: best.provider,
      modelId: best.model.id,
      think: false,
    ),
    displayName: best.model.displayName,
  );
}
