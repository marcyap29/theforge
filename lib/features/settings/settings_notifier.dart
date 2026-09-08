import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/llm/llm_model_config.dart';
import '../../services/llm/llm_provider.dart';
import '../../services/llm/providers/claude_provider.dart';
import '../../services/llm/providers/ollama_provider.dart';
import '../../services/llm/providers/openai_provider.dart';

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
  static const _keychainKeyPrefixSwarmspace = 'forge_api_key_swarmspace';
  static const _configFileName = 'forge_config.json';

  // ── Config file helpers ───────────────────────────────────────────────────

  static Future<File> _configFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _configFileName));
  }

  static Future<Map<String, dynamic>> _readConfigFile() async {
    try {
      final file = await _configFile();
      if (!file.existsSync()) return {};
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeConfigFile(Map<String, dynamic> data) async {
    try {
      final file = await _configFile();
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    } catch (_) {}
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Future<LlmSettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final config = await _readConfigFile();
    final savedKeys =
        (config['api_keys'] as Map<String, dynamic>? ?? {});

    final baseUrl =
        prefs.getString(_prefsKeyBaseUrl) ?? 'https://ollama.com';

    final assignments = <LlmRole, ModelAssignment>{};
    for (final role in LlmRole.values) {
      final providerStr =
          prefs.getString('$_prefsKeyRoleProvider${role.name}');
      final savedModelId =
          prefs.getString('$_prefsKeyRoleModel${role.name}');
      const defaultModelId = 'gpt-oss:120b-cloud';
      final isFirstRun = providerStr == null;
      final providerType = isFirstRun
          ? LlmProviderType.ollama
          : LlmProviderType.values.firstWhere(
              (p) => p.name == providerStr,
              orElse: () => LlmProviderType.ollama,
            );
      // Validate stored model ID against the current catalog. Retired or
      // misspelled IDs fall back to the first valid model for that provider so
      // the app never starts with a model that the API will reject. Ollama
      // accepts any model id (local or cloud), so it is not validated here.
      final validIds = modelsFor(providerType).map((m) => m.id).toSet();
      final fallbackId =
          modelsFor(providerType).firstOrNull?.id ?? defaultModelId;
      final modelId = (savedModelId != null &&
              savedModelId.isNotEmpty &&
              (providerType == LlmProviderType.ollama ||
                  validIds.contains(savedModelId)))
          ? savedModelId
          : (isFirstRun ? defaultModelId : fallbackId);
      assignments[role] = ModelAssignment(
        providerType: providerType,
        modelId: modelId,
      );
    }

    // Load API keys: config file is authoritative, SharedPreferences is fallback
    final apiKeys = <LlmProviderType, String?>{};
    final migratedKeys = <String, dynamic>{};
    bool needsMigration = false;

    for (final type in LlmProviderType.values) {
      {
        // All providers (including Ollama, for Cloud API-key auth) resolve a
        // key from the config file first, then SharedPreferences.
        final fromFile = savedKeys[type.name] as String?;
        final fromPrefs = prefs.getString('$_keychainKeyPrefix${type.name}');
        final resolved =
            (fromFile?.isNotEmpty == true) ? fromFile : fromPrefs;
        apiKeys[type] = resolved;

        // Migrate key found only in prefs to config file
        if (fromFile == null && fromPrefs != null && fromPrefs.isNotEmpty) {
          migratedKeys[type.name] = fromPrefs;
          needsMigration = true;
        } else {
          migratedKeys[type.name] = fromFile;
        }
      }
    }

    if (needsMigration) {
      final updatedConfig = Map<String, dynamic>.from(config);
      updatedConfig['api_keys'] = migratedKeys;
      await _writeConfigFile(updatedConfig);
    }

    final swarmspaceApiKey =
        config['swarmspace_api_key'] as String?;

    return LlmSettingsState(
      settings: LlmSettings(
        roleAssignments: assignments,
        apiKeys: apiKeys,
        ollamaBaseUrl: baseUrl,
        swarmspaceApiKey: swarmspaceApiKey,
      ),
    );
  }

  // ── Mutators ──────────────────────────────────────────────────────────────

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
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;

    // Write to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keychainKeyPrefix${type.name}', trimmed);

    // Write to config file (authoritative on next launch)
    final config = await _readConfigFile();
    final keys = Map<String, dynamic>.from(
        config['api_keys'] as Map<String, dynamic>? ?? {});
    keys[type.name] = trimmed;
    await _writeConfigFile({...config, 'api_keys': keys});

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keychainKeyPrefix${type.name}');

    // Remove from config file
    final config = await _readConfigFile();
    final keys = Map<String, dynamic>.from(
        config['api_keys'] as Map<String, dynamic>? ?? {});
    keys.remove(type.name);
    await _writeConfigFile({...config, 'api_keys': keys});

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

  Future<void> setSwarmspaceApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keychainKeyPrefixSwarmspace, trimmed);

    final config = await _readConfigFile();
    await _writeConfigFile({...config, 'swarmspace_api_key': trimmed});

    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        settings: current.settings.copyWith(swarmspaceApiKey: trimmed),
      ),
    );
  }

  Future<void> clearSwarmspaceApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keychainKeyPrefixSwarmspace);

    final config = await _readConfigFile();
    final updatedConfig = Map<String, dynamic>.from(config);
    updatedConfig.remove('swarmspace_api_key');
    await _writeConfigFile(updatedConfig);

    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        settings: current.settings.copyWith(swarmspaceApiKey: null),
      ),
    );
  }

  /// Returns null on success, error string on failure.
  Future<String?> testProvider(LlmProviderType type) async {
    final current = state.valueOrNull;
    if (current == null) return 'Settings not loaded.';

    final key = current.settings.apiKeys[type];
    final baseUrl = current.settings.ollamaBaseUrl;

    LlmProvider provider;
    String modelId;

    switch (type) {
      case LlmProviderType.claude:
        if (key == null || key.isEmpty) return 'No API key configured.';
        provider = ClaudeProvider(apiKey: key);
        modelId = 'claude-haiku-4-5-20251001';
      case LlmProviderType.openai:
        if (key == null || key.isEmpty) return 'No API key configured.';
        provider = OpenAiProvider(apiKey: key);
        modelId = 'gpt-4o-mini';
      case LlmProviderType.ollama:
        // Cloud (https://ollama.com) needs a key; a local server does not.
        final isCloud = baseUrl.contains('ollama.com');
        if (isCloud && (key == null || key.isEmpty)) {
          return 'No API key configured for Ollama Cloud.';
        }
        provider = OllamaProvider(baseUrl: baseUrl, apiKey: key);
        modelId = current.ollamaModels.firstOrNull?.id ??
            current.settings.roleAssignments[LlmRole.architect]?.modelId ??
            'gpt-oss:120b-cloud';
    }

    try {
      await provider.complete(
        systemPrompt: 'You are a test assistant.',
        userPrompt: 'Reply with exactly one word: OK',
        temperature: 0.0,
        modelId: modelId,
        maxTokens: 100,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> refreshOllama() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      final models = await OllamaProvider.fetchModels(
        current.settings.ollamaBaseUrl,
        apiKey: current.settings.apiKeys[LlmProviderType.ollama],
      );
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
