import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/llm/key_check.dart';
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
  static const _prefsKeyRoleThink = 'forge_role_think_';
  static const _keychainKeyPrefix = 'forge_api_key_';
  static const _keychainKeyPrefixSwarmspace = 'forge_api_key_swarmspace';
  static const _configFileName = 'forge_config.json';

  /// API keys now live in the OS keychain (encrypted at rest) rather than the
  /// plaintext config file / SharedPreferences. The prefixes above are reused as
  /// keychain item names, so legacy plaintext keys migrate to the same names.
  // Use the legacy (file-based) login keychain, not the data-protection
  // keychain — the latter needs a `keychain-access-groups` entitlement that's
  // awkward for a Developer ID (non-App-Store) app. Keys are still encrypted at
  // rest in the macOS keychain; this just avoids the entitlement dance.
  static const _secure = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  static Future<String?> _readSecure(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  /// Returns true only if the keychain write/delete actually succeeded — so
  /// migration never scrubs a plaintext key it failed to move into the keychain.
  static Future<bool> _writeSecure(String key, String? value) async {
    try {
      if (value == null || value.isEmpty) {
        await _secure.delete(key: key);
      } else {
        await _secure.write(key: key, value: value);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

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
      // Thinking defaults ON (model's own default); persisted per role.
      final think =
          prefs.getBool('$_prefsKeyRoleThink${role.name}') ?? true;
      assignments[role] = ModelAssignment(
        providerType: providerType,
        modelId: modelId,
        think: think,
      );
    }

    // Load API keys from the OS keychain (encrypted). For existing users whose
    // keys are still in the plaintext config file / SharedPreferences (or a
    // key a power-user dropped into forge_config.json), migrate into the
    // keychain and then SCRUB the plaintext copies below.
    final apiKeys = <LlmProviderType, String?>{};
    var migratedAny = false;
    var migrationFailed = false;

    for (final type in LlmProviderType.values) {
      final name = type.name;
      var key = await _readSecure('$_keychainKeyPrefix$name');
      if (key == null || key.isEmpty) {
        final fromFile = savedKeys[name] as String?;
        final fromPrefs = prefs.getString('$_keychainKeyPrefix$name');
        final legacy = (fromFile?.isNotEmpty == true) ? fromFile : fromPrefs;
        if (legacy != null && legacy.isNotEmpty) {
          key = legacy; // use it this session regardless of keychain outcome
          if (await _writeSecure('$_keychainKeyPrefix$name', legacy)) {
            migratedAny = true;
          } else {
            migrationFailed = true;
          }
        }
      }
      apiKeys[type] = (key == null || key.isEmpty) ? null : key;
    }

    var swarmspaceApiKey = await _readSecure(_keychainKeyPrefixSwarmspace);
    if (swarmspaceApiKey == null || swarmspaceApiKey.isEmpty) {
      final legacy = (config['swarmspace_api_key'] as String?) ??
          prefs.getString(_keychainKeyPrefixSwarmspace);
      if (legacy != null && legacy.isNotEmpty) {
        swarmspaceApiKey = legacy;
        if (await _writeSecure(_keychainKeyPrefixSwarmspace, legacy)) {
          migratedAny = true;
        } else {
          migrationFailed = true;
        }
      }
    }
    if (swarmspaceApiKey != null && swarmspaceApiKey.isEmpty) {
      swarmspaceApiKey = null;
    }

    // Scrub plaintext ONLY when every discovered key made it into the keychain —
    // never delete a plaintext copy we failed to migrate (retry next launch).
    final scrubPlaintext = migratedAny && !migrationFailed;

    // One-time cleanup: remove every plaintext key copy now that they're in the
    // keychain, leaving non-secret config (if any) intact.
    if (scrubPlaintext) {
      final cleaned = Map<String, dynamic>.from(config)
        ..remove('api_keys')
        ..remove('swarmspace_api_key');
      await _writeConfigFile(cleaned);
      for (final type in LlmProviderType.values) {
        await prefs.remove('$_keychainKeyPrefix${type.name}');
      }
      await prefs.remove(_keychainKeyPrefixSwarmspace);
    }

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
    await prefs.setBool(
      '$_prefsKeyRoleThink${role.name}',
      assignment.think,
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

    // Store in the OS keychain (encrypted), not plaintext.
    await _writeSecure('$_keychainKeyPrefix${type.name}', trimmed);

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
    await _writeSecure('$_keychainKeyPrefix${type.name}', null);
    // Also clear any legacy plaintext copy that predates the keychain move.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keychainKeyPrefix${type.name}');

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

    await _writeSecure(_keychainKeyPrefixSwarmspace, trimmed);

    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        settings: current.settings.copyWith(swarmspaceApiKey: trimmed),
      ),
    );
  }

  Future<void> clearSwarmspaceApiKey() async {
    await _writeSecure(_keychainKeyPrefixSwarmspace, null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keychainKeyPrefixSwarmspace);

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
      return friendlyLlmError(e, type: type);
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
