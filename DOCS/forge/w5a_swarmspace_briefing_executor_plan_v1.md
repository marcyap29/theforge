# §W5a — SwarmSpace Service + Weekly Briefing
## Executor Plan v1 — Qwen3 Coder

**Repo:** `/Volumes/Marc Working Drive/Development/The Forge/`
**Branch:** Create and work on branch `wt/w5-briefing`. Do not commit to main.
**Linter:** `dart analyze lib/` — run after EACH file. Fix all issues before moving to the next file.

---

## Definition of Done

`briefing_screen.dart` is reachable from the Watch Mode dashboard. Tapping "Run Briefing" assembles a Watch Mode data summary, calls SwarmSpace `deep_research` via HTTP, and renders the returned narrative as scrollable markdown. Idle / loading / done / error states all work. `dart analyze lib/` reports zero issues.

---

## Context

The Forge is a Flutter desktop app (macOS). It has a Watch Mode that ingests per-engineer token usage, git activity, CI outcomes, and failure signals. All of that data is available in a `WatchData` object from `watchDataProvider`.

§W5a adds:
1. A SwarmSpace HTTP service that calls the `deep_research` MCP tool
2. A Riverpod provider for that service (nullable — only active when a key is configured)
3. A `BriefingNotifier` that assembles Watch Mode data into a query and calls the service
4. A `BriefingScreen` that displays the result

---

## Files — exact list, no others

### Files to MODIFY

**1. `lib/services/llm/llm_model_config.dart`**
**2. `lib/features/settings/settings_notifier.dart`**

### Files to CREATE

**3. `lib/services/swarmspace/swarmspace_service.dart`** (new directory)
**4. `lib/services/swarmspace/swarmspace_service_provider.dart`**
**5. `lib/features/watch/briefing_notifier.dart`**
**6. `lib/features/watch/briefing_screen.dart`**

Do NOT touch any other file. Do NOT modify `pubspec.yaml` — all dependencies are already present.

---

## File 1 — `lib/services/llm/llm_model_config.dart`

### What to change

Add `swarmspaceApiKey: String?` to `LlmSettings`. This is a top-level field, NOT part of the `apiKeys` map (which is keyed by `LlmProviderType` and is for LLM routing only).

### Current `LlmSettings` class (lines 60–102):

```dart
@immutable
class LlmSettings {
  final Map<LlmRole, ModelAssignment> roleAssignments;
  final Map<LlmProviderType, String?> apiKeys;
  final String ollamaBaseUrl;

  const LlmSettings({
    required this.roleAssignments,
    required this.apiKeys,
    required this.ollamaBaseUrl,
  });

  static const LlmSettings defaults = LlmSettings(
    roleAssignments: { ... },
    apiKeys: { ... },
    ollamaBaseUrl: 'http://localhost:11434',
  );

  LlmSettings copyWith({
    Map<LlmRole, ModelAssignment>? roleAssignments,
    Map<LlmProviderType, String?>? apiKeys,
    String? ollamaBaseUrl,
  }) {
    return LlmSettings(
      roleAssignments: roleAssignments ?? this.roleAssignments,
      apiKeys: apiKeys ?? this.apiKeys,
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
    );
  }
}
```

### Required result — `LlmSettings` after your edit:

```dart
@immutable
class LlmSettings {
  final Map<LlmRole, ModelAssignment> roleAssignments;
  final Map<LlmProviderType, String?> apiKeys;
  final String ollamaBaseUrl;
  final String? swarmspaceApiKey;           // ← ADD THIS

  const LlmSettings({
    required this.roleAssignments,
    required this.apiKeys,
    required this.ollamaBaseUrl,
    this.swarmspaceApiKey,                  // ← ADD THIS (optional, defaults null)
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
    // swarmspaceApiKey omitted → null by default
  );

  LlmSettings copyWith({
    Map<LlmRole, ModelAssignment>? roleAssignments,
    Map<LlmProviderType, String?>? apiKeys,
    String? ollamaBaseUrl,
    String? swarmspaceApiKey,               // ← ADD THIS
  }) {
    return LlmSettings(
      roleAssignments: roleAssignments ?? this.roleAssignments,
      apiKeys: apiKeys ?? this.apiKeys,
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
      swarmspaceApiKey: swarmspaceApiKey ?? this.swarmspaceApiKey,  // ← ADD THIS
    );
  }
}
```

**After editing this file, run `dart analyze lib/` and fix all issues before continuing.**

---

## File 2 — `lib/features/settings/settings_notifier.dart`

### What to change — 3 additions

**Addition A:** In `build()`, after the existing API key loading block, read `swarmspaceApiKey` from `forge_config.json`.

**Addition B:** Add mutator `setSwarmspaceApiKey(String key)`.

**Addition C:** Add mutator `clearSwarmspaceApiKey()`.

### IMPORTANT — static vs instance methods

`_readConfigFile()` and `_writeConfigFile()` are `static` methods on `SettingsNotifier`.
- Call them as: `await SettingsNotifier._readConfigFile()` — NOT as `await _readConfigFile()` from inside instance methods.

Wait — inside the class itself, you can call static methods without the class prefix. The existing code already calls `await _readConfigFile()` and `await _writeConfigFile()` from instance methods — keep that pattern. Do not change the call style.

### Addition A — in `build()`, after `if (needsMigration) { ... }` block (around line 147), add:

```dart
    // Read SwarmSpace API key from config file
    final swarmspaceApiKey =
        config['swarmspace_api_key'] as String?;
```

Then update the `return LlmSettingsState(...)` call to pass the new field:

```dart
    return LlmSettingsState(
      settings: LlmSettings(
        roleAssignments: assignments,
        apiKeys: apiKeys,
        ollamaBaseUrl: baseUrl,
        swarmspaceApiKey: swarmspaceApiKey,   // ← ADD THIS
      ),
    );
```

### Addition B — new mutator, add after `clearApiKey()`:

```dart
  Future<void> setSwarmspaceApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;

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
```

### Addition C — new mutator, add after `setSwarmspaceApiKey()`:

```dart
  Future<void> clearSwarmspaceApiKey() async {
    final config = await _readConfigFile();
    final updated = Map<String, dynamic>.from(config);
    updated.remove('swarmspace_api_key');
    await _writeConfigFile(updated);

    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        settings: current.settings.copyWith(swarmspaceApiKey: null),
      ),
    );
  }
```

**After editing this file, run `dart analyze lib/` and fix all issues before continuing.**

---

## File 3 — `lib/services/swarmspace/swarmspace_service.dart` (NEW)

Create directory `lib/services/swarmspace/` first.

### Full file content:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

class SwarmSpaceService {
  static const _endpoint =
      'https://swarmspace-mcp-server.orbitalai.workers.dev/mcp';

  final String apiKey;

  const SwarmSpaceService({required this.apiKey});

  /// Calls the SwarmSpace deep_research MCP tool and returns the text result.
  /// Throws [SwarmSpaceException] on HTTP or parse errors.
  Future<String> deepResearch(String query) async {
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'tools/call',
      'params': {
        'name': 'deep_research',
        'arguments': {'query': query},
      },
    });

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw SwarmSpaceException(
          'HTTP ${response.statusCode}: ${response.body}');
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final result = json['result'] as Map<String, dynamic>?;
      final content = result?['content'] as List<dynamic>?;
      final first = content?.firstOrNull as Map<String, dynamic>?;
      final text = first?['text'] as String?;
      if (text == null || text.isEmpty) {
        throw SwarmSpaceException('Empty response from deep_research');
      }
      return text;
    } on SwarmSpaceException {
      rethrow;
    } catch (e) {
      throw SwarmSpaceException('Failed to parse response: $e');
    }
  }
}

class SwarmSpaceException implements Exception {
  final String message;
  const SwarmSpaceException(this.message);

  @override
  String toString() => 'SwarmSpaceException: $message';
}
```

**After creating this file, run `dart analyze lib/` and fix all issues before continuing.**

---

## File 4 — `lib/services/swarmspace/swarmspace_service_provider.dart` (NEW)

### Riverpod pattern — EXACT pairing required:

```
Provider<SwarmSpaceService?>  (non-family, non-autoDispose, nullable)
```

Reference pattern from the codebase — `git_activity_service_provider.dart`:
```dart
final gitActivityServiceProvider = Provider<GitActivityService?>((ref) {
  ...
  if (!config.isConfigured) return null;
  return GitActivityService(config: config, roster: roster);
});
```

### Full file content:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/settings_providers.dart';
import 'swarmspace_service.dart';

/// Returns null when no SwarmSpace API key is configured.
/// Consumers must null-check before calling deepResearch().
final swarmSpaceServiceProvider = Provider<SwarmSpaceService?>((ref) {
  final settingsAsync = ref.watch(settingsProvider);
  final key = settingsAsync.valueOrNull?.settings.swarmspaceApiKey;
  if (key == null || key.isEmpty) return null;
  return SwarmSpaceService(apiKey: key);
});
```

**Provider is declared ONLY in this file. Do not declare it anywhere else.**

**After creating this file, run `dart analyze lib/` and fix all issues before continuing.**

---

## File 5 — `lib/features/watch/briefing_notifier.dart` (NEW)

### Riverpod pattern — EXACT pairing required:

```
class BriefingNotifier extends AsyncNotifier<String?>
final briefingProvider = AsyncNotifierProvider<BriefingNotifier, String?>(BriefingNotifier.new)
```

Reference pattern: `lib/features/watch/watch_data_notifier.dart` uses `AsyncNotifier<WatchData>` + `AsyncNotifierProvider`.

### What this notifier does:

1. `build()` returns `null` immediately (idle state — no briefing generated yet)
2. `generate()` is called by the screen when the user taps "Run Briefing":
   - Reads `swarmSpaceServiceProvider` — if null, sets error state
   - Reads `watchDataProvider` — if loading/error, sets error state
   - Assembles the `WatchData` into a briefing query string (see prompt template below)
   - Calls `service.deepResearch(query)` — if throws, sets error state
   - Sets `state = AsyncData(resultText)` on success

### Briefing query template — implement this exactly as a private method `_buildQuery(WatchData data)`:

```
ENGINEERING INTELLIGENCE BRIEFING REQUEST

Workspace 30-day spend: \$[sum of all engineer totalCostUSD30d, formatted to 2 decimal places]
Engineers tracked: [count of usage entries]
Velocity trend: [signalResult.workspaceStatus.velocityTrend]
Commits last 7d: [signalResult.workspaceStatus.commitsLast7d]
Commits prior 7d: [signalResult.workspaceStatus.commitsPrior7d]
Active signals: [count of signalResult.signals]

ENGINEER BREAKDOWN:
[for each usage entry, one line: "- {handle}: \${totalCostUSD30d.toStringAsFixed(2)} 30d spend, alert flags: {alertFlags.join(', ') or 'none'}"]

ACTIVE SIGNALS:
[for each signal in signalResult.signals, one line: "- [{severity.name.toUpperCase()}] {engineerHandle}: {detail}"]
[if no signals: "- No active signals"]

Please synthesize a plain-language weekly engineering intelligence briefing covering:
1. What is going well
2. What needs attention  
3. Top 3 actionable recommendations for the engineering manager

Be direct and specific. Avoid generic advice. Base everything on the telemetry above.
```

### WatchData fields available (do not access fields that don't exist):

```dart
// WatchData
data.usage           // List<EngineerUsage>
data.correlations    // List<EngineerCorrelation>
data.signalResult    // WatchSignalResult
data.hasGitHubConfig // bool

// EngineerUsage
usage.engineerHandle       // String
usage.totalCostUSD30d      // double
usage.alertFlags           // List<String>

// WatchSignalResult
signalResult.signals         // List<FailureSignal>
signalResult.workspaceStatus // WorkspaceStatus

// WorkspaceStatus
workspaceStatus.velocityTrend    // String ('improving'|'stable'|'declining'|'stalled')
workspaceStatus.commitsLast7d    // int
workspaceStatus.commitsPrior7d   // int

// FailureSignal
signal.engineerHandle  // String
signal.severity        // FailureSignalSeverity (enum with .name)
signal.detail          // String
```

### Full file:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../watch/watch_data_notifier.dart';
import '../../services/swarmspace/swarmspace_service_provider.dart';

class BriefingNotifier extends AsyncNotifier<String?> {
  @override
  String? build() => null;

  Future<void> generate() async {
    state = const AsyncLoading();

    final service = ref.read(swarmSpaceServiceProvider);
    if (service == null) {
      state = AsyncError(
        'No SwarmSpace API key configured.',
        StackTrace.current,
      );
      return;
    }

    final watchAsync = ref.read(watchDataProvider);
    final watchData = watchAsync.valueOrNull;
    if (watchData == null) {
      state = AsyncError(
        'Watch Mode data not available.',
        StackTrace.current,
      );
      return;
    }

    try {
      final query = _buildQuery(watchData);
      final result = await service.deepResearch(query);
      state = AsyncData(result);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  String _buildQuery(WatchData data) {
    final totalSpend = data.usage
        .fold<double>(0, (sum, u) => sum + u.totalCostUSD30d);

    final engineerLines = data.usage.map((u) {
      final flags =
          u.alertFlags.isEmpty ? 'none' : u.alertFlags.join(', ');
      return '- ${u.engineerHandle}: \$${u.totalCostUSD30d.toStringAsFixed(2)} 30d spend, alert flags: $flags';
    }).join('\n');

    final signalLines = data.signalResult.signals.isEmpty
        ? '- No active signals'
        : data.signalResult.signals.map((s) {
            return '- [${s.severity.name.toUpperCase()}] ${s.engineerHandle}: ${s.detail}';
          }).join('\n');

    final ws = data.signalResult.workspaceStatus;

    return '''
ENGINEERING INTELLIGENCE BRIEFING REQUEST

Workspace 30-day spend: \$${totalSpend.toStringAsFixed(2)}
Engineers tracked: ${data.usage.length}
Velocity trend: ${ws.velocityTrend}
Commits last 7d: ${ws.commitsLast7d}
Commits prior 7d: ${ws.commitsPrior7d}
Active signals: ${data.signalResult.signals.length}

ENGINEER BREAKDOWN:
$engineerLines

ACTIVE SIGNALS:
$signalLines

Please synthesize a plain-language weekly engineering intelligence briefing covering:
1. What is going well
2. What needs attention
3. Top 3 actionable recommendations for the engineering manager

Be direct and specific. Avoid generic advice. Base everything on the telemetry above.
''';
  }
}

final briefingProvider =
    AsyncNotifierProvider<BriefingNotifier, String?>(BriefingNotifier.new);
```

**Provider is declared ONLY in this file. Do not declare it in the screen.**

**After creating this file, run `dart analyze lib/` and fix all issues before continuing.**

---

## File 6 — `lib/features/watch/briefing_screen.dart` (NEW)

### What this screen does:

- AppBar: "Weekly Engineering Briefing" title + back button
- Body: 4 states driven by `ref.watch(briefingProvider)`:
  - **null (idle):** centered "Run Briefing" `FilledButton`; description text below: "Assembles your Watch Mode data and generates a plain-language engineering intelligence report via SwarmSpace."
  - **loading:** centered `CircularProgressIndicator` + "Generating briefing…" text below
  - **data (String result):** scrollable `Markdown` widget displaying the result; "Regenerate" `OutlinedButton` at bottom that calls `ref.read(briefingProvider.notifier).generate()`
  - **error:** error message in red + "Retry" `TextButton`

### IMPORTANT — macOS InkWell rule (BUG-UI-001):

Every `InkWell` in this file must have `Material(color: Colors.transparent)` as its immediate parent. A `Scaffold` higher in the tree is NOT sufficient on macOS desktop.

If you use `FilledButton` or `OutlinedButton` directly (not wrapping InkWell yourself), this is handled automatically — no Material wrapper needed for those widgets.

### Imports required:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'briefing_notifier.dart';
```

`flutter_markdown` is already in `pubspec.yaml`. Do not add it again.

### Class declaration — use `ConsumerStatefulWidget`:

```dart
class BriefingScreen extends ConsumerStatefulWidget {
  const BriefingScreen({super.key});

  @override
  ConsumerState<BriefingScreen> createState() => _BriefingScreenState();
}
```

### initState — trigger generation automatically on first open:

```dart
@override
void initState() {
  super.initState();
  // Auto-generate on first open if no result yet
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final current = ref.read(briefingProvider);
    if (current.valueOrNull == null && !current.isLoading) {
      ref.read(briefingProvider.notifier).generate();
    }
  });
}
```

### Color palette — match app theme:

```dart
const amber = Color(0xFFF59E0B);
const cardBg = Color(0xFF0F0F10);
const cardBorder = Color(0xFF1F2937);
const textMuted = Color(0xFF9CA3AF);
```

**After creating this file, run `dart analyze lib/` and fix all issues before continuing.**

---

## Verification Checklist

Run each check before reporting done. All must pass.

```
[ ] dart analyze lib/ — zero issues (run after EACH file; fix before moving on)
[ ] grep -rn "briefingProvider" lib/ — declared in briefing_notifier.dart only
[ ] grep -rn "swarmSpaceServiceProvider" lib/ — declared in swarmspace_service_provider.dart only
[ ] grep -rn "swarmspaceApiKey" lib/ — present in llm_model_config.dart AND settings_notifier.dart
[ ] grep -rn "class SwarmSpaceService" lib/ — exactly 1 match
[ ] grep -rn "class BriefingNotifier" lib/ — exactly 1 match
[ ] grep -rn "class BriefingScreen" lib/ — exactly 1 match
[ ] No files modified outside the 6 listed above
[ ] No new entries added to pubspec.yaml
```

---

## Anti-patterns to avoid

1. **Do not batch `dart analyze` to the end.** Run it after every file and fix issues immediately.
2. **Do not leave markdown fence markers (` ``` `) or duplicate closing braces as live Dart code.** Scan each file after writing for stray artifact characters.
3. **`swarmSpaceServiceProvider` is declared ONCE — in `swarmspace_service_provider.dart`.** Do not re-declare it in `briefing_notifier.dart` or `briefing_screen.dart`.
4. **`briefingProvider` is declared ONCE — in `briefing_notifier.dart`.** Do not re-declare it in `briefing_screen.dart`.
5. **`_readConfigFile()` and `_writeConfigFile()` in `settings_notifier.dart` are static methods you are calling from within the same class — call them without the class prefix (existing codebase pattern).**
6. **Do not add `const` to the `LlmSettings.defaults` field for `swarmspaceApiKey` — it is already `null` by default via the optional constructor param.**

---

## When done

Push branch `wt/w5-briefing` to origin. Do not merge. Report:
- Which files were created/modified
- Output of final `dart analyze lib/`
- Any assumptions made where the spec was ambiguous
