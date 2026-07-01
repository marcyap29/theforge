# The Forge — Full Context Reference

**Version:** 1.0  
**For:** New Claude instances, architecture sessions, feature planning  
**Last Updated:** 2026-06-30

---

## What Is The Forge?

The Forge is a **Flutter desktop app (macOS primary)** that acts as a structured project manager for AI-assisted software development. It sits between a human product owner and executor AI agents (Claude Code, Codex, Cursor, DeepSeek, etc.).

The core insight: AI agents build better when they receive a tight, unambiguous spec. The Forge conducts a structured interview, resolves conflicts, and produces that spec — then hands it off to an executor in a format the agent can act on immediately.

**Three operating modes:**

| Mode | Purpose |
|---|---|
| **Plan Mode** | Greenfield interview → locked spec → executor handoff |
| **Watch Mode** | Token spend + git activity + CI correlation + alerts |
| **Pull Mode** | Read existing codebase → as-built spec (for onboarding legacy projects) |

All three modes share one output format: the **Locked Spec** — a structured Markdown document that is immutable after creation.

---

## Tech Stack

```
Flutter 3.38.7 (Dart ^3.10.7)       Desktop macOS app
Riverpod 2.x                          State management (AsyncNotifier, FamilyAsyncNotifier)
Local filesystem                       Primary storage — Markdown + JSON files
drift (SQLite)                         Project browser cache (NOT source of truth)
LlmService (pluggable)                 Routes LLM calls; 4 provider implementations
fl_chart                               Watch Mode spend charts
package:http                           All HTTP calls (no vendor SDKs)
SharedPreferences + forge_config.json  Settings + non-secret config
macOS Keychain (not in use currently)  API keys via forge_config.json in practice
```

**No Firebase. No hardcoded keys. `dart analyze lib/` must be clean (zero warnings) before any change is committed.**

---

## Repository Layout

```
The Forge/                             ← repo root / working directory
├── lib/
│   ├── core/
│   │   ├── app.dart                   MaterialApp, named routes, routeObserver
│   │   └── theme/app_theme.dart       Dark theme: Menlo font, amber #E8A04C accent
│   ├── data/
│   │   ├── filesystem/
│   │   │   └── project_file_repository.dart   ← ALL disk I/O lives here
│   │   └── local_db/
│   │       └── forge_database.dart    drift SQLite schema (projects table)
│   ├── features/
│   │   ├── artifacts/
│   │   │   └── artifact_viewer_screen.dart    Read-only markdown viewer
│   │   ├── interview/
│   │   │   ├── providers/interview_providers.dart   InterviewArgs + interviewProvider
│   │   │   ├── state/
│   │   │   │   ├── interview_dimension.dart   DimensionDef, LayerDef, buildDimensions/auditDimensions
│   │   │   │   ├── interview_notifier.dart    FamilyAsyncNotifier — core LLM loop
│   │   │   │   └── interview_state.dart       InterviewState model
│   │   │   └── ui/
│   │   │       ├── confidence_meter.dart      8-bar dimension meter
│   │   │       └── interview_screen.dart      Chat UI, layer strip, rewind, escape hatch
│   │   ├── projects/
│   │   │   ├── ingestion/             Reference doc ingestion (LLM extract → disk)
│   │   │   ├── providers/             ProjectListNotifier, ActiveProjectNotifier, providers.dart
│   │   │   └── screens/
│   │   │       ├── new_project_screen.dart
│   │   │       ├── project_detail_screen.dart  ← most complex screen; phase timeline, panels, CTAs
│   │   │       └── projects_list_screen.dart
│   │   ├── addendum_interview/        Minor-spec (v1.1) interview system
│   │   │   ├── state/addendum_interview_notifier.dart
│   │   │   └── ui/addendum_interview_screen.dart
│   │   ├── pull_interview/            Pull Mode interview (as-built spec for existing codebases)
│   │   │   ├── state/
│   │   │   └── ui/pull_interview_screen.dart
│   │   ├── settings/
│   │   │   ├── settings_notifier.dart         LLM provider config + BYOK
│   │   │   ├── engineer_roster_notifier.dart  Watch Mode engineer roster
│   │   │   ├── github_config_notifier.dart    GitHub org/token/repos
│   │   │   └── settings_screen.dart
│   │   ├── spec_generation/
│   │   │   ├── spec_generator.dart            All LLM prompt builders + handoff builders
│   │   │   ├── spec_notifier.dart             Spec generation pipeline
│   │   │   ├── spec_parser.dart               Strip code fences, trim
│   │   │   ├── worksheet_generator.dart       Worksheet prompt builder
│   │   │   ├── worksheet_notifier.dart        Worksheet generation pipeline
│   │   │   ├── executor_timeline_notifier.dart  Build sequence generator
│   │   │   ├── as_built_spec_generator.dart   Pull Mode spec prompt builder
│   │   │   ├── as_built_spec_notifier.dart    Pull Mode spec generation pipeline
│   │   │   └── compliance/
│   │   │       ├── spec_compliance_models.dart
│   │   │       ├── spec_compliance_notifier.dart
│   │   │       └── spec_compliance_screen.dart
│   │   └── watch/
│   │       ├── watch_data_notifier.dart        Single orchestrating provider for all watch screens
│   │       ├── watch_dashboard_screen.dart
│   │       ├── engineer_detail_screen.dart
│   │       ├── workspace_health_screen.dart
│   │       ├── alert_log_screen.dart
│   │       ├── briefing_notifier.dart + briefing_screen.dart   SwarmSpace briefing
│   │       └── decision_notifier.dart + decision_screen.dart   Monte Carlo decision sim
│   └── services/
│       ├── llm/                       LLM abstraction layer
│       │   ├── llm_provider.dart      Abstract LlmProvider + LlmRole enum
│       │   ├── llm_service.dart       Resolves role → model → provider
│       │   ├── llm_model_config.dart  Model catalogs, LlmSettings, ModelAssignment
│       │   ├── llm_service_provider.dart
│       │   └── providers/
│       │       ├── claude_provider.dart
│       │       ├── openai_provider.dart
│       │       ├── gemini_provider.dart
│       │       └── ollama_provider.dart
│       ├── swarmspace/
│       │   └── swarmspace_service.dart    JSON-RPC 2.0 to SwarmSpace MCP endpoint
│       └── watch/                     Watch Mode data pipeline
│           ├── usage_provider.dart    Abstract UsageProvider + EngineerUsage/DailyUsage models
│           ├── demo_usage_provider.dart   4 synthetic engineer profiles (demo mode)
│           ├── usage_service.dart     Iterates roster → fetches all usage
│           ├── git_activity_provider.dart   Abstract + models
│           ├── ci_outcome_provider.dart     Abstract + models
│           ├── ci_correlator.dart     Joins token sessions + commits + CI runs
│           ├── git_activity_service.dart    Orchestrates git+CI fetch + correlate
│           ├── failure_signal_engine.dart   Derives 6 signal types from §W1+§W2 data
│           ├── alert_engine.dart      Deduplicates signals → AlertEntry log
│           ├── alert_log_notifier.dart    Persists alert log to forge_config.json
│           ├── project_status_aggregator.dart   Workspace health (velocity, stall, CI)
│           ├── watch_signal_service.dart    Orchestrates §W3 pipeline
│           ├── spec_drift_engine.dart   Checks spec compliance vs. git state
│           └── providers/
│               ├── anthropic_usage_provider.dart
│               ├── openai_usage_provider.dart
│               ├── gemini_usage_provider.dart   (stub — API unsupported)
│               ├── ollama_usage_provider.dart   (stub — local model)
│               ├── github_git_provider.dart     GitHub GraphQL
│               └── github_ci_provider.dart      GitHub Actions REST
```

---

## Local Project File Structure

Every Forge project is a folder on disk. Default root: `~/Documents/The Forge Projects/`.

```
~/Documents/The Forge Projects/{ProjectName}/
├── README.md                                     Phase state — always current
├── specs/
│   ├── v1/{ProjectName}_LockedSpec_v1.md         Immutable after creation
│   ├── v2/{ProjectName}_LockedSpec_v2.md
│   └── v1.1/{ProjectName}_LockedSpec_v1.1.md     Minor/addendum specs
├── handoffs/
│   ├── v1/{ProjectName}_BulletHandoff_v1_Interview.md
│   ├── v1/{ProjectName}_HandoffPackage_v1.json   Machine-readable executor handoff
│   ├── v1/{ProjectName}_goal_v1.md               /goal text for executor harness
│   └── v1/{ProjectName}_BuildSequence_v1.md      LLM-narrated build order
├── worksheets/
│   └── v1/{ProjectName}_SetupWorksheet_v1.md
├── forge/
│   ├── v1/{ProjectName}_LockedSpec_v1.md         Executor context copy
│   ├── v1/{ProjectName}_DecisionContext_v1.md    Decision rationale
│   └── v1/{ProjectName}_OpenFlags_v1.md          Unresolved items
├── ingested/
│   ├── reference_context.md                      LLM-extracted reference doc facts
│   └── {ProjectName}_V2Seeds.md                  Deferred capabilities (written at L3→L4)
├── pull_interview/
│   └── {ProjectName}_PullInterview.json          Pull Mode interview log
└── audit/
    ├── {ProjectName}_AuditLog.md                 Append-only — never replaced
    └── {ProjectName}_InterviewState.json         Full interview state (persisted every LLM turn)
```

**The filesystem is the database.** The SQLite drift index (`forge_database.dart`) is a cache for the project browser — stores path, name, mode, and phase. If deleted, it rebuilds from the filesystem scan.

---

## The LLM Layer

All LLM calls flow through one method:

```dart
// lib/services/llm/llm_service.dart
LlmService.complete({
  required LlmRole role,      // architect | executor
  required String systemPrompt,
  required String userPrompt,
  required double temperature,
  int? maxTokens,
}) → Future<String>
```

`LlmService` resolves `role → ModelAssignment → LlmProvider → HTTP call → String`.

```dart
// lib/services/llm/llm_provider.dart
enum LlmRole { architect, executor }

abstract class LlmProvider {
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required String modelId,
    int? maxTokens,
  });
}
```

| Provider | Class | API endpoint |
|---|---|---|
| Gemini | `GeminiProvider` | `generativelanguage.googleapis.com` REST |
| Claude | `ClaudeProvider` | `api.anthropic.com/v1/messages` |
| OpenAI | `OpenAiProvider` | `api.openai.com/v1/chat/completions` |
| Ollama | `OllamaProvider` | `localhost:11434/api/chat` |

All providers: direct HTTP via `package:http`. No SDK. API keys stored in `forge_config.json` (Application Support). Model IDs validated against the catalog on settings load — retired IDs fall back to the first valid model.

**Temperature conventions:** 0.1–0.2 = procedural/executor, 0.3 = structured output, 0.4–0.6 = balanced spec, higher = creative/experimental.

---

## State Management Patterns

The Forge uses Riverpod 2.x throughout. Key patterns:

### `FamilyAsyncNotifier<State, Args>` — the interview pattern

Used when you need one notifier instance per project. The `args` struct is the key.

```dart
// Example: AddendumInterviewNotifier
class AddendumInterviewArgs {
  final String projectPath;
  final String projectName;
  final String baseVersion;
  const AddendumInterviewArgs({...});
  // NOTE: if you need two widgets to share the SAME notifier instance,
  // implement == and hashCode on Args. If not, Dart's default object
  // identity is fine — each navigation push creates a fresh instance.
}

class AddendumInterviewNotifier
    extends FamilyAsyncNotifier<AddendumInterviewState, AddendumInterviewArgs> {
  @override
  Future<AddendumInterviewState> build(AddendumInterviewArgs arg) async {
    // Called once when first watched. Set up initial state.
    return AddendumInterviewState(...);
  }

  Future<void> addUserMessage(String text) async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isLoading: true));
    // ... LLM call ...
    state = AsyncData(current.copyWith(turns: [...], isLoading: false));
  }
}

final addendumInterviewProvider = AsyncNotifierProviderFamily<
    AddendumInterviewNotifier,
    AddendumInterviewState,
    AddendumInterviewArgs>(AddendumInterviewNotifier.new);
```

### `AsyncNotifier<State>` — the settings/watch pattern

Used for global singleton state (settings, watch data, alert log, etc.).

```dart
class SettingsNotifier extends AsyncNotifier<LlmSettings> {
  @override
  Future<LlmSettings> build() async {
    // Load from disk/prefs. Called once.
  }
  Future<void> setApiKey(String provider, String key) async { ... }
}
final settingsProvider = AsyncNotifierProvider<SettingsNotifier, LlmSettings>(
    SettingsNotifier.new);
```

### `copyWith` — immutable state updates

Every state class implements `copyWith()`. State never mutates in place.

```dart
class InterviewState {
  final List<InterviewTurn> turns;
  final bool isLoading;
  final String? error;
  // ...

  InterviewState copyWith({
    List<InterviewTurn>? turns,
    bool? isLoading,
    String? error,
    bool clearError = false,  // pattern for clearing nullable fields
  }) => InterviewState(
    turns: turns ?? this.turns,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}
```

### Provider reads in the UI

```dart
class _MyScreenState extends ConsumerState<MyScreen> {
  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(someProvider(args));
    final notifier = ref.read(someProvider(args).notifier);

    return asyncState.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text(e.toString()),
      data: (state) => /* build UI from state */,
    );
  }
}
```

---

## Plan Mode — The Interview Engine

The core product loop. Two interview modes share the same UI; mode determines which system prompt and which output format.

### Build Mode — 4-Layer Deductive Funnel

```
L1 Outcome       → Who is this for? What is the single thing it does?
L2 Decomposition → What 3-5 capabilities are needed to deliver L1?
L3 PoC           → Which ONE capability proves the concept? 5-step demo?
L4 Critical Path → Platform, identity model, input, output, external services
```

The LLM is instructed to append a `forge-state` JSON block after every response. Flutter strips the block before display and parses it to update `InterviewState`.

```
```forge-state
{
  "layer": "L1",
  "extracted": {
    "outcome": "string or null",
    "primaryUser": "string or null",
    "capabilities": [],
    "chosenCapability": null,
    "demoScript": [],
    "v2Seeds": [],
    "platform": null,
    "identityModel": null,
    "inputModel": null,
    "outputModel": null,
    "externalServices": []
  },
  "layerComplete": false,
  "conflicts": []
}
```
```

**Key parse safety rule:** All list fields use `is List<dynamic>` check before cast. A hard `as List<T>?` cast throws `TypeError` when the LLM outputs a string (`"None"`, `"TBD"`) — the outer try/catch then swallows the entire parse. Always:

```dart
final caps = extracted['capabilities'];
final capabilities = caps is List<dynamic>
    ? caps.map((e) => e.toString()).toList()
    : <String>[];
```

**`specGenEnabled` gate:** Fires when the L4 gate is met (`platform + identityModel + inputModel + outputModel` all non-null in `extracted`) AND `openConflicts.isEmpty`. Individual dimension tracking can silently fail on parse degradation; the extracted-field gate is the reliable signal.

**Layer advancement:** Flutter code is authoritative. When `layerComplete: true` in the forge-state block AND Flutter's own gate check passes, the layer advances. The LLM cannot force a layer advance by setting `layerComplete: true` alone.

**Interview state persistence:** `writeInterviewProgress()` is called after every successful LLM response. It writes the full turn history + extracted data + confidence map + layer boundaries to `audit/{Name}_InterviewState.json`. This allows seamless resume after app close.

### Audit Mode

8 flat dimensions (project goal, build state, feature ownership, active blockers, blocker blast radius, decision debt, technical debt, AI/token usage). No layer structure. Produces a Current State Spec, not a Locked Spec.

### Feature Interview Mode (V2+)

Once V1 is complete, `InterviewArgs.priorSpecVersion` is set to `"v1"`. The same 4-layer funnel runs but `_featureInterviewSystemPrompt` pre-loads the prior locked spec + V2 seeds. Each version produces artifacts with the correct version suffix in the same project folder.

---

## The Spec Generation Pipeline

After the interview, the user taps "Generate Spec". `SpecNotifier.generate()` runs this sequence:

```
1. Build spec prompt (spec_generator.dart — buildSpecPrompt())
   → Includes: interviewState.extracted, all 8 confidence dimensions,
     ingested reference context, prior spec (if Feature Mode)
2. LLM call: architect role, t=0.6, maxTokens=8192
3. SpecParser.clean() — strip code fences, trim whitespace
4. Truncation guard — abort if spec is missing §9 or §10 (model hit context ceiling)
5. writeLockedSpec() — write-once. Checks file existence. Aborts if file exists.
   → specs/v{N}/{Name}_LockedSpec_v{N}.md
6. buildGoalText() → handoffs/v{N}/{Name}_goal_v{N}.md   (/goal for executor harness)
7. buildHandoffPackage() → handoffs/v{N}/{Name}_HandoffPackage_v{N}.json
8. buildBulletHandoff() → handoffs/v{N}/{Name}_BulletHandoff_v{N}_Interview.md
9. writeForgeFiles() → forge/v{N}/DecisionContext + OpenFlags
10. Build verification checklist (second LLM call, t=0.1, non-fatal on failure)
    → stored in handoff package under 'verificationChecklist'
11. Update README.md phase → "v{N}_spec_locked"
12. Append to audit log
13. Update DB phase
```

Then the user generates the setup worksheet:

```
14. WorksheetNotifier.generate()
    → reads locked spec from disk
    → LLM call: architect role, t=0.3
    → writes worksheets/v{N}/{Name}_SetupWorksheet_v{N}.md
    → phase → "v{N}_worksheet_complete"
```

Optional (gated on worksheet complete):

```
15. ExecutorTimelineNotifier.generate()
    → reads component map from spec
    → LLM call: architect role, t=0.3, maxTokens=2048
    → writes handoffs/v{N}/{Name}_BuildSequence_v{N}.md
```

---

## The Locked Spec Format

10 sections. All are required. `specGenEnabled` only fires when sections §9 and §10 are present (truncation guard).

```
§1  Immutable Goal Statement
§2  Hard Constraints Table
§3  Component Map (single responsibility per component)
§4  Interface Contracts
§5  Completion Criteria (verifiable without human input)
§6  Static Content Specs (if applicable)
§7  Explicit Out-of-Scope List
§8  Accepted Decisions (chosen / rejected / reasoning / confidence)
§9  Open Flags (Flag / Component / Options / Recommended default)
§10 v2 Architecture Notes
+   Handoff Package JSON (appended by SpecNotifier)
```

---

## ProjectFileRepository — the I/O Contract

`lib/data/filesystem/project_file_repository.dart` is the **only** file in the app that reads or writes to disk. Every other module calls into this class. This makes it easy to audit all I/O.

Key methods (current as of 2026-06-30):

```dart
// Project management
Future<void> createProject(String path, String name, String mode)
Future<void> saveRootPath(String path)
Future<String> getSavedRootPath()

// Spec files
Future<void> writeLockedSpec(String path, String name, String version, String content)
    // Throws SpecAlreadyExistsException if file exists — specs are immutable
Future<String> readLockedSpec(String path, String version)
Future<File?> findSpecFile(String projectPath, String version)
    // Searches specs/v{version}/ for *_LockedSpec*.md — handles v1 and v1.1 formats
Future<void> writeMinorLockedSpec(String path, String name, String minorVersion, String content)
    // Writes to specs/v{minor}/ directory, creates it if needed

// Handoffs + forge files
Future<void> writeHandoff(String path, String name, String version, String content)
Future<void> writeHandoffPackage(String path, String name, String version, Map<String,dynamic> data)
Future<void> writeForgeFiles(String path, String name, String version, {...})
Future<Map<String,dynamic>?> readHandoffPackage(String path, String version)

// Worksheets
Future<void> writeWorksheet(String path, String name, String version, String content)

// Interview persistence
Future<void> writeInterviewProgress(String path, String name, Map<String,dynamic> state)
Future<Map<String,dynamic>?> readInterviewProgress(String path, String name)
Future<void> clearInterviewProgress(String path, String name)

// Pull Mode
Future<void> writePullInterviewLog(String path, String name, String content)
Future<String?> readPullInterviewLog(String path, String name)
Future<void> writeAsBuiltSpec(String path, String name, String content)

// Reference docs
Future<void> writeIngestedSummary(String path, String content)
Future<String?> readIngestedSummary(String path)
Future<void> writeIngestedFile(String path, String name, String content)

// Project config (project-level settings)
Future<void> saveProjectConfig(String path, Map<String,dynamic> config)
Future<Map<String,dynamic>?> readProjectConfig(String path)
Future<void> markVersionValidated(String path, String version)
Future<List<String>> readValidatedVersions(String path)

// README
Future<void> updateReadme(String path, {...phase, specVersion, lastUpdated, ...})
Future<Map<String,dynamic>> parseReadme(String path)

// Audit log
Future<void> appendAuditLog(String path, String entry)

// Scan helpers
Future<List<String>> scanProjectPaths(String rootPath)
Future<bool> hasFlatVersionedFiles(String path)
Future<void> migrateToVersionFolders(String path, String name)
String modeDisplay(String mode)     // "BUILD" | "AUDIT" | "PULL"
```

**Write safety patterns:**
- Specs: write-once (check existence, throw `SpecAlreadyExistsException` if present)
- Most writes: atomic temp+rename (write to `.tmp`, then rename — atomic on macOS)
- Safe-write archive: before overwriting handoffs/worksheets/forge files, rename old file to `{stem}{letter}-{M-D-YYYY}{ext}` (e.g., `BulletHandoff_v1a-6-15-2026.md`)
- Audit log: append-only, never truncate

---

## ProjectDetailScreen — The Main UI Hub

`lib/features/projects/screens/project_detail_screen.dart` is the most complex screen. It shows:

**Left panel (`_FilesSidebar`):**
- Scans the project folder tree
- Shows files grouped by folder, filterable
- Orange dot highlights on files belonging to the latest version's coder package
- Uses regex `^v(\d+(?:\.\d+)?)$` to match both major (`v1`) and minor (`v1.1`) version directories
- `RouteAware.didPopNext()` triggers a re-scan when returning from sub-screens

**Right panel — top (`_PhaseTimeline`):**
- Shows the phase progression: Interview → Spec → Worksheet → Executor
- Each version (v1, v2, v3…) has its own timeline row
- Version labels are tappable — tapping selects `_selectedVersion` which drives the detail panel below
- Selected version shown with orange underline
- Layer sub-dots (L1–L4) appear under the Interview step while interview is active
- Colors: gray = not started, amber pulse = in progress, green = complete

**Right panel — bottom (`_CoderPackageSection`):**
- Shows the coder-ready files for `widget.targetVersion` (the selected version)
- Re-discovers files via `didUpdateWidget` when `targetVersion` changes
- "Copy Bundle" — copies all files to clipboard as a formatted text block
- "Export Pack" — writes all files to a single export `.md` file named `{Name}-V{N}-CoderPack.md`; shows "Show in Finder" snackbar with the export path
- If `targetVersion != latestVersionOnDisk`, shows "Update v{N}" button
  → Confirmation dialog → `AddendumInterviewScreen`

**Notes + Backlog sidebar** (integrated into InterviewState):
- `InterviewState.userNotes: String?` — freeform notes visible to the LLM
- `InterviewState.userBacklog: List<String>` — manual backlog items the LLM can reference
- `_buildUserContextBlock()` in `interview_notifier.dart` injects both into every system prompt

---

## Watch Mode Architecture

Watch Mode gives managers visibility into AI agent spend and quality. Four sections:

### §W1 — Token Ingestion

```dart
abstract class UsageProvider {
  Future<EngineerUsage> fetchUsage({
    required String engineerHandle,
    required String apiKey,
    required int lookbackDays,
  });
}

class EngineerUsage {
  final String engineerHandle;
  final String providerName;
  final List<DailyUsage> dailyBreakdown;  // [{date, tokensUsed, costUSD}]
  final double totalCostUSD30d;
  final List<String> alertFlags;  // 'spend_threshold' | 'runaway_session'
}
```

Implementations: `AnthropicUsageProvider`, `OpenAiUsageProvider` (HTTP). Gemini + Ollama return stubs. `DemoUsageProvider` provides 4 synthetic engineer profiles (`Random(42)` — deterministic for demos).

### §W2 — Git Activity + CI Correlation

GitHub GraphQL (commits, PRs) + GitHub Actions REST (CI runs). `CICorrelator.correlate()` joins spend sessions + commits + CI runs by calendar day (v1 proxy — Anthropic API only returns daily aggregates, not sub-hour sessions).

`isAgentCommit()` heuristic: commit message substring scan for Claude/Copilot/OpenHands/🤖/`[ai]`/`[claude]`.

### §W3 — Failure Signal Engine

Pure computation layer. No HTTP. 6 signal types:

| Signal | Condition |
|---|---|
| `highTokenToFailRatio` | 30d token-to-fail ratio exceeds threshold |
| `loopDetected` | ≥2 consecutive days: spend >$15 + zero CI output |
| `churnDetected` | ≥1 commit with `revert` prefix |
| `spendThreshold` | 30d spend exceeds engineer's alert threshold |
| `runawayDay` | Single day spend exceeds $100 |
| `stalledWorkspace` | No commits in 7+ days + 30d spend >$10 |
| `specDriftExceeded` | Spec compliance score ≥30 (warning) or ≥70 (critical) |

`AlertEngine.evaluate()` deduplicates against existing log (24h window, same handle+signalType).

### §W4 — Dashboard UI

5 screens. All read from `watchDataProvider` (single orchestrating `AsyncNotifier`). The notifier fetches §W1+§W2, runs §W3, auto-appends new alerts to the log.

### §W5 — SwarmSpace Briefing + Decision Simulation

`SwarmSpaceService` sends JSON-RPC 2.0 to the SwarmSpace MCP endpoint. `BriefingNotifier` assembles git signal context → SwarmSpace research query → returns markdown. `DecisionNotifier` runs a 50-iteration Monte Carlo simulation prompt for product decisions.

### §W6 — Spec Compliance + Drift Detection

`SpecDriftEngine.evaluateProject()` reads the `verificationChecklist` from the handoff package, runs `git diff` since spec `lockedAt` timestamp, scores each item (failed×10 + uncertain×3, capped at 100). Score ≥30 = warning signal; ≥70 = critical.

---

## Pull Mode

For onboarding existing codebases without a Forge history.

```
1. User links a repo path → _RepoIngestRow reads path from project_config.json
2. Ingestion Engine scans the codebase → LLM extracts structure/dependencies/patterns
   → writes ingested/reference_context.md
3. PullInterviewNotifier runs a targeted interview to fill gaps the code doesn't answer
   → pulls_interview/PullInterview.json persisted after each turn
4. AsBuiltSpecNotifier generates a spec in standard locked-spec format
   → specs/v1/{Name}_LockedSpec_v1_AsBuilt.md
5. Watch Mode (§W6) can immediately monitor drift against this as-built spec
```

---

## Addendum Interview — Minor Specs (v1.1)

For targeted additions to a shipped version without a full V2 interview.

```
Trigger: "Update v{N}" button on _CoderPackageSection (shown when viewing non-latest version)
Flow:
  1. Confirmation dialog
  2. AddendumInterviewScreen opens with AddendumInterviewArgs(projectPath, projectName, baseVersion)
  3. AddendumInterviewNotifier.build() reads base spec via findSpecFile(), builds greeting
  4. 3-turn minimum before "Generate {minor} Spec" button appears
  5. generateMinorSpec() → LLM synthesises transcript → addendum document
  6. writeMinorLockedSpec() → specs/v{N}.1/{Name}_LockedSpec_v{N}.1.md
```

The addendum spec format is lightweight (5 sections): base version reference, addendum summary, new/changed capabilities, updated constraints, out-of-scope items.

---

## Routing

All navigation uses named routes registered in `lib/core/app.dart`:

```dart
'/interview'           → InterviewScreen
'/spec-generation'     → SpecGenerationScreen
'/worksheet-generation'→ WorksheetGenerationScreen
'/artifact-viewer'     → ArtifactViewerScreen
'/settings'            → SettingsScreen
'/watch'               → WatchDashboardScreen
'/watch/briefing'      → BriefingScreen
'/watch/decision'      → DecisionScreen
'/watch/spec-drift'    → SpecDriftScreen
'/pull-interview'      → PullInterviewScreen
'/as-built-spec'       → AsBuiltSpecScreen
'/spec-compliance'     → SpecComplianceScreen
'/reference-docs'      → ReferenceDocsScreen
'/ingestion-progress'  → PullIngestionProgressScreen
'/ingestion-summary'   → PullIngestionSummaryScreen
```

Navigation to AddendumInterviewScreen uses `MaterialPageRoute` directly (not a named route).

---

## Settings + Config

User-configurable settings live in two places:

**`forge_config.json`** (Application Support — survives `flutter clean`):
- API keys: `forge_api_key_claude`, `forge_api_key_openai`, `forge_api_key_gemini`, `forge_api_key_swarmspace`
- Role assignments: `forge_role_architect`, `forge_role_executor` (provider type strings)
- Model IDs: `forge_model_claude`, `forge_model_openai`, `forge_model_gemini`, `forge_model_ollama`
- Watch Mode config: `watch_engineer_roster`, `watch_github_config`, `watch_alert_log`

**SharedPreferences** (NSUserDefaults — may not survive `flutter clean`):
- `forge_root_path` — user's project root directory
- `forge_ollama_base_url` — Ollama endpoint (default: http://localhost:11434)

**`project_config.json`** (per-project, inside project folder):
- `repoPath` — linked repo path (for Pull Mode ingestion)
- `validatedVersions` — list of versions marked as executed+validated
- Any other per-project runtime state

---

## Key Invariants (must never be violated)

1. **Locked specs are immutable.** `writeLockedSpec()` throws if file already exists. Never pass `force: true` without an explicit version bump.

2. **Audit log is append-only.** Open with `FileMode.append`. Never replace or truncate.

3. **Interview state persists to disk after every LLM response.** `writeInterviewProgress()` is called inside `addUserMessage()` after each successful LLM turn. App restarts mid-interview resume from disk.

4. **All LLM list-field parses use `is List<dynamic>` check.** Never hard-cast `as List<T>?`. A non-list LLM output (`"None"`, `"TBD"`) throws `TypeError` which the outer try/catch silently swallows, losing the entire extracted state for that turn.

5. **`dart analyze lib/` must be zero warnings before commit.** No exceptions. Fix the warning, don't suppress it.

6. **No Firebase. No hardcoded secrets.** `grep -ri firebase lib/` must return zero matches. API keys live in `forge_config.json`.

7. **`ProjectFileRepository` is the only I/O path.** No other file touches the filesystem directly. If a new feature needs to read or write files, add a method to the repository.

8. **Version directories use `^v(\d+(?:\.\d+)?)$`.** The old `^v\d+$` pattern silently ignores minor versions (v1.1, v2.3). Always use the minor-version-aware regex when scanning version directories.

9. **`specGenEnabled` is re-derived from extracted data, not from a saved boolean.** `_restoreState()` re-evaluates `specGenEnabled` from the `mergedExtracted` map. Don't trust a persisted boolean; always re-check the conditions.

10. **No executor starts without a complete project folder.** README, locked spec, bullet handoff, and worksheet must all exist before handing off to an executor agent.

---

## Current Feature Status (2026-06-30)

| Feature | Section | Status |
|---|---|---|
| Flutter bootstrap + data layer | §1 | ✅ |
| Riverpod project state | §2 | ✅ |
| Project browser screen | §3 | ✅ |
| LLM provider layer (BYOK) | §4 | ✅ |
| Build interview UI + 4-layer funnel | §5 + §IF1 | ✅ |
| Spec generation pipeline | §6 | ✅ |
| Artifact viewers | §7 | ✅ |
| Setup worksheet generation | §8 | ✅ |
| Handoff package + /goal text | §9 | ✅ |
| Settings screen + key storage | §10 | ✅ |
| Reference doc ingestion | §DOC | ✅ |
| Executor timeline | §EX1 | ✅ |
| Layer sub-timeline UI | §UI1 | ✅ |
| Feature interview mode (V2+) | §FM1 | ✅ |
| Verification checklist | §VC1 | ✅ |
| Spec compliance gate | §CI1 | ✅ |
| Watch: token ingestion | §W1 | ✅ |
| Watch: git activity + CI correlation | §W2 | ✅ |
| Watch: failure signal + alert engine | §W3 | ✅ |
| Watch: dashboard UI | §W4 | ✅ |
| Watch: SwarmSpace briefing + decision sim | §W5 | ✅ |
| Watch: spec compliance + drift detector | §W6 | ✅ |
| Versioned folder structure | §VF1 | ✅ |
| Pull Mode wiring | §R1 | ✅ |
| Pull interview + as-built spec | §R2 | ✅ |
| Notes + Manual Backlog in interview state | §NB1 | ✅ |
| Version-aware detail panel + export | §VUI2 | ✅ |
| Addendum interview (minor spec v1.1) | §AI1 | ✅ |
| Interview state persistence | §PERSIST | 🔲 Backlog |
| Audit interview mode | §11 | 🔲 Backlog |
| Monte Carlo spec generation | §14 | 🔲 Future |
| Workspace + billing (SwarmSpace tier) | §13 | 🔲 Future |

---

## How to Suggest New Features

When proposing a new function or feature, structure it as:

**1. What it does** (one sentence)

**2. Where it lives** (which file/class it belongs in — follow the existing module boundaries)

**3. Method signature** (in Dart)

**4. Dependencies** (what it reads from / calls into)

**5. Files it writes** (if any — must go through `ProjectFileRepository`)

**6. State changes** (which `State.copyWith()` calls it triggers)

**7. UI entry point** (which screen/button triggers it)

**8. Any invariants it must respect** (e.g., write-once for specs)

The implementation loop: Claude Code architects and codes it; DeepSeek or another executor builds it chunk by chunk; Claude Code reviews each chunk and runs `dart analyze lib/` before the next chunk starts.

---

*The Forge · Orbital AI · Context document for new Claude instances · 2026-06-30*
