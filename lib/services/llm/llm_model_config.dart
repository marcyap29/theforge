import 'package:flutter/foundation.dart';

import 'llm_provider.dart';

enum LlmProviderType { ollama, claude, openai, gemini }

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

const geminiModels = <ModelInfo>[
  ModelInfo(id: 'gemini-3.5-flash', displayName: 'Gemini 3.5 Flash'),
  ModelInfo(id: 'gemini-3.1-flash-lite', displayName: 'Gemini 3.1 Flash-Lite'),
  ModelInfo(id: 'gemini-2.5-flash', displayName: 'Gemini 2.5 Flash'),
  ModelInfo(id: 'gemini-2.5-pro', displayName: 'Gemini 2.5 Pro'),
];

List<ModelInfo> modelsFor(LlmProviderType type) {
  return switch (type) {
    LlmProviderType.ollama => const [],
    LlmProviderType.claude => claudeModels,
    LlmProviderType.openai => openAiModels,
    LlmProviderType.gemini => geminiModels,
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
        providerType: LlmProviderType.gemini,
        modelId: 'gemini-3.5-flash',
      ),
      LlmRole.executor: ModelAssignment(
        providerType: LlmProviderType.gemini,
        modelId: 'gemini-3.5-flash',
      ),
    },
    apiKeys: {
      LlmProviderType.ollama: null,
      LlmProviderType.claude: null,
      LlmProviderType.openai: null,
      LlmProviderType.gemini: null,
    },
    ollamaBaseUrl: 'http://localhost:11434',
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
