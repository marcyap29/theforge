# The Forge — Feature Catalog

**Last Updated:** 2026-10-09 (v0.5.35)

---

## Spec / Interview Pipeline

> **Note (v0.5.34):** The original interview → spec → worksheet → handoff pipeline was shipped (v0.4.x) and subsequently removed. Build-with-AI is faster and better; the full pipeline added friction without adding value for the vibecoder user. Items below reflect final status.

| Feature | Status | Notes |
|---|---|---|
| Build Interview (8-dimension confidence model) | Removed v0.5.34 | Was shipped v0.4.x (`lib/features/interview/**`). Removed — superseded by Build-with-AI |
| Audit Interview (current state spec) | Removed v0.5.34 | Shipped v0.4.x; removed with interview pipeline |
| Locked spec (immutable, versioned) | Removed v0.5.34 | Shipped v0.4.x; removed with interview pipeline |
| Bullet handoff (phase transition summary) | Removed v0.5.34 | Shipped v0.4.x; removed with interview pipeline |
| Setup worksheet (external services checklist) | Removed v0.5.34 | Shipped v0.4.x; removed with interview pipeline |
| Handoff package (JSON, for executor agents) | Removed v0.5.34 | Shipped v0.4.x; removed with interview pipeline |
| Import → Spec (paste/doc → spec gen) | Removed v0.5.34 | Shipped v0.4.x; removed with interview pipeline |
| Artifact viewers (spec, handoff, worksheet, audit log) | Removed v0.5.34 | Shipped v0.4.x as `artifact_viewer_screen.dart`; removed with detail screen |
| Document ingestion (text docs → reference context) | Removed v0.5.34 | Shipped v0.4.x (`lib/features/projects/ingestion/**`); ingestion UI removed |
| Pull Mode / Repo onboarding (Quick/Deep scan) | Removed v0.5.34 | Shipped v0.4.x; `pull_ingestion_*` + `pull_interview_*` removed |
| As-built spec generator | Removed v0.5.34 | Shipped v0.4.x; removed with pull interview |
| Monte Carlo spec generation (3 parallel variants) | Backlog | `§14` — never shipped |
| Workspace + billing ($150/workspace/month) | Backlog | `§13` / `§MB` — not started |
| Audit trail export (versioned, client deliverable) | Backlog | `§16` — not started |
| Open source executor path (tool-agnostic JSON spec) | Backlog | `§15` — not started |

---

## Portfolio Tracker

| Feature | Status | Notes |
|---|---|---|
| Portfolio dashboard | Shipped | Home route `/`; all projects with status, last-opened, digest |
| Feature board (status tracking) | Shipped | Grouped by idea/planned/in_progress/blocked/shipped/archived; providers in `lib/features/tracker/**` |
| Auto-scan features (docs + repo) | Shipped | `FeatureScanner` proposes features from `Forge/` docs and/or a linked repo; import dedups against tracked titles |
| Security Check | Shipped v0.4.47 | `FeatureScanner.securityCheck` — deterministic secret grep + LLM audit → markdown report. AI tools ▾ → Security check |
| "What this app can do" summary | Shipped v0.4.38 | `FeatureScanner.describeCapabilities` — plain-language overview of real current capabilities; cached to `Forge/capability_summary.json` |
| Architect epics + build gate | Shipped v0.4.40 (fix v0.4.51) | `FeatureScanner.architectFeature` decomposes an epic into ordered typed sub-features. Epic/manual items gated for Build; non-epic is sharpened in-place |
| Three-layer Architect guard | Shipped v0.5.32 | Before full decomposition: (1) depth limit (blocks at 2+ levels), (2) complexity heuristic (fast, no tokens), (3) LLM self-assessment (~250 tokens). Only features that pass all three proceed |
| "How to build this" (build advice) | Shipped v0.4.39 | `FeatureScanner.adviseBuild` — scale-aware plan (scope/feasibility/approach/packages/effort/risks/breakdown); `BuildAdviceScreen` |
| Recommend new features (virtual-PM) | Shipped v0.4.28 | `FeatureScanner.recommend` → prioritized new feature/enhancement proposals; lightbulb toolbar action → review sheet → board |
| Refine features (conversational) | Shipped v0.5.8 | Multi-turn AI chat on an existing project; proposes features from natural language; `RefineFeaturesScreen` |
| Architect Mode / Build Mode entry points | Shipped v0.5.15 | AppBar Architect (forum icon) / Build (amber construction icon); per-tile blue 🏛️ / amber ⚡ quick actions; fork card with named modes |
| Chat hub (history + inline tools + build-order rail) | Shipped v0.5.9–v0.5.14 | `ConversationStore` multi-session history; right-side `_ToolRail` (Capability/Security/Recommend/Scan + build-order panel); double-click tile → fork card |
| Plan build order (phased roadmap) | Shipped v0.4.29 | `FeatureScanner.planRoadmap` → dependency-aware phases; applies `targetVersion` + `priority` to the board |
| Build-order board grouping | Shipped v0.4.35 | Toggle "Status / Build order"; Build-order mode groups un-built features by `targetVersion` with NEXT UP tag |
| Base View (StarCraft-style game, v1) | Shipped v0.5.0 | Project = base, features = buildings on rings, active run = builder-bot; LLM metaphor; pan/zoom. `lib/features/game/`; castle toolbar icon |
| Edit feature Kind by hand (Buildable/Epic/Manual) | Shipped v0.4.54 | ChoiceChip selector in Edit Feature dialog |
| Subtasks nest under their epic (all views) | Shipped v0.4.52 | ↳ indented under epic in status and build-order views; `_splitEpics` + `_withSubtasks` |
| Remove duplicate features | Shipped v0.4.11 | `FeatureDeduplicator` (exact + semantic LLM pass) + `showDedupReviewSheet` |
| In-app Forge Files drawer | Shipped v0.5.35 | AppBar folder icon → slide-out `ForgeFilesPanel` (right endDrawer); 5 sections (Specs/Handoffs/Worksheets/Ingested Docs/Audit), auto-expanded when non-empty; tap file → opens in default app; "Reveal in Finder" in header. `lib/features/tracker/widgets/forge_files_panel.dart` |
| Ask Anything button | Shipped v0.5.33 | AppBar chat-bubble icon → `RefineFeaturesScreen` with no pre-selected feature; free-form AI chat |
| Virtual-PM check-ins | Shipped | `CheckinService` diffs git since last review → status changes/new features/flags + staleness banner |
| Status reconciliation (self-heal lost "shipped") | Shipped v0.4.57 | `reconcileStatuses` heals `in_progress` features with a build-memory record but no live run |
| Export docs | Shipped | `doc_export.dart` copies `Forge/` deliverables to `<chosen>/forge-docs/` |
| Project deletion (safe) | Shipped | Index + folder cascade, guarded to the canonical projects root |
| Dictation (`theforge://paste`) | Shipped | URL scheme → `lib/services/paste_receiver.dart` |

---

## Build with AI — Implementation Agent

| Feature | Status | Notes |
|---|---|---|
| Build with AI (implementation agent) | Shipped v0.4.0 | `lib/features/implementation/**`; two-pass scout→plan, propose-approve-verify, streamed build window |
| NO FAKE COMPLETIONS prompt rule | Shipped v0.4.49 | `ImplAgent._systemPrompt`: no stubs/simulate/TODO-as-done; empty edits + `CANNOT BUILD:` if genuinely uncodeable |
| Behavioral-substitution guard | Shipped v0.4.59 | `CompletionGuard.detectSubstitutions` flags silent format swaps (JPEG↔PNG, MIME, audio/video containers) on the done bar |
| Completion guard (honesty check on the diff) | Shipped v0.4.50 | `CompletionGuard.inspect` on applied edits; flags noEdits/docs-only/stub-dominated → amber done bar + Ship anyway / Mark shipped |
| Ingested reference context in builds | Shipped v0.4.8 | `Forge/ingested/reference_context.md` always-on slot in `ImplAgent.buildUserContext`; visible trim markers |
| Feature-build memory (gained + remains) | Shipped v0.4.9 | Ship writes `Forge/build_memory/<featureId>.md`; every later build reads them back into `## Prior builds` slot |
| Doc-aware scout (unified manifest) | Shipped v0.4.10 | `gatherDocManifest` for pools that overflow the always-on cap; scout returns a `docs` array; `readDocEntry` fetches into Pass-2 block |
| Live reasoning streaming | Shipped v0.4.0 | `LlmService.completeStream` + `LlmDelta{text, thinking}`; Ollama/Claude/OpenAI real streaming; collapsible thinking block |
| Modify-plan (edit / revise) | Shipped v0.4.0 | Edit proposed plan inline or revise via free-text → re-plan |
| Fix-on-failure | Shipped v0.4.0 | Verify failure routes back through `_plan` in fix mode |
| Analyze-gate after apply | Shipped v0.4.15 | `_analyzeGate` runs `flutter/dart analyze` after edits; compile errors fold into failure report |
| Auto-tidy after apply | Shipped v0.4.20 | `_tidy` runs `dart fix --apply` + `dart format` on edited files post-apply |
| Make runnable (scaffold) | Shipped v0.4.21 | `scaffoldFlutter` runs `flutter create .`; backs up/restores Info.plist + AndroidManifest |
| Ship → document + commit + push | Shipped v0.4.21 (guard v0.4.55) | `shipFeature` → prepends app CHANGELOG, appends DEVELOPMENT_LOG, refreshes ARCHITECTURE, then git commit + push; redundant-ship guard skips when nothing changed |
| Pre-build guards (leftover work + already-built) | Shipped v0.4.58 (v0.4.60; v0.5.11) | Two deterministic checks before new run: uncommitted changes (offer Commit & push or Discard broken edits) + prior build record |
| Four BYOK LLM providers (Ollama · Claude · OpenAI · Gemini) | Shipped v0.5.2 | Per-role (Architect/Executor) provider + model. All BYOK; keys in Keychain |
| Self-diagnosing API-key errors + "Test key" | Shipped v0.5.1 | `key_check.dart` maps 401/404/429/5xx/network → plain actionable text; Settings "Test key" hits `/api/chat` (not public `/api/tags`) |
| Build-model fit warning (coder nudge) | Shipped v0.4.53 | `model_capability.dart`; amber banner when executor role is on a reasoning/vision model + one-click switch to best configured coder |
| Enforced JSON output mode | Shipped v0.4.19 | `jsonMode` → Ollama `format:"json"` on scout/plan/scan/dedup passes |
| Follow-up after a run | Shipped v0.4.12 | "Follow up" on Done bar + "Suggest improvements" → AI reviews written code + proposes fixes through approve/apply loop |
| Undo (edit backups) | Shipped v0.4.0 | Applied edits backed up to `Forge/impl_backups/`; one-click revert |
| Streamed command runner | Shipped v0.4.0 | `Process.start` streaming + denylist + 3-min timeout |
| keepAlive per-feature runs | Shipped v0.4.0 | Live build resumes on navigate-back; generation counter discards stale streams |
| Entitlement gate | Stub v0.4.0 | `entitlementProvider` stub in `implementation_providers.dart`; not yet enforced/monetized |

---

## Run & Preview

| Feature | Status | Notes |
|---|---|---|
| Run & Preview window | Shipped v0.4.36 | `RunController`; detects devices, runs `flutter run -d <id>`, streams console, hot reload/restart/quit over stdin; live screenshot mirror (Simulator / ADB) |
| Auto-boot simulators/emulators | Shipped v0.4.37 | Shut-down iOS Simulators + Android AVDs listed in device picker; `RunController.start` boots chosen one before `flutter run` |
| Scaffold at iOS 15.0 (Xcode 27) | Shipped v0.4.37 | `ios_deployment.dart` — `bumpPbxproj`/`bumpPodfile`; applied after every `flutter create` and as a pre-run safety net |

---

## Releases

| Feature | Status | Notes |
|---|---|---|
| Release tracking | Shipped v0.4.0 | `Releases` drift table; mirrored to `Forge/tracker/releases.json` |
| Cut release | Shipped v0.4.0 | `release_providers.dart` — group features → notes → CHANGELOG + optional git tag |

---

## Design System & Onboarding

| Feature | Status | Notes |
|---|---|---|
| ForgeTheme (design language v2) | Shipped v0.4.0 | `lib/core/theme/forge_theme.dart` — navy + ember/brass; `rust #7A3826` = blocked/stuck |
| Hearth Dial brand mark | Shipped v0.4.0 | `lib/core/widgets/hearth_dial.dart` — `CustomPainter` |
| Launch splash + routing | Shipped v0.4.0 | `/` splash → `/home` |
| First-run onboarding | Shipped v0.4.0 | `lib/features/onboarding/first_run_screen.dart` |
| Portfolio digest | Shipped v0.4.0 | `portfolioDigestProvider` + panel + `ForgeAppHeader` |
| Active model chip | Shipped v0.4.0 | `lib/features/tracker/widgets/active_model_chip.dart` |
| Thinking on/off per role | Shipped v0.4.18 | `ModelAssignment.think` + Settings toggle; Ollama `think:false` when off |
| New Project 2-up | Shipped v0.4.0 | Name field + Create; `ProjectMode.build`, phase `'tracker'` (interview modes removed v0.5.34) |
| Create a code folder | Shipped v0.4.1 | `ProjectFileRepository.createCodeRepo` — makes `~/Development/<name>`, `git init`, links it |
| Platform picker on create → auto-scaffold | Shipped v0.4.26 | `pickPlatforms` → `flutter create --platforms=…` so new app is runnable from start |
| Vibecode prompt + Esc interrupt | Shipped v0.4.4 | Persistent input in Build window; Escape stops running task |
| Copyable build console + raw-output on failure | Shipped v0.4.5 | `SelectionArea` + Copy-all; failed planning shows raw model output |
| Re-edit shipped features | Shipped v0.4.4 | Build-with-AI available on any non-archived feature |
| Relocate code repo (any time) | Shipped v0.4.11 | `relocateRepoFlow`; "Change code location" in Build window toolbar; `isInsideProjectsRoot` guard |

---

## Not Yet Built (open backlog)

| Feature | Backlog item |
|---|---|
| Managed metered AI backend (freemium paid tier) | `§MB` |
| Base View v2 (Flame isometric + Rive robots) | `§GAME-v2` |
| Auto-branch epics (branch on build, merge on done) | `§BRANCH` |
| Teams tier (gate Watch Mode, `.forge` repo sync, Slack alerts, shared workspace) | `§TEAMS-*` |
| Diff-based edits (replace full-file rewrites) | Open follow-up from §BWAI |
| Windows support | `§WIN` |
| Per-screen color migration to ForgeTheme | Open follow-up from §UIK |
| Bundle Unbounded / IBM Plex Mono fonts | Open follow-up from §UIK |
