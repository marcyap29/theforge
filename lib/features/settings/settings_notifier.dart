import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/llm/llm_model_config.dart';
import '../../services/llm/llm_provider.dart';
import '../../services/llm/providers/ollama_provider.dart';

enum OllamaStatus { unknown, connected, notRunning }

@immutable
class LlmSettingsState {
  final LlmSettings settings;
  final List<ModelInfo> ollamaModels;
  final OllamaStatus ollamaStatus;

  const LlmSettingsState({
    required this.settings,
    this.ollamaModels = const [],
    this.ollamaStatus = OllamaStatus.unknown,
  });

  LlmSettingsState copyWith({
    LlmSettings? settings,
    List<ModelInfo>? ollamaModels,
    OllamaStatus? ollamaStatus,
  }) {
    return LlmSettingsState(
      settings: settings ?? this.settings,
      ollamaModels: ollamaModels ?? this.ollamaModels,
      ollamaStatus: ollamaStatus ?? this.ollamaStatus,
    );
  }
}

class SettingsNotifier extends AsyncNotifier<LlmSettingsState> {
  static const _prefsKeyBaseUrl = 'forge_ollama_base_url';
  static const _prefsKeyRoleProvider = 'forge_role_provider_';
  static const _prefsKeyRoleModel = 'forge_role_model_';
  static const _keychainKeyPrefix = 'forge_api_key_';

  @override
  Future<LlmSettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    const storage = FlutterSecureStorage();

    final baseUrl =
        prefs.getString(_prefsKeyBaseUrl) ?? 'http://localhost:11434';

    final assignments = <LlmRole, ModelAssignment>{};
    for (final role in LlmRole.values) {
      final providerStr =
          prefs.getString('$_prefsKeyRoleProvider${role.name}');
      final savedModelId =
          prefs.getString('$_prefsKeyRoleModel${role.name}');
      final isFirstRun = providerStr == null;
      final providerType = isFirstRun
          ? LlmProviderType.gemini
          : LlmProviderType.values.firstWhere(
              (p) => p.name == providerStr,
              orElse: () => LlmProviderType.gemini,
            );
      final modelId = savedModelId ??
          (isFirstRun ? 'gemini-3.5-flash-preview' : '');
      assignments[role] = ModelAssignment(
        providerType: providerType,
        modelId: modelId,
      );
    }

    final apiKeys = <LlmProviderType, String?>{};
    for (final type in LlmProviderType.values) {
      if (type == LlmProviderType.ollama) {
        apiKeys[type] = null;
      } else {
        apiKeys[type] =
            await storage.read(key: '$_keychainKeyPrefix${type.name}');
      }
    }

    return LlmSettingsState(
      settings: LlmSettings(
        roleAssignments: assignments,
        apiKeys: apiKeys,
        ollamaBaseUrl: baseUrl,
      ),
    );
  }

  Future<void> setRoleAssignment(
    LlmRole role,
    ModelAssignment assignment,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefsKeyRoleProvider${role.name}',
      assignment.providerType.name,
    );
    await prefs.setString(
      '$_prefsKeyRoleModel${role.name}',
      assignment.modelId,
    );

    final current = state.valueOrNull;
    if (current == null) return;
    final newAssignments =
        Map<LlmRole, ModelAssignment>.from(current.settings.roleAssignments);
    newAssignments[role] = assignment;
    state = AsyncData(
      current.copyWith(
        settings: current.settings.copyWith(roleAssignments: newAssignments),
      ),
    );
  }

  Future<void> setOllamaBaseUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyBaseUrl, trimmed);

    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        settings: current.settings.copyWith(ollamaBaseUrl: trimmed),
      ),
    );
    await refreshOllama();
  }

  Future<void> setApiKey(LlmProviderType type, String key) async {
    if (type == LlmProviderType.ollama) return;
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    const storage = FlutterSecureStorage();
    await storage.write(
      key: '$_keychainKeyPrefix${type.name}',
      value: trimmed,
    );

    final current = state.valueOrNull;
    if (current == null) return;
    final newKeys = Map<LlmProviderType, String?>.from(
      current.settings.apiKeys,
    );
    newKeys[type] = trimmed;
    state = AsyncData(
      current.copyWith(
        settings: current.settings.copyWith(apiKeys: newKeys),
      ),
    );
  }

  Future<void> clearApiKey(LlmProviderType type) async {
    if (type == LlmProviderType.ollama) return;
    const storage = FlutterSecureStorage();
    await storage.delete(key: '$_keychainKeyPrefix${type.name}');

    final current = state.valueOrNull;
    if (current == null) return;
    final newKeys = Map<LlmProviderType, String?>.from(
      current.settings.apiKeys,
    );
    newKeys[type] = null;
    state = AsyncData(
      current.copyWith(
        settings: current.settings.copyWith(apiKeys: newKeys),
      ),
    );
  }

  Future<void> refreshOllama() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      final models =
          await OllamaProvider.fetchModels(current.settings.ollamaBaseUrl);
      if (state.valueOrNull == null) return;
      state = AsyncData(
        current.copyWith(
          ollamaModels: models,
          ollamaStatus: OllamaStatus.connected,
        ),
      );
    } catch (_) {
      if (state.valueOrNull == null) return;
      state = AsyncData(
        current.copyWith(
          ollamaModels: const [],
          ollamaStatus: OllamaStatus.notRunning,
        ),
      );
    }
  }
}
