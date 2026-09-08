import 'package:flutter/foundation.dart';

import 'llm_provider.dart';

enum LlmProviderType { ollama, claude, openai }

@immutable
class ModelInfo {
  final String id;
  final String displayName;
  const ModelInfo({required this.id, required this.displayName});
}

const claudeModels = <ModelInfo>[
  ModelInfo(id: 'claude-opus-4-7', displayName: 'Claude Opus 4.7'),
  ModelInfo(id: 'claude-sonnet-4-6', displayName: 'Claude Sonnet 4.6'),
  ModelInfo(id: 'claude-haiku-4-5-20251001', displayName: 'Claude Haiku 4.5'),
];

const openAiModels = <ModelInfo>[
  ModelInfo(id: 'gpt-4.1', displayName: 'GPT-4.1'),
  ModelInfo(id: 'gpt-4o', displayName: 'GPT-4o'),
  ModelInfo(id: 'gpt-4o-mini', displayName: 'GPT-4o mini'),
];

/// Curated Ollama Cloud models (the `-cloud`/`:cloud` tags run on Ollama's
/// hosted infrastructure via https://ollama.com with an API key). Users can
/// also type any other Ollama model id; this list just seeds the picker.
const ollamaCloudModels = <ModelInfo>[
  ModelInfo(id: 'gpt-oss:120b-cloud', displayName: 'gpt-oss 120b (cloud)'),
  ModelInfo(id: 'qwen3.5:cloud', displayName: 'Qwen3.5 (cloud)'),
  ModelInfo(id: 'deepseek-v4-flash:cloud', displayName: 'DeepSeek V4 Flash (cloud)'),
  ModelInfo(id: 'glm-5.2:cloud', displayName: 'GLM-5.2 (cloud)'),
  ModelInfo(id: 'kimi-k2.6:cloud', displayName: 'Kimi K2.6 (cloud)'),
  ModelInfo(id: 'minimax-m2.7:cloud', displayName: 'MiniMax M2.7 (cloud)'),
];

List<ModelInfo> modelsFor(LlmProviderType type) {
  return switch (type) {
    LlmProviderType.ollama => ollamaCloudModels,
    LlmProviderType.claude => claudeModels,
    LlmProviderType.openai => openAiModels,
  };
}

@immutable
class ModelAssignment {
  final LlmProviderType providerType;
  final String modelId;
  const ModelAssignment({required this.providerType, required this.modelId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelAssignment &&
          other.providerType == providerType &&
          other.modelId == modelId);

  @override
  int get hashCode => Object.hash(providerType, modelId);
}

@immutable
class LlmSettings {
  final Map<LlmRole, ModelAssignment> roleAssignments;
  final Map<LlmProviderType, String?> apiKeys;
  final String ollamaBaseUrl;
  final String? swarmspaceApiKey;

  const LlmSettings({
    required this.roleAssignments,
    required this.apiKeys,
    required this.ollamaBaseUrl,
    this.swarmspaceApiKey,
  });

  static const LlmSettings defaults = LlmSettings(
    roleAssignments: {
      LlmRole.architect: ModelAssignment(
        providerType: LlmProviderType.ollama,
        modelId: 'gpt-oss:120b-cloud',
      ),
      LlmRole.executor: ModelAssignment(
        providerType: LlmProviderType.ollama,
        modelId: 'gpt-oss:120b-cloud',
      ),
    },
    apiKeys: {
      LlmProviderType.ollama: null,
      LlmProviderType.claude: null,
      LlmProviderType.openai: null,
    },
    ollamaBaseUrl: 'https://ollama.com',
  );

  LlmSettings copyWith({
    Map<LlmRole, ModelAssignment>? roleAssignments,
    Map<LlmProviderType, String?>? apiKeys,
    String? ollamaBaseUrl,
    String? swarmspaceApiKey,
  }) {
    return LlmSettings(
      roleAssignments: roleAssignments ?? this.roleAssignments,
      apiKeys: apiKeys ?? this.apiKeys,
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
      swarmspaceApiKey: swarmspaceApiKey ?? this.swarmspaceApiKey,
    );
  }
}
