# The Forge — Session Log

Newest session first. Each block is prepended.

---

## Session: 2026-09-11 — Claude Code [Fix Mark-shipped on reattach — v0.4.6]

**Branch:** main · **App:** v0.4.6

### Done
- **Fixed BUG-IMPL-005:** "Mark shipped" in the build window did nothing when the run was re-attached (`_buildFeature`'s reattach path `await push; return;` discarded the result; only the fresh path handled shipping). Extracted `_handleBuildResult(feature)` that reads the keepAlive run state's `featureShipped` and applies status+release; called on BOTH nav paths. File: `project_tracker_screen.dart`.

### Verification
`dart analyze lib/` clean · `flutter test` 15/15.

---

## Session: 2026-09-11 — Claude Code [Copy console + diagnose planning failure — v0.4.5]

**Branch:** main · **App:** v0.4.5

### Done
- **Console is copyable:** wrapped `_Console` in `SelectionArea` (drag-select + ⌘C) + a Copy-all header button (`Clipboard`). So the user can grab an error/output and paste it for fixing.
- **Diagnose "did not return valid JSON":** `ImplAgentException` now carries the raw model output; on failure the notifier prints the raw (tail, selectable) to the console so the actual cause is visible instead of a black-box error. Plan `maxTokens` raised 8000→16000. Files: `impl_agent.dart`, `implementation_notifier.dart`, `implementation_screen.dart`.
- **Open question (needs the raw output to confirm):** likely cause of the recurring JSON failure on theforge is the model emitting malformed JSON when embedding Dart code (unescaped quotes/newlines) in the hunk `find`/`replace` strings. If confirmed, the durable fix is a non-JSON SEARCH/REPLACE block format (Aider-style). Awaiting a pasted raw sample.

---

## Session: 2026-09-11 — Claude Code [Vibecode-in-app + re-edit shipped — v0.4.4]

**Branch:** main · **App:** v0.4.4

### Done
- **Persistent vibecode prompt** in the Build window (`_VibeInput`): always-available text box; typing an instruction when the agent is idle calls `notifier.steer()` → `_plan(previousPlan, feedback)`. Replaced the phase-limited Revise box (removed `revise()`, the approval-panel Revise field).
- **Esc interrupts** the running task (`CallbackShortcuts` + `Focus(autofocus)` → `stop()` when busy), like Ctrl-C in a terminal.
- **Re-edit shipped features:** the "Build with AI" tile action is now shown for any non-archived feature (labelled "Re-build / edit with AI" when shipped), so a finished feature isn't locked. Files: `project_tracker_screen.dart`.

### Verification
`dart analyze lib/` clean · `flutter test` 15/15.

### Next
Real §MB entitlement backend; cancel in-flight model call on Stop (Esc currently marks stopped but the two-pass HTTP stream runs to completion in the background); per-screen ForgeTheme color migration; bundle fonts.

---

## Session: 2026-09-10 — Claude Code [Onboarding: create-a-code-folder + review hardening — v0.4.1]

**Branch:** main · **App:** v0.4.1

### Done
- **Build with AI now edits via find/replace hunks, not full-file rewrites** (v0.4.3, roots-fixes BUG-IMPL-003 + BUG-IMPL-004): the model returns small `{find, replace}` snippets for existing files (full `content` only for new files), so a truncated read can't cause "did not return valid JSON" and untouched code can never be dropped. Read cap raised to 24k/file (90k total); unmatched hunks skipped with a note. STEPS timeline no longer shows all-green on a failed run. Files: `impl_agent.dart`, `implementation_screen.dart`.
- **Fixed Build-with-AI planning failure on reasoning models** (BUG-IMPL-004, v0.4.2): glm-5.3 spent the whole turn thinking and returned no valid JSON. Ollama now sends `num_predict` (generous ceiling), plan budget 8000 / scout 4000, prompt forbids asking for more files + forces JSON-only, and the agent auto-retries once. Files: `ollama_provider.dart`, `impl_agent.dart`.
- **Create a code folder from inside The Forge** (§ONB): the project-detail "Link Repo" row and the Build-with-AI "no repo" prompt now offer **Create a new code folder** (makes `~/Development/<name>`, `git init`, seeds README, links it) or **Link an existing folder**. Closes the vibecoder onboarding gap where there was no repo for the agent to write into (The Forge never creates/clones repos otherwise; the fixed project root `~/Documents/The Forge Projects/` is only for `.forge` deliverables). New: `ProjectFileRepository.createCodeRepo` / `defaultCodeRoot`. Files: `project_file_repository.dart`, `project_detail_screen.dart` (`_RepoPathRow`), `project_tracker_screen.dart` (`_ensureRepoPath`).
- **Review hardening (from the v0.4.0 code review):** sandboxed agent writes with `ImplWorkspace.isPathSafe` (rejects absolute/`..` so a model edit can't escape the repo) + `test/impl_workspace_test.dart`; folder pickers pass `lockParentWindow`; fixed a stale keepAlive docstring.

### Verification
`dart analyze lib/` clean · `flutter test` 15/15.

### Next
Real §MB entitlement backend; diff/patch-based edits + post-edit compile check (BUG-IMPL-003); cancel in-flight model call on Stop; per-screen ForgeTheme color migration; bundle Unbounded/IBM Plex Mono fonts.

---

## Session: 2026-09-10 — Claude Code [Build with AI shipped + design kit (§BWAI / §UIK / §NP2) — v0.4.0]

**Branch:** main · **Commits:** `71d7de4` → `027c64c` · **App:** v0.4.0

### Done

**§BWAI — Build with AI, from MVP to shipping feature (Pro).** The propose-&-approve
implementation agent (`lib/features/implementation/`) got the interaction layer that
makes it usable end-to-end:
- **Real token streaming** across all LLM providers — new `LlmDelta{text,thinking}` +
  `completeStream`. Reasoning models (glm-5.3, gpt-oss:120b) stream chain-of-thought
  (Ollama `message.thinking`), shown live. (Previously only `content` was read →
  reasoning models rendered nothing while thinking — see Fixed.)
- **Console UX:** visible scrollbar + smart stick-to-bottom; reasoning rendered as real
  scrollable lines; **internal thinking (dim) vs external presentation (green)**;
  collapsible inline "thinking" block (auto-collapses on done); guaranteed green
  **Summary**; ActiveModelChip + wait-heartbeat + elapsed timer.
- **Two-pass read-then-edit loop:** scout picks files → we read them → plan edits
  grounded in real code (no more blind full-file guesses). Agent is also grounded in
  repo key docs (README/ARCHITECTURE/CLAUDE.md/agents.md).
- **Live commands:** approved commands run with LIVE STREAMED output via `Process.start`
  (first in the app); applied edits keep per-step Undo (`.forge/impl_backups/<runId>/`);
  verified against the Handoff checklist.
- **Modify the plan:** hand-edit a proposed file's content; hand-edit a command;
  **Revise** (tell the AI what to change → re-plan); **Fix-on-failure** ("Fix it" feeds
  command failures + failed checklist items back to the agent for a corrective plan).
- **Runs survive navigation** (keepAlive) and re-attach on reopen; board status dots per
  feature; tap an in-progress feature to open its run.
- **Release tracking** (`§BWAI-REL`, shipped last session): `Releases` drift table
  (schemaVersion 2→3), Releases view grouped by version, "Cut release" → deterministic
  notes → CHANGELOG.md + optional git tag.
- Pro-gated via an `entitlementProvider` stub (real gate = §MB managed backend).

**§NP2 — New Project reduced to two vibecoder choices:** "Describe a new app"
(Import→Spec, with a Paste/Guided sub-toggle) and "Bring in existing code" (onboarding).
The audit-interview was retired from the picker.

**§UIK — Forge design kit:** new `ForgeTheme` (navy + ember/brass "metals"), the
**Hearth Dial** mark (`lib/core/widgets/hearth_dial.dart`), a **launch splash**
(`/` → `/home`) driven by real boot steps, a **first-run onboarding** screen, and a
**portfolio digest** ("what changed since you last looked", from `lastOpened` +
`Features.updatedAt`) + `ForgeAppHeader`. Source kit lives in `UIUX/`. Design language v2:
`rust (#7A3826)` now marks blocked/stuck.

### Key Technical Findings
- Providers are no longer blocking for the build console: `completeStream` yields
  `LlmDelta`s so both text and reasoning arrive incrementally. The live feel is now real
  model streaming, not just command output.
- Reasoning models return their chain-of-thought on a **separate** channel (Ollama
  `message.thinking`); reading only `content` shows nothing while the model thinks.
- Grounding matters: the two-pass read-then-edit loop (read real files before planning)
  plus repo-doc context is what stopped the agent from proposing edits against imagined
  code.
- The Pro gate is a stub today; the real entitlement needs the §MB managed backend.

### INCIDENT
A Build-with-AI run **on theforge itself** corrupted `app.dart` +
`settings_notifier.dart` via a full-file rewrite that silently dropped code. Caught in
review and reverted (uncommitted) — **never shipped**. Root lesson: full-file rewrites are
lossy; move to **diff-based edits** (see Next / planner follow-ups).

### Fixed (see bugtracker)
- **BUG-LLM-001** — reasoning models showed nothing while streaming (only `content` read;
  now reads the thinking channel too).
- **BUG-IMPL-001** — Stop → Try again crashed (stale-stream race; fixed with a generation
  counter).
- **BUG-IMPL-002** — app quit on Apply & Run (unbounded console + unsafe/hung command);
  fixed with console cap + command denylist + 3-min timeout + guarded run.
- **BUG-IMPL-003** — full-file-rewrite corruption incident (above); mitigated by review;
  real fix (diff-based edits) tracked as a follow-up.

### Modified / New
NEW (design kit): `lib/core/widgets/hearth_dial.dart`, `ForgeTheme`, launch splash,
first-run onboarding, portfolio digest + `ForgeAppHeader`, `UIUX/` source kit.
MODIFIED: `lib/features/implementation/**` (streaming console, two-pass loop,
modify/revise/fix, run persistence + board dots), all LLM providers under
`lib/services/llm/**` (`LlmDelta` + `completeStream`), New Project picker (`§NP2`),
`lib/features/tracker/**` (board status dots, tap-to-open in-progress run).

### Verification
`dart analyze lib/` clean · `flutter test` green. Shipped as **v0.4.0** (commits
`71d7de4` → `027c64c`, all on `main`).

### Next
Deploy v0.4.0 and exercise Build with AI on a linked repo end-to-end. Follow-ups:
wire `entitlementProvider` to the **§MB managed backend** (real Pro gate); **diff-based
edits** to prevent full-file-rewrite corruption; per-screen color migration onto
`ForgeTheme`; bundle the **Unbounded / IBM Plex Mono** fonts. Agent commit-per-feature and
LLM-polished release notes remain open.

---

## Session: 2026-09-10 — Claude Code [Build with AI (§BWAI)]

**Branch:** main · **Commit:** `71d7de4`

### Done

**§BWAI — Feature-driven in-app implementation agent (Pro):** From a tracked
feature, The Forge calls the LLM to implement it — propose-&-approve loop
(diffs + commands), applies approved edits with per-step Undo, runs commands
with live streamed output in an in-app console, verifies against the Handoff
checklist. New module `lib/features/implementation/`:
- `models/run_session.dart` (phases, console lines, plan, verify results)
- `data/command_runner.dart` (**first `Process.start`** streaming in the app)
- `data/impl_workspace.dart` (repo gather, edit apply + `.forge/impl_backups/` Undo, checklist verify)
- `data/impl_agent.dart` (executor-role LLM → JSON plan; full-file content, not diffs)
- `providers/` (run notifier state machine + `entitlementProvider` stub)
- `screens/implementation_screen.dart` + `widgets/diff_view.dart` (LCS diff)

**§BWAI-REL — Feature + release tracking:** New `Releases` drift table
(schemaVersion **2→3**, create-only migration) + CRUD; `tracker_repository`
release ensure/save + `.forge/tracker/releases.json` mirror; `releases/
release_providers.dart` (group by version, cut release → notes → CHANGELOG,
optional git tag; deterministic notes); `screens/releases_screen.dart`;
`project_tracker_screen` gains "Build with AI" tile action + Releases app-bar
entry (build → `in_progress`; ship → `shipped` + ensure release row);
`project_file_repository` `gitCommitAll` + `gitTag`.

### Key Technical Findings
- Providers are all blocking (`stream: false`): model reasoning is chunked;
  the live feel is streamed **command** output only. Token-streaming the model
  is a Phase-2 provider change.
- Agent returns **full file content** (not diffs) → reliable apply; diff is
  computed locally for display.
- Verification reuses the existing Handoff checklist as a **deterministic**
  oracle (files exist + keywords present) — no extra LLM call.
- drift codegen still needs the `objective_c` hook workaround (move aside → run
  build_runner → restore).

### Modified / New
NEW: `lib/features/implementation/**` (8), `lib/features/tracker/releases/release_providers.dart`,
`lib/features/tracker/screens/releases_screen.dart`, `test/release_logic_test.dart`,
`DOCS/forge/build_with_ai_plan_v1.md`, `DOCS/Coding Lessons/FOR_MARC_build-with-ai-agent.md`.
MODIFIED: `lib/data/local_db/forge_database.dart` (+ `.g.dart`),
`lib/data/filesystem/project_file_repository.dart`,
`lib/features/tracker/data/tracker_repository.dart`,
`lib/features/tracker/screens/project_tracker_screen.dart`.

### Verification
`dart analyze lib/` clean · `flutter test` 11/11.

### Next
Deploy (`tool/deploy_macos.sh`) and exercise Build with AI on a linked repo.
Phase-2 ideas: token-streaming providers; agent commit-per-feature; LLM-polished
release notes; wire `entitlementProvider` to the managed backend.

---

## Session: 2026-09-10 — Claude Code [Portfolio Tracker era (§PT)]

**Branch:** main

### Done

**§PT1 — Portfolio Tracker data + UI:**
- drift tables `Features` + `ProjectTracking` (schemaVersion 1→2, create-only migration, mirrored to `tracker/*.json`); dashboard is the new home (`/`), old list moved to `/projects`; per-project feature board grouped by status; real tracker tests replaced the stale starter test. Files: `lib/features/tracker/**`, `lib/data/local_db/forge_database.dart`, `test/widget_test.dart`.

**§PT2 — Auto-scan + check-ins:**
- `lib/features/tracker/scan/feature_scan.dart`, `lib/features/tracker/checkin/**`; on-open staleness + review cadence; git-diff check-in with accept/edit.

**§PT3 — Deploy + unsandbox:**
- `tool/deploy_{macos,ios,android}.sh`, `install_macos.sh`; macOS entitlements unsandboxed; `DOCS/deploy/*`.

**§PT4 — Ollama Cloud + Gemini removal:**
- `lib/services/llm/**` (`OllamaProvider` Bearer auth, default `gpt-oss:120b-cloud`), `lib/features/settings/**`; `gemini_provider.dart` + `gemini_usage_provider.dart` deleted.

**§PT5 — Deletion:**
- `lib/features/projects/project_actions.dart` (double-confirm + cascade) + dashboard/list screens.

**§PT6 — Dictation:**
- `macos/Runner/*` + `lib/services/paste_receiver.dart` + `lib/main.dart` (`theforge://paste` → `PasteTextIntent`).

**§PT7 — App icon** across all platforms.

**§PT8 — `.forge` layout:**
- `ProjectFileRepository.forgeDirName`; ~40 path sites + tracker + external readers under `.forge/`; migrated stranded sandbox projects (AR Mechanic, Forkit) into the canonical root; deleted stale `net.orbitalai.dataflow` container.

**§PT9 — Fixed canonical root + Export:**
- removed the settable-root picker; `lib/features/projects/doc_export.dart` ("Export docs…" → `forge-docs/`).

**§PT10 — Import → Spec:**
- `lib/features/import/**` (`import_service`, `import_screen`, `import_confirm_screen`); New Project "Import → Spec" card; reuses `SpecGenerationScreen`.

**§PT11 — Repo onboarding:**
- `import_service` `repoDigest`/`deepAnalysis`/`repoSource`; Quick vs Deep scan; gap form + `openQuestions`; Deep reuses `scanProjectCodebase` + `analyzeFileBatch`.

**§PT12 — Doc-based feature scan:**
- `feature_scan.dart` now reads a project's own `.forge` docs (+ linked repo); button "Scan Repo and Documents".

**Bug fixes:**
- BUG-SETTINGS-002 (role provider but empty model broke every LLM call — Settings auto-picks first model + `LlmService` fallback)
- BUG-UI-003 (macOS folder picker silent — `lockParentWindow`)
- BUG-DATA-001 CRITICAL (deleting a mis-indexed project could `rm -rf` a real code repo — now guarded to the canonical root + index pruning + path shown in dialog)

**Repo:** consolidated to a single `main` (PR #1 merged, #2 closed).

### Key Technical Findings
- Flutter macOS text fields don't reliably receive synthetic ⌘V (CGEvent) — use a URL-scheme + `PasteTextIntent` instead.
- drift codegen (`build_runner`) fails on Dart 3.10 because transitive `objective_c` ships a native build hook that blocks the AOT step; workaround: temporarily move the hook aside during codegen.
- Un-sandboxing was required because the git-based features can't run under the App Sandbox.
- The projects root must be a FIXED canonical home; letting it be set to a code repo caused the index to list real source folders as deletable "projects".
- Import reuses the interview's `InterviewState`/`extracted` contract, so one extractor feeds the existing `SpecGenerationScreen` — no second generator.

### Modified
- `lib/features/tracker/**` (NEW)
- `lib/features/import/**` (NEW)
- `lib/features/projects/project_actions.dart` (NEW), `doc_export.dart` (NEW)
- `lib/data/local_db/forge_database.dart` (schemaVersion 1→2)
- `lib/services/llm/**`, `lib/features/settings/**`; `gemini_provider.dart` + `gemini_usage_provider.dart` (DELETED)
- `lib/services/paste_receiver.dart` (NEW), `lib/main.dart`, `macos/Runner/*`
- `tool/deploy_{macos,ios,android}.sh` (NEW), `install_macos.sh` (NEW), `DOCS/deploy/*` (NEW)
- `test/widget_test.dart` (real tracker tests)

### Next
- Managed-backend metered-gateway spike (freemium Pro tier over Ollama Cloud).
- Optional batch mode for Deep scan (fewer LLM calls on big repos).
- Consider the App-Store sandbox rework (in-process git + security-scoped bookmarks) per `DOCS/deploy/APP_STORE_SANDBOX_PLAN.md`.

---

## Session: 2026-07-02 — Claude Code [Module Discovery + Ingestion Pipeline (§MD)]

**Branch:** main

### Done

**§MD — Module-Aware Codebase Ingestion (Chunks 2–6):**
- `lib/features/projects/ingestion/module_discovery.dart` (NEW) — `ModuleDiscoveryResult` + `ModuleDiscovery` class; `discover()` is deterministic (no LLM call), classifies repos as `single` or `moduleAware` based on `ARCHITECTURE.md`/`README.md` headings and `lib/` folder structure
- `lib/features/projects/ingestion/module_ingestion_pipeline.dart` (NEW) — `ModuleIngestionPipeline`; `ingestModules()` calls shared `analyzeFileBatch()` per module, `synthesize()` produces unified codebase overview via architect-role LLM call
- `lib/features/projects/ingestion/pull_ingestion_notifier.dart` (MODIFIED) — added `tier` + `detectedModules` fields to `PullIngestionState`; `startIngestion()` now runs `ModuleDiscovery` first and returns early on `moduleAware` tier; new `confirmModules()` method runs full multi-module pipeline
- `lib/features/projects/screens/pull_ingestion_progress_screen.dart` (MODIFIED) — converted `ConsumerWidget` → `ConsumerStatefulWidget`; added `awaitingConfirmation` arm with module checkbox list; added `synthesizing` state to inner progress text
- `lib/features/spec_generation/as_built_spec_generator.dart` (MODIFIED) — added `_asBuiltSpecStructureModuleAware` const (identical to `_asBuiltSpecStructure` except §3 is "Module Map" instead of "Component Map")

### Key Technical Findings
- `ModuleDiscovery` must be pure/deterministic — no LLM calls, no Riverpod providers. It's a utility that reads files and walks directories. This keeps it testable and fast.
- `confirmModules()` is additive — it doesn't replace `startIngestion()`'s single-module path. Single-module repos flow through unchanged; only large repos (>40 files with module signals) trigger the confirmation screen.
- Empty `_confirmedModules` set = "all modules confirmed" (lazy-init pattern). First checkbox interaction seeds the set from the full module list. This avoids initializing with all modules checked in the UI (which would render a confusing "all checked" state before the user has seen anything).
- `ConsumerWidget → ConsumerStatefulWidget` conversion: all widget fields become `widget.field` in state; `ref` is available from `ConsumerState`; callbacks like `Navigator.pop(context)` work the same.
- `_asBuiltSpecStructureModuleAware` is intentionally unreferenced in `buildAsBuiltSpecPrompt()` — it's a data asset for future wiring (Chunk 7+). The unused_element suppression is on a single declaration, not the whole file.

### 4-Agent Review (2026-07-02)

**Architecture Review:** PASS
- Clean layering: ModuleDiscovery is pure/deterministic, no LLM/Riverpod
- Correct dependency flow: discovery → state → UI confirmation → confirmModules() → pipeline → LLM → write
- Proper state ownership: PullIngestionState surfaces tier/detectedModules for UI

**Syntax Review:** PASS
- `dart analyze` reports no issues across all 5 files

**Functions Review:** FAIL (4 issues found, all fixed)
1. **Substring path matching bug:** `contains('/$moduleName/')` would match "auth" against "authentication". Fixed: now splits path on `/` and `\` and checks each segment equals the module name.
2. **`synthesize()` never wired in:** The method existed but wasn't called. Fixed: added synthesis step in `confirmModules()` between `ingestModules()` and `aggregating`, feeds synthesized overview into invariant extraction context.
3. **Tautological confirm button check:** `_confirmedModules.isEmpty || _confirmedModules.isNotEmpty` is always true. Fixed: changed to `_confirmedModules.isNotEmpty` (button disabled until user interacts with at least one checkbox).
4. **Silent module drop:** `if (moduleFiles.isEmpty) continue;` dropped modules with no matching files silently. Fixed: added `skippedModules` list to track (though currently not surfaced to user — future enhancement).

**Formatting Review:** FAIL (all 5 files needed formatting)
- Ran `dart format` on all 5 files — all pass now.
- `dart analyze lib/` → zero new warnings/errors (1 pre-existing info in project_detail_screen.dart, unchanged).

### Modified
- `lib/features/projects/ingestion/module_discovery.dart` (NEW)
- `lib/features/projects/ingestion/module_ingestion_pipeline.dart` (NEW)
- `lib/features/projects/ingestion/pull_ingestion_notifier.dart` (MODIFIED)
- `lib/features/projects/screens/pull_ingestion_progress_screen.dart` (MODIFIED)
- `lib/features/spec_generation/as_built_spec_generator.dart` (MODIFIED)

### Next
- Dogfood module-aware ingestion: push a 50+ file repo, verify discovery triggers confirmation screen, confirm modules → multi-module pipeline runs end-to-end
- Wire `_asBuiltSpecStructureModuleAware` into `buildAsBuiltSpecPrompt()` when `summary.tier == IngestionTier.moduleAware`
- §MD post-review: run 4-agent review (Architecture, Syntax, Functions, Formatting)

---

## Session: 2026-07-01 — Claude Code [Version Labels + Updates Section (§VUI3 + §UPD1)]

**Branch:** main

### Done

**§VUI3 — Version-Aware Labels + Button Decoupling (Ornith, reviewed + bug-fixed this session):**
- `_BuildSequenceSection` now takes `targetVersion` prop; "Build Sequence — V*" header reflects active version
- `_CopyWorksheetButton` label: `'Copy ${specVersion.toUpperCase()} Handoff to Clipboard'`
- `_CoderPackageSectionState`: split `bool _working` → `bool _copying` / `bool _exporting`; each button has its own guard and spinner
- Expand tap handler: `onVersionTap(version)` called on expand → last-clicked version is always active
- Parent call sites pass `_selectedVersion ?? _versionOf(live.phase)` to both `_BuildSequenceSection` and `_CopyWorksheetButton`

**Bug fixes (Ornith-introduced, caught in review):**
- `setState(() => _discovery = _discover())` — arrow fn returned Future; fixed to block fn: `setState(() { _discovery = _discover(); })`
- `setState` in `didUpdateWidget` caused cascading build-scope assertion failures (Duplicate GlobalKey, `_dependents.isEmpty`, sliver errors); fixed by removing `setState` entirely — assign field directly, parent rebuild calls `build()` anyway. **Invariant: never call setState synchronously in didUpdateWidget.**
- Two indentation drift issues corrected (Ornith's known failure mode): `_buildCta` closing braces, expand tap handler body

**§UPD1 — Updates Section (replaces ✎ Amend Story dialog):**
- Deleted: `_AmendStoryDialog`, `_showAmendStoryDialog`, "✎ Amend Story" `MouseRegion` block (0 references remain)
- Added: `_UpdatesSection` StatefulWidget between "Project State" and "Reference Documents" in right panel
- Reads `ingested/{projectName}_StoryAmendments_{version}.md`; lists amendments (label badge + date + text)
- Inline `TextField` + `+ Add` button → calls `ProjectFileRepository().appendStoryAmendment()`
- `didUpdateWidget`: no setState — assigns `_amendments = []` + calls `_load()` directly
- try/finally in `_submit`: `_saving` always cleared even if save/load throws
- Loading spinner on initial `_load()`; saving spinner replaces "+ Add" button during write

### Key Technical Findings
- `setState(() => expr)` with an async expr returns a Future from the arrow fn — Flutter throws "setState() callback argument returned a Future". Always use block form for setState in async contexts.
- `setState` from `didUpdateWidget` schedules a child rebuild during the parent's active build scope → cascading assertion failures. The pattern in this codebase is: assign fields directly in `didUpdateWidget` (no setState). `FutureBuilder` re-reads its `future:` prop on every `build()`, so updating `_discovery` directly is sufficient.

### Uncommitted
- `lib/features/projects/screens/project_detail_screen.dart` — all §VUI3 + §UPD1 changes
- `lib/data/filesystem/project_file_repository.dart` — `appendStoryAmendment()` method

### Next
- Commit the uncommitted diff
- Dogfood Updates Section with a real project
- §PERSIST — Interview state persistence — backlog

---

## Session: 2026-07-01 — Claude Code [V1 Interview Redesign (§VI)]

**Branch:** main

### Done

**§VI — V1 Build Interview redesigned:**
- **Root problem fixed:** Previous L1 forced a one-sentence outcome; L3 forced a single capability choice. Result: specs that captured only a UI layer (e.g. swipe UI) with no end-to-end user flow (no invite logic, no connection, no backend). App looked right but couldn't be used.
- `lib/features/interview/state/interview_state.dart` — `InterviewState.empty()` extracted map now includes `userScenarios`, `userStories`, `storyAmendments`, `detectedHoles`, `v1UserStories` (all default `<String>[]`)
- `lib/features/interview/state/interview_notifier.dart`:
  - **Build openers** — invite the full story ("tell me the story of how you imagine someone using this app…") instead of asking for a one-liner
  - **L1 — Vision Capture** — accept freewheeling full vision; multiple scenarios; ask "any other scenarios?" until user confirms done; extracts `outcome`, `primaryUser`, `userScenarios`
  - **L2 — Story Synthesis + Hole Detection** — three steps in order: (A) synthesize into titled numbered stories showing full both-sides flow, (B) detect logical gaps (missing invite flow, no post-match communication, unspecified data source) and ask permission before filling each one, give 1-3 recommendations + state recommended one, (C) confirm the final story map; extracts `userStories`, `capabilities`, `detectedHoles`
  - **L3 — Version Scoping** — V1 = minimum COMPLETE working slice end-to-end (not one screen), propose V1/V2/V3+ breakdown, demo script covers full primary flow including any invite/connection steps; extracts `v1UserStories`, `chosenCapability`, `demoScript`, `v2Seeds`
  - **L4** — unchanged
  - **Story Amendments** — at any point in L2/L3, user can modify a confirmed story; AI tracks changes as V1a → V1b → V1c (count of existing `storyAmendments` determines next letter); entries: "V1a: what changed and why"
  - `parseForgeState()` — parses all 5 new fields with `is List<dynamic>` safety checks
  - `_layerGateMet()` — L1 requires `userScenarios.isNotEmpty`, L2 requires `userStories.isNotEmpty && capabilities.length >= 2`, L3 requires `v1UserStories.isNotEmpty`; all backward-compatible (old states without new fields fall back to previous gate logic)
  - `_extractedAtLayerStart()` — resets new fields at correct layer boundaries on rewind

### Key Technical Findings
- The L3 "pick ONE capability" rule was the structural cause of incomplete specs. The fix isn't relaxing scope — it's reordering: capture full vision first (L1), synthesize (L2), THEN scope what the minimum complete V1 is (L3). Now V1 must include everything the primary user story depends on.
- Backward compat is handled by checking `null` vs empty list: `stories == null` means old state → old gate logic. `stories is List && stories.isEmpty` means new state not yet populated → gate not met. This avoids breaking in-flight interviews.
- Story amendment notation (V1a/V1b) is derived from `storyAmendments.length` — the AI counts existing entries and picks the next ASCII letter. No separate counter field needed.

### Modified
- `lib/features/interview/state/interview_state.dart`
- `lib/features/interview/state/interview_notifier.dart`

### Next
- Dogfood the new interview flow with a real project to validate L2 hole detection
- Consider UI panel in InterviewScreen showing confirmed user stories and their amendment trail
- §PERSIST — Interview state persistence — backlog

---

## Session: 2026-07-01 — Claude Code [Cross-Cutting Invariant Extraction (§CCI)]

**Branch:** main

### Done

**§CCI — Cross-Cutting Invariant Extraction:**
- `lib/features/projects/ingestion/invariant_extractor.dart` (NEW) — `InvariantConfidence` enum (high/medium/low); `ExtractedInvariant` `@immutable` class with `fromJson` (safe `is List<dynamic>` + `? ??` null guards), `toJson`, `toMarkdown`; `_invariantSystemPrompt` const; `_buildExtractionPrompt()` + `_parseInvariants()` top-level helpers (fence-stripping + `is List<dynamic>` safe decode); `InvariantExtractor` class calling `LlmService.complete()` at t=0.2, maxTokens 4096
- `lib/features/projects/models/pull_ingestion_summary.dart` — added `import invariant_extractor.dart`; `final List<ExtractedInvariant> invariants` field (defaults `const []`); `copyWith({List<ExtractedInvariant>?})`; `lowConfidenceInvariants` getter; `toJson()` serialises invariants; `fromJson()` safe `is List<dynamic>` parse (backward-compatible — old JSON without `invariants` key falls back to `const []`); `toMarkdown()` appends `## Cross-Cutting Invariants` section when non-empty
- `lib/features/projects/ingestion/pull_ingestion_notifier.dart` — import `invariant_extractor.dart`; `startIngestion()` now: sets `IngestionState.aggregating` → calls `InvariantExtractor(service).extract()` → `summary.copyWith(invariants: invariants)` → single `writeIngestionSummary()` call (was 0 invariants; now includes them)
- `lib/features/spec_generation/as_built_spec_generator.dart` — added `§2a. Cross-Cutting Invariants` section to `_asBuiltSpecStructure` const; every as-built spec now includes the extracted rules
- `lib/features/projects/screens/pull_ingestion_summary_screen.dart` — import `invariant_extractor.dart`; invariant count row in `_buildSummaryCard`; `_buildInvariantsSection()` (confidence badge + rule + appliesTo + enforcement + violationConsequence + source); `_confidenceBadge()` with color-coded `Container` (green/orange/red); wired into `build()` Column after gaps section
- `lib/features/pull_interview/state/pull_interview_notifier.dart` — import `invariant_extractor.dart`; `_buildGreeting()` counts `low`-confidence invariants and adds confirmation note; `_buildSystemPrompt()` injects `LOW-CONFIDENCE INVARIANTS TO CONFIRM` block with targeted question guidance per rule

### Key Technical Findings
- DeepSeek swapped `systemPrompt`/`userPrompt` in the LLM call: put the data context (ingestion summary) as system and the instruction string as user — exactly backwards from the codebase pattern. Always verify the role assignment in LLM calls, not just the response parse.
- DeepSeek omitted `_parseInvariants()` and used `jsonDecode(response) as Map<String, dynamic>` expecting `{"invariants": [...]}` — but the system prompt instructs the LLM to return a plain JSON array. Mismatch between what you tell the LLM to return and what you try to parse is a silent runtime crash. Write parse and prompt in the same review.
- DeepSeek wrote the summary to disk twice: once before extraction (empty invariants) and once after. The correct pattern is a single write after invariant extraction. Extra disk writes are wasteful and the first write would contain stale/incomplete data.
- DeepSeek didn't use `copyWith()` we added in Chunk 1 — manually reconstructed `IngestionSummary` with all fields. When you add `copyWith()` to a model specifically for downstream use, verify the downstream actually uses it.
- `fromJson()` backward compat: old ingestion summaries on disk don't have an `invariants` key. Guard with `json['invariants'] is List<dynamic>` before casting — the `is` check returns false for null, so missing keys are handled automatically.

### Modified
- `lib/features/projects/ingestion/invariant_extractor.dart` (NEW)
- `lib/features/projects/models/pull_ingestion_summary.dart`
- `lib/features/projects/ingestion/pull_ingestion_notifier.dart`
- `lib/features/spec_generation/as_built_spec_generator.dart`
- `lib/features/projects/screens/pull_ingestion_summary_screen.dart`
- `lib/features/pull_interview/state/pull_interview_notifier.dart`

### Next
- Dogfood The Forge (Pull Mode end-to-end) to generate a §CCI-enriched as-built spec
- §PERSIST — Interview state persistence — backlog

---

## Session: 2026-06-30 — Claude Code [Notes/Backlog Sidebar + Version-Aware Panel + Addendum Interview]

**Branch:** main

### Done

**§NB1 — Notes + Manual Backlog in InterviewState:**
- `interview_state.dart` — `userNotes: String?` + `userBacklog: List<String>` fields; `clearUserNotes` flag on `copyWith`
- `interview_notifier.dart` — `_buildUserContextBlock()` top-level helper; injected into all three system prompts (build, audit, feature) so the LLM sees the user's notes and backlog items every turn

**§VUI2 — Version-aware detail panel + Coder Package Export:**
- `project_detail_screen.dart`:
  - `_selectedVersion: String?` state var on `_ProjectDetailScreenState`; drives which version the right panel shows
  - `_PhaseTimeline` — `selectedVersion` + `onVersionTap` params; tapping a version label selects it (orange underline on selected)
  - `_CoderPackageSection` — `targetVersion` param + `didUpdateWidget` + rewritten `_discover()` targeting selected version; Copy Bundle / Export Pack buttons with "Show in Finder" snackbar to communicate export location
  - `_FilesSidebar` — orange-dot highlight on files belonging to the latest version's coder package
  - `_contextPanelHeight` min 200 px, clamp to `screenHeight - 160`

**§AI1 — Addendum Interview (v1.1 minor spec):**
- `lib/features/addendum_interview/state/addendum_interview_notifier.dart` (NEW) — `AddendumInterviewArgs`, `AddendumTurn`, `AddendumInterviewState`, `AddendumInterviewNotifier` (`FamilyAsyncNotifier`); `addUserMessage()` (LLM turn), `generateMinorSpec()` (produces v{N}.1 spec); `addendumInterviewProvider`
- `lib/features/addendum_interview/ui/addendum_interview_screen.dart` (NEW) — `ConsumerStatefulWidget` chat UI; user/Forge bubbles; "Generate {minorVersion} Spec" button appears after ≥3 turns; success screen shows filename; matches Forge dark theme (Menlo, orange #E8A04C)
- `lib/data/filesystem/project_file_repository.dart` — `findSpecFile(projectPath, version)` scans `specs/v{version}/` for locked spec; `writeMinorLockedSpec(...)` writes to `specs/v{minor}/`
- `lib/features/projects/screens/project_detail_screen.dart` — addendum imports; regex fix (`^v(\d+(?:\.\d+)?)$` for minor version dirs); `_buildUpdateCta` method + `_latestVersionOnDisk()` helper; "Update v{N}" outlined button with confirmation dialog when viewing a non-latest version panel

### Key Technical Findings
- DeepSeek brace-count failure pattern: when replacing a method + class-closing `}` in one edit, DeepSeek dropped the class closing brace — `_PackBtn` ended up nested inside `_CoderPackageSectionState`. Python brace-count script (`{open} - {close} between two class markers`) is the fastest diagnosis. DeepSeek caught and fixed it without external prompting.
- `AddendumInterviewArgs` lives in the notifier file, not the screen file — import the notifier directly when the screen calls `AddendumInterviewArgs(...)`.
- `FamilyAsyncNotifier` with complex `args` objects: the `args` struct must implement `==` and `hashCode` for Riverpod family providers to key correctly. `AddendumInterviewArgs` uses Dart's default object identity — fine for this use case since a new `args` object is created per navigation push (no caching needed).
- Minor version dirs (`v1.1`) need regex `^v(\d+(?:\.\d+)?)$` — the old `^v\d+$` would skip them entirely in the sidebar scan.

### Modified
- `lib/features/interview/state/interview_state.dart`
- `lib/features/interview/state/interview_notifier.dart`
- `lib/features/projects/screens/project_detail_screen.dart`
- `lib/data/filesystem/project_file_repository.dart`
- `lib/features/addendum_interview/state/addendum_interview_notifier.dart` (NEW)
- `lib/features/addendum_interview/ui/addendum_interview_screen.dart` (NEW)

### Next
- Dogfood The Forge (Pull Mode) to spec next features
- §PERSIST — Interview state persistence (survive spec gen failure) — backlog

---

## Session: 2026-06-29 — Claude Code [Hotfixes + Forkit v3 Implementation]

**Branch:** main (The Forge) · `wt/forkit-v1-multiplayer` (Forkit)

### Done — The Forge

**Safe-write archive system (committed `d6c3c9c`):**
- `project_file_repository.dart` — `_archiveIfExists(File)` helper; called before writes in `writeHandoff`, `writeWorksheet`, `writeHandoffPackage`, `writeAsBuiltSpec`. Renames existing file to `{stem}{letter}-{M-D-YYYY}{ext}` before overwriting. `writeLockedSpec` unchanged (already throws `SpecAlreadyExistsException`).

**Regenerate button per version panel (committed `d6c3c9c`):**
- `project_detail_screen.dart` — `_buildVersionPanel` header row restructured to `Row(mainAxisSize: max)` with the chevron/label on the left and a `↻ Regenerate` button on the right (via `Spacer()`). Tapping navigates to `WorksheetGenerationScreen` with the correct `specVersion`. Shown only for shipped versions.

**Compliance screen version labels (committed `9768350`):**
- `spec_compliance_screen.dart` — 3 hardcoded strings replaced: AppBar title was `'V$priorSpecVersion Compliance Check'` (produced "Vv2"), summary header was hardcoded `'V1 Build Compliance Summary'`, CTA button was hardcoded `'Continue to V2 Interview'`. All now use `priorSpecVersion.toUpperCase()` / `nextVersion.toUpperCase()`.

**Earlier in session (from prior context):**
- Timeline `didPopNext()` re-discovers disk versions on return navigation
- BUILD SEQUENCE header shows correct disk-scanned version (`V{n}`)
- Unvalidated panels default to expanded; validated + shipped panels collapse
- `_findSpecFile` broader detection with `.md` fallback
- `_handoffDirHasFiles()` helper for handoff-only version detection
- Interview version bug: `_buildTimelineRow` passes `priorSpecVersion` so V3 interviews generate V3 files
- Interview AppBar title shows target version (e.g. "Build Interview — Forkit · V3")
- Execution validation flow: amber/green timeline colors, "Mark as Executed & Validated" button, rotating banner CTA, `readValidatedVersions()`/`markVersionValidated()` written to `project_config.json`

### Done — Forkit (committed `622fd8f` on `wt/forkit-v1-multiplayer`)

- `deep_link_service.dart` — `sessionIdStream` broadcast stream; `_extractSessionId()` helper extracted; emits to stream on both cold-start (`getInitialLink`) and runtime (`uriLinkStream`) links; `dispose()` closes controller
- `session_manager.dart` — `_linkSub` subscribes to `DeepLinkService.sessionIdStream` in `initState()`; host nickname dialog (`_HostNicknameDialog`) before session creation; button text "CREATE GROUP SESSION"
- `firestore_service.dart` — match detection bug fix: was checking `data.votes` (pre-transaction state), now checks `updatedVotes` (includes the current swipe). Without this, a mutual yes-swipe never fired a match on the vote that caused it.

### Key Technical Findings
- `_archiveIfExists` uses sync `renameSync` — fast and atomic on the same volume; no data loss window
- `Spacer()` in a `Row(mainAxisSize: max)` is the correct way to push a button to the far right inside a panel header
- DeepSeek agent directory confusion: always include working directory explicitly in the prompt header; DeepSeek will scan for files and if it can't find them it creates stubs from scratch in whatever CWD it has
- Firestore transaction bug pattern: reads inside `runTransaction` return a snapshot (`data`); any field you update goes into a separate `updated` map — always check membership against the updated map, not the original snapshot

### Modified (The Forge)
- `lib/data/filesystem/project_file_repository.dart` — safe-write archive
- `lib/features/projects/screens/project_detail_screen.dart` — regenerate button + all fixes above
- `lib/features/spec_generation/compliance/spec_compliance_screen.dart` — dynamic version labels

### Modified (Forkit)
- `lib/deep_link_service.dart` — sessionIdStream
- `lib/session_manager.dart` — live deep link + host nickname dialog
- `lib/firestore_service.dart` — match detection fix

### Next
- §R2 — Pull Interview (not started, requires §R1 ✅)
- §D1 — Disk-First Status (backlog)
- Forkit v3: PR review + merge `wt/forkit-v1-multiplayer` → main

---

## Session: 2026-06-28 — Claude Code [§R1 Completion: Pull Mode Wiring]

**Branch:** main

### Done

**§R1 — Pull Mode Wiring (uncommitted, Marc reviews):**
- R1-1: `project_file_repository.dart` — `modeDisplay` ternary → switch expression handling all 3 modes; "What's Next" section conditional on mode
- R1-2: `new_project_screen.dart` — added Project Onboarding card (REVERSE MODE → PROJECT ONBOARDING) with purple accent; `_ModeCard` icon/accent now uses switch instead of boolean
- R1-3: `project_detail_screen.dart` — `_RepoIngestRow` loads `repoPath` from `project_config.json` on init; shows SnackBar if no repo linked; uses `_repoPath` for ingestion instead of `widget.projectPath`; dynamic label shows linked repo name

### Key Technical Findings
- `_ModeCard` was using an `isBuild` boolean to derive icon and accent color. Replacing with a switch on `ProjectMode` is more extensible for future modes.
- `_RepoIngestRow` must watch `project_config.json` asynchronously on mount — same pattern as `_RepoPathRow`. The repo path is the source of truth for what to ingest.

### Next
- Marc reviews changes, then commits
- §R2 — Pull Interview (separate plan, not started)

### Modified
- `lib/data/filesystem/project_file_repository.dart` — modeDisplay switch, What's Next conditional
- `lib/features/projects/screens/new_project_screen.dart` — Project Onboarding card, switch for icon/accent
- `lib/features/projects/screens/project_detail_screen.dart` — _RepoIngestRow loads repoPath, dynamic label

---

## Session: 2026-06-27 — Claude Code [§VF1/§VC1/§CI1/§QOL — Versioned FS + Verification Checklist + QOL]

**Branch:** main

### Done

**§VF1 — Versioned Folder Structure (committed — `723d733`):**
- All artifact writes now go into version subfolders instead of flat directories:
  - Before: `specs/ProjectName_LockedSpec_v1.md`
  - After: `specs/v1/ProjectName_LockedSpec_v1.md`
  - Same change applies to `handoffs/`, `forge/`, `worksheets/`
- New methods added to `ProjectFileRepository`:
  - `getSavedRootPath()` [STATIC] — reads root path from SharedPreferences
  - `saveRootPath(String path)` [STATIC] — persists root path to SharedPreferences
  - `_defaultRootDir()` — now checks saved root path first, falls back to `~/Documents/The Forge Projects/`
  - `_extractVersion(String filename)` [STATIC] — regex extracts `v1`, `v2`, etc. from filename
  - `hasFlatVersionedFiles(String projectPath)` — detects old flat-structure files needing migration
  - `migrateToVersionFolders(String projectPath)` — moves flat versioned files into version subfolders; returns count of files moved
- Backward compatibility: all reads check versioned path first, fall back to flat for existing projects. `writeHandoffPackage` now writes to `handoffs/v1/`.

**§VC1 — Verification Checklist (committed — `723d733`):**
- After spec generation, a second LLM call generates a machine-readable verification checklist and stores it in the handoff package JSON under `verificationChecklist`
- New functions in `spec_generator.dart`:
  - `buildVerificationChecklistPrompt(String specContent, String projectName)` — builds the LLM prompt
  - `parseVerificationChecklist(String llmOutput)` — parses JSON output, returns `List<Map<String, dynamic>>`
- Changes in `spec_notifier.dart`:
  - `maxTokens` raised from 4096 → 8192
  - Truncation guard added: if the spec doesn't contain `## 9.` and `## 10.`, throws an error ("Spec generation was truncated — sections 9/10 are missing")
  - After `writeLockedSpec()`, calls checklist generation; failure is non-fatal (spec is already locked)
  - `buildSpecPrompt()` now accepts `specVersion` param so the spec title includes the version number

**§CI1 — Spec Compliance Gate + Compliance-Informed Feature Interview (committed — `1a8dcaf` + `723d733`):**
- Full 3-file compliance gate in `lib/features/spec_generation/compliance/`:
  - `spec_compliance_models.dart` — `ComplianceStatus` enum (verified/uncertain/failed/skipToLlm); `ChecklistItem`; `SpecComplianceResult` (cached by commit hash)
  - `spec_compliance_notifier.dart` — `SpecComplianceNotifier` (`AutoDisposeFamilyAsyncNotifier`); reads `verificationChecklist` from handoff package; git-diff file-presence check per item; caches to `forge/{version}/`; invalidates when HEAD changes; `skipToLlm` path for non-verifiable items
  - `spec_compliance_screen.dart` — full check UI; idle/checking/done/error; items grouped by status; feeds result as `complianceContext` to V2 interview
- `InterviewArgs` gains `complianceContext: String?`; `_featureInterviewSystemPrompt()` injects compliance block when non-null

**QOL fixes (committed — `723d733`):**
- `lib/services/llm/llm_model_config.dart` — Gemini default reverted to `gemini-3.5-flash` (from `gemini-2.5-flash`; model ID had been upgraded prematurely, causing inconsistent outputs)
- `lib/features/settings/settings_notifier.dart` — Ollama health check `maxTokens` bumped from 10 → 100 (10 tokens was too small to get a valid Ollama response, producing false "not connected" diagnostics)

**Commits this session:**
- `723d733` — feat(interview+spec): interview UX, persistence, feature mode, compliance gate, model catalog
- `1a8dcaf` — feat(compliance): spec compliance gate — pre-V2 interview build verification check

### Key Technical Findings
- **Versioned folder migrations must decouple reads from writes** — if reads hard-require the new versioned path, existing projects break at launch before the user has a chance to migrate. The correct pattern: write to `specs/v1/`, read versioned first then fall back to flat. Migration is opt-in via `_FixStructureBanner`, not forced.
- **Spec truncation is silent without a content guard** — `maxTokens: 4096` cut specs mid-section with no error; the write-once lock sealed a half-finished document. Checking for trailing sections (`## 9.`, `## 10.`) as a completeness proxy catches this before `writeLockedSpec()` fires.
- **Post-lock supplementary LLM calls must be non-fatal** — the spec is write-once; re-throwing from a post-lock call misleads the user into thinking the spec wasn't saved when it was. Wrap in try/catch, swallow the error, log if needed.
- **Escape hatch gate logic needs a length-only fallback** — layer-gated triggers (`L3/L4 + 6 turns`) break when the LLM exits the interview at L1/L2 without emitting forge-state JSON blocks, leaving the layer stuck and the button never showing. A raw turn-count fallback (≥10 turns, any layer) is the safety net.
- **`FilePicker` dismissal must save a default** — if the user cancels the root path picker, `picked` is null. Not saving a default in that branch means the picker reappears on every future project create, making the app appear broken on first launch.

### Next
- §W5 — Watch Mode: SwarmSpace Briefing + Decision Simulation (next on critical path; requires §W4 ✅)

### Modified (key files)
- `lib/data/filesystem/project_file_repository.dart` — versioned folder writes + root path persistence + migration helpers
- `lib/features/projects/screens/project_detail_screen.dart` — multi-version panel, _FixStructureBanner, _BacklogSection, _RepoPathRow, _CopyWorksheetButton
- `lib/features/spec_generation/spec_generator.dart` — buildVerificationChecklistPrompt, parseVerificationChecklist, specVersion param
- `lib/features/spec_generation/spec_notifier.dart` — maxTokens 8192, truncation guard, checklist generation
- `lib/features/interview/providers/interview_providers.dart` — complianceContext on InterviewArgs
- `lib/features/interview/state/interview_notifier.dart` — compliance block injection, escape hatch fallback
- `lib/features/projects/screens/new_project_screen.dart` — first-time root path picker
- `lib/services/llm/llm_model_config.dart` — Gemini default gemini-3.5-flash
- `lib/features/settings/settings_notifier.dart` — Ollama maxTokens 10 → 100
- `lib/features/spec_generation/executor_timeline_notifier.dart` — versioned handoffs scan

## Session: 2026-06-18/19 — Claude Code [Interview UX + Bug Fixes + Watch Mode §W4 Ship]

**Branch:** main

### Done

**Interview UX improvements (all committed):**
- **Shift+Enter newline / Enter sends** — `FocusNode.onKeyEvent` intercepts Enter; Shift+Enter falls through to multiline default
- **Auto-scroll on AI response** — `ref.listen` on turn count; scrolls on user AND AI messages
- **Auto-focus text field** — `requestFocus()` on mount + after send + after AI response via `addPostFrameCallback`
- **Conversation turn rewind** — "edit" link on every user bubble; tapping populates composer + calls `rewindTo(i)` which truncates turns and refocuses
- **"Continue with V1/V2 Interview →" CTA** — first user message writes `v1_interview_active` phase to DB; detail screen shows "Continue" vs "Start" correctly
- **Auto-opener (zero tokens)** — 4 variations per mode (Build / Feature V2+ / Audit) injected as AI turn in `build()`; reset also reinjects opener
- **Layer rewind** — completed L1/L2/L3 dots are tappable; `rewindToLayer(layer)` truncates turns to layer boundary, clears extracted data for that layer+later, re-derives confidence map, persists to disk
- **Layer boundaries** — `InterviewState.layerBoundaries: Map<String,int>` tracks when each layer was entered; persisted and restored across app restarts
- **Escape hatch button** — amber `OutlinedButton` at L3/L4 after ≥6 user turns when `specGenEnabled` is still false; "Generate Spec with current data →"

**Interview persistence (all committed):**
- **Full state restore on relaunch** — `writeInterviewProgress` now saves turns + confidenceMap + extracted + specGenEnabled + layerBoundaries on every LLM response (Build + Audit)
- `build()` reads `InterviewState.json` on launch; restores full turn history so mid-interview app close = seamless resume
- `reset()` clears the state file; spec generation clears it after locking
- `_restoreState` re-evaluates `specGenEnabled` from extracted data (fixes old sessions saved with buggy code)

**Interview gate bugs fixed:**
- **`externalServices` TypeError** — `(as List<dynamic>?)` hard cast threw when LLM output `"None"` (string); normalized to `is List` check; non-list → `[]`
- **Same fix for `capabilities`, `demoScript`, `v2Seeds`** — all 4 list fields now use safe `is List` parse; prevents full parse degradation on any field
- **`specGenEnabled` gate relaxed** — now fires when `allResolved || l4GateMet`; L4 funnel completion (platform+identity+input+output non-null) is sufficient, individual dimension tracking no longer the sole gate
- **`_confidenceFromExtracted` externalServices** — now resolves when other L4 fields are present (not just `is List` which was always true from initial empty state)

**Handoff/output bug fixes:**
- **`v2SeedItems` populated** in `HandoffPackage.json` from `state.extracted['v2Seeds']`
- **`setupWorksheetComplete: true`** written to HandoffPackage after worksheet generation via `updateHandoffPackageField()`
- **Component names strip `**`** — `parseComponentNames` now strips markdown bold formatting
- **README "What's Next"** updated to "Ready for executor — review build sequence" after worksheet completes

**Model catalog + settings fixes:**
- **Model ID validation on load** — `settings_notifier.build()` validates stored model IDs; retired IDs (`gemini-3.5-flash`, `gpt-4-turbo`) silently fall back to first valid model
- **Model catalog updated** — OpenAI: `gpt-4-turbo` → `gpt-4.1`; Gemini: `gemini-1.5-flash` → `gemini-2.0-flash`; `gemini-2.5-flash` + `gemini-2.5-pro` retained

**Commits this session:**
- `f4c106c` — interview resume, auto-opener, chat UX + handoff fixes
- `7390568` — externalServices parse TypeError + escape hatch
- `716e475` — layer rewind (tappable L1/L2/L3 dots)
- `0c2f4b1` — all list field parse fixes + gate relaxation + widened escape hatch
- `3721a29` — specGen restore + model ID validation + retire outdated models
- `a8062bc` — escape hatch button amber outlined

### Key Technical Findings
- **`as List<dynamic>?` hard cast pattern is dangerous** — any non-list LLM output (string, null) throws TypeError; the outer try/catch degrades the ENTIRE parse, discarding all extracted data for that turn. Always use `is List<dynamic>` check first.
- **specGenEnabled should track funnel completion, not dimension resolution** — dimension resolution is a derivative signal that can silently fail; funnel gate (L4 fields all present) is the ground truth
- **`_restoreState` must re-evaluate gates** — never trust saved booleans for computed state; re-derive from the data on restore
- **Model IDs in SharedPreferences outlive code changes** — need validation on load to handle catalog updates across app versions
- **`layerBoundaries[newLayer] = withUser.turns.length + 1`** — the boundary is stored AFTER the transition AI response is added, so rewinding to that layer keeps the transition message visible (user sees "great, now L2: list your capabilities")

### Next
- §W5 — Watch Mode: SwarmSpace Briefing + Decision Simulation (next on critical path)
- AR Mechanic project still shows "Continue with V1 Interview →" — interview complete inside app but DB phase not yet `v1_spec_locked`; user needs to generate spec from within interview screen

### Modified (key files)
- `lib/features/interview/state/interview_state.dart` — `layerBoundaries` field
- `lib/features/interview/state/interview_notifier.dart` — openers, boundaries, rewindToLayer, persist, gate fixes, parse fixes, model restore fix
- `lib/features/interview/ui/interview_screen.dart` — FocusNode, auto-scroll, escape hatch, layer dot taps
- `lib/features/projects/screens/project_detail_screen.dart` — "Continue" CTA, `_previousVersion` helper
- `lib/features/spec_generation/spec_generator.dart` — v2SeedItems, component name strip
- `lib/features/spec_generation/worksheet_notifier.dart` — setupWorksheetComplete, README update
- `lib/features/settings/settings_notifier.dart` — model ID validation
- `lib/services/llm/llm_model_config.dart` — model catalog update
- `lib/data/filesystem/project_file_repository.dart` — clearInterviewProgress, updateHandoffPackageField

---



## Session: 2026-06-17 — Claude Code [§W4 Watch Mode: Dashboard UI Shell]

**Branch:** main

### Done
- **§W4 — Watch Mode Dashboard UI Shell — shipped:** 5 new files + 3 modifications implementing the full Watch Mode dashboard. The UI reads §W1/§W2/§W3 data via a single orchestrating `WatchDataNotifier` and displays engineer cards, a spend chart, workspace health, and an alert log. Read-only except for alert dismissal.
  - `lib/features/watch/watch_data_notifier.dart` — `WatchData` model (usage, correlations, signalResult, hasGitHubConfig) + `WatchDataNotifier` AsyncNotifier; `_fetch()` reads §W1+§W2 services + roster + alertLog → runs `watchSignalService.evaluate()` → auto-appends new alerts → returns WatchData; convenience getters `allCommits`, `signalsFor(handle)`, `workspaceSignals`; `refresh()` pattern (AsyncLoading → AsyncValue.guard)
  - `lib/features/watch/watch_dashboard_screen.dart` — main screen; workspace strip (total 30d spend + active alert count + git connected/not-configured status, tappable → WorkspaceHealthScreen) + critical alert banner (red, shown only when non-dismissed critical alerts exist, tappable → AlertLogScreen) + ENGINEERS section + `_EngineerCard` per usage entry sorted by 30d spend descending (handle in white Menlo + provider chip amber/gray + first signal detail line in severity color + $total 16px + CI pass rate colored green>70%/amber 30–70%/red<30%) + VIEW WORKSPACE HEALTH OutlinedButton; AppBar refresh + notifications icons
  - `lib/features/watch/engineer_detail_screen.dart` — per-engineer drill-down; summary row (30d spend, CI pass %, AI %, PRs merged) + fl_chart `BarChart` (30d daily spend, bars colored per-day by that day's pass rate green/amber/red, date axis M/D interval 7, $ axis, grid horizontal lines, no border, dark background) + git activity 4-chip row (COMMITS/REVERTS/PRs MERGED/AI) + active signals list with severity icons (error/warning_amber/info_outline); "No data yet" placeholder when daily empty
  - `lib/features/watch/workspace_health_screen.dart` — velocity trend card (IMPROVING green / STABLE white / DECLINING amber / STALLED red, large 22px label + commits 7d vs prior 7d + change % colored green/red) + last commit row (red if stalled, "never" for stalledDays≥999) + CI stats row (total runs + pass rate) + workspace signals list
  - `lib/features/watch/alert_log_screen.dart` — alert log; active entries first with Dismiss TextButton, "— N dismissed —" divider (only when dismissed exist), dismissed entries (opacity 0.4 + strikethrough + no button); Clear Dismissed AppBar action; empty state "No alerts"; severity icons + handle chip + MM/DD HH:mm timestamp + 2-line detail
  - `pubspec.yaml` — `fl_chart: ^0.70.0` added (flutter pub get run by executor)
  - `lib/core/app.dart` — `/watch` route → `WatchDashboardScreen`
  - `lib/features/projects/screens/projects_list_screen.dart` — `Icons.monitor_heart_outlined` Watch Mode button before Settings in non-selecting AppBar
- **Committed:** `feat(§W4): Watch Mode dashboard UI — engineer cards, spend chart, workspace health, alert log` (9 files including pubspec.lock, 1458 insertions)

### Key Technical Findings
- **Single orchestrating provider pattern:** `WatchDataNotifier` is the only provider the watch screens watch. It fetches §W1+§W2, runs §W3, auto-appends alerts, and returns a `WatchData` bundle. The UI never imports `usageServiceProvider` or `gitActivityServiceProvider` directly — it reads `watchDataProvider`. This keeps the UI layer decoupled from the fetch+signal pipeline. If the fetch pipeline changes (e.g. add caching, add polling), only `WatchDataNotifier` changes; the screens don't.
- **Auto-append alerts on fetch:** `_fetch()` calls `alertLogProvider.notifier.appendAlerts(signalResult.newAlerts)` after signal evaluation. Opening the dashboard triggers a fetch→evaluate→persist cycle — the first open populates the log, subsequent opens see persisted state + new alerts. The alert log is the persistence layer; the dashboard reads it for the active-alert count via `ref.watch(alertLogProvider)`.
- **v1 limitation — ciRuns not exposed post-correlation:** `GitActivityService.fetchCorrelations()` consumes `ciRuns` internally for correlation but doesn't return them. `WatchDataNotifier` passes `ciRuns: const []` to `watchSignalService.evaluate()`, so `WorkspaceStatus.ciPassRate30d` is 0 in v1. Velocity trend and stall detection (commit-based) still work. Upgrade path documented in `watch_data_notifier.dart`: expose `ciRuns` from `fetchCorrelations()` so `ProjectStatusAggregator` can compute the real pass rate.
- **fl_chart bar coloring per-day by pass rate:** Each bar's color reflects that day's pass rate (green >70%, amber 30–70%, red <30%), not a single color for the whole chart. This makes the chart a "spend + quality" view — a tall red bar is "high spend, low pass rate" (the worst case); a tall green bar is "high spend, high pass rate" (the best case). Single-color bars would show spend but not quality.
- **`.length` is a getter, not a method:** First dashboard draft used `.length()` on `List.where(...)` result — analyzer caught `invocation_of_non_function_expression`. `List.length` is a property, not a method. Fix: `.length` (no parens). This is the kind of mistake that happens when switching between languages (Python's `len()` is a function; Dart's `.length` is a getter). The analyzer is the safety net.
- **`firstWhere(orElse: () => null as dynamic)` anti-pattern tempted again:** First dashboard draft had `_passRateFor` using the broken cast pattern. Caught it, replaced with `.where(...).firstOrNull` (Dart 3). This is the third time this anti-pattern has tempted in §W1-§W4 — the pattern is now documented in BUG_PREVENTION (via the §W2 coding lesson). The fix is always the same: `firstOrNull`.
- **Import ordering matters to the linter:** `directives_ordering` info fires when imports aren't alphabetically sorted within their section. The fix is mechanical (sort the lines), but it's worth knowing: the analyzer treats `package:` imports and relative imports as separate sections, and within each section, alphabetical order is required.

### Next
- §W5 — Watch Mode: SwarmSpace Briefing + Decision Simulation (next on critical path; requires §W4 ✅)
- Manual smoke test: run the app, tap the Watch Mode icon in the projects list AppBar → dashboard renders with demo data (default roster has one `demo` entry) → tap an engineer card → detail screen with bar chart → tap VIEW WORKSPACE HEALTH → workspace screen → tap notifications icon → alert log (empty initially, populates after first fetch+evaluate)

### Modified
- `lib/features/watch/watch_data_notifier.dart` — NEW
- `lib/features/watch/watch_dashboard_screen.dart` — NEW
- `lib/features/watch/engineer_detail_screen.dart` — NEW
- `lib/features/watch/workspace_health_screen.dart` — NEW
- `lib/features/watch/alert_log_screen.dart` — NEW
- `pubspec.yaml` — fl_chart added
- `pubspec.lock` — updated by flutter pub get
- `lib/core/app.dart` — /watch route added
- `lib/features/projects/screens/projects_list_screen.dart` — Watch Mode AppBar button
- `tracking md files/context.md` — this block
- `tracking md files/planner.md` — §W4 COMPLETE block + §W5 next-up
- `tracking md files/backlog.md` — §W4 ✅ in critical path + status line + Completed section
- `operations md files/CONFIGURATION_MANAGEMENT.md` — inventory + changelog
- `DOCS/Coding Lessons/FOR_MARC_watch-mode-dashboard-ui.md` — NEW

---

## Session: 2026-06-17 — Claude Code [§W3 Watch Mode: Failure Signal Engine + Alert Engine]

**Branch:** main

### Done
- **§W3 — Watch Mode Failure Signal Engine + Alert Engine — shipped:** 6 new files implementing the pure-computation signal/alert/status layer over §W1+§W2 data. Unlike §W1/§W2, §W3 does NO HTTP fetching — it's pure derivation. `WatchSignalService` is `const`-constructible and always non-null (no config deps).
  - `lib/services/watch/failure_signal_engine.dart` — `FailureSignal` model + `FailureSignalEngine` deriving 6 signal types:
    - `highTokenToFailRatio` (warning >30, critical >100, emit one severity only)
    - `loopDetected` (warning when ≥2 consecutive days with spend>$15 + zero CI output; tracks longest run + longest-run spend)
    - `churnDetected` (info 1–2 reverts, warning 3+; counts `revert`-prefixed commit messages)
    - `spendThreshold` (warning >threshold, critical >2×threshold, one severity only; re-derives from `EngineerUsage` + roster for formal signal pipeline)
    - `runawayDay` (critical when any day >$100; emits ONE signal per engineer — the worst day, to avoid flooding)
    - `stalledWorkspace` (workspace-level, handle=`'workspace'` literal; fires when no commits in 7+ days AND workspace 30d spend >$10; `stalledDays=999` for empty commit list)
  - `lib/services/watch/alert_engine.dart` — `AlertEntry` model (`toJson`/`fromJson`/`copyWithDismissed`) + `AlertEngine.evaluate()` deduplicates against existing log (24h window, same handle+signalType; dismissed alerts still dedup so a dismissed condition doesn't re-alert); id format `${handle}_${signalType.name}_${millisEpoch}`
  - `lib/services/watch/alert_log_notifier.dart` — `AlertLogNotifier` extends `AsyncNotifier<List<AlertEntry>>` persisting to `forge_config.json` key `watch_alert_log`; `build()` reads+parses (returns [] on missing/error), `appendAlerts()` prepends newest-first, `dismissAlert(id)` replaces with dismissed copy, `clearDismissed()` removes dismissed entries; mirrors `EngineerRosterNotifier` pattern
  - `lib/services/watch/project_status_aggregator.dart` — `WorkspaceStatus` + `ProjectStatusAggregator.aggregate()`; commits 7d vs prior 7d (days 8–14), ±20% velocity trend (`improving`/`stable`/`declining`/`stalled`), stall detection 7d (`stalledDays=999` for empty commit list so `isStalled=true` is correct), CI pass rate; per-repo upgrade-path comment (v1 aggregates across all repos combined — `GitCommit.repo` not in §W2)
  - `lib/services/watch/watch_signal_service.dart` — `WatchSignalResult` (signals + newAlerts + workspaceStatus) + `WatchSignalService.evaluate()` orchestrating all three engines; single call site for §W4 — imports nothing from §W4
  - `lib/services/watch/watch_signal_service_provider.dart` — `Provider<WatchSignalService>` non-nullable (pure computation, no config deps — inverse of §W1/§W2 nullable providers)
- **Committed:** `feat(§W3): failure signal engine + alert engine + workspace status — pure computation layer over §W1+§W2 data` (6 files, 586 insertions)

### Key Technical Findings
- **Pure-computation layering:** §W3 is the first Watch Mode subsystem with no HTTP. `WatchSignalService` is `const`-constructible and always non-null — the provider is `Provider<WatchSignalService>`, not `Provider<WatchSignalService?>`. This is the inverse of §W1 (`UsageService?`) and §W2 (`GitActivityService?`) where services were nullable when unconfigured. The pattern: fetching services are nullable (config-gated), computation services are not.
- **Severity escalation rule — emit one, not both:** For `highTokenToFailRatio` and `spendThreshold`, the engine emits critical OR warning, never both. Implemented by testing the critical threshold first and using else-if for warning. If both were emitted, the alert log would have two entries for the same condition, inflating the count and confusing the dashboard.
- **Loop detection — longest run, not first run:** The engine scans sorted `DailyCorrelation` for the longest consecutive run of "loop days" (spend>$15 + zero CI output). If ≥2, emits one warning. Tracks `longestSpend` (the spend during the longest run, not total across all loops — the longest run is the most actionable signal). This is a sliding-window count, not a simple counter — the current run resets when a non-loop day is hit.
- **Runaway day — one signal per engineer, worst day:** A naive implementation would emit one signal per $100+ day, flooding the alert log for an engineer with multiple runaway days. The engine emits ONE signal per engineer — the worst day by `tokenSpend`. The metadata records the peak day's date and spend so the dashboard can show "worst day was $X on Y" without flooding.
- **Stalled workspace is workspace-level, not per-engineer:** The handle is the literal string `'workspace'`, not an engineer handle. This distinguishes workspace-level signals from per-engineer signals in the alert log. `stalledDays=999` for an empty commit list ensures `isStalled=true` is correct for a workspace with no commits at all (the alternative — `stalledDays=0` — would incorrectly report "not stalled").
- **Alert dedup window is 24h, not "ever":** The same handle+signalType within 24h is skipped. After 24h, the same condition can re-alert (e.g. a runaway spend that persists across days should surface again). Dismissed alerts still dedup — a dismissed condition shouldn't re-alert within the window, but *should* re-alert after 24h if it persists (the dismissal is "I saw this," not "this is resolved").
- **Bug introduction rate explicitly out of scope:** Requires GitHub Issues API + issue-to-commit attribution, which §W2 didn't add. No stub signal added — the spec was explicit: "Do not attempt to implement it. Do not add a stub signal for it either." A stub would suggest the signal exists when it doesn't.
- **Field access bug caught by analyzer:** First draft of `_runawayDay` used a `DailyUsage? peak` temporary but accessed `.tokenSpend` (which is on `DailyCorrelation`, not `DailyUsage`). Analyzer caught it. Fix: iterate `DailyCorrelation` directly, store peak as `DailyCorrelation?`. Lesson: when two models have similar fields (`DailyUsage.costUSD` vs `DailyCorrelation.tokenSpend`), the wrong type can slip in — the analyzer is the safety net.

### Next
- §W4 — Watch Mode Dashboard UI Shell (next on critical path; requires §W3 ✅)
- Manual smoke test: instantiate `WatchSignalService()`, call `evaluate()` with §W1 demo usage + §W2 demo correlations + empty commits (or demo commits), verify `WatchSignalResult` returns correct signals (runaway profile should trigger `spendThreshold` + `runawayDay`; ghost profile should trigger neither; stalled workspace should fire when commits empty + spend >$10)

### Modified
- `lib/services/watch/failure_signal_engine.dart` — NEW
- `lib/services/watch/alert_engine.dart` — NEW
- `lib/services/watch/alert_log_notifier.dart` — NEW
- `lib/services/watch/project_status_aggregator.dart` — NEW
- `lib/services/watch/watch_signal_service.dart` — NEW
- `lib/services/watch/watch_signal_service_provider.dart` — NEW
- `tracking md files/context.md` — this block
- `tracking md files/planner.md` — §W3 COMPLETE block + §W4 next-up
- `tracking md files/backlog.md` — §W3 ✅ in critical path + status line + Completed section
- `operations md files/CONFIGURATION_MANAGEMENT.md` — inventory + changelog
- `DOCS/Coding Lessons/FOR_MARC_watch-mode-signal-engine.md` — NEW

---

## Session: 2026-06-17 — Claude Code [§W2 Watch Mode: Git Activity Engine + CI Outcome Correlator]

**Branch:** main

### Done
- **§W2 — Watch Mode Git Activity Engine + CI Outcome Correlator — shipped:** 8 new files implementing GitHub GraphQL commit fetch + GitHub Actions REST CI run fetch + per-engineer correlation of daily token spend (§W1) to CI outcomes via commit SHA. Output is `EngineerCorrelation` per engineer — the shape §W3 (failure signals + alerts) and §W4 (dashboard) consume.
  - `lib/services/watch/git_activity_provider.dart` — `GitActivityProvider` abstract + `GitCommit`/`EngineerGitActivity` `@immutable` models
  - `lib/services/watch/providers/github_git_provider.dart` — GitHub GraphQL impl; `fetchCommits` per-repo `Future.wait` parallel (query `repository.defaultBranchRef.target.history.nodes`), `fetchMergedPRCount` (query `pullRequests(states: MERGED)` filtered by author.login); module-level `isAgentCommit()` heuristic scans commit message for Claude/Copilot/OpenHands/🤖/[ai]/[claude] markers; defensive parse (statusCode != 200 → empty, FormatException + TypeError → empty)
  - `lib/services/watch/ci_outcome_provider.dart` — `CIOutcomeProvider` abstract + `CIRun`/`CIOutcome` enum (pass/fail/timeout)
  - `lib/services/watch/providers/github_ci_provider.dart` — GitHub Actions REST impl; `fetchRuns` per-repo `Future.wait` parallel; `conclusion` mapping (`success`→pass, `failure`→fail, `timed_out`→timeout, cancelled/skipped/neutral → skip entirely); per-repo failure isolation
  - `lib/services/watch/ci_correlator.dart` — `CICorrelator.correlate()` joins §W1 `EngineerUsage` + `GitCommit` list + `CIRun` list; builds per-engineer per-day `DailyCorrelation` (`tokenPerPass`, `tokenPerFail`, `passRate`); rolling 7d/30d `tokenToFailRatio`; commit-timestamp-proxy limitation documented at top of file (v1 uses commit date = token date; upgrade path to time-window when session-level data exists)
  - `lib/services/watch/git_activity_service.dart` — `fetchCorrelations()` parallel-fetches git+CI via `Future.wait`, correlates via `CICorrelator`, enriches per-engineer PR counts (one extra GraphQL call per engineer, default 0 on failure); `isConfigured` guard
  - `lib/features/settings/github_config_notifier.dart` — `GitHubConfig` + `GitHubEngineerMapping` + `AsyncNotifier` persisting to `forge_config.json` key `watch_github_config`; `isConfigured` getter (`token.isNotEmpty && org.isNotEmpty && repos.isNotEmpty`)
  - `lib/services/watch/git_activity_service_provider.dart` — `Provider<GitActivityService?>` watching `githubConfigProvider` + `engineerRosterProvider`, nullable when unconfigured
- **Committed:** `feat(§W2): git activity engine + CI outcome correlator — GitHub GraphQL + Actions REST + commit-timestamp-proxy correlation` (8 files, 843 insertions)

### Key Technical Findings
- **Commit-timestamp proxy for correlation:** The Anthropic usage API returns daily aggregates (`aggregation_key.date`), not sub-hour session timestamps. The SuperSpec's 4-hour lookback window correlation isn't possible at v1 resolution. v1 correlates an engineer's daily token spend to CI runs triggered by their commits on the same calendar day. The upgrade path (time-window query) is documented in `ci_correlator.dart` — when daily-granularity session data becomes available via a proxy/sidecar or richer provider API, replace the date-equality check with a ±4h window query.
- **Agent attribution is a commit-message heuristic, not a git-trailer parse:** `isAgentCommit()` scans for `co-authored-by: claude`, `co-authored-by: github copilot`, `generated with claude code`, `generated by claude`, `authored by openhands`, the 🤖 emoji, `[ai]`, `[claude]` tags (all case-insensitive). Imperfect — some AI commits won't match, some human commits might (rare). Cheap to compute, upgradeable to git-trailer parsing or `.author` email heuristics later.
- **CI conclusion mapping skips non-failures:** `success`→pass, `failure`→fail, `timed_out`→timeout, everything else (`cancelled`, `skipped`, `neutral`) is skipped entirely — not counted as fails. Counting cancelled runs as fails would inflate the token-to-fail ratio and make high-cancellation repos look worse than they are.
- **`GitHubConfig.isConfigured` is the single guard:** `token.isNotEmpty && org.isNotEmpty && repos.isNotEmpty`. Used in the service, the provider, and anywhere else that needs to gate on "is GitHub wired up." Repeating the inline check would drift if the definition changes.
- **Per-repo/per-engineer error isolation throughout:** `Future.wait` + catch → empty list / 0, never crashes the batch. One bad repo (404, permissions) doesn't poison the rest. Same pattern as §W1 `fetchAllUsage()`.
- **PR count enrichment is supplementary:** one extra GraphQL call per engineer after correlation, default 0 on any failure. Keeps the main fetch+correlate path fast; PRs aren't load-bearing for §W3 signals (those use commits + CI runs, not PR counts).
- **Config file reuse:** `GitHubConfigNotifier` writes to the same `forge_config.json` as `SettingsNotifier` and `EngineerRosterNotifier`, under a new key `watch_github_config`. Three concerns, one file — matches the established pattern. No new database table.
- **Import path bug caught by analyzer:** three files (`ci_correlator.dart`, `git_activity_service.dart`, `git_activity_service_provider.dart`) initially imported `github_config_notifier.dart` as a relative path from `lib/services/watch/`, but the file lives in `lib/features/settings/`. The analyzer caught it immediately. Fix: `../../features/settings/github_config_notifier.dart`. Lesson: when a file is in a different feature directory, the relative import path must cross the `lib/` boundary correctly.

### Next
- §W3 — Watch Mode: Failure Signal Engine + Alert Engine (next on critical path; requires §W2 ✅)
- Manual smoke test: configure `GitHubConfig` with a real org/repos/token + engineer mappings, call `GitActivityService.fetchCorrelations()` with §W1 demo usage, verify `EngineerCorrelation` list returns with correct `DailyCorrelation` entries (tokenSpend from §W1, ciPasses/ciFails from §W2)

### Modified
- `lib/services/watch/git_activity_provider.dart` — NEW
- `lib/services/watch/providers/github_git_provider.dart` — NEW
- `lib/services/watch/ci_outcome_provider.dart` — NEW
- `lib/services/watch/providers/github_ci_provider.dart` — NEW
- `lib/services/watch/ci_correlator.dart` — NEW
- `lib/services/watch/git_activity_service.dart` — NEW
- `lib/features/settings/github_config_notifier.dart` — NEW
- `lib/services/watch/git_activity_service_provider.dart` — NEW
- `tracking md files/context.md` — this block
- `tracking md files/planner.md` — §W2 COMPLETE block + §W3 next-up
- `tracking md files/backlog.md` — §W2 ✅ in critical path + status line + Completed section
- `operations md files/CONFIGURATION_MANAGEMENT.md` — inventory + changelog
- `DOCS/Coding Lessons/FOR_MARC_watch-mode-git-ci-correlation.md` — NEW

---

## Session: 2026-06-17 — Claude Code [§W1 Watch Mode: Token Ingestion Engine]

**Branch:** main

### Done
- **§W1 — Watch Mode Token Ingestion Engine — shipped:** 9 new files implementing the abstract `UsageProvider` layer + 4 provider implementations + demo profiles + engineer roster. This is the foundation data source for all Watch Mode signals (§W2–§W6 consume `EngineerUsage` only, never a provider directly).
  - `lib/services/watch/usage_provider.dart` — `UsageProvider` abstract + `EngineerUsage`/`DailyUsage` `@immutable` models
  - `lib/services/watch/providers/anthropic_usage_provider.dart` — HTTP GET `api.anthropic.com/v1/usage` with `start_date`/`end_date` query; blended $9/MTok (`$0.000009/token`); defensive parse catches `FormatException` + `TypeError` → returns empty `EngineerUsage` with `['api_error']` flag (never crashes)
  - `lib/services/watch/providers/openai_usage_provider.dart` — HTTP GET `api.openai.com/v1/usage?date=YYYY-MM-DD` per day in lookback window, `Future.wait` parallel; blended $5/MTok; same defensive parse pattern
  - `lib/services/watch/providers/gemini_usage_provider.dart` — stub returning `['api_unsupported']` (no reliable per-engineer usage API exists as of 2026; keeps code path alive without crashing)
  - `lib/services/watch/providers/ollama_usage_provider.dart` — stub returning `['local_model_unsupported']` (local models have no central usage API; proxy/sidecar out of scope for v1)
  - `lib/services/watch/demo_usage_provider.dart` — 4 synthetic profiles (runaway 9×=$135/day, ghost 0.1×=$1.50/day, highperformer 1.5×=$22.50/day, self 1.0×=$15/day); `Random(42)` fixed seed = deterministic output every run; ±20% variance per day; alert flags: `spend_threshold` when 30d total >$200, `runaway_session` when any day >$100; `sessionCount = dailyBreakdown.length`
  - `lib/services/watch/usage_service.dart` — `UsageService.fetchAllUsage()` iterates roster, resolves each entry to a provider via `switch` on `providerType`, isolates failures to a `fetch_error` `EngineerUsage` (never crashes the whole batch)
  - `lib/features/settings/engineer_roster_notifier.dart` — `EngineerRosterEntry` model (handle/providerType/apiKey/alertThreshold) + `AsyncNotifier` persisting to `forge_config.json` under key `watch_engineer_roster`; mirrors `SettingsNotifier`'s read/write pattern exactly; default `demo` entry auto-present on first launch so app never shows empty state before configuration
  - `lib/services/watch/usage_service_provider.dart` — `Provider<UsageService?>` watching `engineerRosterProvider`; nullable so consumers can gate on loading state
- **Committed:** `feat(§W1): token ingestion engine — UsageProvider layer + 4 providers + demo profiles + engineer roster` (9 files, 516 insertions)

### Key Technical Findings
- **Interface segregation:** `UsageProvider` is the single abstract surface; §W2–§W6 never touch a provider directly — they consume the normalized `EngineerUsage` shape only. Same pattern as `LlmProvider` → `LlmService` in §4. Keeps provider swap-cost at zero.
- **Error isolation over propagation:** `UsageService.fetchAllUsage()` catches per-entry failures and returns an `EngineerUsage` with `alertFlags: ['fetch_error']` rather than throwing. One bad API key doesn't poison the whole batch — the dashboard can still render the other engineers. This is the right default for a telemetry ingestion layer (vs. a request-response layer where you want the error to surface).
- **Defensive parse pattern for LLM-billable APIs:** HTTP usage APIs are inconsistent and under-documented. The Anthropic response shape (`data[].aggregation_key.date` + `input_tokens` + `output_tokens`) is approximate; the OpenAI shape (`data[].aggregation_timestamp` as Unix epoch + `n_context_tokens_total` + `n_generated_tokens_total`) differs. Both providers catch `FormatException` + `TypeError` and fall back to an `api_error` flag rather than crashing — models for these APIs will shift, and the parser must not be brittle.
- **OpenAI `/v1/usage` takes a single `date`, not a range:** Unlike Anthropic's `start_date`/`end_date`, the OpenAI endpoint requires one `date` per call. Implementation loops over each day in the lookback window with `Future.wait` for parallelism. This is a real API constraint, not a design choice.
- **Config-file reuse:** `EngineerRosterNotifier` writes to the same `forge_config.json` as `SettingsNotifier` under a new top-level key (`watch_engineer_roster`). One file, multiple concerns — matches the existing settings storage pattern. No new database table, no SharedPreferences for roster data (secrets stay in the same file as API keys for settings, by the existing convention).
- **Default-entry-on-first-launch pattern:** `build()` returns `[_defaultEntry]` (handle=`demo`, providerType=`demo`, alertThreshold=200.0) when the config key is missing or empty. The app never shows an empty state before configuration — demo data is always available. This is the same "ship with synthetic data" principle as the 4 demo profiles themselves.
- **`Random(42)` determinism is a feature, not a hack:** Same seed → same sequence → same 30-day breakdown every run. Demo dashboards (§W4) will render identical charts across launches, which is what you want for screenshots, demos, and regression tests. Changing the seed would change the output — the seed is part of the contract.

### Next
- §W2 — Watch Mode: Git Activity Engine + CI Outcome Correlator (next on critical path; requires §W1 ✅)
- Manual smoke test: instantiate `UsageService` with the default demo roster, call `fetchAllUsage()`, verify 4 `EngineerUsage` entries return with correct alert flags (runaway should trigger both `spend_threshold` and `runaway_session`; ghost should trigger neither)

### Modified
- `lib/services/watch/usage_provider.dart` — NEW
- `lib/services/watch/providers/anthropic_usage_provider.dart` — NEW
- `lib/services/watch/providers/openai_usage_provider.dart` — NEW
- `lib/services/watch/providers/gemini_usage_provider.dart` — NEW
- `lib/services/watch/providers/ollama_usage_provider.dart` — NEW
- `lib/services/watch/demo_usage_provider.dart` — NEW
- `lib/services/watch/usage_service.dart` — NEW
- `lib/features/settings/engineer_roster_notifier.dart` — NEW
- `lib/services/watch/usage_service_provider.dart` — NEW
- `tracking md files/context.md` — this block
- `tracking md files/planner.md` — §W1 COMPLETE block + §W2 next-up
- `tracking md files/backlog.md` — §W1 ✅ in critical path + status line + Completed section
- `operations md files/CONFIGURATION_MANAGEMENT.md` — inventory + changelog

---

## Session: 2026-06-17 — Claude Code [§FM1 Implementation + UX Iteration + Merge]

**Branch:** main (merged from `wt/feature-mode`)

### Done
- **§FM1 — Feature Interview Mode — COMPLETE:** V2+ interviews implemented and merged. 10 files, 1097 insertions. Full feature working on Forkit (v1_worksheet_complete → Start V2 Interview → V2 funnel with V1 context).
- **Core architecture:** `InterviewArgs.priorSpecVersion` → `InterviewNotifier.build()` loads prior spec + V2 seeds from disk → `_featureInterviewSystemPrompt` (present-first L1, scope enforcement referencing V1 goal, L2 from V2 seeds, incremental L4)
- **Interview screen UX:** `_V1BuiltHeader` (dark green panel, goal + chips); "V2 FUNNEL" label on layer strip; "Generate V2 Spec" button label; `targetSpecVersion` threaded through to `SpecGenerationScreen` → `spec_notifier` → `worksheet_notifier`
- **Version-aware phase strings:** `_stageOf`/`_versionOf`/`_nextVersion` helpers replace all hardcoded `v1_*` checks throughout project_detail_screen; `spec_notifier` writes `${specVersion}_spec_locked`; `worksheet_notifier` writes `${specVersion}_worksheet_complete`
- **Project detail screen UX (iterated):**
  - Removed BUILD INTERVIEW badge (redundant with V2+)
  - V1 SHIPPED integrated INTO `_PhaseTimeline` dot: checkmark stays, "V1 SHIPPED" replaces "Interview" label, chips + "Interview L1-L4" row below timeline row (not inside it — key fix for connector alignment)
  - Collapsed strip for prior versions: V1 ✓ pills appear when V2+ ships; latest version chips always expanded
  - `_allComponents: Map<String, List<String>>` loads component map from each completed version's spec async on initState
  - **BUG fixed mid-session:** Chips inside Interview Column (inside timeline Row) made the column ~350px wide, breaking connector alignment. Fix: moved chips + pills + Interview+L1-L4 to a `Column` below the timeline `Row`.
- **Projects list:** Goal statement between project name and phase row; loaded async from locked spec per project row; omitted when no spec exists
- **Project detail AppBar:** Goal statement as subtitle under project name; loaded async from locked spec; maxLines: 1, truncated
- **`readFeatureContext()`** added to `ProjectFileRepository` — reads prior spec + V2Seeds.md, returns formatted context block for the feature prompt
- **`nextSpecVersion()` public helper** — `v1 → v2`, `v2 → v3` etc; used in interview notifier + interview screen
- **Worktree `wt/feature-mode` merged → main → pushed to origin**

### Key Technical Findings
- Chips and wide widgets must NOT live inside a Column that is itself inside a horizontal timeline Row — they make the column wide, shifting the connector far from the dot. Always render timeline-adjacent detail in a separate Column below the Row.
- `_VersionHistoryLane` (separate panel approach) was wrong UX — integrating version history INTO the timeline step is cleaner than a floating panel above it.
- Goal statement parsing: look for `## \d*\.?\s*(Immutable )?Goal Statement` heading, take first non-empty non-heading line. Component map: look for `## \d*\.?\s*Component\s+(Map|List)`, parse first column of table rows past the separator.
- `ConsumerWidget → ConsumerStatefulWidget` conversion: all widget fields become `widget.field` in state; `ref` is still available; callbacks like `onRename` need `widget.onRename()` not direct call.

### Next
- §W1: Watch Mode Token Ingestion Engine (next on critical path)
- Or: continue testing V2 interview end-to-end (generate V2 spec, verify v2_spec_locked phase, Start V3 button appears)

### Modified
- `lib/data/filesystem/project_file_repository.dart` — `readFeatureContext()`
- `lib/features/interview/providers/interview_providers.dart` — `priorSpecVersion` on `InterviewArgs`
- `lib/features/interview/state/interview_notifier.dart` — feature prompt + helpers + scope guard
- `lib/features/interview/state/interview_state.dart` — `featureContext` field
- `lib/features/interview/ui/interview_screen.dart` — `_V1BuiltHeader`, V2 FUNNEL label, targetSpecVersion
- `lib/features/projects/screens/project_detail_screen.dart` — major rewrite of `_PhaseTimeline` + helpers + AppBar title + projects list goal
- `lib/features/projects/screens/projects_list_screen.dart` — goal text in project rows
- `lib/features/spec_generation/spec_generation_screen.dart` — `targetSpecVersion` param
- `lib/features/spec_generation/spec_notifier.dart` — version-aware phase strings
- `lib/features/spec_generation/worksheet_notifier.dart` — version-aware phase string
- `tracking md files/context.md` — this block

---

## Session: 2026-06-13 — Claude Code [§FM1 Plan + UX Polish + Bug Fixes + Sidebar Fix]

**Branch:** main

### Done
- **§FM1 plan written:** `DOCS/forge/feature_mode_executor_plan_v1.md` — full 9-file executor prompt for DeepSeek V4 Pro. Feature Interview mode lets a completed V1 project run V2, V3, … interviews against the same folder with the prior spec and V2 seeds injected into the system prompt. Worktree `wt/feature-mode` created, ready for implementation.
- **BUG-INTERVIEW-001 (layerComplete gate):** Flutter side is now authoritative for layer advancement. Models copied the hardcoded `false` in the system prompt literally — layerComplete was never true. Fix: advance when Flutter's own gate conditions pass, ignore `parse.layerComplete`.
- **BUG-INTERVIEW-002 (specGenEnabled gate):** `specGenEnabled` was also gated on `parse.layerComplete`. Simplified to `allResolved && newConflicts.isEmpty`.
- **BUG-INTERVIEW-003 (forge-state regex):** Lenient regex now handles trailing whitespace before closing fence — was causing `parseDegraded` every turn.
- **Interview loop fix:** Three root causes — (1) LLM received only the current message, not full history; every turn it saw `extracted={outcome:null}` and re-asked L1. Now all prior turns are prepended. (2) `parseDegraded` froze state instead of falling back to stub + `_layerFromConfidence`. (3) `llmUnavailable` stuck true after one failure; now resets on each successful call.
- **Bugtracker:** BUG-INTERVIEW-001/002/003 records filed; `BUG_PREVENTION.md` updated.
- **UX — generation screens:** `generation_widgets.dart` NEW (`GenerationPhaseBar` with amber-pulse on current step, `ArtifactInfoCard`, `TipRotator` with 5s crossfade, 6–7 tips each); `spec_generation_screen.dart` + `worksheet_generation_screen.dart` both updated with phase bar, artifact cards, rotating tip strip in generating state.
- **Sidebar fix:** `writeHandoffPackage` was writing to project root (invisible). Now writes to `handoffs/`. `ingested/` folder added to sidebar so V2Seeds.md and reference_context.md are visible.

### Key Technical Findings
- Flutter-side authority over LLM-side flags: when a model is given a hardcoded example value (`layerComplete: false`) in a system prompt, it will often reproduce it literally every turn — never setting true. Gate logic for state advancement must live in Flutter, not be delegated to the LLM's JSON output.
- Full conversation history must be passed every turn for stateless LLM calls. Without it, every turn looks like the first turn to the model.
- `parseDegraded` must degrade gracefully — fall back to stub inference + derive state from what's resolvable — never freeze.

### Next
- §FM1 implementation in `wt/feature-mode` — 9 files, DeepSeek V4 Pro

### Modified
- `lib/features/interview/state/interview_notifier.dart` — loop fix (3), gate fix (BUG-001/002/003)
- `lib/features/spec_generation/generation_widgets.dart` — NEW
- `lib/features/spec_generation/spec_generation_screen.dart` — phase bar + artifact cards
- `lib/features/spec_generation/worksheet_generation_screen.dart` — phase bar + cards
- `lib/data/filesystem/project_file_repository.dart` — writeHandoffPackage path fix
- `lib/features/projects/screens/project_detail_screen.dart` — ingested/ sidebar folder
- `bugtracker/bug_tracker.md` — BUG-INTERVIEW-001/002/003
- `bugtracker/records/BUG-INTERVIEW-001-layercomplete-gate.md` — NEW
- `bugtracker/records/BUG-INTERVIEW-002-specgen-layercomplete.md` — NEW
- `bugtracker/records/BUG-INTERVIEW-003-forgestate-regex.md` — NEW
- `bugtracker/BUG_PREVENTION.md` — interview gate + history rules added
- `DOCS/forge/feature_mode_executor_plan_v1.md` — NEW
- `tracking md files/context.md` — this block

---

## Session: 2026-06-12 — DeepSeek/Claude Code [§UI1 Layer Sub-Timeline]

**Branch:** main (merged from `wt/layer-timeline`)

### Done
- **§UI1 — project detail sub-timeline:** Stacked L1–L4 dot row added under the Interview step in `_PhaseTimeline` on `project_detail_screen.dart`. Dots: gray (future), amber-pulse (current), green (done). Connected by a thin vertical line; connector alignment fixed post-merge. Layer state persists across navigation via `currentLayer` in `InterviewState`.
- **§UI1 — interview screen funnel strip:** Compact FUNNEL strip (L1 Outcome → L2 Decomposition → L3 PoC → L4 Critical Path) added above the confidence meter in `interview_screen.dart`. Matching dot style. Build mode only; Audit interviews unchanged.
- **Plan doc:** `DOCS/forge/layer_timeline_executor_plan_v1.md` NEW.

### Key Technical Findings
- The `currentLayer` field on `InterviewState` (added in §IF1) is the single source of truth for which dot is lit. Both the project detail sub-row and the interview screen funnel strip read from the same provider — no separate state needed.
- Connector alignment: the vertical line between dots is a `Container` inside a `Column`; must be wrapped in a sized box to prevent overflow when dot sizes differ.

### Next
- Bug fixes for IF1 gate issues (resolved in same day — see session above)

### Modified
- `lib/features/projects/screens/project_detail_screen.dart` — L1–L4 sub-row in `_PhaseTimeline`
- `lib/features/interview/ui/interview_screen.dart` — FUNNEL strip (163 insertions)
- `DOCS/forge/layer_timeline_executor_plan_v1.md` — NEW
- `tracking md files/context.md` — this block

---

## Session: 2026-06-11/12 — DeepSeek [§IF1 Interview Funnel Redesign — Implementation]

**Branch:** main (merged from `wt/interview-funnel`)

### Done
- **§IF1 implemented:** Converted Build Interview from flat 8-dimension list to 4-layer deductive funnel (L1 Outcome → L2 Decomposition → L3 PoC reduction → L4 Critical Path). The 8 dimensions survive as spec invariants; confidence resolution is now content-driven, not stub-driven.
- **`interview_dimension.dart`** NEW — `LayerDef` data class + `buildLayers` (L1–L4 definitions with exit conditions).
- **`interview_state.dart`** — added `currentLayer` (`LayerDef`), `extracted` (`Map<String, dynamic>` cumulative map), `parseDegraded` (`bool`) fields and `copyWith` updates.
- **`interview_notifier.dart`** — full Build system prompt rewritten to 4-layer funnel with forge-state JSON contract; `parseForgeState` parser added; stub demoted to LLM-unavailable fallback only (scripted conflict deleted); confidence resolution now content-driven from `extracted` map; v2 seed file written to `ingested/` at L3→L4 transition.
- **`spec_generator.dart`** — funnel data block (layers + extracted map) injected into spec prompt; L3 demo script seeds Completion Criteria.
- **`project_file_repository.dart`** — `writeIngestedFile()` added for V2Seeds.md (and future per-doc files).
- **`workflow_template.md`** — Stage 1A fully rewritten to 4-layer funnel + new invariants (one question per turn, forge-state mandatory every response).
- **parseForgeState fixes:** Catches `TypeError` in addition to `FormatException`; lenient regex for trailing whitespace (fixed post-merge).

### Key Technical Findings
- `parseForgeState` must catch `TypeError` not just `FormatException` — Dart's `json.decode` can succeed on malformed LLM output but subsequent map access throws `TypeError` when a field's type doesn't match the expected shape.
- The `forge-state` fenced block regex must be lenient about whitespace before the closing ` ``` ` — models sometimes emit trailing spaces or newlines that a strict pattern won't match, causing every turn to fall through to `parseDegraded`.
- `writeIngestedFile` is a general-purpose write to `ingested/`; it's not limited to V2Seeds — the same method will serve any future per-doc ingestion artifacts.

### Next
- §UI1: Layer sub-timeline to visualize L1–L4 progress (see session above)

### Modified
- `lib/features/interview/state/interview_dimension.dart` — NEW
- `lib/features/interview/state/interview_notifier.dart` — 493-line delta (system prompt rewrite, forge-state parser, content-driven confidence)
- `lib/features/interview/state/interview_state.dart` — `currentLayer`, `extracted`, `parseDegraded` added
- `lib/features/spec_generation/spec_generator.dart` — funnel data block in spec prompt
- `lib/data/filesystem/project_file_repository.dart` — `writeIngestedFile()`
- `DOCS/forge/workflow_template.md` — Stage 1A rewritten
- `tracking md files/context.md` — this block

---

## Session: 2026-06-11 — Cowork [Interview Funnel Redesign Plan]

**Branch:** main (docs only, no code)

### Done
- **DOCS/forge/The_Forge_InterviewFunnel_Plan_v1.md — NEW:** Planning doc for converting the Build Interview from a flat 8-dimension list into a 4-layer deductive funnel (L1 Outcome → L2 Decomposition → L3 PoC reduction via demo script → L4 Critical Path confirmations + blocker scan). The 8 dimensions survive as spec invariants. Includes revised system prompt draft and a structured-output contract (fenced `forge-state` JSON block per turn) to replace stub-driven confidence resolution.
- **Key finding:** `stubInterviewStep` in `interview_notifier.dart` drives the confidence map by user-turn count and injects a scripted conflict at turn 3 regardless of content — the LLM only supplies chat text. Stub confidence updates merge in even when the LLM call succeeds (lines 177–181). Any interview redesign is cosmetic until resolution is content-driven; the plan's §5 specifies the fix.
- **Inconsistency flagged:** workflow_template.md Stage 1A says max 3 questions per turn; `_interviewSystemPrompt` says exactly one. Plan standardizes on one.

### Next
- Marc marks up The_Forge_InterviewFunnel_Plan_v1.md; open questions in §11 (L2 cap, demo length, seed persistence, v2 funnel variant)
- On approval: execute plan §9 file list (interview_dimension/state/notifier, spec_generator, workflow_template Stage 1A rewrite)

### Modified
- `DOCS/forge/The_Forge_InterviewFunnel_Plan_v1.md` — NEW
- `operations md files/CONFIGURATION_MANAGEMENT.md` — inventory row added
- `tracking md files/context.md` — this block

---

## Session: 2026-06-11 — Claude Code [Open Items + §EX1 Executor Timeline]

**Branch:** main

### Done
- **§DOC E2E code verification:** Confirmed both injection paths are correctly wired — `interview_notifier.dart:162` reads `readIngestedSummary()` from disk each turn and injects as REFERENCE CONTEXT block; `spec_notifier.dart:42` does the same before `buildSpecPrompt()`. Manual UI run still needed to fully confirm end-to-end.
- **FOR_MARC_reference-doc-ingestion.md:** 9-step coding lesson written — disk-as-cache pattern, three roads not taken, per-doc facts file architecture, three post-merge bugs (allowMultiple, InkWell/Material, state race), macOS entitlement pitfall, transferable patterns.
- **forge-mcp/ silenced in .gitignore:** forge-mcp has its own git history and origin remote — kept repos independent, removed `??` noise from parent `git status`.
- **§EX1 Executor Timeline — shipped:** `buildExecutorTimelinePrompt()` added to `spec_generator.dart`; `executor_timeline_notifier.dart` created (AutoDisposeFamilyAsyncNotifier by projectPath — scans handoffs/ on build, loads from disk if found); `_BuildSequenceSection` widget added to `ProjectDetailScreen` behind `phase == v1_worksheet_complete` gate; all 4 states (notGenerated/generating/done/error).
- **§EX1 post-review fixes:** Two lint issues from Gemma left unfixed — `super.key` unused parameter on private widget + import not sorted alphabetically. Both fixed; `dart analyze lib/` → zero issues.
- **Bugtracker updated:** BUG-UI-001 (InkWell/Material macOS) and BUG-UI-002 (IngestionNotifier state race) recorded; BUG_PREVENTION.md updated with macOS InkWell rule and multiple-initState-writers rule.

### Key Technical Findings
- `AutoDisposeFamilyAsyncNotifier<State, Arg>` is the correct base class for autoDispose family providers in Riverpod 2.x — `FamilyAsyncNotifier` without the AutoDispose prefix fails the type bounds check at `AsyncNotifierProvider.autoDispose.family<>`.
- Private widgets (`_Foo`) don't need `super.key` — they're never constructed externally with a key. Always omit `super.key` from private widget constructors to avoid the `unused_element_parameter` warning.
- When an external agent adds an import, it tends to append at the bottom rather than insert alphabetically — always check import ordering lint after agent work.

### Next
- Manual end-to-end test: create project → add reference doc → run interview → generate spec → verify context in both prompts; then test BUILD SEQUENCE generation
- §W1 Watch Mode: Token Ingestion Engine (next on critical path)

### Modified
- `.gitignore` — forge-mcp/ excluded
- `DOCS/Coding Lessons/FOR_MARC_reference-doc-ingestion.md` — NEW
- `DOCS/forge/ex1_executor_timeline_plan.md` — NEW (Gemma handoff, now executed)
- `lib/features/spec_generation/spec_generator.dart` — `buildExecutorTimelinePrompt()` added
- `lib/features/spec_generation/executor_timeline_notifier.dart` — NEW
- `lib/features/projects/screens/project_detail_screen.dart` — `_BuildSequenceSection` + import fix
- `bugtracker/bug_tracker.md` — BUG-UI-001, BUG-UI-002 added
- `bugtracker/records/BUG-UI-001-inkwell-material-macos.md` — NEW
- `bugtracker/records/BUG-UI-002-ingestion-state-race.md` — NEW
- `bugtracker/BUG_PREVENTION.md` — macOS InkWell rule + multiple initState writers rule added

---

## Session: 2026-06-10 — Claude Code [§DOC Merge + Post-Merge Bug Fixes]

**Branch:** main (merged from wt/reference-doc-ingestion)

### Done
- **§9.5 committed to main:** All uncommitted §9.5 changes committed before worktree rebase. Key: the entitlements file in the worktree was stale (still had `keychain-access-groups`) — committed HEAD was the correct source of truth.
- **Worktree rebase:** `wt/reference-doc-ingestion` rebased onto committed §9.5. 4 merge conflicts resolved manually: `project_file_repository.dart` (kept both `forge/` + `ingested/`), both `.entitlements` files (kept `user-selected.read-only`, dropped `keychain-access-groups`), `project_detail_screen.dart` (took §9.5 two-panel layout, then separately inserted `_ReferenceDocsRow`).
- **§DOC merged to main:** `wt/reference-doc-ingestion` merged into main with all conflicts resolved.
- **Post-merge fix 1 — Multi-file picker:** `reference_docs_screen.dart`: added `allowMultiple: true` to `pickFiles()` call and changed single-file path to loop over `result.files`.
- **Post-merge fix 2 — Material wrapper for InkWell:** `_ReferenceDocsRow` in `project_detail_screen.dart`: wrapped `InkWell` with `Material(color: Colors.transparent)` — macOS Flutter desktop requires an immediate Material ancestor; Scaffold-level Material is NOT sufficient. "Manage →" button was unresponsive without it.
- **Post-merge fix 3 — Redundant loadDocs removed:** `interview_screen.dart` `initState` was calling `loadDocs()` concurrently with in-flight `addDoc` LLM calls — state race on the global `IngestionNotifier`. Removed initState call entirely; interview screen now watches provider passively via `_DocCountChip`.
- **Build error resolved:** `flutter clean && flutter pub get` required after merge added `file_picker` dependency.

### Key Technical Findings
- Git worktrees must be created from a **committed** HEAD. Uncommitted changes on main do not carry into the worktree — they appear as conflicts at merge time. Commit first, then create or rebase the worktree.
- `InkWell` on macOS Flutter desktop requires `Material(color: Colors.transparent)` in its immediate subtree. A `Scaffold` or `Material` higher in the tree is insufficient — ink effects require a local Material ancestor.
- Global non-AutoDispose `Notifier` concurrent state race: do NOT call state-writing methods (e.g., `loadDocs`) from multiple widget `initState` callbacks simultaneously. Two concurrent async writers on one shared state object produce interleaved updates. Watch the provider passively from secondary screens.
- `file_picker` `NSOpenPanel` is silently blocked by macOS sandbox without `com.apple.security.files.user-selected.read-only` in both `.entitlements` files.

### Next
- End-to-end test: create project → add reference doc → run interview → generate spec → verify context injected in both prompts
- Write `FOR_MARC_reference-doc-ingestion.md` coding lesson
- §EX1: Executor Timeline (parse spec §3 Component Map → LLM-narrated build sequence)

### Modified
- `lib/features/projects/ingestion/reference_docs_screen.dart` — multi-file picker
- `lib/features/projects/screens/project_detail_screen.dart` — Material wrapper for InkWell in `_ReferenceDocsRow`
- `lib/features/interview/ui/interview_screen.dart` — removed redundant `loadDocs` from `initState`

---

## Session: 2026-06-09 — Claude Code [Reference Doc Ingestion Engine — §DOC v1]

**Branch:** wt/reference-doc-ingestion (merged to main 2026-06-10)

### Done
- **§DOC-1 — Entitlements + deps + filesystem layer:** Added `file_picker` 8.3.7 to pubspec.yaml; added `com.apple.security.files.user-selected.read-only` to both entitlement files; `createProject()` now creates `/ingested/` subfolder; 4 new methods in `ProjectFileRepository`: `writeIngestedSummary()`, `readIngestedSummary()`, `listReferenceDocs()`, `copyReferenceDoc()`
- **§DOC-2 — Ingestion engine + notifier:** Created `lib/features/projects/ingestion/` with 3 files: `reference_doc.dart` (ReferenceDoc + IngestedFacts model), `ingestion_engine.dart` (LLM prompt builder + output parser), `ingestion_notifier.dart` (project-scoped `IngestionNotifier` with add/remove/rebuildContext pipeline). Ingestion uses architect role at t=0.2 for precision extraction.
- **§DOC-3 — Interview prompt injection:** `_interviewSystemPrompt()` accepts optional `ingestedContext` param; `InterviewNotifier.addUserMessage()` reads from disk via `readIngestedSummary()` each turn; context injected as "REFERENCE CONTEXT" block in system prompt
- **§DOC-4 — Spec generation prompt injection:** `buildSpecPrompt()` accepts optional `ingestedContext` param; `SpecNotifier.generate()` reads from disk before building prompt (same pattern as `readLockedSpec()`); context injected between confidence map and spec structure instructions
- **§DOC-5 — UI:** Created `reference_docs_screen.dart` (full management UI with file picker, doc cards with remove, error/empty/loading states); added `_ReferenceDocsRow` to `project_detail_screen.dart` (count + "Manage →" link); added `_DocCountChip` to interview_screen.dart AppBar (shows `N docs` when >0)
- All 4 amendments applied: text-only (.md/.txt), project-scoped notifier, disk-persisted context, macOS entitlement

### Key Technical Findings
- `file_picker` 8.3.7 resolves as the latest compatible version with Flutter 3.38.7; 11.x requires newer analyzer
- `NSOpenPanel` on macOS sandbox requires `user-selected.read-only` entitlement — without it the file picker dialog is silently blocked. Added to both .entitlements files.
- Persisting ingested context to `reference_context.md` on disk is the right pattern — both the interview notifier (AutoDisposeNotifier) and spec notifier read from disk independently. Same architecture as `readLockedSpec()`.
- `IngestionNotifier` is a vanilla `Notifier` (not `AsyncNotifier`) — all async work happens in public methods, not in `build()`. Matches `ActiveProjectNotifier` pattern.
- The interview chip shows doc count only when >0 — avoids clutter for projects without reference docs. The project detail row always shows (0 or N) with a "Add →" / "Manage →" link.
- Ingestion engine uses `LlmRole.architect` at t=0.2 for precision extraction of definitions, equations, and constraints. The prompt instructs verbatim quoting — no interpretation or inference.

### Next
1. User review: `git diff main..HEAD` in worktree — approve to merge
2. After merge: end-to-end test — create project, add a .md reference doc, run interview, generate spec, verify context appears in both prompts
3. Write `FOR_MARC_reference-doc-ingestion.md` coding lesson

### Modified (all in worktree)
- `pubspec.yaml` — added `file_picker: ^8.0.0`
- `macos/Runner/DebugProfile.entitlements` — added `user-selected.read-only`
- `macos/Runner/Release.entitlements` — added `user-selected.read-only`
- `lib/data/filesystem/project_file_repository.dart` — `/ingested/` folder + 4 new methods
- `lib/features/projects/ingestion/reference_doc.dart` — NEW: model
- `lib/features/projects/ingestion/ingestion_engine.dart` — NEW: LLM prompt + parser
- `lib/features/projects/ingestion/ingestion_notifier.dart` — NEW: project-scoped notifier
- `lib/features/projects/ingestion/reference_docs_screen.dart` — NEW: management UI
- `lib/features/interview/state/interview_notifier.dart` — disk read + prompt injection
- `lib/features/interview/ui/interview_screen.dart` — doc count chip in AppBar
- `lib/features/spec_generation/spec_generator.dart` — optional ingestedContext param
- `lib/features/spec_generation/spec_notifier.dart` — disk read before spec prompt
- `lib/features/projects/screens/project_detail_screen.dart` — Reference Docs row

### Warnings
- `file_picker` 11.x exists but requires newer analyzer — staying on 8.x for Flutter 3.38.7 compatibility
- Binary formats (PDF, DOCX) are explicitly out of scope for v1 — only .md and .txt supported
- Ingestion costs one LLM call per document added — the result is cached to disk and only re-parsed on explicit rebuild
- The `reference_context.md` file aggregates all extracted facts from all docs — adding/removing a doc triggers a full rebuild of this file

---

## Session: 2026-06-05 — Claude Code [Plan Mode v1 — End-to-End Complete + UX Polish]

### Done
- **forge-mcp post-grade fixes**: removed dead variable `sessionsByAgent` in `queryApi.ts`; fixed `percentComplete` math bug (divided by wrong denominator); removed duplicate `deriveContextFiles` in `index.ts`
- **Compressed `forge_mcp_build_plans.md`**: 1,292 lines → ~100 lines; Plans 1–6 replaced with status table (all ✅ Complete)
- **§9.5 Flutter amendment**: `createProject()` now creates `forge/` subdir; `writeForgeFiles()` writes LockedSpec + DecisionContext + OpenFlags to `forge/`; `writeHandoffPackage()` updated to include `projectName`, `components`, `contextFiles`; `spec_notifier.dart` wired to call all new methods
- **macOS build signing**: removed `keychain-access-groups` entitlement (required provisioning profile); fixed 2 Manual → Automatic signing entries in `project.pbxproj`
- **`flutter_secure_storage` → `SharedPreferences`**: sandbox `-34018 errSecMissingEntitlement` error after entitlement removal; replaced API key storage with SharedPreferences throughout `settings_notifier.dart`
- **Settings Save button fix**: `_controller.addListener(() => setState(() {}))` in `_ByokCardState.initState()` — button was always disabled because text was evaluated at build time without listening
- **Gemini model IDs**: fixed `gemini-3.5-flash-preview` → `gemini-3.5-flash` / `gemini-2.5-flash` / `gemini-2.5-pro`; WebFetch confirmed current stable model IDs
- **Back button on spec error screen**: added "Back to Projects" `TextButton` using `popUntil(r.isFirst)`
- **File sidebar**: `project_detail_screen.dart` rewritten as two-panel layout; `_FilesSidebar` (220px) scans all 5 folders (forge/specs/handoffs/worksheets/audit) with amber selection highlighting; `ArtifactViewMode.forge` added to artifact viewer
- **API key gate on New Project**: `new_project_screen.dart` checks architect role's API key; red banner + "Settings →" link + disabled Create button when no key configured
- **Interactive phase timeline**: 3-step timeline (Interview → Worksheet → Ready) with amber pulse animation on current step; green ✓ with click-to-open artifact when done; pending steps gray; `ProjectDetailScreen` watches `projectListProvider` for live phase; `WorksheetGenerationScreen` now sets `v1_worksheet_complete` phase in DB
- **Sidebar auto-refresh**: `RouteObserver` registered in `app.dart`; `_FilesSidebarState` subscribes via `RouteAware.didPopNext()` — sidebar rescans whenever a sub-route is popped
- **CTA button phase-aware**: "Start Interview" → "Generate Setup Worksheet →" → "Ready for executor" green badge based on project phase
- **`vv1` filename bug**: `writeHandoffPackage` had `v$version` where version already included `v` prefix → fixed to `$version`
- **API key persistence via config file**: `settings_notifier.dart` dual-writes to `forge_config.json` in Application Support dir; file is authoritative on next launch; auto-migrates keys from SharedPreferences if found only there
- **First end-to-end Plan Mode test**: Testapp project — interview → spec → worksheet → all artifacts generated and verified; all 5 folders populated correctly

### Key Technical Findings
- macOS sandbox + `keychain-access-groups` entitlement requires a provisioning profile with `$(AppIdentifierPrefix)` — unusable without paid Apple Developer account in dev. Removed entirely; `flutter_secure_storage` was a casualty, replaced with SharedPreferences + config file.
- `NSUserDefaults` (SharedPreferences on macOS) can be cleared during development container resets. Config file in Application Support is more durable.
- `FutureBuilder(future: _scan())` in a `StatefulWidget.build()` creates a new Future every build — correct, but only fires on rebuild. RouteAware subscription needed for cross-route refresh.
- Interview state is `AutoDisposeNotifier` — disposed when navigated away from. If spec generation fails and user presses back, interview state is lost. Noted as backlog item.

### Next
1. Executor timeline: parse spec § 3 Component Map → generate LLM-narrated timeline steps per component (unique per project, shown when phase = `v1_worksheet_complete`)
2. Watch Mode §W1 — Token Ingestion Engine (gate: end-to-end run ✅ now passed)
3. First MCP end-to-end: register Testapp in `~/.forge/registry.json`, test `forge_session_start` + `forge_check_scope` via MCP
4. Backlog: interview state persistence across navigation (survives spec gen failure)

### Modified
- `forge-mcp/src/index.ts`, `forge-mcp/src/lib/queryApi.ts` — post-grade fixes
- `DOCS/forge/forge_mcp_build_plans.md` — compressed to status table
- `lib/data/filesystem/project_file_repository.dart` — §9.5: forge/ dir, writeForgeFiles(), writeHandoffPackage() with projectName; vv1 fix
- `lib/features/spec_generation/spec_generator.dart` — §9.5: parseComponentNames(), buildContextFiles(), buildDecisionContext(), buildOpenFlags(), buildHandoffPackage() fields
- `lib/features/spec_generation/spec_notifier.dart` — §9.5 wiring; projectListProvider.refresh() call
- `lib/features/spec_generation/worksheet_notifier.dart` — v1_worksheet_complete phase update + projectListProvider.refresh()
- `lib/features/spec_generation/spec_generation_screen.dart` — Back to Projects button on error
- `lib/features/settings/settings_notifier.dart` — SharedPreferences + forge_config.json dual-write; correct Gemini model IDs
- `lib/features/settings/settings_screen.dart` — Save button controller listener fix
- `lib/services/llm/llm_model_config.dart` — correct Gemini model IDs and defaults
- `lib/features/artifacts/artifact_viewer_screen.dart` — ArtifactViewMode.forge added
- `lib/features/projects/screens/project_detail_screen.dart` — full rewrite: two-panel layout, _PhaseTimeline, _FilesSidebar with RouteAware, phase-aware CTA
- `lib/features/projects/screens/new_project_screen.dart` — API key gate
- `lib/core/app.dart` — routeObserver added
- `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements` — keychain-access-groups removed
- `macos/Runner.xcodeproj/project.pbxproj` — Manual → Automatic signing

### Warnings
- Testapp HandoffPackage is named `vv1` (old run before fix). New projects will generate `_v1.json` correctly.
- Interview state lost on spec gen failure + back navigation — user must redo interview. Backlog item.
- `flutter_markdown` 0.7.7+1 is discontinued upstream; non-blocking, migrate to `flutter_markdown_plus` when needed.
- Worksheets/handoffs folders are normal write (not write-once) — can be regenerated.

---

## Session: 2026-06-04 — Claude Code [Forge MCP Server — Gap Analysis + 6 Executor Plans]

### Done
- Full repo review: Plan Mode §1–§9 all complete; backlog and context read
- Read all ForkIt example files (5-file system reference implementation)
- Compared Flutter app current output vs MCP server expected input — identified all gaps
- Wrote 6 DeepSeek executor prompts for the MCP server build
- Saved plans to `DOCS/forge/forge_mcp_build_plans.md`

### Key Gap Analysis Findings
- **File 1 path mismatch**: app writes to `specs/`, MCP expects `forge/` subfolder — plans include fallback
- **Files 2 + 5 missing**: app doesn't generate `DecisionContext` or `OpenFlags` as separate files yet
- **HandoffPackage missing fields**: `components` and `contextFiles` not generated by current app
- **HandoffPackage filename**: app writes `handoff_package_v1.json`, MCP expects `{ProjectName}_HandoffPackage_v1.json` — plans include 3-pattern filename resolution
- Plans adapt the MCP server to be forward-compatible (works with target state) AND include graceful fallbacks for current state

### Next
1. Run Plan 1 in DeepSeek → bring back for evaluation
2. Run Plans 2–6 sequentially, each evaluated before next
3. After MCP server is built → §9.5 Flutter app amendment to generate full 5-file system
4. After §9.5 → first end-to-end Plan Mode run (interview → spec → MCP server → executor build)

### Modified
- `DOCS/forge/forge_mcp_build_plans.md` — NEW: 6 DeepSeek executor prompts + gap analysis

### Warnings
- MCP server goes in `forge-mcp/` subfolder inside The Forge repo
- The ForkIt example files represent TARGET state, not current app output — plans bridge the gap
- DeepSeek must be given full context files from previous plan on each subsequent call (append-on, not greenfield)
- `forge_check_scope` uses exact section headings from File 5 (`## Explicit Out-of-Scope`, `## V2 Architecture Seeds`) — do not rename

---

## Session: 2026-06-04 — DeepSeek V4 Pro [Session 2 — §8 Setup Worksheet + §9 Handoff Package + /goal text]

### Done
- `spec_generator.dart` extended — `buildGoalText()`, `buildHandoffPackage()`, `_extractSection()`, `_countTableRows()`, `_countListItems()`
- `spec_notifier.dart` extended — calls `buildGoalText()` + `buildHandoffPackage()` after `writeLockedSpec()`; `specVersion` added to `SpecGenState`
- `project_file_repository.dart` — added `readLockedSpec()` for reading spec from disk
- `worksheet_generator.dart` created — `buildWorksheetPrompt()`, `buildWorksheetAuditEntry()`
- `worksheet_notifier.dart` created — `WorksheetNotifier`, `WorksheetGenState`, `worksheetNotifierProvider`
- `worksheet_generation_screen.dart` created — full UI with idle/generating/done/error states (mirrors SpecGenerationScreen)
- `spec_generation_screen.dart` — done state updated: "Generate Worksheet →" primary button + "Back to Projects" secondary
- `dart analyze lib/` — zero issues
- `grep -ri firebase lib/` — zero matches

### Next
1. First end-to-end Plan Mode run: Project → Interview → Spec → Worksheet → Artifacts
2. Gate opens for Watch Mode (§W1 Token Ingestion Engine)
3. Then: §W2–§W6 → Pull Mode → Configuration C pilot (Qualcomm)

### Modified
- `lib/features/spec_generation/spec_generator.dart` — added §9 builders
- `lib/features/spec_generation/spec_notifier.dart` — wired §9 calls + specVersion
- `lib/data/filesystem/project_file_repository.dart` — added readLockedSpec()
- `lib/features/spec_generation/worksheet_generator.dart` — NEW
- `lib/features/spec_generation/worksheet_notifier.dart` — NEW
- `lib/features/spec_generation/worksheet_generation_screen.dart` — NEW
- `lib/features/spec_generation/spec_generation_screen.dart` — worksheet button

### Warnings
- `_countTableRows` filter checks for `---` and `--` (without dashes) — handles both `|---|` and `---|---|---|` patterns
- Worksheet temperature is 0.3 (procedural) vs spec generation 0.6 (creative)
- `readLockedSpec()` throws if file doesn't exist — WorksheetNotifier catches it via try/catch

---

## Session: 2026-06-04 — DeepSeek V4 Pro [Session 1 — §6 SpecParser + §7 Artifact Viewers complete]

### Done
- `spec_parser.dart` created — strips code fences, trims whitespace from LLM output before writing spec
- Wired `SpecParser.clean()` into `spec_notifier.dart` → LLM raw output is cleaned before `writeLockedSpec()`
- `flutter_markdown` added to `pubspec.yaml`; `flutter pub get` completed
- `artifact_viewer_screen.dart` created — single reusable viewer with `ArtifactViewMode` enum (spec/handoff/worksheet/audit)
- `project_detail_screen.dart` updated — all artifact rows now tappable with folder-aware routing to viewer
- `dart analyze lib/` — zero issues
- `grep -ri firebase lib/` — zero matches

### Next
1. §8 — Setup Worksheet Generation (Stage 3): generate a worksheet from the spec's external services list
2. §9 — Handoff Package + Bullet Handoff + /goal text (Stage 4)
3. After §8+§9 → first end-to-end Plan Mode run → gate opens for Watch Mode

### Modified
- `lib/features/spec_generation/spec_parser.dart` — NEW: SpecParser.clean() strips code fences
- `lib/features/spec_generation/spec_notifier.dart` — wired SpecParser.clean() into generate()
- `lib/features/artifacts/artifact_viewer_screen.dart` — NEW: single reusable artifact viewer
- `lib/features/projects/screens/project_detail_screen.dart` — artifact rows now tappable
- `pubspec.yaml` — added flutter_markdown

### Warnings
- Routes used via `MaterialPageRoute` directly (Navigator.push) rather than named routes — matches existing codebase pattern (project_detail_screen uses same approach for /interview)
- All 4 artifact types (spec/handoff/worksheet/audit) share one `ArtifactViewerScreen` — mode is determined by `_ArtifactEntry.folder`

---

## Session: 2026-06-03 — Platform merge: Vigilint absorbed; SuperSpec v1 filed; Watch + Pull Mode backlog added

### What was done
- **Product merger decision:** Vigilint retired as standalone product name. Its capabilities become Watch Mode within The Forge. Brand rationale in `audit/The_Forge_AuditLog.md` entry 002.
- **SuperSpec filed:** `DOCS/forge/The_Forge_SuperSpec_v1.md` — defines the merged three-mode platform (Plan / Watch / Reverse), 19 modules, 4 activation configurations (A=Plan only, B=Watch only, C=Watch+Reverse, D=Full)
- **Backlog appendation filed:** `DOCS/forge/The_Forge_SuperSpec_Backlog_v1.md` — two backlog items: first-party decision simulation engine (long-term moat), Monte Carlo naming disambiguation
- **Audit log created:** `audit/The_Forge_AuditLog.md` — entry 002 documents merger decision and the open platform flag
- **Backlog updated:** Critical path now shows Plan Mode → Watch Mode (§W1–§W6) → Pull Mode (§R1–§R2) → Qualcomm pilot gate; all 8 new phase specs added
- **Handoff created:** `DOCS/forge/The_Forge_BulletHandoff_v1_PlatformMerge.md` — ready for DeepSeek Flash (next: §6 Spec Generation)

### What does NOT change
- §1–§5 codebase is unchanged. `dart analyze lib/` passing. The existing Interview Engine, LLM Provider Layer, Settings, and Project screens are Plan Mode and continue as-is.
- Next coding work remains §6 Spec Generation — unchanged from before the merge.

### Open flag — resolve before Watch Mode build
SuperSpec draft said Watch/Reverse = web-based. The Forge = Flutter macOS. Recommended: Flutter desktop for all three modes. **Must be confirmed before §W1 starts.** See audit log entry 002.

### Next
1. Resolve the Flutter-vs-web platform flag (user decision)
2. §6 — Spec Generation + Artifact Writing (Plan Mode critical path continues)
3. §7 — Artifact Viewers
4. After §6+§7+§8+§9 complete → first end-to-end Plan Mode run → gate opens for Watch Mode

### Modified
- `DOCS/forge/The_Forge_SuperSpec_v1.md` — new
- `DOCS/forge/The_Forge_SuperSpec_Backlog_v1.md` — new
- `DOCS/forge/The_Forge_BulletHandoff_v1_PlatformMerge.md` — new
- `audit/The_Forge_AuditLog.md` — new (entry 002)
- `tracking md files/backlog.md` — critical path updated, §W1–§W6 and §R1–§R2 added
- `tracking md files/context.md` — this entry

---

## Session: 2026-06-02 — §5 Extension: Dual Interview Mode UI (Build + Audit) (worktree wt/llm-provider-layer)

### What was done
- **Architectural pivot**: replaced the typed `ConfidenceDimension` enum with a generic `DimensionDef` data class (`id`, `label`, `question`). The central change that unlocks both Build and Audit modes. `Map<ConfidenceDimension, DimensionState>` → `Map<String, DimensionState>`, keyed by `DimensionDef.id`. `InterviewState` now carries `List<DimensionDef> dimensions` so every consumer (meter, notifier, system-prompt builder) looks up labels/questions from the active list.
- Created `lib/features/interview/state/interview_dimension.dart` — `DimensionDef` immutable class + `buildDimensions` (8 Build dims) + `auditDimensions` (8 Audit dims) + `dimensionsFor(ProjectMode)` helper
- Rewrote `lib/features/interview/state/interview_state.dart` — removed `ConfidenceDimension` enum and its label/question extension; `ConflictItem` now uses `String dimensionALabel` / `String dimensionBLabel`; `InterviewState` carries `dimensions` list
- Updated `lib/features/interview/providers/interview_providers.dart` — `InterviewArgs` gains `ProjectMode mode`; `==` and `hashCode` updated
- Rewrote `lib/features/interview/state/interview_notifier.dart` — stub now uses `state.dimensions[N-1]` / `state.dimensions[N-2]` (preserves original conflict-offset behavior so turn 4 re-resolves `dim[2]` from partial back to resolved; uniform `N-1` would have left `dim[2]` stuck partial and `specGenEnabled` permanently false — this was the subtle bug I caught and fixed before merge). `build()` uses `dimensionsFor(args.mode)`. `_interviewSystemPrompt` uses dimension lookups from `state.dimensions` and computes the mode label by `state.dimensions == buildDimensions` (works because both lists are const-equal)
- Updated `lib/features/interview/ui/confidence_meter.dart` — new signature `List<DimensionDef>` + `Map<String, DimensionState>`; iterates `dimensions` (not a hardcoded enum); label width bumped 120→140px to fit longer Audit labels (e.g. "Blocker blast radius", "AI & token usage")
- Updated `lib/features/interview/ui/interview_screen.dart` — `InterviewScreen` now takes `InterviewArgs args` directly (was `projectPath` + `projectName`); AppBar shows "Build Interview — {name}" or "Audit Interview — {name}"; `_EmptyChat` uses the live `state.dimensions.length`; `_ConflictSurface` reads `dimensionALabel` / `dimensionBLabel`
- Created `lib/features/projects/screens/new_project_screen.dart` — `ConsumerStatefulWidget`; name input + two `_ModeCard`s (Build / Audit) with amber border + 0x1A amber background when selected, slate border when unselected; "Create" button disabled until name is non-empty; on tap: `repo.createProject(name, mode)` → `db.upsertProject(ProjectsCompanion.insert(...))` → `projectListProvider.notifier.refresh()` → `Navigator.pop()`. `ProjectAlreadyExistsException` surfaces a red SnackBar "A project named '$name' already exists." General exceptions surface "Failed to create project: $e"
- Created `lib/features/projects/screens/project_detail_screen.dart` — `ConsumerWidget` taking `Project project`; mode badge (amber for Build, slate for Audit) + "Phase: v1_interview" line + parsed README sections ("What's Done", "What's Next", "Open Flags") in a bordered card + "Start Build/Audit Interview" FilledButton (amber, full width) → `Navigator.pushNamed('/interview', arguments: InterviewArgs(...))`; artifacts list scans `specs/`, `handoffs/`, `worksheets/` via `Directory.listSync()` in a `FutureBuilder`; Close button calls `activeProjectProvider.notifier.close()` then pops
- Updated `lib/features/projects/screens/projects_list_screen.dart` — removed inline `_ProjectDetailStub` and `_NewProjectStub`; navigation now uses `MaterialPageRoute` to `NewProjectScreen()` and `ProjectDetailScreen(project: ...)`; empty-state copy updated to mention both interview modes
- Updated `lib/core/app.dart` — `/interview` route now passes full `InterviewArgs` to `InterviewScreen(args: args)` (was unpacking into `projectPath`/`projectName`)
- Verified: `dart analyze lib/` → No issues found
- Verified: `grep -rn "ConfidenceDimension" lib/` → zero matches
- Verified: `grep -rn "_ProjectDetailStub\|_NewProjectStub" lib/` → zero matches
- Verified: zero Firebase imports

### Architectural decisions
- **String-keyed map is the central refactor** — once `Map<String, DimensionState>` keyed by dimension ID, every other change (meter iteration, notifier lookups, system prompt, conflict labels) follows naturally. `InterviewState.dimensions` is the single source of truth for what's in the map.
- **`_stubConflictFor(state)` is mode-agnostic** — it reads `state.dimensions[0].label` and `state.dimensions[2].label`, so Build mode gets `corePurpose ↔ identityModel` and Audit mode gets `projectGoal ↔ currentBuildState` from the same function. Description text is generic ("X implies one direction. Y implies another. I recommend the conservative reading for v1…") but follows the Workflow Template pattern verbatim. The original Build-specific "user-account system adds friction" wording is gone — it didn't generalize to Audit.
- **Stub preserves the conflict-offset pattern**: turn 3 surfaces the conflict and marks `dim[2]` partial; turn 4 re-resolves `dim[2]` (because the user just accepted the conflict via the Accept button) and prompts `dim[3]`. Turns 5..9 continue with `dim[N-2]`. This is the same logic as the original §5 stub — the uniform `dim[N-1]` rule in the prompt's spec was too simplistic and would have broken Generate Spec enablement.
- **`InterviewScreen` takes `InterviewArgs` directly** — not just `projectPath` + `projectName`. Adding `mode` to the args signature made the constructor change necessary. Cleaner than three separate fields that have to stay in sync.
- **No LLM-parsed mode label needed** — `state.dimensions == buildDimensions` does a const-equality check on the dimension list, which is O(n) but n=8, so it's effectively free. Cleaner than threading the mode through to the notifier for a single string comparison.
- **Artifacts list includes worksheets too** — the prompt said "specs/, handoffs/ contents" but the project folder structure also creates `worksheets/`, and listing all three gives a more honest view of "what's been generated." Tappable rows are intentionally non-tappable (no viewer yet — that's §7).
- **`ProjectDetailScreen` is a `ConsumerWidget`, not stateful** — it reads `activeProjectProvider` (which is the existing source of truth for README content, loaded by `_ProjectRow.onTap` before navigation). No need to re-load the README on the detail screen.
- **README parsing is local to the detail screen** — `_ReadmeContent._extractSection(content, header)` does a simple `indexOf` + `indexOf('\n## ', ...)` to slice out H2 sections. No markdown parser dependency added; this is sufficient for the README shape that `ProjectFileRepository.createProject` writes.
- **Two `_ModeCard`s, not a dropdown** — the spec called for "two side-by-side (or stacked) cards" and cards give a more honest preview of the mode (you can read the 4 sample dimensions and decide). Side-by-side on wide screens, stacked on narrow — the layout flows naturally with `ListView`.
- **Drift's `insert()` for nullable columns is `Value.absent()` by default** — `ProjectsCompanion.insert(...)` doesn't need explicit `lastOpened: const Value(null)` etc. (I added them initially, then removed; drift handles it.) The existing `project_list_notifier.dart` confirmed this pattern.

### Out of scope (verified — matches prompt's "What is NOT in scope")
- Doc ingestion UI
- Model configuration (Settings §10) — already done
- Resuming a project mid-interview
- Rendering spec/handoff artifacts in a viewer (§7)
- Audit-specific stub conflict text — generic conflict works for both modes

### Open items / next
- §6 Spec Generation (the Generate Spec button — currently SnackBar)
- §7 Artifact Viewers (the project_detail_screen artifacts list is read-only display only)
- §11 Audit Interview Mode — the dimension lists are wired but the `Current State Spec` structure (different from Locked Spec) is a §6/§11 dependency
- End-to-end test: open app → FAB → name "AuditTest" → Audit card → Create → tap row → Start Audit Interview → meter shows 8 Audit dimensions (Project goal, Active blockers, etc.)

---

## Session: 2026-06-02 — §4 Change: Gemini 3.5 Flash as default (worktree wt/llm-provider-layer)

### What was done
- **Bug fix**: `GeminiProvider` was sending `system_instruction` (snake_case) to the Gemini REST API v1beta. The API silently ignores unknown field names, so the system prompt was being dropped. Changed to `systemInstruction` (camelCase) — the field name the API actually reads. Also added explicit `'role': 'user'` to the `contents` entry.
- **Default flip**: `LlmSettings.defaults` now points both Architect and Executor roles to `LlmProviderType.gemini` with modelId `gemini-3.5-flash-preview`.
- **First-run logic**: `SettingsNotifier.build()` no longer falls back to `LlmProviderType.ollama` when no role assignment is saved. New code distinguishes first-run (`providerStr == null`) and uses Gemini as the fallback provider and `gemini-3.5-flash-preview` as the fallback modelId. The `orElse:` in the `firstWhere` also falls back to Gemini (was Ollama).
- **Model catalog**: Added `gemini-3.5-flash-preview` as the first entry in `geminiModels`. Display name: `Gemini 3.5 Flash`.
- **Settings UI reorder**: Provider cards now go Gemini → Claude → OpenAI → Ollama. Gemini card has `isDefault: true`, which appends ` (default)` to the title.
- **Role card always-shows-all**: `availableProviders` changed from a filtered list (only Ollama + providers with saved keys) to `LlmProviderType.values` (all four). Missing keys surface as runtime errors via `LlmService.complete()` — the user sees `Gemini API key not configured. Open Settings.` in the chat bubble rather than the option being hidden.
- Verified: `dart analyze lib/` → No issues found
- Verified: `grep -n "system_instruction"` → no matches (bug fix confirmed)
- Verified: `LlmSettings.defaults` uses `gemini-3.5-flash-preview` for both roles

### Model ID note
Used `gemini-3.5-flash-preview` as the model ID. **Did not verify against https://aistudio.google.com/** — LUMARA Desktop uses `gemini-3-flash-preview` (no `.5`), and the user specified "3.5 Flash". The `.5-flash-preview` string is a best-guess following Google's preview-versioning pattern. If Google rejects the ID at call time, the error will surface in the chat bubble as `Gemini error 404: ...` and the user can pick a working model from the dropdown.

### Ollama is still supported
Ollama card stays in the UI (just last, not first). `OllamaProvider` is untouched. The user can still pick Ollama from any role's provider dropdown; the connection check still runs on mount and on URL save; models still fetch live from `/api/tags`. The only thing that changed is the default.

### Why this matters
- More reliable default: Ollama needs the user to have a local server running; Gemini just needs one API key.
- Out-of-the-box UX: the user pastes one Gemini key and the app works for all 8 interview dimensions + future spec/worksheet generation.
- Bug fix is invisible until the user actually invokes Gemini — but it would have caused every interview response to lose the system prompt (the interviewer would be un-primed, asking generic questions, missing the dimension-tracking scaffolding in the prompt).

### Next
- End-to-end test: open the app, add a Gemini key, run an interview turn, verify the response uses the system prompt (e.g., mentions the project's 8 confidence dimensions).
- §6 Spec Generation (Generate Spec button action)
- Merge worktree → main

---

## Session: 2026-06-02 — §4 LLM Provider Layer + §10 Settings (worktree wt/llm-provider-layer)

### What was done
- Added deps: `http: ^1.2.2`, `flutter_secure_storage: ^9.2.4`, `shared_preferences: ^2.3.3` (resolved to 1.6.0, 9.2.4, 2.5.5)
- Created `lib/services/llm/` — 8 files (provider abstract, model config, service, service provider, 4 provider implementations)
- Created `lib/features/settings/` — 3 files (notifier, providers, screen)
- Modified `lib/features/interview/state/interview_notifier.dart` — replaced stub with `llmService.complete(role: LlmRole.executor, ...)`; kept stub for confidence-map updates (per §5.1 split); added `_interviewSystemPrompt` helper
- Modified `lib/core/app.dart` — added `/settings` named route; renamed `_MissingRouteArgs` → `_MissingInterviewArgs`
- Modified `lib/features/projects/screens/projects_list_screen.dart` — added settings gear icon to AppBar
- Verified: `dart analyze lib/` → No issues found
- Verified: zero Firebase imports (all 4 LLM providers are direct HTTP)

### Architecture decisions
- Two-layer design: `LlmService` resolves `LlmRole → ModelAssignment → LlmProvider`. The notifier (and future spec generator, worksheet generator) never knows which provider is active.
- API keys in `flutter_secure_storage` (macOS Keychain) ONLY. Base URL, role assignments, model IDs in `SharedPreferences`. No key ever written to a `prefs` key.
- `llmServiceProvider` watches `settingsProvider` (via derived `llmSettingsProvider`) — service rebuilds on every settings change. No manual invalidation needed.
- Interview wire-in: real LLM call drives `interviewerTurn.content`; stub still drives `confidenceMap` updates and `newConflicts` until §5.1 prompt engineering parses LLM output. This is the plan's explicit "stub stays for dimension tracking" carve-out.
- Error path: `try/catch` around `llmService.complete` surfaces a clear "Connection error: ... Open Settings" message in the chat bubble. No crash, no silent failure.
- Ollama always available in provider list (no key required). `OllamaProvider.fetchModels` is a static method — `SettingsNotifier.refreshOllama` calls it on `setOllamaBaseUrl` and on demand from the UI.
- Provider constructors are non-`const` (LlmProvider is an abstract class with no const default constructor, so subclasses can't be const).
- Role card is a `ConsumerWidget` (not stateful) — the provider is the source of truth, dropdown changes apply immediately via `setRoleAssignment`. No "Save" button.

### Out of scope (verified)
- No SwarmSpace provider (§13 billing tier)
- No OpenAI-compatible custom base URL in UI
- No model list validation
- No streaming responses (Ollama `stream: false`)
- No LLM-parsed dimension updates (stub counter stays)

### Critical invariants upheld
- API keys never logged or displayed in full — masked as `••••••{last4}` in hintText
- LlmService rebuilt on settings change (Riverpod watch chain)
- Clear error if no model for role (don't crash)
- Ollama always in provider list
- `dart analyze lib/` zero issues
- No build_runner needed (no drift changes)

### Next
- §6 Spec Generation (the "Generate Spec" button action — currently SnackBar)
- §7 Artifact Viewers
- Merge worktree `wt/llm-provider-layer` → `main` after review
- End-to-end test: Settings → add Ollama (or other) → Interview → real LLM response in chat

---

## Session: 2026-06-01 — §5 Build Interview UI + State

### What was done
- Created `lib/features/interview/state/interview_state.dart` — `ConfidenceDimension` enum (8 values, with `.label` and `.question` extensions), `DimensionState` enum (unknown/partial/resolved), `InterviewTurn`, `ConflictItem`, `InterviewState` model (with `.empty()` factory and `copyWith`)
- Created `lib/features/interview/state/interview_notifier.dart` — `FamilyAsyncNotifier<InterviewState, InterviewArgs>` + `stubInterviewStep()` top-level function (turn-based deterministic stub: 9 user messages cycle through the 8 dimensions, surface a `corePurpose ↔ identityModel` conflict on turn 3). Single call site flagged with `// §5 LLM STUB:` comment for §4 swap.
- Created `lib/features/interview/providers/interview_providers.dart` — `InterviewArgs` class (with `==`/`hashCode` for family equality) + `interviewProvider` (`AsyncNotifierProvider.family<InterviewNotifier, InterviewState, InterviewArgs>`)
- Created `lib/features/interview/ui/confidence_meter.dart` — `ConfidenceMeter` widget with 8 horizontal `LinearProgressIndicator` bars; bar fill = 0% unknown / 50% partial / 100% resolved; track color `#1F2937`, state colors gray/amber/green
- Created `lib/features/interview/ui/interview_screen.dart` — `ConsumerStatefulWidget` watching `interviewProvider(args)`; layout: `AppBar` (with restart icon) → `ConfidenceMeter` → optional `_ConflictSurface` (only when `openConflicts.isNotEmpty`) → `Expanded` chat history (`_TurnBubble` per turn) → `_Composer` (text input + send button, disabled while `isLoading`) → `FilledButton.icon` "Generate Spec" (only when `specGenEnabled`, click shows §6 SnackBar)
- Updated `lib/core/app.dart` — added `'/interview'` named route; route builder reads `ModalRoute.settings.arguments`, casts to `InterviewArgs`, falls back to `_MissingRouteArgs` helper screen if args absent
- Verified: `dart analyze lib/` → No issues found
- Verified: zero Firebase imports

### Architectural decisions
- Family provider with `InterviewArgs` (path + name) — one interview state per project; switching projects gets its own state for free
- Stub LLM is a pure top-level function `stubInterviewStep(state, userMessage)` returning a record `({String interviewerText, Map confidenceUpdates, List newConflicts})`. Notifier is the only caller. §4 swap = replace one function call with `await llmProvider.complete(...)` and JSON-parse the result.
- Stub is turn-counter driven (count user turns), not message-content driven — keeps the stub deterministic and the test path short (9 user messages = 8 resolved + 1 surfaced conflict)
- Conflict text follows Workflow Template pattern verbatim: "Your answers on [X] and [Y] pull in opposite directions. [X] implies [consequence]. [Y] implies [consequence]. I recommend [conservative option] for v1 because [reason]. Do you accept this scope?"
- `specGenEnabled` is a stored field on the state, recomputed on every transition (all 8 resolved + 0 open conflicts). Not a getter — explicit state machine field.
- `isLoading` gates the text input, send button, AND conflict Accept button — prevents race conditions where user resolves a conflict during the 400ms stub latency
- Composer is a `SafeArea(top: false)` so the iOS-style home indicator doesn't overlap the input on macOS
- Send button shows a `CircularProgressIndicator` (not a static icon) while `isLoading` — visual feedback that the LLM call is in flight
- Chat bubbles: user right-aligned (`#1F2937`), interviewer left-aligned (`#1C1C1E`); max width 640px; role label "YOU" / "INTERVIEWER" in 10px gray
- Auto-scroll to bottom on new turn via `WidgetsBinding.instance.addPostFrameCallback` — guard with `hasClients` check
- Entry point (button in project list to push `/interview`) deliberately out of scope — user can add in §6, §7, or hot-reload. Route is registered and ready.

### Open items / next
- §4 LLM Provider Layer (replaces the stub)
- §6 Spec Generation (the "Generate Spec" button action)
- Entry-point wiring: project list or detail stub → push `/interview` with `InterviewArgs`

---

## Session: 2026-06-01 — §3 Project Folder Browser

### What was done
- Rewrote `lib/main.dart` to wrap `TheForgeApp` in `ProviderScope`
- Created `lib/core/app.dart` — `TheForgeApp` MaterialApp with dark theme + `ProjectsListScreen` as home
- Created `lib/core/theme/app_theme.dart` — macOS dark theme, Menlo monospace, Forge amber (`#E8A04C`) primary, minimal chrome
- Created `lib/features/projects/screens/projects_list_screen.dart` — `ConsumerWidget` with:
  - `AsyncValue<List<Project>>` states (loading / error+retry / empty / data)
  - List rows showing name, phase, mode, last-opened date
  - `_ModeBadge` chip (amber for Build, slate for Audit)
  - Pull-to-refresh + AppBar refresh icon → `projectListProvider.notifier.refresh()`
  - Tap row → `activeProjectProvider.open(path, repo)` → push `_ProjectDetailStub` reading `activeProjectProvider`
  - FAB → push `_NewProjectStub` placeholder
- Verified: `dart analyze lib/` → No issues found
- Verified: zero Firebase imports

### Architectural decisions
- Inline `_ProjectDetailStub` and `_NewProjectStub` in the list screen file — keeps the §3 file count to 4 per the task scope
- Detail stub reads `activeProjectProvider` and renders the README.md content as monospace text
- `ActiveProjectState` exposes `readmeContent` only — no `error` field — detail stub simply shows `(no README.md found)` when null
- Navigator captured to local before `await` to avoid `use_build_context_synchronously` lint
- Theme: `ColorScheme.dark` with explicit `primary`/`surface`/`onSurface`/`error`; `Card` + `Divider` + `ListTile` themes set for flat dark macOS feel
- `floatingActionButtonTheme` uses primary as background, background as foreground (inverse) for contrast

### Open items / next
- §4 LLM Provider Layer (BYOK + SwarmSpace)
- §10 Settings screen (provider config UI; back-end to read it lives in §4)
- Detail screen will need real resume logic (read README + most recent bullet handoff + locked spec) once §9 lands

---

## Session: 2026-06-01 — Build order strategy + agent registry updates

### What was done
- Scored Minimax M3 on /goal integration task: 5/4/4/5/4 = 4.4 → Rank 1; added to agent registry in `agents md files/agent_scoping.md`
- Added strategic priority block to backlog.md: build order gate (Forge #1 → SwarmSpace Builder #2 → Iterix #3) — every §N on the critical path now explicitly unblocks the full product roadmap
- Bootstrapped Iterix repo at `/Volumes/Marc Working Drive/Development/Iterix/` from Starter Repo scaffold: CLAUDE.md, backlog §1–§9, ARCHITECTURE.md, agents.md, planner.md, context.md, all SOP boilerplate, git init + initial commit

### Key decisions
- Iterix is product #3: built after The Forge (#1) and SwarmSpace Visual Builder (#2)
- The Forge is used to dogfood the spec for SwarmSpace Builder; SwarmSpace Blocks used to build Iterix
- Iterix stack is an explicit open flag — no code until The Forge interview produces the locked spec
- Minimax M3 confirmed Rank 1 for doc-layer / multi-file markdown update tasks

### Next
- §3: Project folder browser screen (Flutter macOS UI, lists projects from `projectListProvider`)

---

## Session: 2026-06-01 — /goal integration updates

### What was done
- Applied /goal integration brief to The Forge workflow documentation
- Added Completion Criteria section to Locked Spec format (Stage 2) in
  both repo workflow_template.md and Obsidian source copy
- Added Stage 4b (/goal text output) to workflow_template.md — format,
  naming convention, and write path defined
- Updated Stage 5 executor handoff checklist — two new required items
- Updated Bullet Handoff format — Completion Criteria met field added
- Updated backlog.md §6 (spec structure +1 item) and §9 (3 outputs, not 2)

### Key decisions
- The /goal text is written to /handoffs/ alongside the Bullet Handoff,
  not as a separate artifact type — same write path, different filename
- Completion Criteria is inserted at position 5 in the spec structure,
  after Interface Contracts and before Static Content Specs
- Bullet Handoff gains "Completion Criteria met" field for v2 interview
  context — executor loop results travel forward through the audit trail

### Next
- §3: Project folder browser screen (Flutter UI)

---

---

## Session: 2026-06-01 — §2 Riverpod Project State Layer

### What was done
- Created `lib/features/projects/providers/project_list_notifier.dart` — `ProjectListNotifier` (AsyncNotifier) scans filesystem via `ProjectFileRepository.scanProjectPaths()`, upserts missing entries into `ForgeDatabase`, returns `getAllProjects()`. `refresh()` method invalidates self and awaits future.
- Created `lib/features/projects/providers/active_project_notifier.dart` — `ActiveProjectNotifier` (Notifier) with `ActiveProjectState` (projectPath, projectName, readmeContent, isLoading). `open()` sets isLoading → reads README.md → populates state. `close()` resets to empty.
- Created `lib/features/projects/providers/providers.dart` — 4 providers: `projectFileRepositoryProvider`, `forgeDatabaseProvider`, `projectListProvider` (AsyncNotifierProvider), `activeProjectProvider` (NotifierProvider).
- Verified: `dart analyze lib/` = zero issues
- Verified: zero Firebase references in lib/

### Architectural decisions
- `ProjectListNotifier` uses `ref.watch()` to pull `projectFileRepositoryProvider` and `forgeDatabaseProvider` — idiomatic Riverpod, avoids constructor injection complexity with `.new` factory
- `ActiveProjectNotifier` is a vanilla `Notifier` (not `AsyncNotifier`) — state transitions are explicit via the `ActiveProjectState` model
- All 4 providers in a single `providers.dart` barrel — not scattered across files

### Next
- §3: Project folder browser screen (Flutter UI — list projects, create new project)

---

## Session: 2026-06-01 — Backlog rewrite from product documentation

### What was done
- Read all product docs in Obsidian: Agent Workflow Template v3.0, Positioning Brief v4.0, Locked Spec (ForkIt v1.1), Setup Worksheet (ForkIt v1), Bullet Handoff (ForkIt v1 Interview)
- Rewrote `tracking md files/backlog.md` from 11 items → 16 items, grounded in actual product stages
- Removed all stale Firestore/Firebase Function references from §2–§9
- Reordered critical path: project folder browser now precedes interview (was reversed)
- Added missing items: §2 Riverpod state layer, §4 LLM provider layer (BYOK + SwarmSpace), §9 Handoff Package + Bullet Handoff generation, §10 Settings screen + BYOK Keychain storage, §14 Monte Carlo spec generation (separated from single-call §6)
- Each backlog item now references the Workflow Template stage it maps to and the ForkIt worked example as ground truth for correct output
- Corrected agent review scoring: DeepSeek v4 Pro scored 4.6/5 (not 4.4) — `← Edit` in DeepSeek UI shows old content, not new; DeepSeek had correctly removed flutter_lints
- Registered DeepSeek v4 Pro in `agents md files/agent_scoping.md` as Rank 1 Executor

### Key decisions
- Monte Carlo spec generation (3 parallel LLM calls at t=0.2/0.6/1.0) is §14, not part of §6 — single-call spec gen ships first
- §4 LLM provider layer is the pivot point for the entire app: all LLM calls route through one interface regardless of provider
- Worked examples (ForkIt spec, worksheet, handoff) are named as reference outputs in each backlog item for future executor prompts

### Next
- §2: Riverpod project state layer — `ProjectListNotifier` + `ActiveProjectNotifier`

---

## Session: 2026-05-31 — §1 Review + Codegen complete

### What was done
- Reviewed DeepSeek v4 Pro's §1 output — scored 4.6/5 → Rank 1 Executor
- Correction: `← Edit` format in DeepSeek UI shows OLD content; DeepSeek correctly removed `flutter_lints` + `cupertino_icons` in the pubspec edit (no dead dep, score revised upward)
- Fixed AOT/build-hook incompatibility: `objective_c 9.4.1` (transitive via path_provider on macOS) has a native build hook that blocks `dart compile aot-snapshot` in Dart 3.10.7 + build_runner 2.15.0. Solution: `--force-jit` flag
- Ran `dart run build_runner build --force-jit` → `forge_database.g.dart` generated, 10 outputs written in 8s
- `dart analyze lib/` → zero issues
- Registered DeepSeek v4 Pro in The Forge's `agents md files/agent_scoping.md`
- Updated backlog.md §1 → ✅ Complete; fixed stale Critical Path ("Firestore schema" → "Local data layer")
- Updated planner.md → §1 marked COMPLETE with --force-jit note

### Key finding
`dart run build_runner build` must always use `--force-jit` in this repo on macOS due to the `objective_c` native build hook. Document this in any future executor prompts for The Forge.

### Next
- §2: Build Interview — Flutter UI + State (Riverpod providers for project list + active project; interview screen scaffold)

---

## Session: 2026-05-31 — §1 Flutter Bootstrap + Local Data Layer

### What was done
- Ran `flutter create . --project-name the_forge --org ai.orbitalai` — Flutter 3.38.7, Dart 3.10.7
- Replaced pubspec.yaml dependencies: flutter_riverpod 2.6.1, riverpod 2.6.1, path_provider 2.1.5, path 1.9.0, uuid 4.5.1, drift 2.22.0, drift_flutter 0.2.1, build_runner 2.4.13, drift_dev 2.22.0
- Created `lib/data/local_db/forge_database.dart` — drift schema with Projects table (8 columns) + 4 method contracts (getAllProjects, upsertProject, removeProject, getProjectById)
- Created `lib/data/filesystem/project_file_repository.dart` — 8 method contracts including write-once locked spec with atomic temp→rename, append-only audit log, project folder creation with full structure
- Verified: `dart analyze lib/data/filesystem/ lib/main.dart` = zero issues
- Verified: zero Firebase references in pubspec.yaml

### Build-time requirements
- `build_runner` must be run before the app compiles: `dart run build_runner build`
- Only `forge_database.dart` needs codegen — the g.dart missing error is expected until build_runner runs

### Next
- Run `dart run build_runner build` to generate `forge_database.g.dart`
- §2: Riverpod providers (project list provider, active project provider)

### Warnings / open items
- `forge_database.g.dart` not yet generated — drift codegen must run before full `dart analyze lib/` passes
- analysis_options.yaml replaced flutter_lints with explicit rule set (flutter_lints was removed as dev_dependency)

---

## Session: 2026-05-31 — Repo bootstrap

### What was done
- Created The Forge repo at `/Volumes/Marc Working Drive/Development/The Forge/` from Starter Repo
- Wrote `claude.md` (Forge-specific SOPs, invariants, conditional triggers)
- Wrote `agents md files/agents.md` (architecture, subsystems, Firestore schema, data flow)
- Wrote `tracking md files/ARCHITECTURE.md` (full system architecture)
- Wrote `tracking md files/backlog.md` (§1–§11, prioritized, critical path defined)
- Wrote `backend.md` (Firebase + SwarmSpace reference)
- Wrote `tracking md files/FEATURES.md`, `UI_UX.md`, `CHANGELOG.md`, `planner.md`
- Copied all Starter Repo agent SOPs and bugtracker files
- Copied The Forge protocol docs (workflow_template.md, positioning_brief.md) into `DOCS/forge/`
- Initialized git and pushed to `https://github.com/marcyap29/theforge.git`

### Next
- Start §1: Firestore schema + `forge_project_repository.dart`
- Start Flutter project scaffold (`flutter create`)

### Warnings / open items
- Flutter project not yet created — repo is docs + config only at this stage
- Firebase project `arc-epi` shared with LUMARA + SwarmSpace — no new Firebase project needed
- SwarmSpace spec gen function does not exist yet — will need to add route to swarmspaceRouter or create standalone `generateSpec` function
