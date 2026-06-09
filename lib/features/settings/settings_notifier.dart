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
import '../../services/llm/providers/gemini_provider.dart';
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
          (isFirstRun ? 'gemini-3.5-flash' : '');
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
      if (type == LlmProviderType.ollama) {
        apiKeys[type] = null;
      } else {
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

    return LlmSettingsState(
      settings: LlmSettings(
        roleAssignments: assignments,
        apiKeys: apiKeys,
        ollamaBaseUrl: baseUrl,
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
    if (type == LlmProviderType.ollama) return;
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
    if (type == LlmProviderType.ollama) return;

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

  /// Returns null on success, error string on failure.
  Future<String?> testProvider(LlmProviderType type) async {
    final current = state.valueOrNull;
    if (current == null) return 'Settings not loaded.';

    final key = current.settings.apiKeys[type];
    final baseUrl = current.settings.ollamaBaseUrl;

    LlmProvider provider;
    String modelId;

    switch (type) {
      case LlmProviderType.gemini:
        if (key == null || key.isEmpty) return 'No API key configured.';
        provider = GeminiProvider(apiKey: key);
        modelId = 'gemini-3.5-flash';
      case LlmProviderType.claude:
        if (key == null || key.isEmpty) return 'No API key configured.';
        provider = ClaudeProvider(apiKey: key);
        modelId = 'claude-haiku-4-5-20251001';
      case LlmProviderType.openai:
        if (key == null || key.isEmpty) return 'No API key configured.';
        provider = OpenAiProvider(apiKey: key);
        modelId = 'gpt-4o-mini';
      case LlmProviderType.ollama:
        provider = OllamaProvider(baseUrl: baseUrl);
        modelId = current.ollamaModels.firstOrNull?.id ?? 'llama3';
    }

    try {
      await provider.complete(
        systemPrompt: 'You are a test assistant.',
        userPrompt: 'Reply with exactly one word: OK',
        temperature: 0.0,
        modelId: modelId,
        maxTokens: 10,
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
