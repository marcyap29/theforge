# The Forge — Active Planner

Active sprint tasks only. Wipe clean when a feature ships. Preserve partial work between sessions.

---

## §1 — Flutter Bootstrap + Local Data Layer — COMPLETE ✅

**Completed:** 2026-05-31

- [x] `flutter create` — Flutter 3.38.7, Dart 3.10.7
- [x] pubspec.yaml — correct deps, no Firebase
- [x] `lib/data/local_db/forge_database.dart` — drift schema + 4 methods
- [x] `lib/data/filesystem/project_file_repository.dart` — 8 methods
- [x] `dart run build_runner build --force-jit` — `forge_database.g.dart` generated
- [x] `dart analyze lib/` — zero issues

**Note:** build_runner requires `--force-jit` flag on Dart 3.10.7 / macOS due to `objective_c` native build hook blocking AOT compilation.

---

## §2 — Riverpod Project State Layer — COMPLETE ✅

**Completed:** 2026-06-01

- [x] `lib/features/projects/providers/project_list_notifier.dart` — scans root dir, syncs to ForgeDatabase
- [x] `lib/features/projects/providers/active_project_notifier.dart` — holds open project, reads README.md
- [x] `lib/features/projects/providers/providers.dart` — 4 Riverpod provider declarations
- [x] `dart analyze lib/` — zero issues
- [x] `grep -ri firebase lib/` — zero matches

### Notes
- `ProjectListNotifier`: `build()` → scan paths → upsert missing → return all. `refresh()` → invalidate + await future.
- `ActiveProjectNotifier`: vanilla `Notifier`, no async lifecycle — `open()` and `close()` are explicit public methods.
- Circular import avoided: notifiers import `providers.dart` for `ref.watch()`, providers.dart imports notifier types — Dart handles this correctly.

---

## §3 — Project Folder Browser Screen — COMPLETE ✅

**Completed:** 2026-06-01

- [x] `lib/main.dart` rewritten — wraps `TheForgeApp` in `ProviderScope`
- [x] `lib/core/app.dart` created — `TheForgeApp` MaterialApp with dark theme + home route
- [x] `lib/core/theme/app_theme.dart` created — macOS dark monospace theme, Forge amber accent
- [x] `lib/features/projects/screens/projects_list_screen.dart` created — `ConsumerWidget` watching `projectListProvider`; rows with name/phase/mode/last-opened; tap → open + navigate; FAB → new project stub; pull-to-refresh
- [x] `dart analyze lib/` — No issues found
- [x] `grep -ri firebase lib/` — zero matches

### Notes
- Detail and New-Project screens are inline stubs (`_ProjectDetailStub`, `_NewProjectStub`) — no separate files. Full implementations land in §7 (artifact viewers) and §5 (interview UI).
- `_ProjectDetailStub` reads `activeProjectProvider` and renders the loaded README.md. No resume logic yet — that's §7.
- Navigator captured to local before `await` to satisfy `use_build_context_synchronously` lint.

---

## §4 — LLM Provider Layer (BYOK + SwarmSpace) — COMPLETE ✅

**Completed:** 2026-06-02 (worktree wt/llm-provider-layer)

- [x] `lib/services/llm/llm_provider.dart` — `LlmRole` enum + `LlmProvider` abstract class
- [x] `lib/services/llm/llm_model_config.dart` — `LlmProviderType`, `ModelInfo`, hardcoded catalogs (Claude/OpenAI/Gemini), `ModelAssignment`, `LlmSettings` with `defaults` and `copyWith`
- [x] `lib/services/llm/llm_service.dart` — `LlmService.complete(role:)` resolves assignment → provider, throws clear errors on missing config
- [x] `lib/services/llm/llm_service_provider.dart` — `llmSettingsProvider` + `llmServiceProvider` derived from `settingsProvider`
- [x] `lib/services/llm/providers/ollama_provider.dart` — HTTP to `/api/chat`; static `fetchModels` to `/api/tags`
- [x] `lib/services/llm/providers/claude_provider.dart` — Anthropic Messages API
- [x] `lib/services/llm/providers/openai_provider.dart` — OpenAI Chat Completions
- [x] `lib/services/llm/providers/gemini_provider.dart` — Google Generative Language API
- [x] `dart analyze lib/` — No issues found
- [x] `grep -ri firebase lib/` — zero matches

### Notes
- 4 provider implementations are direct HTTP via `package:http` — no SDK dependencies
- All API contracts match the §4 plan verbatim (request bodies, headers, response parsing)
- `OllamaProvider.fetchModels` is a `static` method called by the settings notifier for live model list

---

## §10 — Settings Screen + BYOK Key Storage — COMPLETE ✅

**Completed:** 2026-06-02 (worktree wt/llm-provider-layer)

- [x] `lib/features/settings/settings_notifier.dart` — `AsyncNotifier<LlmSettingsState>`; loads from SharedPreferences (base URL, role assignments) + Keychain (API keys); methods: `setRoleAssignment`, `setOllamaBaseUrl`, `setApiKey`, `clearApiKey`, `refreshOllama`
- [x] `lib/features/settings/settings_providers.dart` — `settingsProvider` declaration
- [x] `lib/features/settings/settings_screen.dart` — 4 provider cards (Ollama + 3 BYOK) + 2 role cards (Architect/Executor); live Ollama connection check; masked key entry (`••••••{last4}`); provider dropdown filtered to configured providers
- [x] `lib/core/app.dart` — added `/settings` route; renamed `_MissingRouteArgs` → `_MissingInterviewArgs`
- [x] `lib/features/projects/screens/projects_list_screen.dart` — added settings gear icon to AppBar
- [x] `dart analyze lib/` — No issues found

### Notes
- API keys → `flutter_secure_storage` (macOS Keychain via the `flutter_secure_storage_macos` platform plugin)
- Base URL, role assignments, model IDs → `SharedPreferences`
- No key ever logged or displayed in full — masked as `••••••{last4}` in hintText
- Ollama card auto-runs `refreshOllama` on mount and after every base-URL save
- `setApiKey` + `clearApiKey` use FlutterSecureStorage directly (no SharedPreferences for secrets)
- Role cards are stateless `ConsumerWidget`s — provider is the source of truth, dropdown changes apply immediately

### §4+§10 interview wire-in
- `interview_notifier.dart` calls `llmService.complete(role: LlmRole.executor, ...)` instead of the stub
- Stub still drives `confidenceMap` updates and conflict surfacing (per §5.1 carve-out)
- `try/catch` surfaces a clear "Connection error: ... Open Settings" message in the chat bubble
- New `_interviewSystemPrompt(state)` helper builds the role-specific system prompt for each turn

---

## §5 — Build Interview UI + State (Stage 1A) — COMPLETE ✅

**Completed:** 2026-06-01

- [x] `lib/features/interview/state/interview_state.dart` — 8-dimension enum, `DimensionState`, `InterviewTurn`, `ConflictItem`, `InterviewState` model
- [x] `lib/features/interview/state/interview_notifier.dart` — `FamilyAsyncNotifier` with turn-based stub LLM; `addUserMessage`, `resolveConflict`, `reset` methods
- [x] `lib/features/interview/providers/interview_providers.dart` — `InterviewArgs` (==/hashCode) + `interviewProvider` family
- [x] `lib/features/interview/ui/confidence_meter.dart` — 8-bar meter with resolved/partial/unknown fill levels
- [x] `lib/features/interview/ui/interview_screen.dart` — full screen layout: meter → conflict surface → chat history → composer → Generate Spec button
- [x] `lib/core/app.dart` — `/interview` named route added
- [x] `dart analyze lib/` — No issues found
- [x] `grep -ri firebase lib/` — zero matches

### Notes
- Stub is deterministic and turn-counter driven: 9 user messages cover all 8 dimensions; a `corePurpose ↔ identityModel` conflict is surfaced on turn 3.
- Stub call site is one function call (`stubInterviewStep(state, text)`) — comment marks the swap point for §4.
- `isLoading` gates text input, send button, AND conflict Accept button — prevents races during the 400ms stub latency.
- `InterviewArgs` (path + name) is the family arg; each project gets its own interview state. Switching projects → fresh state, no manual reset.
- Entry-point wiring (button in project list → push `/interview`) is out of scope per the plan. Route is registered and ready.

---

## §5 Extension — Dual Interview Mode UI (Build + Audit) — COMPLETE ✅

**Completed:** 2026-06-02 (worktree wt/llm-provider-layer)

- [x] `lib/features/interview/state/interview_dimension.dart` (NEW) — `DimensionDef` data class + `buildDimensions` (8 Build dims) + `auditDimensions` (8 Audit dims) + `dimensionsFor(ProjectMode)` helper
- [x] `lib/features/interview/state/interview_state.dart` (REWRITE) — dropped `ConfidenceDimension` enum; `ConflictItem` uses `String dimensionALabel` / `String dimensionBLabel`; `InterviewState` carries `List<DimensionDef> dimensions`; `confidenceMap` is `Map<String, DimensionState>`
- [x] `lib/features/interview/providers/interview_providers.dart` (MODIFIED) — `InterviewArgs` gains `ProjectMode mode`
- [x] `lib/features/interview/state/interview_notifier.dart` (REWRITE) — stub resolves labels/IDs from `state.dimensions`; `build()` calls `dimensionsFor(args.mode)`; `_interviewSystemPrompt` uses dimension lookups; preserves original conflict-offset pattern (turn 4 re-resolves `dim[2]` from partial, not uniform `dim[N-1]`)
- [x] `lib/features/interview/ui/confidence_meter.dart` (MODIFIED) — new signature `List<DimensionDef>` + `Map<String, DimensionState>`; iterates `dimensions`; label width 120→140px to fit Audit labels
- [x] `lib/features/interview/ui/interview_screen.dart` (MODIFIED) — `InterviewScreen` takes `InterviewArgs args`; AppBar shows mode name; conflict surface uses string labels
- [x] `lib/features/projects/screens/new_project_screen.dart` (NEW) — name input + Build/Audit cards; create via repo + db upsert + refresh; `ProjectAlreadyExistsException` → red SnackBar
- [x] `lib/features/projects/screens/project_detail_screen.dart` (NEW) — mode badge + phase + parsed README sections + Start Interview FilledButton + artifacts list (read-only)
- [x] `lib/features/projects/screens/projects_list_screen.dart` (MODIFIED) — removed inline `_ProjectDetailStub` and `_NewProjectStub`; navigation to real screens via `MaterialPageRoute`
- [x] `lib/core/app.dart` (MODIFIED) — `/interview` route passes full `InterviewArgs`
- [x] `dart analyze lib/` — No issues found
- [x] `grep -rn "ConfidenceDimension" lib/` — zero matches
- [x] `grep -rn "_ProjectDetailStub\|_NewProjectStub" lib/` — zero matches
- [x] `grep -ri firebase lib/` — zero matches

### Notes
- The string-keyed dimension map (`Map<String, DimensionState>` keyed by `DimensionDef.id`) is the central refactor that unlocks both modes. `InterviewState.dimensions` is the single source of truth for the map's keys.
- Stub `_stubConflictFor(state)` is mode-agnostic — reads `state.dimensions[0].label` and `state.dimensions[2].label`. Build gets `corePurpose ↔ identityModel`, Audit gets `projectGoal ↔ currentBuildState`. Same function, both modes.
- Stub preserves the original conflict-offset pattern (turn 4 re-resolves the conflict dimension, not `dim[N-1]` uniformly). The prompt's stated `dim[N-1]` rule was oversimplified — uniform would leave `dim[2]` stuck partial and break Generate Spec enablement. Caught and fixed before merge.
- Drift's `ProjectsCompanion.insert(...)` doesn't need explicit `Value(null)` for nullable columns — drift handles them as absent by default.
- `state.dimensions == buildDimensions` does a const-equality check that picks the mode label — no need to thread the mode through to the notifier for a single string comparison.

---

## §6 — Spec Generation + Artifact Writing (Stage 2) — COMPLETE ✅

**Completed:** 2026-06-04

- [x] `spec_parser.dart` — strips code fences, trims whitespace
- [x] Wired `SpecParser.clean()` into `spec_notifier.dart` before `writeLockedSpec()`
- [x] `dart analyze lib/` — zero issues
- [x] `grep -ri firebase lib/` — zero matches

### Notes
- `spec_generation_screen.dart`, `spec_notifier.dart`, `spec_generator.dart`, `spec_providers.dart` were already built in a prior session — this session added the parser and connected it
- `SpecGenerationScreen` is a full-screen progress UI with idle/generating/done/error states
- `spec_generator.dart` builds mode-aware prompts (Build vs Audit) with the correct spec structure from `workflow_template.md`

---

## §7 — Artifact Viewers — COMPLETE ✅

**Completed:** 2026-06-04

- [x] `flutter_markdown` added to `pubspec.yaml`; `flutter pub get`
- [x] `artifact_viewer_screen.dart` — single reusable viewer with `ArtifactViewMode` enum
- [x] `project_detail_screen.dart` — artifact rows tappable; folder-aware routing
- [x] `dart analyze lib/` — zero issues

### Notes
- Single `ArtifactViewerScreen` instead of 4 separate screens — cleaner, same code path, mode determined by artifact folder
- Navigation uses `MaterialPageRoute` directly (matching existing codebase pattern — project_detail_screen already uses this for /interview route)
- `flutter_markdown` 0.7.7+1 installed (discontinued upstream, will need migration to `flutter_markdown_plus` later — non-blocking)

---

## §8 — Setup Worksheet Generation (Stage 3) — COMPLETE ✅

**Completed:** 2026-06-04

- [x] `worksheet_generator.dart` — `buildWorksheetPrompt()` + `buildWorksheetAuditEntry()`
- [x] `worksheet_notifier.dart` — `WorksheetNotifier` with `generate()`, full idle/generating/done/error pipeline
- [x] `worksheet_generation_screen.dart` — full UI (mirrors SpecGenerationScreen pattern)
- [x] `project_file_repository.dart` — added `readLockedSpec()` for disk read
- [x] `spec_generation_screen.dart` — done state updated with "Generate Worksheet →" primary button
- [x] README.md `**Setup worksheet:**` flips to `Complete` after worksheet generation
- [x] `dart analyze lib/` — zero issues

### Notes
- Worksheet temperature: 0.3 (procedural) vs spec generation 0.6 (creative)
- Worksheet reads the locked spec from disk via `readLockedSpec()` — no need to hold specContent in memory across screens
- `writeWorksheet()` is a normal write (not write-once) — worksheets can be regenerated
- Navigation via `MaterialPageRoute` directly (matches existing codebase pattern)

---

## §9 — Handoff Package + /goal text — COMPLETE ✅

**Completed:** 2026-06-04

- [x] `spec_generator.dart` — `buildGoalText()`, `buildHandoffPackage()`, `_extractSection()`, `_countTableRows()`, `_countListItems()`
- [x] `spec_notifier.dart` — calls /goal + handoff builders after `writeLockedSpec()`; `specVersion` added to `SpecGenState`
- [x] `handoffs/{ProjectName}_goal_v1.md` written during spec generation pipeline
- [x] `handoff_package_v1.json` written during spec generation pipeline
- [x] `dart analyze lib/` — zero issues

### Notes
- §9 outputs are derived from interview state + spec content — no new LLM call, no new screen
- `/goal` text follows `workflow_template.md` Stage 4b format exactly
- Handoff package supports both Build and Audit schemas
- `_countTableRows` subtracts 1 for the header row; filter handles `|---|` and `---|---|---|` patterns

---

## §9.5 — 5-File System Amendment + UX Polish — COMPLETE ✅

**Completed:** 2026-06-05

- [x] `project_file_repository.dart` — `createProject()` creates `forge/` subdir; `writeForgeFiles()` writes LockedSpec + DecisionContext + OpenFlags to `forge/`; `writeHandoffPackage()` updated with `projectName` + `vv1` fix
- [x] `spec_generator.dart` — `parseComponentNames()`, `buildContextFiles()`, `buildDecisionContext()`, `buildOpenFlags()`; HandoffPackage gains `components` + `contextFiles`
- [x] `spec_notifier.dart` — wired `writeForgeFiles()` + updated `writeHandoffPackage()` call
- [x] `worksheet_notifier.dart` — sets `v1_worksheet_complete` phase in DB + refreshes project list
- [x] `macos/Runner/*.entitlements` — removed `keychain-access-groups` (required provisioning profile; broke sandbox builds)
- [x] `macos/Runner.xcodeproj/project.pbxproj` — Manual → Automatic code signing (2 targets)
- [x] `settings_notifier.dart` — replaced `flutter_secure_storage` with SharedPreferences + `forge_config.json` dual-write; correct Gemini model IDs (`gemini-3.5-flash`)
- [x] `settings_screen.dart` — Save button fix (controller listener in initState)
- [x] `llm_model_config.dart` — correct Gemini model IDs and defaults
- [x] `artifact_viewer_screen.dart` — `ArtifactViewMode.forge` added
- [x] `project_detail_screen.dart` — full rewrite: two-panel layout, interactive `_PhaseTimeline` (3 steps, pulse animation, click-to-resume), `_FilesSidebar` with RouteAware auto-refresh, phase-aware CTA button
- [x] `new_project_screen.dart` — API key gate with red warning banner
- [x] `core/app.dart` — `routeObserver` registered as `navigatorObserver`
- [x] `spec_generation_screen.dart` — "Back to Projects" added to error state
- [x] First end-to-end Plan Mode test: Testapp — all 5 folders populated, all 3 timeline steps green
- [x] `dart analyze lib/` — zero issues

### Notes
- macOS sandbox entitlement lesson: `keychain-access-groups` requires `$(AppIdentifierPrefix)` which needs a provisioning profile. Never add it for development builds without a paid developer account.
- API key persistence: `forge_config.json` in Application Support survives preferences container resets during development. SharedPreferences (NSUserDefaults) does not always survive `flutter clean`.
- `RouteAware.didPopNext()` fires when a pushed route is popped and the parent route becomes visible — reliable refresh trigger without polling.
- Interview state is `AutoDisposeNotifier` — lost on back navigation. Backlog item to persist mid-interview state to disk.

---

---

## §DOC — Reference Doc Ingestion Engine (v1) — COMPLETE ✅ (merged to main)

**Completed:** 2026-06-09 · **Merged:** 2026-06-10

- [x] `macos/Runner/*.entitlements` — added `com.apple.security.files.user-selected.read-only`
- [x] `pubspec.yaml` — added `file_picker: ^8.0.0`
- [x] `lib/data/filesystem/project_file_repository.dart` — `/ingested/` folder + 4 new methods (writeIngestedSummary, readIngestedSummary, listReferenceDocs, copyReferenceDoc)
- [x] `lib/features/projects/ingestion/reference_doc.dart` — ReferenceDoc + IngestedFacts model
- [x] `lib/features/projects/ingestion/ingestion_engine.dart` — LLM prompt builder + output parser
- [x] `lib/features/projects/ingestion/ingestion_notifier.dart` — project-scoped notifier (add/remove/rebuild)
- [x] `lib/features/projects/ingestion/reference_docs_screen.dart` — management UI with file picker (multi-file)
- [x] `lib/features/interview/state/interview_notifier.dart` — reads ingested context from disk per turn
- [x] `lib/features/spec_generation/spec_generator.dart` — buildSpecPrompt() accepts ingestedContext
- [x] `lib/features/spec_generation/spec_notifier.dart` — reads ingested context from disk before spec prompt
- [x] `lib/features/projects/screens/project_detail_screen.dart` — Reference Docs row with Material wrapper fix
- [x] `lib/features/interview/ui/interview_screen.dart` — doc count chip in AppBar; removed redundant initState loadDocs
- [x] `dart analyze lib/` — zero issues
- [x] `grep -ri firebase lib/` — zero matches

### Post-Merge Fixes (2026-06-10)
- **Multi-file picker**: `allowMultiple: true` + loop over `result.files` in `reference_docs_screen.dart`
- **InkWell/Material wrapper**: `_ReferenceDocsRow` wrapped with `Material(color: Colors.transparent)` — "Manage →" was unresponsive without it on macOS desktop
- **State race fixed**: removed `loadDocs` from `interview_screen.dart` `initState` — concurrent call raced with in-flight `addDoc` LLM calls

### Notes
- Text-only v1: .md and .txt files only. Binary formats (PDF, DOCX) out of scope.
- Ingestion uses architect role at t=0.2 for precision extraction. Results cached to `ingested/reference_context.md`.
- Notifier is global (not AutoDispose, not family) — docs survive navigation and interview sessions.
- macOS entitlement `user-selected.read-only` is required for file_picker's NSOpenPanel.

---

## Next Up — §EX1: Executor Timeline

**What it is:** When `phase == v1_worksheet_complete`, parse the spec's `§3 Component Map` table and generate an LLM-narrated timeline (one milestone per component, unique per project). Displayed in `ProjectDetailScreen` below the phase timeline when Ready is green.

**Why it matters:** Gives the executor agent a visual build sequence unique to the project — mirrors how The Forge's own timeline is driven by its spec.

**Dependencies:** §9.5 complete ✅ (spec is locked and parseable); `parseComponentNames()` already exists in `spec_generator.dart`

**Status:** Backlog — not started
