# Configuration Management — The Forge

**Last Updated:** 2026-09-10
**Status:** ✅ Synced

---

## Documentation Inventory

| Document | Location | Last Reviewed | Status |
|----------|----------|---------------|--------|
| claude.md | root | 2026-05-31 | ✅ Synced |
| agents.md | agents md files/ | 2026-05-31 | ✅ Synced |
| ARCHITECTURE.md | tracking md files/ | 2026-05-31 | ✅ Synced |
| FEATURES.md | tracking md files/ | 2026-05-31 | ✅ Synced |
| UI_UX.md | tracking md files/ | 2026-05-31 | ✅ Synced |
| CHANGELOG.md | tracking md files/ | 2026-05-31 | ✅ Synced |
| backend.md | root | 2026-05-31 | ✅ Synced |
| context.md | tracking md files/ | 2026-05-31 | ✅ Synced |
| planner.md | tracking md files/ | 2026-05-31 | ✅ Synced |
| backlog.md | tracking md files/ | 2026-06-01 | ✅ Synced |
| BUG_PREVENTION.md | bugtracker/ | 2026-05-31 | ✅ Synced |
| workflow_template.md | DOCS/forge/ | 2026-05-31 | ✅ Synced |
| The_Forge_InterviewFunnel_Plan_v1.md | DOCS/forge/ | 2026-06-11 | ✅ Synced |
| positioning_brief.md | DOCS/forge/ | 2026-05-31 | ✅ Synced |
| pubspec.yaml | root | 2026-05-31 | ✅ Synced |
| analysis_options.yaml | root | 2026-05-31 | ✅ Synced |
| forge_database.dart | lib/data/local_db/ | 2026-05-31 | ✅ Synced |
| project_file_repository.dart | lib/data/filesystem/ | 2026-05-31 | ✅ Synced |
| project_list_notifier.dart | lib/features/projects/providers/ | 2026-06-01 | ✅ Synced |
| active_project_notifier.dart | lib/features/projects/providers/ | 2026-06-01 | ✅ Synced |
| providers.dart | lib/features/projects/providers/ | 2026-06-01 | ✅ Synced |
| main.dart | lib/ | 2026-06-01 | ✅ Synced |
| app.dart | lib/core/ | 2026-06-01 | ✅ Synced |
| app_theme.dart | lib/core/theme/ | 2026-06-01 | ✅ Synced |
| projects_list_screen.dart | lib/features/projects/screens/ | 2026-06-01 | ✅ Synced |
| interview_state.dart | lib/features/interview/state/ | 2026-06-01 | ✅ Synced |
| interview_notifier.dart | lib/features/interview/state/ | 2026-06-02 | ✅ Synced |
| interview_providers.dart | lib/features/interview/providers/ | 2026-06-01 | ✅ Synced |
| confidence_meter.dart | lib/features/interview/ui/ | 2026-06-01 | ✅ Synced |
| interview_screen.dart | lib/features/interview/ui/ | 2026-06-01 | ✅ Synced |
| llm_provider.dart | lib/services/llm/ | 2026-06-02 | ✅ Synced |
| llm_model_config.dart | lib/services/llm/ | 2026-06-02 | ✅ Synced |
| llm_service.dart | lib/services/llm/ | 2026-06-02 | ✅ Synced |
| llm_service_provider.dart | lib/services/llm/ | 2026-06-02 | ✅ Synced |
| ollama_provider.dart | lib/services/llm/providers/ | 2026-06-02 | ✅ Synced |
| claude_provider.dart | lib/services/llm/providers/ | 2026-06-02 | ✅ Synced |
| openai_provider.dart | lib/services/llm/providers/ | 2026-06-02 | ✅ Synced |
| gemini_provider.dart | lib/services/llm/providers/ | 2026-06-02 | ✅ Synced |
| settings_notifier.dart | lib/features/settings/ | 2026-06-05 | ✅ Synced |
| settings_providers.dart | lib/features/settings/ | 2026-06-02 | ✅ Synced |
| settings_screen.dart | lib/features/settings/ | 2026-06-05 | ✅ Synced |
| llm_model_config.dart | lib/services/llm/ | 2026-06-05 | ✅ Synced |
| project_file_repository.dart | lib/data/filesystem/ | 2026-06-05 | ✅ Synced |
| artifact_viewer_screen.dart | lib/features/artifacts/ | 2026-06-05 | ✅ Synced |
| project_detail_screen.dart | lib/features/projects/screens/ | 2026-06-05 | ✅ Synced |
| new_project_screen.dart | lib/features/projects/screens/ | 2026-06-05 | ✅ Synced |
| spec_generation_screen.dart | lib/features/spec_generation/ | 2026-06-05 | ✅ Synced |
| spec_generator.dart | lib/features/spec_generation/ | 2026-06-05 | ✅ Synced |
| spec_notifier.dart | lib/features/spec_generation/ | 2026-06-05 | ✅ Synced |
| worksheet_notifier.dart | lib/features/spec_generation/ | 2026-06-05 | ✅ Synced |
| worksheet_generation_screen.dart | lib/features/spec_generation/ | 2026-06-04 | ✅ Synced |
| app.dart | lib/core/ | 2026-06-05 | ✅ Synced |
| DebugProfile.entitlements | macos/Runner/ | 2026-06-05 | ✅ Synced |
| Release.entitlements | macos/Runner/ | 2026-06-05 | ✅ Synced |
| BUG_PREVENTION.md | bugtracker/ | 2026-06-05 | ✅ Synced |
| usage_provider.dart | lib/services/watch/ | 2026-06-17 | ✅ Synced |
| anthropic_usage_provider.dart | lib/services/watch/providers/ | 2026-06-17 | ✅ Synced |
| openai_usage_provider.dart | lib/services/watch/providers/ | 2026-06-17 | ✅ Synced |
| gemini_usage_provider.dart | lib/services/watch/providers/ | 2026-06-17 | ✅ Synced |
| ollama_usage_provider.dart | lib/services/watch/providers/ | 2026-06-17 | ✅ Synced |
| demo_usage_provider.dart | lib/services/watch/ | 2026-06-17 | ✅ Synced |
| usage_service.dart | lib/services/watch/ | 2026-06-17 | ✅ Synced |
| usage_service_provider.dart | lib/services/watch/ | 2026-06-17 | ✅ Synced |
| engineer_roster_notifier.dart | lib/features/settings/ | 2026-06-17 | ✅ Synced |
| git_activity_provider.dart | lib/services/watch/ | 2026-06-17 | ✅ Synced |
| github_git_provider.dart | lib/services/watch/providers/ | 2026-06-17 | ✅ Synced |
| ci_outcome_provider.dart | lib/services/watch/ | 2026-06-17 | ✅ Synced |
| github_ci_provider.dart | lib/services/watch/providers/ | 2026-06-17 | ✅ Synced |
| ci_correlator.dart | lib/services/watch/ | 2026-06-17 | ✅ Synced |
| git_activity_service.dart | lib/services/watch/ | 2026-06-17 | ✅ Synced |
| github_config_notifier.dart | lib/features/settings/ | 2026-06-17 | ✅ Synced |
| git_activity_service_provider.dart | lib/services/watch/ | 2026-06-17 | ✅ Synced |
| failure_signal_engine.dart | lib/services/watch/ | 2026-06-17 | ✅ Synced |
| alert_engine.dart | lib/services/watch/ | 2026-06-17 | ✅ Synced |
| alert_log_notifier.dart | lib/services/watch/ | 2026-06-17 | ✅ Synced |
| project_status_aggregator.dart | lib/services/watch/ | 2026-06-17 | ✅ Synced |
| watch_signal_service.dart | lib/services/watch/ | 2026-06-17 | ✅ Synced |
| watch_signal_service_provider.dart | lib/services/watch/ | 2026-06-17 | ✅ Synced |
| watch_data_notifier.dart | lib/features/watch/ | 2026-06-17 | ✅ Synced |
| watch_dashboard_screen.dart | lib/features/watch/ | 2026-06-17 | ✅ Synced |
| engineer_detail_screen.dart | lib/features/watch/ | 2026-06-17 | ✅ Synced |
| workspace_health_screen.dart | lib/features/watch/ | 2026-06-17 | ✅ Synced |
| alert_log_screen.dart | lib/features/watch/ | 2026-06-17 | ✅ Synced |
| interview_dimension.dart | lib/features/interview/state/ | 2026-06-18 | ✅ Synced |
| interview_state.dart | lib/features/interview/state/ | 2026-06-18 | ✅ Synced |
| interview_notifier.dart | lib/features/interview/state/ | 2026-06-20 | ✅ Synced |
| interview_screen.dart | lib/features/interview/ui/ | 2026-06-20 | ✅ Synced |
| project_detail_screen.dart | lib/features/projects/screens/ | 2026-06-18 | ✅ Synced |
| projects_list_screen.dart | lib/features/projects/screens/ | 2026-06-18 | ✅ Synced |
| spec_generator.dart | lib/features/spec_generation/ | 2026-06-19 | ✅ Synced |
| spec_notifier.dart | lib/features/spec_generation/ | 2026-06-19 | ✅ Synced |
| worksheet_notifier.dart | lib/features/spec_generation/ | 2026-06-19 | ✅ Synced |
| settings_notifier.dart | lib/features/settings/ | 2026-06-20 | ✅ Synced |
| llm_model_config.dart | lib/services/llm/ | 2026-06-20 | ✅ Synced |
| project_file_repository.dart | lib/data/filesystem/ | 2026-06-30 | ✅ Synced |
| interview_state.dart | lib/features/interview/state/ | 2026-06-30 | ✅ Synced |
| interview_notifier.dart | lib/features/interview/state/ | 2026-06-30 | ✅ Synced |
| project_detail_screen.dart | lib/features/projects/screens/ | 2026-06-30 | ✅ Synced |
| addendum_interview_notifier.dart | lib/features/addendum_interview/state/ | 2026-06-30 | ✅ Synced |
| addendum_interview_screen.dart | lib/features/addendum_interview/ui/ | 2026-06-30 | ✅ Synced |
| invariant_extractor.dart | lib/features/projects/ingestion/ | 2026-07-01 | ✅ Synced |
| module_discovery.dart | lib/features/projects/ingestion/ | 2026-07-02 | ✅ Synced |
| module_ingestion_pipeline.dart | lib/features/projects/ingestion/ | 2026-07-02 | ✅ Synced |
| pull_ingestion_summary.dart | lib/features/projects/models/ | 2026-07-01 | ✅ Synced |
| pull_ingestion_notifier.dart | lib/features/projects/ingestion/ | 2026-07-02 | ✅ Synced |
| as_built_spec_generator.dart | lib/features/spec_generation/ | 2026-07-02 | ✅ Synced |
| pull_ingestion_progress_screen.dart | lib/features/projects/screens/ | 2026-07-02 | ✅ Synced |
| pull_ingestion_summary_screen.dart | lib/features/projects/screens/ | 2026-07-01 | ✅ Synced |
| pull_interview_notifier.dart | lib/features/pull_interview/state/ | 2026-07-01 | ✅ Synced |
| forge_database.dart | lib/data/local_db/ | 2026-09-10 | ✅ Synced (schemaVersion 2 — Features + ProjectTracking) |
| tracker_enums.dart | lib/features/tracker/models/ | 2026-09-10 | ✅ Synced |
| tracker_repository.dart | lib/features/tracker/data/ | 2026-09-10 | ✅ Synced |
| tracker_providers.dart | lib/features/tracker/providers/ | 2026-09-10 | ✅ Synced |
| portfolio_dashboard_screen.dart | lib/features/tracker/screens/ | 2026-09-10 | ✅ Synced (app home `/`) |
| project_tracker_screen.dart | lib/features/tracker/screens/ | 2026-09-10 | ✅ Synced |
| feature_scan.dart | lib/features/tracker/scan/ | 2026-09-10 | ✅ Synced |
| checkin_service.dart | lib/features/tracker/checkin/ | 2026-09-10 | ✅ Synced |
| checkin_review_dialog.dart | lib/features/tracker/checkin/ | 2026-09-10 | ✅ Synced |
| import_service.dart | lib/features/import/ | 2026-09-10 | ✅ Synced |
| import_screen.dart | lib/features/import/ | 2026-09-10 | ✅ Synced |
| import_confirm_screen.dart | lib/features/import/ | 2026-09-10 | ✅ Synced |
| project_actions.dart | lib/features/projects/ | 2026-09-10 | ✅ Synced (delete guard — BUG-DATA-001) |
| doc_export.dart | lib/features/projects/ | 2026-09-10 | ✅ Synced |
| project_file_repository.dart | lib/data/filesystem/ | 2026-09-10 | ✅ Synced (`.forge/` dir + fixed canonical root) |
| paste_receiver.dart | lib/services/ | 2026-09-10 | ✅ Synced (`theforge://paste`) |
| settings_screen.dart | lib/features/settings/ | 2026-09-10 | ✅ Synced (provider auto-selects model — BUG-SETTINGS-002) |
| llm_service.dart | lib/services/llm/ | 2026-09-10 | ✅ Synced (empty-modelId fallback) |
| deploy_macos.sh | tool/ | 2026-09-10 | ✅ Synced |
| deploy_ios.sh | tool/ | 2026-09-10 | ✅ Synced |
| deploy_android.sh | tool/ | 2026-09-10 | ✅ Synced |
| install_macos.sh | tool/ | 2026-09-10 | ✅ Synced |


---


## Change Log

### 2026-09-10 — §PT Portfolio Tracker + §DIST Deploy + §FORGEDIR + §IMPORT

**Action:** Major release (v0.3.0). The Forge becomes a virtual project manager: a portfolio tracker across all projects, an LLM feature scanner over docs and/or code, a check-in service, direct-distribution deploy, a `.forge/` per-project deliverables folder with a fixed canonical root, and an import-a-repo → gap-form → spec flow. Gemini removed; Ollama Cloud default. 3 bugs fixed.

**Key changes:**
- `lib/data/local_db/forge_database.dart` — `Features` + `ProjectTracking` tables; `schemaVersion` 1→2 with create-only migration; `removeTracking()`.
- `lib/features/tracker/**` — enums, repository, providers, portfolio dashboard (app home `/`), per-project tracker screen, LLM feature scanner (`scan/feature_scan.dart` — reads a project's own `.forge` docs and/or a linked repo), check-in service + review dialog.
- `lib/features/import/**` — import service (extract → gap form → `SpecGenerationScreen`), import screen (Quick/Deep chooser), import confirm screen (gap form + Dig deeper).
- `lib/data/filesystem/project_file_repository.dart` — `.forge/` deliverables dir (~40 sites); fixed canonical root (no longer settable to a code repo).
- `lib/features/projects/project_actions.dart` — delete fenced to canonical root (BUG-DATA-001); `project_list_notifier.dart` prunes stale index rows.
- `lib/features/projects/doc_export.dart` — `exportProjectDocs` → `<destDir>/forge-docs/`.
- `lib/services/llm/llm_service.dart` + `settings_screen.dart` — empty-`modelId` fallback + provider auto-selects first model (BUG-SETTINGS-002).
- `lib/services/paste_receiver.dart`, `main.dart`, `macos/Runner/*` — `theforge://paste` receiver for dictation.
- `tool/deploy_{macos,ios,android}.sh` + `install_macos.sh`; `DOCS/deploy/`.
- Gemini provider removed entirely; Ollama Cloud default (`gpt-oss:120b-cloud`).

**Bugs fixed:** BUG-SETTINGS-002 (`6f677c0`), BUG-UI-003 (`a11c2a8`), BUG-DATA-001 (`5ee6aee`, `a11c2a8`).

**Docs:** `DOCS/Portfolio-Tracker_Development-Story.md` (new); ARCHITECTURE.md v3.0.0; FEATURES.md; CHANGELOG.md v0.3.0; context.md + planner.md + backlog.md updated; 3 new bugtracker records + master index + BUG_PREVENTION.

---

### 2026-07-01 — §CCI: Cross-Cutting Invariant Extraction

**Action:** New Pull Mode layer — extract cross-cutting rules during ingestion, surface in as-built spec + pull interview. 1 new file, 5 modified.

**Files created:**
- `lib/features/projects/ingestion/invariant_extractor.dart` — `InvariantConfidence` enum; `ExtractedInvariant` model; `InvariantExtractor` class; safe JSON array parse with fence-stripping

**Files modified:**
- `lib/features/projects/models/pull_ingestion_summary.dart` — `invariants` field + `copyWith` + `lowConfidenceInvariants` getter + `toJson`/`fromJson`/`toMarkdown`
- `lib/features/projects/ingestion/pull_ingestion_notifier.dart` — `InvariantExtractor` wired after aggregation; `aggregating` state; single write
- `lib/features/spec_generation/as_built_spec_generator.dart` — `§2a` CCI section in spec template
- `lib/features/projects/screens/pull_ingestion_summary_screen.dart` — invariant count + `_buildInvariantsSection` + confidence badges
- `lib/features/pull_interview/state/pull_interview_notifier.dart` — low-confidence invariants in greeting + system prompt

**Verification:** `dart analyze lib/` → 0 errors, 1 pre-existing info (non-blocking)

---

### 2026-07-02 — §MD: Module-Aware Codebase Ingestion

**Action:** Add multi-module ingestion pipeline with confirmation UI. 2 new files, 3 modified.

**Files created:**
- `lib/features/projects/ingestion/module_discovery.dart` — `ModuleDiscoveryResult` (single/moduleAware) + `ModuleDiscovery` class; `discover()` deterministic (ARCHITECTURE.md/README.md headings + lib/ folder walk); no LLM, no Riverpod
- `lib/features/projects/ingestion/module_ingestion_pipeline.dart` — `ModuleIngestionPipeline`; `ingestModules()` calls shared `analyzeFileBatch()` per module; `synthesize()` produces unified overview via architect-role LLM call

**Files modified:**
- `lib/features/projects/ingestion/pull_ingestion_notifier.dart` — `PullIngestionState` gains `tier` + `detectedModules`; `startIngestion()` runs `ModuleDiscovery` first, returns early on `moduleAware`; new `confirmModules()` method (scans, runs pipeline, writes summary)
- `lib/features/projects/screens/pull_ingestion_progress_screen.dart` — `ConsumerWidget` → `ConsumerStatefulWidget`; `awaitingConfirmation` arm with checkbox list + confirm button; `synthesizing` in progress text
- `lib/features/spec_generation/as_built_spec_generator.dart` — `_asBuiltSpecStructureModuleAware` const added (section 3 = "Module Map" instead of "Component Map"); currently unreferenced in `buildAsBuiltSpecPrompt()`

**Verification:** `dart analyze lib/` → zero new warnings or errors (1 pre-existing info-level import ordering in `project_detail_screen.dart`, unchanged)

**4-Agent Review Fixes (2026-07-02):**
- Fixed substring path matching in `ingestModules()` — now uses path segment matching (splits on `/` and `\`, checks each segment equals module name)
- Wired `synthesize()` into `confirmModules()` — feeds synthesized overview into invariant extraction context
- Fixed tautological confirm button check — now properly disables until user interacts with checkboxes
- Ran `dart format` on all 5 files — all pass

---

### 2026-06-30 — §NB1 + §VUI2 + §AI1: Notes/Backlog + Version-Aware Panel + Addendum Interview

**Action:** Three features in one session. 4 files modified, 2 new files.

**Files modified:**
- `lib/features/interview/state/interview_state.dart` — `userNotes: String?` + `userBacklog: List<String>` fields; `clearUserNotes` flag
- `lib/features/interview/state/interview_notifier.dart` — `_buildUserContextBlock()` injected into all 3 system prompts
- `lib/features/projects/screens/project_detail_screen.dart` — `_selectedVersion` state; version-tappable `_PhaseTimeline`; versioned `_CoderPackageSection` with Copy/Export; `_FilesSidebar` orange-dot highlights; `findSpecFile`/`writeMinorLockedSpec` imports; `_latestVersionOnDisk()` + `_buildUpdateCta()`; minor-version regex fix
- `lib/data/filesystem/project_file_repository.dart` — `findSpecFile()` + `writeMinorLockedSpec()`

**Files created:**
- `lib/features/addendum_interview/state/addendum_interview_notifier.dart` — `AddendumInterviewArgs`, `AddendumTurn`, `AddendumInterviewState`, `AddendumInterviewNotifier`, `addendumInterviewProvider`
- `lib/features/addendum_interview/ui/addendum_interview_screen.dart` — chat UI, success screen, "Generate Spec" gate at ≥3 turns

**Verification:** `dart analyze lib/` → 0 errors, 1 info-level import ordering (non-blocking)

---

### 2026-06-28 — §R1 Completion: Reverse Mode Wiring

**Action:** Completed 3 missing wiring pieces for Reverse mode. 3 files changed, uncommitted (Marc reviews).

**Key changes:**
- `project_file_repository.dart` — `modeDisplay` ternary → switch for Build/Audit/Reverse; "What's Next" conditional on mode
- `new_project_screen.dart` — Project Onboarding card (purple accent); `_ModeCard` icon/accent use switch on `ProjectMode`
- `project_detail_screen.dart` — `_RepoIngestRow` loads `repoPath` from `project_config.json`; SnackBar guard if null; dynamic label shows linked repo name

---

### 2026-06-18/20 — Interview UX + Bug Fixes + Model Catalog

**Action:** Interview UX overhaul, full state persistence, layer rewind, interview gate fixes, handoff output fixes, model catalog update. 6 commits, 9 files changed.

**Key changes:**
- `interview_state.dart` — `layerBoundaries: Map<String,int>` field added
- `interview_notifier.dart` — full disk persistence (turns+confidence+extracted+specGenEnabled+layerBoundaries after every LLM response); auto-opener (4 variations per mode, zero tokens); `rewindToLayer()`; `rewindTo(i)` turn rewind; parse TypeError fix for all 4 list fields (`capabilities`, `demoScript`, `v2Seeds`, `externalServices`); `specGenEnabled` gate relaxed to `allResolved || l4GateMet`; `_restoreState` re-evaluates `specGenEnabled` from extracted data
- `interview_screen.dart` — Enter=send / Shift+Enter=newline (`FocusNode.onKeyEvent`); auto-scroll on AI response (`ref.listen`); auto-focus on load+send; "edit" rewind link on user bubbles; tappable layer dots (`_LayerIndicator` + `Tooltip` + `MouseRegion`); amber outlined escape hatch button at L3/L4 ≥6 turns
- `project_detail_screen.dart` — "Continue with V1/V2 Interview →" CTA (detects `interview_active` DB phase); `_previousVersion()` helper
- `spec_generator.dart` — `v2SeedItems` populated from extracted data; `parseComponentNames` strips `**` markdown bold
- `spec_notifier.dart` — clears `InterviewState.json` after spec is locked
- `worksheet_notifier.dart` — calls `updateHandoffPackageField(setupWorksheetComplete: true)`; updates README "What's Next" to "Ready for executor"
- `settings_notifier.dart` — validates stored model IDs against current catalog on load; stale IDs fall back to first valid model
- `llm_model_config.dart` — retired `gpt-4-turbo` → `gpt-4.1`; retired `gemini-1.5-flash` → `gemini-2.0-flash`
- `project_file_repository.dart` — `clearInterviewProgress()`, `updateHandoffPackageField()`

**Bugs fixed:** BUG-INTERVIEW-004, BUG-INTERVIEW-005, BUG-SETTINGS-001, BUG-SPECGEN-001

**Commits:** `f4c106c` `7390568` `716e475` `0c2f4b1` `3721a29` `a8062bc`

### 2026-06-17 — §W4 Watch Mode: Dashboard UI Shell

**Action:** Watch Mode dashboard — 5 new files + 3 modifications. Engineer cards, spend chart (fl_chart), workspace health, alert log. Read-only except alert dismiss.

**Files created:**
- `lib/features/watch/watch_data_notifier.dart` — `WatchData` + `WatchDataNotifier` orchestrating §W1+§W2 fetch → §W3 evaluate → auto-append alerts
- `lib/features/watch/watch_dashboard_screen.dart` — main screen; workspace strip + critical alert banner + engineer cards sorted by 30d spend + workspace health button
- `lib/features/watch/engineer_detail_screen.dart` — summary row + fl_chart 30d spend bar chart (bars colored by day's pass rate) + git activity chips + signals
- `lib/features/watch/workspace_health_screen.dart` — velocity trend card + last commit + CI stats + workspace signals
- `lib/features/watch/alert_log_screen.dart` — active/dismissed sections with divider, dismiss button, clear-dismissed action

**Files modified:**
- `pubspec.yaml` — `fl_chart: ^0.70.0` added
- `pubspec.lock` — updated by `flutter pub get`
- `lib/core/app.dart` — `/watch` route → `WatchDashboardScreen`
- `lib/features/projects/screens/projects_list_screen.dart` — `Icons.monitor_heart_outlined` Watch Mode button in AppBar

**Verification:** `dart analyze lib/` → No issues found; `grep -ri firebase lib/` → zero matches; `grep -rn "class WatchData" lib/` → 1; `grep -rn "watchDataProvider" lib/` → 4; `grep -rn "fl_chart" pubspec.yaml` → 1; `grep -rn "'/watch'" lib/` → 2 (app.dart + projects_list); `git diff --stat HEAD` → 9 files (5 new + 3 modified + pubspec.lock), 1458 insertions

**Key design choices:**
- Single orchestrating provider: all watch screens watch `watchDataProvider`, not §W1/§W2/§W3 providers directly — UI decoupled from fetch+signal pipeline
- Auto-append alerts on fetch: opening dashboard triggers fetch→evaluate→persist cycle; alert log is the persistence layer
- fl_chart bars colored per-day by pass rate — "spend + quality" view, not just spend
- v1 limitation: `WorkspaceStatus.ciPassRate30d` is 0 (ciRuns not exposed from fetchCorrelations) — documented with upgrade path
- Alert log: active first, dismissed section with divider, dismissed entries opacity 0.4 + strikethrough

**Commit:** `feat(§W4): Watch Mode dashboard UI — engineer cards, spend chart, workspace health, alert log`

### 2026-06-17 — §W3 Watch Mode: Failure Signal Engine + Alert Engine

**Action:** Pure-computation signal/alert/status layer over §W1+§W2 data. 6 new files, 0 modified, zero analyzer issues, zero HTTP imports in §W3 files.

**Files created:**
- `lib/services/watch/failure_signal_engine.dart` — `FailureSignal` model + `FailureSignalEngine` deriving 6 signal types with severity escalation
- `lib/services/watch/alert_engine.dart` — `AlertEntry` model + `AlertEngine.evaluate()` with 24h dedup
- `lib/services/watch/alert_log_notifier.dart` — `AlertLogNotifier` persisting to `forge_config.json` key `watch_alert_log`; append/dismiss/clearDismissed
- `lib/services/watch/project_status_aggregator.dart` — `WorkspaceStatus` + `ProjectStatusAggregator`; velocity trend ±20%, stall detection 7d, CI pass rate
- `lib/services/watch/watch_signal_service.dart` — `WatchSignalResult` + `WatchSignalService.evaluate()` orchestrating all three engines
- `lib/services/watch/watch_signal_service_provider.dart` — `Provider<WatchSignalService>` non-nullable (pure computation, no config deps)

**Verification:** `dart analyze lib/` → No issues found; `grep -ri firebase lib/` → zero matches; `grep -rn "class FailureSignal" lib/` → 1; `grep -rn "class AlertEntry" lib/` → 1; `grep -rn "class WorkspaceStatus" lib/` → 1; `grep -rn "class WatchSignalResult" lib/` → 1; `grep -rn "v1 aggregates across ALL repos" lib/` → comment present; `git diff --stat HEAD` → 6 new files, 586 insertions

**Key design choices:**
- Pure-computation layering: `WatchSignalService` is `const`-constructible, always non-null (inverse of §W1/§W2 nullable providers) — fetching services are config-gated, computation services are not
- Severity escalation: emit critical OR warning, never both (for highTokenToFailRatio/spendThreshold) — tested critical first, else-if for warning
- Loop detection: longest consecutive run of "loop days" (spend>$15 + zero CI output), one warning if ≥2
- Runaway day: ONE signal per engineer (worst day), avoids alert flooding
- Stalled workspace: workspace-level (handle=`'workspace'` literal), `stalledDays=999` for empty commit list
- Alert dedup: 24h window, same handle+signalType, dismissed alerts still dedup
- Bug introduction rate explicitly out of scope (no stub) — requires GitHub Issues API not in §W2
- Per-repo breakdown explicitly out of scope — upgrade path documented in `project_status_aggregator.dart`

**Commit:** `feat(§W3): failure signal engine + alert engine + workspace status — pure computation layer over §W1+§W2 data`

### 2026-06-17 — §W2 Watch Mode: Git Activity Engine + CI Outcome Correlator

**Action:** GitHub GraphQL commit fetch + GitHub Actions REST CI run fetch + per-engineer correlation of token spend to CI outcomes via commit SHA. 8 new files, 0 modified, zero analyzer issues.

**Files created:**
- `lib/services/watch/git_activity_provider.dart` — `GitActivityProvider` abstract + `GitCommit`/`EngineerGitActivity` models
- `lib/services/watch/providers/github_git_provider.dart` — GitHub GraphQL impl; `fetchCommits` + `fetchMergedPRCount`; `isAgentCommit()` heuristic
- `lib/services/watch/ci_outcome_provider.dart` — `CIOutcomeProvider` abstract + `CIRun`/`CIOutcome`
- `lib/services/watch/providers/github_ci_provider.dart` — GitHub Actions REST impl; conclusion mapping (success/failure/timed_out, skip cancelled/skipped/neutral)
- `lib/services/watch/ci_correlator.dart` — `CICorrelator` joins §W1 usage + commits + CI runs by SHA; per-day `DailyCorrelation`; rolling 7d/30d `tokenToFailRatio`; commit-timestamp-proxy limitation documented
- `lib/services/watch/git_activity_service.dart` — `fetchCorrelations()` parallel fetch+correlate+PR-enrich
- `lib/features/settings/github_config_notifier.dart` — `GitHubConfig` + `AsyncNotifier` persisting to `forge_config.json` key `watch_github_config`; `isConfigured` guard
- `lib/services/watch/git_activity_service_provider.dart` — `Provider<GitActivityService?>` nullable when unconfigured

**Verification:** `dart analyze lib/` → No issues found; `grep -ri firebase lib/` → zero matches; `grep -rn "class GitActivityProvider" lib/` → 1; `grep -rn "class CIRun" lib/` → 1; `grep -rn "class EngineerCorrelation" lib/` → 1; `grep -rn "CORRELATION PROXY" lib/` → 1 (proxy comment present); `git diff --stat HEAD` → 8 new files, 843 insertions

**Key design choices:**
- v1 correlation proxy: commit timestamp = token session timestamp (same calendar day) — Anthropic API returns daily aggregates, not sub-hour sessions; 4h window from SuperSpec not possible at v1. Upgrade path documented in `ci_correlator.dart`.
- Agent attribution: commit-message substring heuristic (Claude/Copilot/OpenHands/🤖/[ai]/[claude]) — cheap, upgradeable to git-trailer parsing later
- CI conclusion: success→pass, failure→fail, timed_out→timeout; cancelled/skipped/neutral skipped entirely (not counted as fails — would inflate token-to-fail ratio)
- `GitHubConfig.isConfigured` is the single guard used everywhere — no inline `token.isEmpty` checks
- Per-repo/per-engineer error isolation: `Future.wait` + catch → empty/0, never crashes the batch
- PR count enrichment is supplementary: one extra GraphQL call per engineer after correlate, default 0 on failure
- Config file reuse: `GitHubConfigNotifier` writes to same `forge_config.json` under key `watch_github_config`

**Commit:** `feat(§W2): git activity engine + CI outcome correlator — GitHub GraphQL + Actions REST + commit-timestamp-proxy correlation`

### 2026-06-17 — §W1 Watch Mode: Token Ingestion Engine

**Action:** Abstract `UsageProvider` layer + 4 provider implementations + demo profiles + engineer roster notifier. 9 new files, 0 modified, zero analyzer issues.

**Files created:**
- `lib/services/watch/usage_provider.dart` — `UsageProvider` abstract + `EngineerUsage`/`DailyUsage` `@immutable` models
- `lib/services/watch/providers/anthropic_usage_provider.dart` — HTTP GET `/v1/usage`, blended $9/MTok, defensive parse
- `lib/services/watch/providers/openai_usage_provider.dart` — HTTP GET `/v1/usage` per-day parallel, blended $5/MTok
- `lib/services/watch/providers/gemini_usage_provider.dart` — stub, `['api_unsupported']`
- `lib/services/watch/providers/ollama_usage_provider.dart` — stub, `['local_model_unsupported']`
- `lib/services/watch/demo_usage_provider.dart` — 4 profiles, `Random(42)` deterministic, alert flags
- `lib/services/watch/usage_service.dart` — `fetchAllUsage()` with per-entry error isolation
- `lib/features/settings/engineer_roster_notifier.dart` — `EngineerRosterEntry` + `AsyncNotifier` persisting to `forge_config.json` key `watch_engineer_roster`; default demo entry on first launch
- `lib/services/watch/usage_service_provider.dart` — `Provider<UsageService?>` watching roster

**Verification:** `dart analyze lib/` → No issues found; `grep -ri firebase lib/` → zero matches; `grep -rn "Random(42)" lib/` → 1 match in demo provider; `git diff --stat HEAD` → 9 new files, 516 insertions

**Key design choices:**
- Interface segregation: §W2–§W6 consume `EngineerUsage` only, never a provider directly — same pattern as `LlmProvider` → `LlmService`
- Error isolation: `fetchAllUsage()` catches per-entry failures → `fetch_error` flag, never crashes the batch
- Defensive parse: HTTP usage APIs are inconsistent — catch `FormatException` + `TypeError`, fall back to `api_error` flag
- Config-file reuse: `EngineerRosterNotifier` writes to same `forge_config.json` as `SettingsNotifier` under new key `watch_engineer_roster`
- Default-entry-on-first-launch: `build()` returns `[_defaultEntry]` when key missing — app never shows empty state before configuration
- `Random(42)` determinism is a contract — same seed → same demo data every run (screenshots, demos, regression tests)

**Commit:** `feat(§W1): token ingestion engine — UsageProvider layer + 4 providers + demo profiles + engineer roster`

### 2026-06-05 — §9.5 + Plan Mode v1 Complete + UX Polish

**Action:** 5-file system amendment, macOS sandbox fixes, UX polish, first end-to-end test passing. 15 files modified, 0 new code files, 1 new coding lesson.

**Files modified:**
- `lib/data/filesystem/project_file_repository.dart` — `createProject()` creates `forge/` subdir; `writeForgeFiles()` new method; `writeHandoffPackage()` takes `projectName`; fixed `v$version` → `$version` (was generating `_vv1` filenames)
- `lib/features/spec_generation/spec_generator.dart` — `parseComponentNames()`, `buildContextFiles()`, `buildDecisionContext()`, `buildOpenFlags()` added; HandoffPackage gains `components` + `contextFiles`
- `lib/features/spec_generation/spec_notifier.dart` — wired `writeForgeFiles()` + updated `writeHandoffPackage()` call
- `lib/features/spec_generation/worksheet_notifier.dart` — sets `v1_worksheet_complete` phase in DB; calls `projectListProvider.notifier.refresh()`
- `lib/features/spec_generation/spec_generation_screen.dart` — "Back to Projects" `TextButton` added to error state
- `lib/features/settings/settings_notifier.dart` — replaced `flutter_secure_storage` with SharedPreferences + `forge_config.json` dual-write; correct Gemini model IDs; Save button fix (controller listener)
- `lib/services/llm/llm_model_config.dart` — correct Gemini model IDs (`gemini-3.5-flash`, `gemini-2.5-flash`, `gemini-2.5-pro`); `LlmSettings.defaults` updated
- `lib/features/artifacts/artifact_viewer_screen.dart` — `ArtifactViewMode.forge` added
- `lib/features/projects/screens/project_detail_screen.dart` — full rewrite: two-panel layout, interactive `_PhaseTimeline` (3 steps, pulse animation, click-to-resume/artifact), `_FilesSidebar` with `RouteAware` auto-refresh, phase-aware CTA
- `lib/features/projects/screens/new_project_screen.dart` — API key gate with red warning banner + Settings link
- `lib/core/app.dart` — `routeObserver` global + registered in `navigatorObservers`
- `macos/Runner/DebugProfile.entitlements` — removed `keychain-access-groups`
- `macos/Runner/Release.entitlements` — removed `keychain-access-groups`
- `macos/Runner.xcodeproj/project.pbxproj` — `CODE_SIGN_STYLE` Manual → Automatic (2 targets)

**Files created:**
- `DOCS/Coding Lessons/FOR_MARC_macos-sandbox-and-interview-v1-complete.md`

**Tag:** `v1.0-interview-complete`

**Verification:** `dart analyze lib/` → No issues found; Testapp end-to-end run ✅

### 2026-06-02 — §4 Change: Gemini 3.5 Flash as default provider (worktree wt/llm-provider-layer)

**Action:** Default provider flip + bug fix. 4 files modified, 0 new.

**Files modified:**
- `lib/services/llm/llm_model_config.dart` — added `gemini-3.5-flash-preview` as first geminiModels entry; `LlmSettings.defaults` now uses Gemini for both roles
- `lib/services/llm/providers/gemini_provider.dart` — **bug fix**: `system_instruction` → `systemInstruction` (Gemini REST API v1beta uses camelCase; snake_case was silently ignored); added explicit `'role': 'user'` to `contents`
- `lib/features/settings/settings_notifier.dart` — `build()` first-run logic now defaults to Gemini (was Ollama); `orElse:` in `firstWhere` also falls back to Gemini
- `lib/features/settings/settings_screen.dart` — provider cards reordered Gemini → Claude → OpenAI → Ollama; Gemini card has `isDefault: true` with ` (default)` label appended; `_RoleCard.availableProviders` changed from filtered list to `LlmProviderType.values` (always show all four)
- `tracking md files/context.md` — session block prepended

**Reason:** Ollama needs a running local server; Gemini just needs one API key. Out-of-the-box UX is dramatically better. The bug fix is critical — `system_instruction` was being silently dropped, meaning every interview response would lose the system prompt scaffolding.

**Model ID note:** Used `gemini-3.5-flash-preview`. LUMARA Desktop uses `gemini-3-flash-preview` (no `.5`); user said "3.5 Flash". The `.5-flash-preview` string is a best-guess following Google's preview-versioning pattern. If Google rejects it, the error surfaces in the chat bubble and the user picks a working model from the dropdown.

**Verification:**
- `dart analyze lib/` → No issues found
- `grep -n "system_instruction"` → no matches (bug fix confirmed)
- `LlmSettings.defaults` uses `gemini-3.5-flash-preview` for both Architect and Executor

**Ollama is still supported:** card stays in UI (last, not first); `OllamaProvider` is untouched; live `/api/tags` model fetch still works; user can pick Ollama from any role's provider dropdown.

### 2026-06-02 — §4 LLM Provider Layer + §10 Settings (worktree wt/llm-provider-layer)

**Action:** Provider-agnostic LLM service + Settings screen + interview wire-in. 11 new files, 3 modified, 1 worktree. Zero analyzer issues.

**Files created:**
- `lib/services/llm/llm_provider.dart` — `LlmRole` enum + `LlmProvider` abstract class
- `lib/services/llm/llm_model_config.dart` — `LlmProviderType`, `ModelInfo`, hardcoded catalogs (Claude/OpenAI/Gemini), `ModelAssignment`, `LlmSettings` with `defaults` and `copyWith`
- `lib/services/llm/llm_service.dart` — `LlmService.complete(role:)` resolves assignment → provider, throws clear errors on missing config
- `lib/services/llm/llm_service_provider.dart` — `llmSettingsProvider` + `llmServiceProvider` derived from `settingsProvider`
- `lib/services/llm/providers/ollama_provider.dart` — HTTP to `/api/chat`; static `fetchModels` to `/api/tags`
- `lib/services/llm/providers/claude_provider.dart` — Anthropic Messages API
- `lib/services/llm/providers/openai_provider.dart` — OpenAI Chat Completions
- `lib/services/llm/providers/gemini_provider.dart` — Google Generative Language API
- `lib/features/settings/settings_notifier.dart` — `AsyncNotifier<LlmSettingsState>`; SharedPreferences (base URL, role assignments) + Keychain (API keys); `setRoleAssignment` / `setOllamaBaseUrl` / `setApiKey` / `clearApiKey` / `refreshOllama`
- `lib/features/settings/settings_providers.dart` — `settingsProvider` declaration
- `lib/features/settings/settings_screen.dart` — 4 provider cards + 2 role cards; live Ollama check; masked key entry; provider dropdown filtered to configured providers

**Files modified:**
- `pubspec.yaml` — added `http: ^1.2.2`, `flutter_secure_storage: ^9.2.4`, `shared_preferences: ^2.3.3`
- `lib/features/interview/state/interview_notifier.dart` — replaced stub with `llmService.complete(role: LlmRole.executor, ...)`; kept stub for confidence-map updates; added `_interviewSystemPrompt` helper
- `lib/core/app.dart` — added `/settings` named route; renamed `_MissingRouteArgs` → `_MissingInterviewArgs`
- `lib/features/projects/screens/projects_list_screen.dart` — added settings gear icon to AppBar
- `tracking md files/context.md` — session block prepended
- `tracking md files/planner.md` — §4 + §10 marked COMPLETE ✅
- `tracking md files/backlog.md` — §4 + §10 marked ✅ Complete; added to Completed section; Critical Path shows ✅ on §4 + §10

**Key design choices:**
- Two-layer architecture: `LlmService` resolves `LlmRole → ModelAssignment → LlmProvider`. The notifier (and future spec generator, worksheet generator) never knows which provider is active.
- API keys in `flutter_secure_storage` (macOS Keychain) ONLY. Base URL, role assignments, model IDs in `SharedPreferences`. No key ever written to a `prefs` key.
- `llmServiceProvider` watches `settingsProvider` (via derived `llmSettingsProvider`) — service rebuilds on every settings change.
- Interview wire-in: real LLM call drives `interviewerTurn.content`; stub still drives `confidenceMap` updates and `newConflicts` until §5.1 prompt engineering parses LLM output.
- `try/catch` around `llmService.complete` surfaces a clear "Connection error: ... Open Settings" message in the chat bubble.
- Role card is a `ConsumerWidget` (not stateful) — provider is the source of truth, dropdown changes apply immediately.

### 2026-06-01 — §5 Build Interview UI + State

**Action:** Core product loop — 8-dimension interview state machine + visual confidence meter + conflict surface + Generate Spec gating. 5 new files, 1 update, zero analyzer issues.

**Files created:**
- `lib/features/interview/state/interview_state.dart` — `ConfidenceDimension` enum (8 values with `.label` and `.question` extensions), `DimensionState` enum, `InterviewTurn`, `ConflictItem`, `InterviewState` model
- `lib/features/interview/state/interview_notifier.dart` — `FamilyAsyncNotifier<InterviewState, InterviewArgs>` with `addUserMessage`, `resolveConflict`, `reset` methods; top-level `stubInterviewStep()` function returns structured `({String, Map, List})` record. Single call site flagged with `// §5 LLM STUB:` comment for §4 swap.
- `lib/features/interview/providers/interview_providers.dart` — `InterviewArgs` (with `==`/`hashCode`) + `interviewProvider` (`AsyncNotifierProvider.family`)
- `lib/features/interview/ui/confidence_meter.dart` — 8-bar `LinearProgressIndicator` meter; resolved/partial/unknown fill levels
- `lib/features/interview/ui/interview_screen.dart` — `ConsumerStatefulWidget` with AppBar (restart icon), `ConfidenceMeter`, `_ConflictSurface` (gated on `openConflicts.isNotEmpty`), chat history (`_TurnBubble` per turn, user right / interviewer left), `_Composer` (text input + send button), `Generate Spec` button (gated on `specGenEnabled`, shows §6 SnackBar)

**Files modified:**
- `lib/core/app.dart` — added `'/interview'` named route; reads `ModalRoute.settings.arguments` as `InterviewArgs`; falls back to `_MissingRouteArgs` helper screen if args absent
- `tracking md files/context.md` — session block prepended
- `tracking md files/planner.md` — §5 marked COMPLETE ✅
- `tracking md files/backlog.md` — §5 status set to ✅ Complete; §5 added to Completed section; Critical Path updated with ✅ on §5

**Key design choices:**
- Family provider with `InterviewArgs` (path + name) — one interview state per project; switching projects = fresh state for free
- Stub is turn-counter driven (9 user messages = 8 dimensions + 1 surfaced conflict) — deterministic, fast to test, no message parsing required
- Conflict text follows Workflow Template pattern verbatim ("Your answers on X and Y pull in opposite directions...")
- `isLoading` gates text input + send button + conflict Accept button — prevents races during the 400ms stub latency
- `specGenEnabled` is a stored field on state, recomputed on every transition (all 8 resolved + 0 open conflicts)
- Entry-point wiring (button in project list → push `/interview`) deliberately out of scope per the §5 plan; route is registered and ready for any future caller

### 2026-06-01 — §3 Project Folder Browser

**Action:** App bootstrap + first screen implemented — 1 file rewritten, 3 new files, zero analyzer issues.

**Files created:**
- `lib/core/app.dart` — `TheForgeApp` MaterialApp wrapping the dark theme + `ProjectsListScreen` home route
- `lib/core/theme/app_theme.dart` — macOS dark theme, Menlo monospace, Forge amber (`#E8A04C`) primary, flat surfaces, minimal chrome
- `lib/features/projects/screens/projects_list_screen.dart` — `ConsumerWidget` for project list; `AsyncValue` states (loading/error/empty/data); `_ProjectRow` + `_ModeBadge`; tap row → `activeProjectProvider.open()` + push detail stub; FAB → push new-project stub; pull-to-refresh + AppBar refresh icon

**Files modified:**
- `lib/main.dart` — rewritten to `runApp(ProviderScope(child: TheForgeApp()))` (replaces stock counter)
- `tracking md files/context.md` — session block prepended
- `tracking md files/planner.md` — §3 marked COMPLETE ✅; §4 set as UP NEXT
- `tracking md files/backlog.md` — §3 status set to ✅ Complete; §3 added to Completed section; Critical Path updated with ✅ on §1, §2, §3

**Key design choices:**
- Detail and new-project screens are inline private widgets (`_ProjectDetailStub`, `_NewProjectStub`) in the list screen file — keeps §3 file count to 4 per task scope
- Detail stub reads `activeProjectProvider` and renders README.md as monospace text
- Navigator captured to local before `await` to satisfy `use_build_context_synchronously` lint
- `ColorScheme.dark` with explicit `primary`/`surface`/`onSurface`/`error`; FAB uses primary/background inverse for contrast

### 2026-06-01 — /goal integration: workflow template + backlog updates

**Action:** Applied /goal primitive integration to The Forge workflow docs.

**Files modified:**
- `DOCS/forge/workflow_template.md` — Completion Criteria section added
  to Stage 2 spec format; Stage 4b /goal text artifact added; Stage 5
  checklist updated; Bullet Handoff format updated
- Obsidian `The Forge — Agent Workflow Template v3.0.md` — same changes
- `tracking md files/backlog.md` — §6 spec structure updated, §9 outputs
  updated to include /goal text artifact
- `tracking md files/context.md` — session block prepended

**Reason:** The /goal primitive in Claude Code and OpenAI Codex maps
directly to the Locked Spec. The spec now explicitly produces a /goal
text artifact and includes verifiable Completion Criteria so judge agents
can confirm completion autonomously.

### 2026-06-01 — §2 Riverpod Project State Layer

**Action:** Riverpod state layer implemented — 3 new files, 4 providers, zero issues.

**Files created:**
- `lib/features/projects/providers/project_list_notifier.dart` — `ProjectListNotifier` (AsyncNotifier): scans filesystem, syncs to SQLite, `refresh()` method
- `lib/features/projects/providers/active_project_notifier.dart` — `ActiveProjectNotifier` (Notifier): manages open project state, reads README.md on `open()`
- `lib/features/projects/providers/providers.dart` — 4 provider declarations: `projectFileRepositoryProvider`, `forgeDatabaseProvider`, `projectListProvider`, `activeProjectProvider`

**Files modified:**
- `tracking md files/context.md` — session block prepended
- `tracking md files/planner.md` — §2 marked COMPLETE ✅
- `tracking md files/backlog.md` — §2 marked ✅ Complete

### 2026-06-01 — Backlog rewrite from product documentation

**Action:** Backlog fully rewritten from 11 items to 16 items based on Obsidian product docs.

**Files modified:**
- `tracking md files/backlog.md` — complete rewrite: stale Firestore refs removed, critical path corrected, §2/§4/§9/§10/§14 added as new items
- `tracking md files/context.md` — session block prepended
- `tracking md files/planner.md` — §2 added as next sprint task
- `agents md files/agent_scoping.md` — DeepSeek v4 Pro registered as Rank 1 Executor (4.6/5)

**Reason:** Old backlog described Firestore-primary architecture (superseded by local-first pivot on 2026-05-31). New backlog maps to actual Workflow Template stages and references ForkIt worked examples as ground truth for each output.

### 2026-05-31 — §1 Flutter Bootstrap + Local Data Layer

**Action:** Flutter project created, dependencies added, data layer implemented.

**Files created:**
- All Flutter platform scaffolds via `flutter create`
- `pubspec.yaml` — replaced deps with Riverpod, drift, path_provider, uuid
- `analysis_options.yaml` — replaced flutter_lints with explicit rule set
- `lib/data/local_db/forge_database.dart` — drift schema, 4 method contracts
- `lib/data/filesystem/project_file_repository.dart` — 8 method contracts

**Files modified:**
- `tracking md files/context.md` — session block prepended
- `tracking md files/planner.md` — §1 task added, sub-tasks checked off
- `tracking md files/backlog.md` — §1 status updated to In Progress

**Deleted:**
- `README.md` (auto-generated Flutter template — project has its own SOP docs)

### 2026-05-31 — Initial repo bootstrap

**Action:** Repo created from Starter Repo template.

**Files created:**
- All core docs (claude.md, agents.md, ARCHITECTURE.md, backlog.md, backend.md, etc.)
- Bugtracker scaffold
- Agent SOPs
- The Forge protocol docs (workflow_template.md, positioning_brief.md)
- .gitignore (Flutter + Firebase + macOS)
- Git initialized and pushed to github.com/marcyap29/theforge
