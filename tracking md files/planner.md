# The Forge — Active Planner

Active sprint tasks only. Wipe clean when a feature ships. Preserve partial work between sessions.

---

## §BWAI / §UIK / §NP2 — Build with AI + design kit — COMPLETE ✅ (v0.4.0)

**Completed:** 2026-09-10 · **Commits:** `71d7de4` → `027c64c`

- [x] §BWAI Build with AI (Pro) — `lib/features/implementation/**`: propose-&-approve loop, approved edits with per-step Undo (`.forge/impl_backups/<runId>/`), commands with live streamed output (`Process.start`), verify against the Handoff checklist
- [x] §BWAI Real token streaming across all providers — `LlmDelta{text,thinking}` + `completeStream`; reasoning models stream chain-of-thought (Ollama `message.thinking`)
- [x] §BWAI Build console — visible scrollbar + smart stick-to-bottom; reasoning as scrollable lines; internal thinking (dim) vs external presentation (green); collapsible inline "thinking" block; guaranteed green Summary; active-model chip + wait-heartbeat + elapsed timer
- [x] §BWAI Two-pass read-then-edit loop — scout picks files → read them → plan edits grounded in real code + repo docs (README/ARCHITECTURE/CLAUDE.md/agents.md)
- [x] §BWAI Modify / Revise / Fix — hand-edit a proposed file's content or a command; Revise (steer → re-plan); Fix-on-failure (feed failures + failed checklist items back for a corrective plan)
- [x] §BWAI Runs survive navigation (keepAlive) + re-attach on reopen; per-feature board status dots; tap an in-progress feature to open its run
- [x] §BWAI-REL Release tracking — `Releases` drift table (schemaVersion 2→3), Releases view by version, "Cut release" → deterministic notes → CHANGELOG + optional git tag
- [x] §NP2 New Project reduced to two vibecoder choices — "Describe a new app" (Import→Spec, Paste/Guided sub-toggle) + "Bring in existing code" (onboarding); audit-interview retired from picker
- [x] §UIK Forge design kit — `ForgeTheme` (navy + ember/brass); Hearth Dial (`lib/core/widgets/hearth_dial.dart`); launch splash (real boot steps); first-run onboarding; portfolio digest + `ForgeAppHeader`; `UIUX/` source kit; design language v2 (`rust #7A3826` = blocked/stuck)
- [x] Bug fixes: BUG-LLM-001, BUG-IMPL-001, BUG-IMPL-002, BUG-IMPL-003 (see bugtracker)

**INCIDENT:** a Build-with-AI run on theforge corrupted `app.dart` + `settings_notifier.dart` via a full-file rewrite that dropped code — caught in review and reverted (uncommitted, never shipped).

**Follow-ups (open):**
- [ ] Wire `entitlementProvider` to the **§MB managed backend** — replace the Pro-gate stub with a real entitlement
- [ ] **Diff-based edits** — replace lossy full-file rewrites to prevent the corruption above
- [ ] Per-screen color migration onto `ForgeTheme` (screens still carry ad-hoc colors)
- [ ] Bundle the **Unbounded / IBM Plex Mono** fonts (design kit assumes them)
- [ ] Agent commit-per-feature; LLM-polished release notes

---

## §PT — Portfolio Tracker era — COMPLETE ✅

**Completed:** 2026-09-10

- [x] §PT1 Portfolio Tracker data + UI — drift `Features` + `ProjectTracking` (schemaVersion 1→2, create-only, mirrored to `tracker/*.json`); dashboard is new home, board grouped by status; `lib/features/tracker/**`
- [x] §PT2 Auto-scan + check-ins — on-open staleness + review cadence; git-diff check-in accept/edit; `lib/features/tracker/scan/feature_scan.dart`, `lib/features/tracker/checkin/**`
- [x] §PT3 Deploy + unsandbox — `tool/deploy_{macos,ios,android}.sh`, `install_macos.sh`; macOS entitlements unsandboxed; `DOCS/deploy/*`
- [x] §PT4 Ollama Cloud + Gemini removal — `lib/services/llm/**` (Bearer auth, default `gpt-oss:120b-cloud`); `gemini_provider.dart` + `gemini_usage_provider.dart` deleted
- [x] §PT5 Deletion — double-confirm + cascade; `lib/features/projects/project_actions.dart`
- [x] §PT6 Dictation — `theforge://paste` → `PasteTextIntent`; `macos/Runner/*`, `lib/services/paste_receiver.dart`, `lib/main.dart`
- [x] §PT7 App icon across all platforms
- [x] §PT8 `.forge` layout — `ProjectFileRepository.forgeDirName`; ~40 path sites migrated under `.forge/`; stranded sandbox projects consolidated to canonical root
- [x] §PT9 Fixed canonical root + Export — removed settable-root picker; `lib/features/projects/doc_export.dart` (→ `forge-docs/`)
- [x] §PT10 Import → Spec — `lib/features/import/**`; New Project "Import → Spec" card; reuses `SpecGenerationScreen`
- [x] §PT11 Repo onboarding — `import_service` `repoDigest`/`deepAnalysis`/`repoSource`; Quick vs Deep scan; gap form + `openQuestions`
- [x] §PT12 Doc-based feature scan — `feature_scan.dart` reads a project's own `.forge` docs (+ linked repo); "Scan Repo and Documents"
- [x] Bug fixes: BUG-SETTINGS-002, BUG-UI-003, BUG-DATA-001 (see bugtracker)

---

## §MD — Module-Aware Codebase Ingestion — COMPLETE ✅

**Completed:** 2026-07-02

- [x] `lib/features/projects/ingestion/module_discovery.dart` (NEW) — `ModuleDiscoveryResult` + `ModuleDiscovery` (deterministic, no LLM); `discover()` classifies repos as `single` or `moduleAware` via `ARCHITECTURE.md`/`README.md` headings + `lib/` folder walk
- [x] `lib/features/projects/ingestion/module_ingestion_pipeline.dart` (NEW) — `ModuleIngestionPipeline`; `ingestModules()` calls shared `analyzeFileBatch()` per module; `synthesize()` produces unified overview
- [x] `lib/features/projects/ingestion/pull_ingestion_notifier.dart` — `PullIngestionState` gains `tier` + `detectedModules`; `startIngestion()` runs `ModuleDiscovery` first, returns early on `moduleAware`; new `confirmModules()` method
- [x] `lib/features/projects/screens/pull_ingestion_progress_screen.dart` — `ConsumerWidget` → `ConsumerStatefulWidget`; `awaitingConfirmation` arm with module checkbox list; `synthesizing` in progress text
- [x] `lib/features/spec_generation/as_built_spec_generator.dart` — `_asBuiltSpecStructureModuleAware` const added (section 3 = "Module Map" instead of "Component Map")
- [x] `dart analyze lib/` — zero new warnings or errors (1 pre-existing info-level import ordering in `project_detail_screen.dart`)

**Note:** `_asBuiltSpecStructureModuleAware` is currently unreferenced in `buildAsBuiltSpecPrompt()` — reserved for future wiring when `summary.tier == IngestionTier.moduleAware`.

**4-Agent Review Fixes (2026-07-02):**
- Fixed substring path matching bug in `ingestModules()` — now uses path segment matching instead of `contains()`
- Wired `synthesize()` into `confirmModules()` — feeds synthesized overview into invariant extraction context
- Fixed tautological confirm button check — now properly disables until user interacts with checkboxes
- Ran `dart format` on all 5 files — all pass

---

## §VI — V1 Interview Redesign — COMPLETE ✅

**Completed:** 2026-07-01

- [x] `lib/features/interview/state/interview_state.dart` — Added `userScenarios`, `userStories`, `storyAmendments`, `detectedHoles`, `v1UserStories` to `InterviewState.empty()` extracted map
- [x] `lib/features/interview/state/interview_notifier.dart` — New full-vision build openers; redesigned L1 (vision capture), L2 (story synthesis + hole detection), L3 (minimum complete V1 scope); `parseForgeState()` parses 5 new fields; `_layerGateMet()` updated for new gate conditions with backward compat; `_extractedAtLayerStart()` resets new fields on rewind; story amendment tracking (V1a/V1b) in system prompt and extracted map

---

## §CCI — Cross-Cutting Invariant Extraction — COMPLETE ✅

**Completed:** 2026-07-01

- [x] `lib/features/projects/ingestion/invariant_extractor.dart` (NEW) — `InvariantConfidence` enum; `ExtractedInvariant` class; `InvariantExtractor.extract()` LLM call at t=0.2; `_parseInvariants()` with fence-stripping + `is List<dynamic>` safe decode
- [x] `lib/features/projects/models/pull_ingestion_summary.dart` — `invariants` field (default `const []`); `copyWith()`; `lowConfidenceInvariants` getter; `toJson`/`fromJson`/`toMarkdown` updated; backward-compatible `fromJson` (old files without `invariants` key fall back to `const []`)
- [x] `lib/features/projects/ingestion/pull_ingestion_notifier.dart` — wired `InvariantExtractor` after `aggregateComponents()`; `IngestionState.aggregating` state transition; single write with `summary.copyWith(invariants: invariants)`
- [x] `lib/features/spec_generation/as_built_spec_generator.dart` — `§2a. Cross-Cutting Invariants` section added to spec template
- [x] `lib/features/projects/screens/pull_ingestion_summary_screen.dart` — invariant count in summary card; `_buildInvariantsSection()` with confidence badges; `_confidenceBadge()` color-coded widget
- [x] `lib/features/pull_interview/state/pull_interview_notifier.dart` — greeting + system prompt surface low-confidence invariants for confirmation
- [x] `dart analyze lib/` — 0 errors, 1 pre-existing info-level import ordering (non-blocking)

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

## §EX1 — Executor Timeline — COMPLETE ✅

**Completed:** 2026-06-11 (Gemma4 + Claude Code review)

- [x] `lib/features/spec_generation/spec_generator.dart` — `buildExecutorTimelinePrompt(projectName, specContent)` added
- [x] `lib/features/spec_generation/executor_timeline_notifier.dart` — NEW: `AutoDisposeFamilyAsyncNotifier` by projectPath; `build()` scans handoffs/ on mount; `generate()` reads locked spec → LLM → writes `_BuildSequence_{specVersion}.md`
- [x] `lib/features/projects/screens/project_detail_screen.dart` — `_BuildSequenceSection` widget; phase-gated on `v1_worksheet_complete`; all 4 states (notGenerated / generating / done / error with retry)
- [x] `dart analyze lib/` — zero issues

### Notes
- Scans `handoffs/` for `*_BuildSequence_*` on every mount — no re-generation on subsequent opens
- LLM call: architect role, t=0.3 (procedural), maxTokens 2048
- Post-review fixes: removed `super.key` from private widget (unused_element_parameter warning); moved executor_timeline import to correct alphabetical position (directives_ordering info)

---

## §IF1 — Interview Funnel Redesign (4-Layer Deductive Funnel) — COMPLETE ✅

**Completed:** 2026-06-11/12 (DeepSeek + Claude Code review)

- [x] `lib/features/interview/state/interview_dimension.dart` — NEW: `LayerDef` + `buildLayers` (L1–L4 with exit conditions)
- [x] `lib/features/interview/state/interview_state.dart` — added `currentLayer`, `extracted`, `parseDegraded`
- [x] `lib/features/interview/state/interview_notifier.dart` — Build system prompt rewritten to 4-layer funnel + forge-state JSON contract; `parseForgeState` parser; stub demoted to LLM-unavailable fallback; content-driven confidence; v2 seed write at L3→L4; loop fix (full history per turn; parseDegraded graceful fallback; llmUnavailable auto-reset)
- [x] `lib/features/spec_generation/spec_generator.dart` — funnel data block injected into spec prompt
- [x] `lib/data/filesystem/project_file_repository.dart` — `writeIngestedFile()` for V2Seeds.md
- [x] `DOCS/forge/workflow_template.md` — Stage 1A rewritten to 4-layer funnel + invariants
- [x] BUG-INTERVIEW-001/002/003 filed and fixed (layerComplete gate, specGenEnabled gate, forge-state regex)
- [x] `dart analyze lib/` — zero issues

### Notes
- Flutter side is authoritative for layer advancement — never delegate gate logic to LLM JSON output
- Full conversation history must be prepended every turn for stateless LLM calls
- `parseForgeState` catches `TypeError` + `FormatException`; regex lenient for trailing whitespace before closing fence

---

## §UI1 — Layer Sub-Timeline UI — COMPLETE ✅

**Completed:** 2026-06-12 (DeepSeek + Claude Code)

- [x] `lib/features/projects/screens/project_detail_screen.dart` — stacked L1–L4 dot sub-row under Interview step in `_PhaseTimeline`; gray/amber-pulse/green; connector alignment fixed
- [x] `lib/features/interview/ui/interview_screen.dart` — compact FUNNEL strip above confidence meter; Build mode only
- [x] `DOCS/forge/layer_timeline_executor_plan_v1.md` — NEW (plan doc)
- [x] `dart analyze lib/` — zero issues

### Notes
- Both the project detail sub-row and interview funnel strip read from `currentLayer` in `InterviewState` — single source of truth, no separate state
- Connector vertical line must be inside a `SizedBox` to avoid overflow when dot sizes differ

---

## §FM1 — Feature Interview Mode (V2+) — COMPLETE ✅

**Completed:** 2026-06-17 · **Merged + pushed:** main → origin

- [x] `lib/features/interview/providers/interview_providers.dart` — `priorSpecVersion: String?` on `InterviewArgs`
- [x] `lib/features/interview/state/interview_state.dart` — `featureContext: String?`
- [x] `lib/features/interview/state/interview_notifier.dart` — `readFeatureContext()` in `build()`; `_featureInterviewSystemPrompt` (present-first L1, scope guard, V2 seeds as L2 menu, incremental L4); `nextSpecVersion()` public helper; `_extractGoalStatement`/`_extractComponents`
- [x] `lib/features/interview/ui/interview_screen.dart` — `_V1BuiltHeader` panel; "V2 FUNNEL" label; "Generate V2 Spec" button; `targetSpecVersion` passed to SpecGenerationScreen
- [x] `lib/features/spec_generation/spec_generation_screen.dart` — `targetSpecVersion` param (default `'v1'`)
- [x] `lib/features/spec_generation/spec_notifier.dart` — version-aware phase strings
- [x] `lib/features/spec_generation/worksheet_notifier.dart` — version-aware phase string
- [x] `lib/features/projects/screens/project_detail_screen.dart` — `_stageOf`/`_versionOf`/`_nextVersion` helpers; V1 SHIPPED in `_PhaseTimeline` dot; chips + Interview+L1-L4 below timeline row; collapsed prior-version pills; AppBar goal subtitle; "Start V2 Interview" button
- [x] `lib/features/projects/screens/projects_list_screen.dart` — goal text in project rows (async, spec-gated)
- [x] `lib/data/filesystem/project_file_repository.dart` — `readFeatureContext()`
- [x] `dart analyze lib/` — zero issues

### Notes
- Chips/wide widgets must be placed BELOW the timeline Row, never inside a Column that is part of the horizontal Row — breaks connector alignment
- `_allComponents: Map<String, List<String>>` loads each completed version's component map on mount; latest version chips expanded, prior versions collapsed to "V1 ✓" pills
- Goal statement + component parsing uses regex section matching on the locked spec markdown

---

## §W1 — Watch Mode: Token Ingestion Engine — COMPLETE ✅

**Completed:** 2026-06-17

- [x] `lib/services/watch/usage_provider.dart` — `UsageProvider` abstract + `EngineerUsage`/`DailyUsage` immutable models
- [x] `lib/services/watch/providers/anthropic_usage_provider.dart` — HTTP GET `/v1/usage` with `start_date`/`end_date`, blended $9/MTok, defensive parse (FormatException + TypeError → `api_error`)
- [x] `lib/services/watch/providers/openai_usage_provider.dart` — HTTP GET `/v1/usage?date=` per day in lookback, `Future.wait` parallel, blended $5/MTok
- [x] `lib/services/watch/providers/gemini_usage_provider.dart` — stub returning `['api_unsupported']` flag
- [x] `lib/services/watch/providers/ollama_usage_provider.dart` — stub returning `['local_model_unsupported']` flag
- [x] `lib/services/watch/demo_usage_provider.dart` — 4 profiles (runaway 9×/ghost 0.1×/highperformer 1.5×/self 1.0×), `Random(42)` deterministic, ±20% variance, alert flags
- [x] `lib/services/watch/usage_service.dart` — `fetchAllUsage()` iterates roster, isolates failures to `fetch_error` entry
- [x] `lib/features/settings/engineer_roster_notifier.dart` — `EngineerRosterEntry` + `AsyncNotifier` persisting to `forge_config.json` key `watch_engineer_roster`; default `demo` entry auto-present on first launch
- [x] `lib/services/watch/usage_service_provider.dart` — nullable `UsageService?` provider watching roster
- [x] `dart analyze lib/` — zero issues
- [x] `grep -ri firebase lib/` — zero matches
- [x] `grep -rn "Random(42)" lib/` — 1 match in demo provider
- [x] Committed: `feat(§W1): token ingestion engine — UsageProvider layer + 4 providers + demo profiles + engineer roster`

### Notes
- Provider impls use `implements UsageProvider` (not `extends`) — matches the existing `LlmProvider` abstract-class pattern but lets providers stay const-constructible where possible (Gemini/Ollama are `const`).
- `UsageService` is the single call site for usage data in the app — §W2–§W6 consume `EngineerUsage` only, never a provider directly. Error isolation: any provider throw → `fetch_error` flag, never a crash.
- `EngineerRosterNotifier` mirrors `SettingsNotifier`'s `forge_config.json` read/write pattern exactly (same file, different key). No new database table, no SharedPreferences for roster data.
- Default `demo` roster entry (handle=`demo`, providerType=`demo`, alertThreshold=$200) is returned from `build()` when the config key is missing or empty — app never shows empty state before configuration.
- Demo cost rate derived from the spec's $9/MTok blended Anthropic rate (`dailyCost / 0.000009`) so demo tokens are consistent with real Anthropic provider math.

---

## §W2 — Watch Mode: Git Activity Engine + CI Outcome Correlator — COMPLETE ✅

**Completed:** 2026-06-17

- [x] `lib/services/watch/git_activity_provider.dart` — `GitActivityProvider` abstract + `GitCommit`/`EngineerGitActivity` immutable models
- [x] `lib/services/watch/providers/github_git_provider.dart` — GitHub GraphQL impl; `fetchCommits` per-repo `Future.wait` parallel, `fetchMergedPRCount`; module-level `isAgentCommit()` heuristic (Claude/Copilot/OpenHands/🤖/[ai]/[claude]); defensive parse (statusCode != 200 → empty, FormatException + TypeError → empty)
- [x] `lib/services/watch/ci_outcome_provider.dart` — `CIOutcomeProvider` abstract + `CIRun`/`CIOutcome` enum
- [x] `lib/services/watch/providers/github_ci_provider.dart` — GitHub Actions REST impl; `fetchRuns` per-repo `Future.wait` parallel; `conclusion` → pass/fail/timeout, skips cancelled/skipped/neutral; per-repo failure isolation
- [x] `lib/services/watch/ci_correlator.dart` — `CICorrelator.correlate()` joins §W1 `EngineerUsage` + commits + CI runs by SHA; per-engineer per-day `DailyCorrelation` (`tokenPerPass`/`tokenPerFail`/`passRate`); rolling 7d/30d `tokenToFailRatio`; commit-timestamp-proxy limitation documented at top
- [x] `lib/services/watch/git_activity_service.dart` — `fetchCorrelations()` parallel-fetches git+CI (`Future.wait`), correlates, enriches per-engineer PR counts (default 0 on failure); `isConfigured` guard
- [x] `lib/features/settings/github_config_notifier.dart` — `GitHubConfig` + `GitHubEngineerMapping` + `AsyncNotifier` persisting to `forge_config.json` key `watch_github_config`; `isConfigured` getter guards token+org+repos
- [x] `lib/services/watch/git_activity_service_provider.dart` — `Provider<GitActivityService?>` watching `githubConfigProvider` + `engineerRosterProvider`, nullable when unconfigured
- [x] `dart analyze lib/` — zero issues
- [x] `grep -ri firebase lib/` — zero matches
- [x] `grep -rn "commit timestamp as proxy\|CORRELATION PROXY" lib/` — proxy comment present
- [x] Committed: `feat(§W2): git activity engine + CI outcome correlator — GitHub GraphQL + Actions REST + commit-timestamp-proxy correlation`

### Notes
- v1 correlation proxy: commit timestamp = token session timestamp (same calendar day). The Anthropic usage API returns daily aggregates, not sub-hour sessions, so the SuperSpec's 4-hour window isn't possible. Documented in `ci_correlator.dart` with upgrade path.
- Agent attribution heuristic (`isAgentCommit`) is a commit-message substring scan — case-insensitive match for Claude/Copilot/OpenHands signatures + 🤖 emoji + `[ai]`/`[claude]` tags. Imperfect but cheap; upgradeable to git-trailer parsing or `.author` email heuristics later.
- CI conclusion mapping: `success`→pass, `failure`→fail, `timed_out`→timeout, everything else (cancelled/skipped/neutral) skipped entirely — not counted as fails. These aren't real failures; counting them would inflate the token-to-fail ratio.
- `GitHubConfig.isConfigured` is the single guard — `token.isNotEmpty && org.isNotEmpty && repos.isNotEmpty`. Used everywhere instead of repeating the inline check.
- PR count enrichment is supplementary: one extra GraphQL call per engineer, default 0 on any failure. Keeps the main path fast; PRs aren't load-bearing for §W3 signals.
- Per-repo/per-engineer error isolation throughout: `Future.wait` + catch → empty/0, never crashes the batch. Same pattern as §W1 `fetchAllUsage()`.

---

## §W3 — Watch Mode Failure Signal Engine + Alert Engine — COMPLETE ✅

**Completed:** 2026-06-17

- [x] `lib/services/watch/failure_signal_engine.dart` — `FailureSignal` model + `FailureSignalEngine` deriving 6 signal types (highTokenToFailRatio, loopDetected, churnDetected, spendThreshold, runawayDay, stalledWorkspace); severity escalation (critical-only emit for highTokenToFailRatio/spendThreshold); loop detection scans `DailyCorrelation` for consecutive days (spend>$15 + zero CI output); churn counts `revert`-prefixed commits (info 1–2, warning 3+); runaway emits ONE signal per engineer (worst day); stalled uses literal `'workspace'` handle + `stalledDays=999` for empty commit list
- [x] `lib/services/watch/alert_engine.dart` — `AlertEntry` model (`toJson`/`fromJson`/`copyWithDismissed`) + `AlertEngine.evaluate()` deduplicates against existing log (24h window, same handle+signalType, dismissed alerts still dedup); id format `${handle}_${signalType.name}_${millisEpoch}`
- [x] `lib/services/watch/alert_log_notifier.dart` — `AlertLogNotifier` extends `AsyncNotifier<List<AlertEntry>>` persisting to `forge_config.json` key `watch_alert_log`; `build`/`appendAlerts` (prepend newest-first)/`dismissAlert`/`clearDismissed`; mirrors `EngineerRosterNotifier` pattern
- [x] `lib/services/watch/project_status_aggregator.dart` — `WorkspaceStatus` + `ProjectStatusAggregator.aggregate()`; commits 7d vs prior 7d, ±20% velocity trend (`improving`/`stable`/`declining`/`stalled`), stall detection 7d (`stalledDays=999` for empty), CI pass rate; per-repo upgrade-path comment
- [x] `lib/services/watch/watch_signal_service.dart` — `WatchSignalResult` + `WatchSignalService.evaluate()` orchestrating FailureSignalEngine + AlertEngine + ProjectStatusAggregator; single call site for §W4
- [x] `lib/services/watch/watch_signal_service_provider.dart` — `Provider<WatchSignalService>` non-nullable (pure computation, no config deps)
- [x] `dart analyze lib/` — zero issues
- [x] `grep -ri firebase lib/` — zero matches
- [x] `grep -rn "class FailureSignal\|class AlertEntry\|class WorkspaceStatus\|class WatchSignalResult" lib/` — 1 match each
- [x] `grep -rn "v1 aggregates across ALL repos" lib/` — comment present
- [x] Committed: `feat(§W3): failure signal engine + alert engine + workspace status — pure computation layer over §W1+§W2 data`

### Notes
- §W3 is pure computation — no HTTP, no config deps. `WatchSignalService` is `const`-constructible and always non-null. This is the inverse of §W1/§W2 where services were nullable when unconfigured. The provider reflects this: `Provider<WatchSignalService>` not `Provider<WatchSignalService?>`.
- Severity escalation rule: for highTokenToFailRatio and spendThreshold, emit critical OR warning, never both — checked by testing the critical threshold first and using else-if for warning.
- Loop detection scans sorted `DailyCorrelation` for the longest run of consecutive "loop days" (spend>$15 + zero CI output). If ≥2, emit one warning signal. Tracks `longestSpend` (the spend during the longest loop run, not total across all loops).
- Runaway day emits ONE signal per engineer — the worst day by `tokenSpend`. Avoids alert flooding when an engineer has multiple $100+ days.
- Stalled workspace is workspace-level (handle=`'workspace'` literal). Fires when no commits in 7+ days AND workspace 30d spend >$10. Empty commit list → `stalledDays=999` (so `isStalled=true` is correct for an empty workspace).
- `AlertEngine` dedup window is 24h — same handle+signalType within 24h is skipped regardless of dismissed status. Dismissed alerts still dedup (prevents re-alerting on a dismissed condition).
- Bug introduction rate explicitly out of scope (requires GitHub Issues API — not in §W2). No stub added.
- Per-repo breakdown explicitly out of scope (requires `GitCommit.repo` — not in §W2 data model). Upgrade path documented in `project_status_aggregator.dart`.

---

## §W4 — Watch Mode Dashboard UI Shell — COMPLETE ✅

**Completed:** 2026-06-17

- [x] `lib/features/watch/watch_data_notifier.dart` — `WatchData` model (usage, correlations, signalResult, hasGitHubConfig) + `WatchDataNotifier` AsyncNotifier; `_fetch()` reads §W1+§W2 services + roster + alertLog → runs `watchSignalService.evaluate()` → auto-appends new alerts → returns WatchData; `refresh()` sets AsyncLoading then AsyncValue.guard
- [x] `lib/features/watch/watch_dashboard_screen.dart` — main screen; workspace strip (total 30d spend + active alert count + git status) + critical alert banner (amber/red, tappable) + ENGINEERS section + `_EngineerCard` per usage entry sorted by 30d spend descending (handle + provider chip + first signal detail + $total + CI pass rate colored) + VIEW WORKSPACE HEALTH button; AppBar refresh + notifications icons
- [x] `lib/features/watch/engineer_detail_screen.dart` — per-engineer drill-down; summary row (30d spend, CI pass, AI %, PRs) + fl_chart `BarChart` (30d daily spend, bars colored by day's pass rate green/amber/red, date axis M/D, $ axis) + git activity 4-chip row (COMMITS/REVERTS/PRs MERGED/AI) + active signals list with severity icons; "No data yet" placeholder when daily empty
- [x] `lib/features/watch/workspace_health_screen.dart` — velocity trend card (IMPROVING/STABLE/DECLINING/STALLED colored, commits 7d vs prior 7d, change % colored) + last commit row (red if stalled, "never" for stalledDays≥999) + CI stats row + workspace signals list
- [x] `lib/features/watch/alert_log_screen.dart` — alert log; active entries first, "— N dismissed —" divider, dismissed entries (opacity 0.4 + strikethrough), Dismiss TextButton per active entry, Clear Dismissed AppBar action; empty state "No alerts"
- [x] `pubspec.yaml` — `fl_chart: ^0.70.0` added
- [x] `lib/core/app.dart` — `/watch` route → `WatchDashboardScreen`
- [x] `lib/features/projects/screens/projects_list_screen.dart` — `Icons.monitor_heart_outlined` Watch Mode button before Settings in non-selecting AppBar
- [x] `dart analyze lib/` — zero issues
- [x] `grep -ri firebase lib/` — zero matches
- [x] `grep -rn "class WatchData" lib/` — 1 match
- [x] `grep -rn "watchDataProvider" lib/` — 4 matches (notifier, dashboard, detail, plus import)
- [x] `grep -rn "'/watch'" lib/` — 1 in app.dart, 1 in projects_list_screen.dart
- [x] Committed: `feat(§W4): Watch Mode dashboard UI — engineer cards, spend chart, workspace health, alert log`

### Notes
- `WatchDataNotifier` is the single orchestrating provider — all watch screens watch `watchDataProvider`, not the individual §W1/§W2/§W3 providers directly. This keeps the UI layer decoupled from the fetch+signal pipeline; the UI never knows that §W1 fetches tokens, §W2 fetches git, §W3 derives signals — it just reads `WatchData`.
- `_fetch()` auto-appends new alerts to `alertLogProvider` after signal evaluation. The alert log is the persistence layer; the dashboard reads it for the active-alert count. This means opening the dashboard triggers a fetch+evaluate+persist cycle — the first open populates the log, subsequent opens see the persisted state + new alerts.
- v1 limitation: `WorkspaceStatus.ciPassRate30d` is 0 because `GitActivityService.fetchCorrelations()` doesn't expose `ciRuns` (it consumes them internally for correlation but doesn't return them). Documented in `watch_data_notifier.dart` with upgrade path. Velocity trend and stall detection (commit-based) still work; only the CI pass rate is affected.
- fl_chart `BarChart` bars colored per-day by that day's pass rate — a green bar = high pass rate that day, red bar = low pass rate. This makes the chart a "spend + quality" view, not just spend. Single-color bars would be less informative.
- `_passRateFor` uses `.where(...).firstOrNull` (Dart 3) — same pattern as §W2, avoids the `firstWhere(orElse: () => null as dynamic)` anti-pattern.
- Alert log screen separates active from dismissed with a divider — active entries are full-opacity with a Dismiss button; dismissed are 0.4 opacity with strikethrough and no button. The "— N dismissed —" divider only shows when there are dismissed entries.
- `flutter pub get` was run by the executor (adds fl_chart) — `pubspec.lock` updated and committed alongside the code.

---

## §VF1 — Versioned Folder Structure — COMPLETE ✅

**Completed:** 2026-06-27

- [x] `lib/data/filesystem/project_file_repository.dart` — versioned subfolder writes (`specs/v1/`, `handoffs/v1/`, `forge/v1/`, `worksheets/v1/`); backward-compatible reads (versioned path first, flat fallback); `_extractVersion()` regex helper; `hasFlatVersionedFiles()` + `migrateToVersionFolders()` migration helpers; `getSavedRootPath()` + `saveRootPath()` configurable root path via SharedPreferences
- [x] `lib/features/projects/screens/project_detail_screen.dart` — `_FixStructureBanner` widget (detects flat files, runs migration on tap, auto-hides after); versioned artifact browser (`_scan()` returns `Map<folder, Map<version, List<filename>>>`); multi-version accordion panel (`_buildVersionPanel` / `_buildVersionEntry`; latest expanded, prior versions collapsed to pills); `_BacklogSection` (V2 seeds from ingested files); `_RepoPathRow` (repo path + Show in Finder); `_CopyWorksheetButton`
- [x] `lib/features/projects/screens/new_project_screen.dart` — first-time root path picker via `FilePicker.platform.getDirectoryPath()`; saves path via `saveRootPath()`; falls back to default if dismissed
- [x] `lib/features/spec_generation/executor_timeline_notifier.dart` — scans versioned handoffs subfolders for `*_BuildSequence_*` files (was flat-only)
- [x] `dart analyze lib/` — zero issues

### Notes
- Backward compatibility is load-bearing: reads check versioned path first, fall back to flat. Existing projects open without migration. `_FixStructureBanner` offers one-click migration when flat files are detected.
- Root path stored under SharedPreferences key `forge_root_path`; `_defaultRootDir()` reads it on every launch.
- `writeHandoffPackage` now writes to `handoffs/v1/`. `writeLockedSpec` writes to `specs/v1/`. `writeForgeFiles` writes to `forge/v1/`. `writeWorksheet` writes to `worksheets/v1/`.

---

## §VC1 — Verification Checklist — COMPLETE ✅

**Completed:** 2026-06-27

- [x] `lib/features/spec_generation/spec_generator.dart` — `buildVerificationChecklistPrompt(specContent, projectName)` generates machine-readable checklist prompt; `parseVerificationChecklist(llmOutput)` parses JSON → `List<Map<String, dynamic>>`; `buildSpecPrompt()` gains `specVersion` param (spec title now includes version number); `externalServices` safe-null parse fix
- [x] `lib/features/spec_generation/spec_notifier.dart` — `maxTokens` raised 4096 → 8192; truncation guard (throws if `## 9.` or `## 10.` absent — "try again" error instead of silently-truncated spec); post-lock checklist LLM call (non-fatal on failure; spec already immutably locked); checklist stored in handoff package under `verificationChecklist`
- [x] `dart analyze lib/` — zero issues

### Notes
- Checklist generation is a second LLM call (architect role, t=0.1, maxTokens 1024) after `writeLockedSpec()`. Failure is explicitly non-fatal.
- Truncation guard fires when the model hits its context ceiling; `maxTokens` raised to 8192 because the 10-section spec format was hitting 4096 regularly.
- Each checklist item: `id`, `requirement`, `expectedFiles`, `expectedKeywords`, `autoVerifiable`, `verificationNote`.

---

## §CI1 — Spec Compliance Gate + Compliance-Informed Feature Interview — COMPLETE ✅

**Completed:** 2026-06-27

- [x] `lib/features/spec_generation/compliance/spec_compliance_models.dart` — NEW: `ComplianceStatus` enum (verified/uncertain/failed/skipToLlm); `ChecklistItem` model (id, requirement, expectedFiles, expectedKeywords, autoVerifiable, verificationNote); `SpecComplianceResult` model (priorSpecVersion, checkedAt, checkedCommit, ranGitCheck, grouped item lists)
- [x] `lib/features/spec_generation/compliance/spec_compliance_notifier.dart` — NEW: `SpecComplianceNotifier` (`AutoDisposeFamilyAsyncNotifier` by `{projectPath, projectName, priorSpecVersion}`); `check()` reads `verificationChecklist` from handoff package, runs git-diff file-presence check per item, caches result to `forge/{version}/` keyed by commit hash, invalidates when HEAD changes; `skipToLlm` items skip git check (deployed services, external configs)
- [x] `lib/features/spec_generation/compliance/spec_compliance_screen.dart` — NEW: full compliance check UI; idle/checking/done/error states; items grouped by status; feeds `SpecComplianceResult` as `complianceContext` to V2 interview
- [x] `lib/features/interview/providers/interview_providers.dart` — `complianceContext: String?` added to `InterviewArgs`; `==` and `hashCode` updated
- [x] `lib/features/interview/state/interview_notifier.dart` — `_featureInterviewSystemPrompt()` injects compliance block when `complianceContext` non-null; escape hatch fallback extended: fires at ANY layer after ≥10 user turns (was L3/L4 after ≥6)
- [x] `dart analyze lib/` — zero issues

### Notes
- Full pipeline: §VC1 generates `verificationChecklist` JSON at spec-lock time → §CI1 `SpecComplianceNotifier.check()` evaluates each item against git state → `SpecComplianceScreen` shows results → user proceeds to V2 interview with compliance context injected.
- Cache-by-commit: result is invalidated when the repo HEAD changes, so re-checking after new commits re-runs the evaluation. Cached to `forge/{version}/` to survive app restarts.
- `autoVerifiable: false` items (deployed services, external configs, runtime behavior) are classified `skipToLlm` — the git check can't evaluate them, so they're surfaced in the compliance context for the LLM to ask about in the interview.
- Escape hatch fallback (10 turns, any layer) catches the LLM concluding the interview at L1/L2 without emitting forge-state JSON blocks, which left the app stuck with no Generate Spec button.

---

## §W5 — SwarmSpace Briefing + Decision Simulation — COMPLETE ✅

**Completed:** 2026-06-27

- [x] `lib/services/swarmspace/swarmspace_service.dart` — `SwarmSpaceService` HTTP client; JSON-RPC 2.0 to `swarmspace-mcp-server.orbitalai.workers.dev/mcp`; `deepResearch(String query) → Future<String>`
- [x] `lib/services/swarmspace/swarmspace_service_provider.dart` — `Provider<SwarmSpaceService?>` watching `settingsProvider.swarmspaceApiKey`
- [x] `lib/features/settings/settings_notifier.dart` — `setSwarmspaceApiKey` / `clearSwarmspaceApiKey` persisted to `forge_config.json`
- [x] `lib/services/llm/llm_model_config.dart` — `swarmspaceApiKey: String?` added to `LlmSettings`
- [x] `lib/features/watch/briefing_notifier.dart` — `BriefingNotifier` (`AsyncNotifier<BriefingState>`); `runBriefing()` assembles git signals → SwarmSpace query → returns markdown
- [x] `lib/features/watch/briefing_screen.dart` — idle/loading/done/error states; markdown rendered in `SelectableText`
- [x] `lib/features/watch/decision_models.dart` — `DecisionInput` + `DecisionResult`
- [x] `lib/features/watch/decision_notifier.dart` — `DecisionNotifier` (`AsyncNotifier<DecisionResult?>`); `runSimulation(DecisionInput)` → 50-iteration Monte Carlo prompt → SwarmSpace → markdown; `reset()` back to form
- [x] `lib/features/watch/decision_screen.dart` — form (question + context + 3 options) → loading → result markdown; `ConsumerStatefulWidget`
- [x] `lib/features/watch/watch_dashboard_screen.dart` — WEEKLY BRIEFING + RUN DECISION SIM buttons
- [x] `lib/core/app.dart` — `/watch/briefing` + `/watch/decision` routes
- [x] `dart analyze lib/` — zero issues

---

## §W6 — Spec Compliance Monitor + Drift Detector — COMPLETE ✅

**Completed:** 2026-06-27

- [x] `lib/services/watch/spec_drift_engine.dart` — `SpecDriftResult` model + `SpecDriftEngine` static `evaluateProject()`: version discovery loop (v3→v1), git diff since `lockedAt`, item scoring (failed×10 + uncertain×3, cap 100)
- [x] `lib/services/watch/spec_drift_service.dart` — `SpecDriftService` const class; `evaluate(List<Project>)` with per-project try/catch isolation
- [x] `lib/services/watch/spec_drift_service_provider.dart` — `Provider<SpecDriftService>` non-nullable
- [x] `lib/services/watch/failure_signal_engine.dart` — `specDriftExceeded` enum value; `_specDrift()` method; warning ≥30, critical ≥70; `specDrift` optional param on `evaluate()`
- [x] `lib/services/watch/watch_signal_service.dart` — `specDrift` param threaded through
- [x] `lib/features/watch/watch_data_notifier.dart` — `specDrift: List<SpecDriftResult>` on `WatchData`; `await projectListProvider.future` + `specDriftService.evaluate()` in `_fetch()`
- [x] `lib/features/watch/spec_drift_screen.dart` — drift card list with color-coded score badge (0–29 green / 30–69 amber / 70+ red), project name, specVersion, missing/partial counts; empty state
- [x] `lib/features/watch/watch_dashboard_screen.dart` — SPEC DRIFT → button (conditional on `data.specDrift.isNotEmpty`)
- [x] `lib/core/app.dart` — `/watch/spec-drift` route
- [x] `dart analyze lib/` — zero issues

---

## §R1 — Pull Mode Wiring — COMPLETE ✅

**Completed:** 2026-06-28 (uncommitted, Marc reviews)

- [x] R1-1: `project_file_repository.dart` — `modeDisplay` ternary → switch for all 3 modes; "What's Next" conditional
- [x] R1-2: `new_project_screen.dart` — Project Onboarding card; `_ModeCard` icon/accent use switch
- [x] R1-3: `project_detail_screen.dart` — `_RepoIngestRow` loads `repoPath` from config; SnackBar guard; dynamic label
- [x] `dart analyze lib/` — zero issues

### Notes
- Card title: "PROJECT ONBOARDING" (not "REVERSE MODE")
- Accent color: purple (`0xFFA78BFA`) for onboarding, amber for build, slate for audit
- `_RepoIngestRow` mirrors `_RepoPathRow` pattern for loading `repoPath` from `project_config.json`

---

## §R2 — Pull Interview Engine + As-Built Spec Generator — COMPLETE ✅

**Completed:** 2026-06-28 (committed `eaf786a`)

- [x] `lib/features/pull_interview/state/pull_interview_state.dart` — `PullInterviewTurn`, `PullInterviewState`, `PullInterviewArgs`, `pullInterviewProvider`
- [x] `lib/features/pull_interview/state/pull_interview_notifier.dart` — `PullInterviewNotifier`; `addUserMessage`, `markComplete`, `_buildGreeting`, `_buildSystemPrompt`; gap-driven opening question
- [x] `lib/features/pull_interview/ui/pull_interview_screen.dart` — chat UI (amber user / dark Forge bubbles); Enter-to-send; "Generate As-Built Spec →" enabled after 4 user turns
- [x] `lib/features/spec_generation/as_built_spec_generator.dart` — `buildAsBuiltSpecPrompt()` with 10-section as-built spec structure
- [x] `lib/features/spec_generation/as_built_spec_notifier.dart` — `AsBuiltSpecNotifier`; reads ingestion summary + interview log → LLM → writes spec
- [x] `lib/features/spec_generation/as_built_spec_screen.dart` — generation UI (idle/generating/done/error); "Back to Projects" + Retry
- [x] `lib/features/projects/screens/project_detail_screen.dart` — `_ReverseModeCta` replaced with real `_PullModeCta` wired to `PullInterviewScreen`
- [x] `lib/data/filesystem/project_file_repository.dart` — `writePullInterviewLog`, `readPullInterviewLog`, `writeAsBuiltSpec` (archive-safe)
- [x] `lib/core/app.dart` — `/pull-interview` + `/as-built-spec` routes
- [x] `dart analyze lib/` — zero issues

---

## §NB1 — Notes + Manual Backlog in Interview State — COMPLETE ✅

**Completed:** 2026-06-30

- [x] `lib/features/interview/state/interview_state.dart` — `userNotes: String?` + `userBacklog: List<String>` fields; `clearUserNotes` flag on `copyWith`
- [x] `lib/features/interview/state/interview_notifier.dart` — `_buildUserContextBlock()` helper injected into all 3 system prompts (build, audit, feature)
- [x] `dart analyze lib/` — zero issues

### Notes
- `_buildUserContextBlock` is a top-level function (not a method) so it can be called from all three system prompt builders without threading state through
- `clearUserNotes: bool` flag pattern on `copyWith` allows clearing nullable fields (Dart can't distinguish `null` meaning "unset" vs "clear" without an explicit flag)

---

## §VUI2 — Version-Aware Detail Panel + Coder Package Export — COMPLETE ✅

**Completed:** 2026-06-30

- [x] `lib/features/projects/screens/project_detail_screen.dart`:
  - `_selectedVersion: String?` on `_ProjectDetailScreenState`; drives right-panel content
  - `_PhaseTimeline` — `selectedVersion` + `onVersionTap` params; version labels tappable with orange underline when selected
  - `_CoderPackageSection` — `targetVersion` param; `didUpdateWidget` triggers re-discovery on version change; versioned `_discover()` scans the correct version's files
  - Copy Bundle + Export Pack buttons with "Show in Finder" snackbar (communicates export location to user)
  - `_FilesSidebar` — orange-dot highlight on latest-version coder files
  - `_contextPanelHeight` min 200 px, clamp to `screenHeight - 160`
- [x] `dart analyze lib/` — zero issues

---

## §AI1 — Addendum Interview (v1.1 Minor Spec) — COMPLETE ✅

**Completed:** 2026-06-30

- [x] `lib/features/addendum_interview/state/addendum_interview_notifier.dart` (NEW) — `AddendumInterviewArgs`, `AddendumTurn`, `AddendumInterviewState`, `AddendumInterviewNotifier`; `addUserMessage()` LLM turn; `generateMinorSpec()` writes v{N}.1 locked spec; `addendumInterviewProvider`
- [x] `lib/features/addendum_interview/ui/addendum_interview_screen.dart` (NEW) — chat UI; "Generate {minor} Spec" button after ≥3 turns; success screen; Forge dark theme
- [x] `lib/data/filesystem/project_file_repository.dart` — `findSpecFile()` + `writeMinorLockedSpec()`
- [x] `lib/features/projects/screens/project_detail_screen.dart` — addendum imports; minor-version regex fix; `_latestVersionOnDisk()` + `_buildUpdateCta()`; "Update v{N}" CTA with confirmation dialog on non-latest version panels
- [x] `dart analyze lib/` — zero issues (1 info-level import ordering)

### Notes
- Minor version dirs (`v1.1`) require regex `^v(\d+(?:\.\d+)?)$`; old `^v\d+$` silently skipped them
- `AddendumInterviewArgs` is in the notifier file — import the notifier when calling `AddendumInterviewArgs(...)` from the detail screen
- "Generate Spec" button appears after ≥3 user turns — enough for the LLM to have gathered meaningful context

---

## §VUI3 — Version-Aware Labels + Button Decoupling — COMPLETE ✅

**Completed:** 2026-07-01 (Ornith + Claude Code review)

- [x] `lib/features/projects/screens/project_detail_screen.dart` — `_BuildSequenceSection` header shows active version; `_CopyWorksheetButton` label version-aware; `_copying`/`_exporting` decoupled bools; expand tap sets active version; parent passes `_selectedVersion ?? _versionOf(live.phase)` to both widgets
- [x] Bug fix: `setState(() => _discovery = _discover())` → block form (arrow fn returned Future)
- [x] Bug fix: `setState` removed from `didUpdateWidget` (cascading build-scope assertion failures)
- [x] Bug fix: two indentation drift issues corrected

---

## §UPD1 — Updates Section (replaces ✎ Amend Story dialog) — COMPLETE ✅

**Completed:** 2026-07-01 (Ornith + Claude Code review)

- [x] `lib/features/projects/screens/project_detail_screen.dart` — deleted `_AmendStoryDialog`, `_showAmendStoryDialog`, "✎ Amend Story" block; added `_UpdatesSection` between "Project State" and "Reference Documents"; reads/writes `ingested/{projectName}_StoryAmendments_{version}.md`; inline TextField + `+ Add` button; loading/saving spinners; `didUpdateWidget` no-setState pattern; try/finally in `_submit`
- [x] `lib/data/filesystem/project_file_repository.dart` — `appendStoryAmendment()` already present; no changes needed
- [x] `dart analyze` — 1 pre-existing info only

**Note:** Changes uncommitted — Marc to commit when ready.

---

## Next Up — Use The Forge to pull next features

**Status:** Marc is dogfooding The Forge (Pull Mode on existing repos) to spec next features.
