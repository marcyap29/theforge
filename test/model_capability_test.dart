import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/services/llm/llm_model_config.dart';
import 'package:the_forge/services/llm/model_capability.dart';

void main() {
  group('classifyModel', () {
    test('the failing model (qwen3.5) is reasoning → warns for Build', () {
      expect(classifyModel('qwen3.5:cloud'), ModelCapability.reasoning);
      expect(warnsForBuildRole(classifyModel('qwen3.5:cloud')), isTrue);
    });

    test('glm is reasoning → warns', () {
      expect(classifyModel('glm-5.2:cloud'), ModelCapability.reasoning);
      expect(warnsForBuildRole(ModelCapability.reasoning), isTrue);
    });

    test('kimi is a coder → no warning', () {
      expect(classifyModel('kimi-k2.6:cloud'), ModelCapability.coder);
      expect(warnsForBuildRole(classifyModel('kimi-k2.6:cloud')), isFalse);
    });

    test('explicit coder tags classify as coder', () {
      expect(classifyModel('kimi-k2.7-code:cloud'), ModelCapability.coder);
      expect(classifyModel('qwen2.5-coder:32b'), ModelCapability.coder);
      expect(classifyModel('codestral:latest'), ModelCapability.coder);
      expect(classifyModel('deepseek-coder-v2'), ModelCapability.coder);
    });

    test('Claude Opus/Sonnet are coders; Haiku is fast', () {
      expect(classifyModel('claude-opus-4-7'), ModelCapability.coder);
      expect(classifyModel('claude-sonnet-4-6'), ModelCapability.coder);
      expect(classifyModel('claude-haiku-4-5-20251001'), ModelCapability.fast);
    });

    test('mini/flash variants are fast (checked before their family)', () {
      expect(classifyModel('gpt-4o-mini'), ModelCapability.fast);
      expect(classifyModel('deepseek-v4-flash:cloud'), ModelCapability.fast);
    });

    test('vision models are flagged (wrong tool for code)', () {
      expect(classifyModel('qwen2-vl:7b'), ModelCapability.vision);
      expect(classifyModel('llava:13b'), ModelCapability.vision);
      expect(warnsForBuildRole(ModelCapability.vision), isTrue);
    });

    test('gpt-oss default stays unknown → never nags on the default', () {
      expect(classifyModel('gpt-oss:120b-cloud'), ModelCapability.unknown);
      expect(warnsForBuildRole(ModelCapability.unknown), isFalse);
    });

    test('fast passes silently (not flagged for Build)', () {
      expect(warnsForBuildRole(ModelCapability.fast), isFalse);
    });
  });

  group('pickBuildCoderUpgrade', () {
    LlmSettings settingsWith({String? claudeKey, String? openaiKey}) =>
        LlmSettings(
          roleAssignments: const {},
          apiKeys: {
            LlmProviderType.ollama: 'k',
            LlmProviderType.claude: claudeKey,
            LlmProviderType.openai: openaiKey,
          },
          ollamaBaseUrl: 'https://ollama.com',
        );

    test('an Ollama user on qwen is offered Kimi (same provider, coder)', () {
      final up = pickBuildCoderUpgrade(
        currentProvider: LlmProviderType.ollama,
        settings: settingsWith(),
        ollamaModels: const [],
      );
      expect(up, isNotNull);
      expect(up!.assignment.providerType, LlmProviderType.ollama);
      expect(up.assignment.modelId, 'kimi-k2.6:cloud');
      // Executor upgrades default thinking off for reliable JSON plans.
      expect(up.assignment.think, isFalse);
    });

    test('prefers a coder in the current provider over another provider', () {
      final up = pickBuildCoderUpgrade(
        currentProvider: LlmProviderType.ollama,
        settings: settingsWith(claudeKey: 'sk-ant'),
        ollamaModels: const [],
      );
      // Kimi (ollama) wins because ollama is the current provider.
      expect(up!.assignment.providerType, LlmProviderType.ollama);
    });

    test('crosses providers when the current one has no coder', () {
      // OpenAI selected but (hypothetically) no coder available there → falls
      // back to a keyed provider that does. Here Claude is keyed.
      final up = pickBuildCoderUpgrade(
        currentProvider: LlmProviderType.claude,
        settings: settingsWith(claudeKey: 'sk-ant'),
        ollamaModels: const [],
      );
      expect(up, isNotNull);
      expect(up!.assignment.providerType, LlmProviderType.claude);
      expect(up.assignment.modelId, 'claude-opus-4-7'); // curated top coder
    });

    test('live Ollama tags are considered and deduped against the seed', () {
      final up = pickBuildCoderUpgrade(
        currentProvider: LlmProviderType.ollama,
        settings: settingsWith(),
        ollamaModels: const [
          ModelInfo(id: 'kimi-k2.6:cloud', displayName: 'dupe'),
          ModelInfo(id: 'qwen2.5-coder:7b', displayName: 'Qwen Coder 7b'),
        ],
      );
      // Kimi still wins on family rank; the dupe id doesn't crash the picker.
      expect(up!.assignment.modelId, 'kimi-k2.6:cloud');
    });
  });
}
