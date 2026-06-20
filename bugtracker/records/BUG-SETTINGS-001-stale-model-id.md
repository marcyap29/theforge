# BUG-SETTINGS-001 — Retired Model ID in SharedPreferences Causes API 404

**ID:** BUG-SETTINGS-001
**Area:** SETTINGS
**Severity:** High
**Status:** Fixed 2026-06-20

---

## Symptom

Spec generation and worksheet generation failed with an API error. The app was making LLM calls using model ID `gemini-3.5-flash` which does not exist in the Gemini API (Google skipped from 1.5 to 2.0; there is no 3.5). Gemini returned a 404, surfaced as an error in the spec generation screen.

## Root Cause

`SettingsNotifier.build()` loaded role assignments from SharedPreferences without validating the model ID:
```dart
final savedModelId = prefs.getString('$_prefsKeyRoleModel${role.name}');
final modelId = savedModelId ?? (isFirstRun ? 'gemini-2.5-flash' : '');
```

If `savedModelId` is `'gemini-3.5-flash'` (stored from a prior code version), it's used verbatim. SharedPreferences persists across app updates. When the model catalog in `llm_model_config.dart` is updated to remove retired IDs, previously stored values are not migrated.

## Fix

Added validation in `settings_notifier.build()`:
```dart
final validIds = modelsFor(providerType).map((m) => m.id).toSet();
final fallbackId = modelsFor(providerType).firstOrNull?.id ?? 'gemini-2.5-flash';
final modelId = (savedModelId != null &&
        savedModelId.isNotEmpty &&
        (providerType == LlmProviderType.ollama ||
            validIds.contains(savedModelId)))
    ? savedModelId
    : (isFirstRun ? 'gemini-2.5-flash' : fallbackId);
```

Ollama is exempted because its model list is dynamic (fetched from `localhost:11434`).

Also updated model catalog:
- Removed `gpt-4-turbo` (retired) → replaced with `gpt-4.1`
- Removed `gemini-1.5-flash` → replaced with `gemini-2.0-flash` (stable)
- Retained `gemini-2.5-flash`, `gemini-2.5-pro` (current)

## Prevention Rule

See BUG_PREVENTION.md — "Validate stored model IDs against the current catalog on settings load."

## Commit

`3721a29`
