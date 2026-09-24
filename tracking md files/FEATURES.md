# The Forge — Feature Catalog

**Last Updated:** 2026-09-10

---

## Core Features

| Feature | Status | Notes |
|---|---|---|
| Build Interview (8-dimension confidence model) | Planned | §2 in backlog |
| Audit Interview (current state spec) | Planned | §6 in backlog |
| Monte Carlo spec generation (3 parallel variants) | Planned | §3 in backlog |
| Locked spec (immutable, versioned) | Planned | Part of §3 |
| Bullet handoff (phase transition summary) | Planned | Part of §3 |
| Setup worksheet (external services checklist) | Planned | §9 in backlog |
| Handoff package (JSON, for executor agents) | Planned | Part of §3 |
| Project folder browser (list + resume) | Planned | §4 in backlog |
| Artifact viewers (spec, handoff, worksheet, audit) | Planned | §5 in backlog |
| Document ingestion (PDF, Word, Markdown) | Planned | §7 in backlog |
| Workspace + billing ($150/workspace/month) | Planned | §8 in backlog |
| Audit trail export (versioned, client deliverable) | Future | §11 in backlog |
| Open source executor path (tool-agnostic JSON spec) | Future | §10 in backlog |

---

## Portfolio Tracker

| Feature | Status | Notes |
|---|---|---|
| Portfolio dashboard | Shipped | Home route `/`; old project list moved to `/projects` |
| Feature board (status tracking) | Shipped | Grouped by idea/planned/in_progress/blocked/shipped/archived; providers in `lib/features/tracker/**` |
| Auto-scan features (docs + repo) | Shipped | `FeatureScanner` proposes features from `.forge` docs and/or a linked repo; import dedups against tracked titles (BUG-TRACKER-001) |
| Security Check (secret pre-scan + LLM audit) | Shipped v0.4.47 | `FeatureScanner.securityCheck` — deterministic secret grep (`_scanForSecretHits`: private keys, AWS/OpenAI/GitHub/Slack/Google tokens, hardcoded assignments) feeds redacted hits + source + docs to the Architect LLM → markdown report (risk, secrets, permissions, deps, unsafe patterns, fix-first). `SecurityCheckScreen`; right-click a dashboard project card, or AI tools ▾ → Security check |
| "What this app can do" summary | Shipped v0.4.38 | `FeatureScanner.describeCapabilities` reads current repo (key `lib/` source + README + `.forge` docs) + tracked features → plain-language markdown overview of real current capabilities (+ honest "not yet functional" section). On-demand + cached to `.forge/capability_summary.json` (stamped with git commit); `CapabilitySummaryScreen` shows it instantly with a "repo changed → Refresh" nudge. ✨ toolbar action |
| Architect epics + build gate | Shipped v0.4.40 (fix v0.4.51) | Feature `buildKind` (standard/epic/manual) + `parentId` (drift v4). `FeatureScanner.architectFeature` decomposes an epic into ordered typed sub-features → `showArchitectReviewSheet` → creates them nested under the epic. Build-with-AI is gated on epic/manual items (steers to Architect / How-to-build, explicit override). Board tags epic/manual. Stops big features being stubbed and marked shipped. **v0.4.51:** the flow branches on the model's `isEpic` judgment — a non-epic is sharpened in place + marked buildable (not wrapped in an epic + cloned), fixing the architect→gate→architect loop (BUG-TRACKER-003) |
| "How to build this" (build advice) | Shipped v0.4.39 | `FeatureScanner.adviseBuild` — per-feature ⋮ action; scale-aware markdown (Scope: feature vs epic · Feasibility: Buildable/Hybrid/Needs-human · Approach + named packages · Effort · Risks · Breakdown into sub-features · Suggested descriptor), grounded in current repo + docs. `BuildAdviceScreen`, on-demand + Regenerate/Copy. Correctly flags epics like on-device recognition as ML/dataset work, not one-shot code-gen |
| Recommend new features (virtual-PM) | Shipped v0.4.28 | `FeatureScanner.recommend` analyzes built/tracked features + docs + code → prioritized NEW feature/enhancement/improvement suggestions (excludes existing); lightbulb toolbar action → review sheet → import (source `recommend`) |
| Plan build order (phased roadmap) | Shipped v0.4.29 | `FeatureScanner.planRoadmap` → dependency-aware phases (RoadmapPhase/RoadmapEntry) with version + per-feature reason; `showRoadmapReviewSheet` → Apply writes phase `targetVersion` + running `priority` (board sorts by priority); route toolbar action |
| Build-order board grouping | Shipped v0.4.35 | "Group by: Status / Build order" toggle above the board; Build-order mode groups the not-yet-built features (idea/planned/blocked/in_progress) by `targetVersion` (ascending, next-up tagged NEXT UP) and priority within version — the sequence to feed into Build-with-AI; reads what Plan build order assigns; unversioned features collect in a trailing group with a Plan-build-order shortcut |
| Base View (StarCraft-style game, v1) | 🚧 v1 on branch `feat/base-view-game` (v0.5.0) | Game-mode visualization over existing data: project = base, feature = building (styled by status + epic/manual marker), active run = builder-bot colored by `RunPhase`, tap bot → live status (phase + console tail + elapsed), tap building → feature; LLM-distilled project metaphor themes the base (cached `.forge/project_metaphor.json`); pan/zoom via `InteractiveViewer`. `lib/features/game/` (`base_layout.dart` pure grid math, `base_view_screen.dart`) + `FeatureScanner.distillMetaphor` + `ProjectFileRepository.read/writeProjectMetaphor`; castle toolbar icon. Pure wrapper (reads `featureListProvider`/`implActiveRunsProvider`/`implRunProvider`). v2+: pts 5–6, drag-to-assign, Flame RTS input, multi-base portfolio map (§GAME) |
| Edit a feature's Kind by hand (Buildable/Epic/Manual) | Shipped v0.4.54 | Edit Feature dialog gains a **Kind** ChoiceChip selector (+ per-kind hint), so a mis-tagged item is no longer stuck as whatever Architect made it — demote an over-eager epic, promote a `manual` sub-feature. `FeatureEditResult.buildKind` in `feature_edit_dialog.dart`, threaded through `_addFeature`/`_editFeature` → `addFeature`/`updateFeature` (provider already supported it). Unblocks reconciling redundant epic+clone pairs |
| Subtasks nest under their epic (all views) | Shipped v0.4.52 | Epic + its subtasks render as one unit: subtasks are pulled out of independent placement and shown **indented under their epic** (↳ glyph) in both status and build-order views, so switching views never restages a step above/away from its epic. `_splitEpics` + `_withSubtasks` (recursive, orphan-safe) drive `_group` (status: epic anchors its subtasks in its column) and `_buildOrderGroups` (ancestor keep-set pins each unbuilt step under its epic); `_FeatureTile.indent` in `project_tracker_screen.dart` |
| Remove duplicate features | Shipped v0.4.11 | `FeatureDeduplicator` (exact-title + conservative LLM semantic pass) + `showDedupReviewSheet`; broom icon on the board finds same-feature groups (incl. reworded across scans), user reviews, keeps most-progressed/newest, deletes extras |
| Virtual-PM check-ins | Shipped | `CheckinService` diffs git since last review → status changes/new features/flags + staleness banner |
| Status reconciliation (self-heal lost "shipped") | Shipped v0.4.57 | On board open, `FeatureListNotifier.reconcileStatuses` heals a feature stuck at `in_progress` that has a build-memory record (ground-truth it shipped, via `ProjectFileRepository.hasBuildMemory`) and no live run → back to `shipped`, with a surfaced note. Fixes features mis-marked before the v0.4.56 root-cause fix; conservative (only in_progress, never a currently-building feature — board passes the active-run set) |
| Import → Spec | Shipped | Paste description/doc/transcript → `ImportService` → existing `SpecGenerationScreen` |
| Repo onboarding (Quick/Deep) | Shipped | Quick = docs+structure; Deep also reads code via `scanProjectCodebase`+`analyzeFileBatch`; unknowns → gaps |
| Export docs | Shipped | `doc_export.dart` copies `.forge` deliverables to `<chosen>/forge-docs/` |
| Project deletion (safe) | Shipped | Index + folder cascade, guarded to the canonical projects root |
| Dictation (`theforge://paste`) | Shipped | URL scheme → `lib/services/paste_receiver.dart` |

---

## Build with AI — Implementation Agent

| Feature | Status | Notes |
|---|---|---|
| Build with AI (implementation agent) | Shipped v0.4.0 | `lib/features/implementation/**`; two-pass scout→plan, propose-approve-verify, streamed build window |
| NO FAKE COMPLETIONS prompt rule | Shipped v0.4.49 | `ImplAgent._systemPrompt`: implement the real artifact, no stub/`simulate…`/`TODO`-as-done; if it genuinely can't be code-generated, return empty edits + a `CANNOT BUILD:` summary. Mirrors `templates/COLLABORATION_PLAYBOOK.md` |
| Behavioral-substitution guard (format/encoding swaps) | Shipped v0.4.59 | `CompletionGuard.detectSubstitutions` scans the applied diff for a swap within a mutually-exclusive format family (image encode `ImageByteFormat.jpeg`↔`png`, MIME `image/jpeg`↔`image/png`/webp/heic, encoders `encodeJpg`↔`encodePng`, audio/video containers) — removed-one-member + added-a-different-one. Flags a silent format change (e.g. the AR Mechanic JPEG→PNG compile workaround) on the done bar for explicit confirmation before ship. Conservative (same-format or brand-new-file never fires); deterministic, no AI call; unit-tested. Composes with the completion warning |
| Completion guard (honesty check on the diff) | Shipped v0.4.50 | `CompletionGuard.inspect` runs at the end of `ImplRunNotifier._applyAndRun` on the **applied** edits; flags noEdits / docs-config-only / stub-placeholder-only → `ImplRunState.completionWarning`; `_DoneBar` turns amber, shows the reason, offers **Ship anyway** vs one-click **Mark shipped**. Deterministic enforcement of the NO FAKE COMPLETIONS rule; pure + unit-tested (`test/completion_guard_test.dart`); conservative (placeholder check fires only when markers dominate added code) |
| Ingested reference context in builds | Shipped v0.4.8 | Builder reads `.forge/ingested/reference_context.md` (same pool as interview/spec) each planning round; always-on `## Reference context` slot in `ImplAgent.buildUserContext`; console shows `Loaded reference context (~N words)`; visible over-budget trim markers; spec cap 6k→12k |
| Feature-build memory (gained + remains) | Shipped v0.4.9 | Shipping a feature writes a "what/why/files" record to `.forge/build_memory/<featureId>.md` (one per feature, overwritten on re-ship); every later build reads them back via `readBuildMemory` into a `## Prior builds` slot; console logs `Loaded build memory (N prior features)` / `Saved to build memory…` |
| Doc-aware scout (unified manifest) | Shipped v0.4.10 | `gatherDocManifest` builds one `DocPoolEntry` per ingested doc + build-memory record; scout receives the manifest for pools that overflow their always-on cap and returns a `docs` array; `readDocEntry` (sandboxed) fetches full text into a `## Retrieved reference material` Pass-2 block, de-duped against always-on context. No change for small pools |
| Live reasoning streaming | Shipped v0.4.0 | `LlmService.completeStream` + `LlmDelta{text, thinking}`; Ollama/Claude/OpenAI real streaming; reasoning shown in collapsible `thinking` console line |
| Modify-plan (edit / revise) | Shipped v0.4.0 | Edit the proposed plan inline or revise via free-text feedback → re-plan through shared revision block |
| Fix-on-failure | Shipped v0.4.0 | Verify failure (e.g. `dart analyze`) routes back through `_plan` in fix mode for a corrective plan |
| Analyze-gate after apply | Shipped v0.4.15 | `_analyzeGate` runs `flutter/dart analyze` right after edits; compile errors (`error •`) fold into the failure report → canFix/"Fix it"; catches hunk corruption (stray brace / dropped symbol, BUG-IMPL-003 class) before a run is called done |
| Auto-tidy after apply | Shipped v0.4.20 | `_tidy` runs `dart fix --apply` + `dart format` on edited files post-apply; removes unused imports / formats automatically (best-effort, Dart/Flutter only) so builds don't accumulate cosmetic debris |
| Make runnable (scaffold) | Shipped v0.4.21 | `scaffoldFlutter` runs `flutter create .` to generate missing android/ios platform folders; backs up/restores Info.plist + AndroidManifest so permission edits survive; "Make runnable" action button |
| Ship → document + commit + push | Shipped v0.4.21 (guard v0.4.55) | `shipFeature`→`_documentAndCommit`: prepends app repo `CHANGELOG.md`, appends `docs/DEVELOPMENT_LOG.md`, LLM-refreshes `docs/ARCHITECTURE.md`, then `gitCommitAll` + `gitPush` (best-effort); applies The Forge's docs-ship-with-code rule to built apps. **v0.4.55:** redundant-ship guard — `gitHasChanges` (git status --porcelain) is checked *before* the non-deterministic ARCHITECTURE rewrite, so a repeat ship with nothing new skips the rewrite + commit instead of churning a duplicate-titled docs-only commit (BUG-IMPL-010); `shipFeature` also no-ops when already shipped |
| Pre-build guards (leftover work + already-built) | Shipped v0.4.58 (commit action v0.4.60) | Before dispatching a new Build-with-AI run, `_preBuildChecks` runs two deterministic checks (no AI call): (1) `gitHasChanges` — warn if the repo has uncommitted changes from a prior/failed build; (2) `hasBuildMemory` — warn if the feature was built before (build record) but isn't marked shipped. Only gates a new build, never a re-attach. Stops the recurring duplicate-creation pattern (duplicate `_HighlightPainter`, `procedure_model.dart`). **v0.4.60:** the uncommitted-changes dialog (`_handleUncommittedChanges`) lists changed files (`gitChangedFiles`) and offers **Commit & push** (commits + best-effort push, then builds once clean) alongside Build anyway / Cancel |
| Build-model fit warning (coder nudge) | Shipped v0.4.53 | `model_capability.dart` — pure `classifyModel(id)→{coder/reasoning/vision/fast/unknown}` (curated map + heuristics, errs to `unknown` so it never nags a sane default). When the executor role is on a reasoning/vision model, an amber banner above the build console warns + offers one-click **Switch to `<best configured coder>`** via `pickBuildCoderUpgrade` (same-provider preferred, `think:false`, button hides if none). Nothing auto-switches. Catches the qwen3.5-loops-on-hunks failure; foundation for future opt-in auto-select. `_ModelFitBanner`; unit-tested (`test/model_capability_test.dart`) |
| Enforced JSON output mode | Shipped v0.4.19 | `jsonMode` threads to Ollama `format:"json"` on scout/plan/scan/dedup passes so a model can't return prose where JSON is required (note: not enforced on some cloud models) |
| Follow-up after a run | Shipped v0.4.12 | "Follow up" on the Done bar + "Suggest improvements" action → AI reviews the just-written code and proposes hardening fixes (error/permission handling, lifecycle, platform/config completeness, tests) through the normal approve/apply loop; iterate in rounds before shipping |
| Undo (edit backups) | Shipped v0.4.0 | Applied edits backed up to `.forge/impl_backups/`; one-click revert |
| Streamed command runner | Shipped v0.4.0 | `Process.start` streaming + denylist + 3-min timeout; first streamed subprocess in the app |
| keepAlive per-feature runs | Shipped v0.4.0 | Live build resumes on navigate-back; generation counter discards stale streams |
| Entitlement gate | Stub v0.4.0 | Entitlement check present as a stub in `implementation_providers.dart`; not yet enforced/monetized |

---

## Run & Preview

| Feature | Status | Notes |
|---|---|---|
| Run & Preview window | Shipped v0.4.36 | Play toolbar action → `RunPreviewScreen`; `RunController` (`lib/features/run/`) detects devices (`flutter devices --machine`), runs long-lived `flutter run -d <id>` in the repo, streams console, forwards hot reload/restart/quit over stdin. Live screenshot mirror of the running app via `xcrun simctl io booted screenshot` (iOS Simulator) / `adb exec-out screencap` (Android), auto-refreshed after each reload. macOS/web run in their own window/browser + console. Screenshot-mirror chosen over embedded WebView for reliability (no fragile macOS in-tree webview) + native fidelity (camera/AR) |
| Auto-boot simulators/emulators | Shipped v0.4.37 | Device picker also lists shut-down iOS Simulators (`simctl list --json`, `parseIosSimulators`) + Android AVDs (`flutter emulators --machine`, `parseAndroidEmulators`), tagged "(tap to boot)". `RunController.start` boots the chosen one (`simctl boot` + wait / `flutter emulators --launch` + resolve device id) before `flutter run` |
| Scaffold at iOS 15.0 (Xcode 27) | Shipped v0.4.37 | `lib/data/filesystem/ios_deployment.dart` — pure `bumpPbxproj`/`bumpPodfile` transforms + `applyMinIosDeploymentTarget`; called after every `flutter create` (`createCodeRepo` + `scaffoldFlutter`) and as a pre-run safety net for iOS targets. Prevents the "deployment target below 15.0" build wall |

---

## Releases

| Feature | Status | Notes |
|---|---|---|
| Release tracking | Shipped v0.4.0 | `Releases` drift table (schemaVersion 2→3, create-only); mirrored to `.forge/tracker/releases.json` |
| Cut release | Shipped v0.4.0 | `release_providers.dart` — group features by version → notes → CHANGELOG + git tag; feature status auto-transitions on ship |

---

## Design System & Onboarding (v0.4.0)

| Feature | Status | Notes |
|---|---|---|
| ForgeTheme (design language v2) | Shipped v0.4.0 | `lib/core/theme/forge_theme.dart` — navy + ember/brass; replaced `AppTheme`; `rust #7A3826` = blocked/stuck |
| Hearth Dial brand mark | Shipped v0.4.0 | `lib/core/widgets/hearth_dial.dart` — `CustomPainter` |
| Launch splash + launch→home routing | Shipped v0.4.0 | `lib/features/launch/launch_screen.dart`; `/` splash → `/home` |
| First-run onboarding | Shipped v0.4.0 | `lib/features/onboarding/first_run_screen.dart` |
| Portfolio digest | Shipped v0.4.0 | `lib/features/tracker/widgets/portfolio_digest.dart` — `portfolioDigestProvider` + panel + `ForgeAppHeader` |
| Active model chip | Shipped v0.4.0 | `lib/features/tracker/widgets/active_model_chip.dart` |
| Thinking on/off per role | Shipped v0.4.18 | `ModelAssignment.think` + Settings toggle per role; `LlmService` sends Ollama `think:false` only when off; off routes full budget to the answer (avoids thinking-driven JSON truncation/loops) |
| New Project 2-up | Shipped v0.4.0 | `new_project_screen.dart` reduced to two modes |
| Create a code folder | Shipped v0.4.1 | `ProjectFileRepository.createCodeRepo` — makes `~/Development/<name>`, `git init`, links it; offered in the Link-Repo row and the Build-with-AI no-repo prompt |
| Platform picker on create → auto-scaffold | Shipped v0.4.26 | `pickPlatforms` dialog (iOS/Android/macOS/Windows/Linux/Web) → `createCodeRepo(platforms:)` runs `flutter create --platforms=…` so a new app is runnable from the start; platforms saved to project config; removes the need to press Make runnable for new apps |
| Vibecode prompt + Esc interrupt | Shipped v0.4.4 | Persistent input in the Build window (`notifier.steer`); Escape stops the running task |
| Copyable build console + raw-output on failure | Shipped v0.4.5 | `SelectionArea` + Copy-all; failed planning prints the model's raw output for diagnosis |
| Build-with-AI compose screen | Shipped v0.4.7 | No auto-run; on-screen hints + prompt box; nothing sent until the user acts |
| Build action buttons | Shipped v0.4.7 | Right-side: Build this feature / Run checks / Fix errors / Commit & push (git) |
| Re-edit shipped features | Shipped v0.4.4 | "Build with AI" available on non-archived features, incl. shipped ("Re-build / edit with AI") |
| Relocate code repo (any time) | Shipped v0.4.11 | `relocateRepoFlow` + `ProjectFileRepository.relocateRepo`/`createEmptyCodeFolder`; "Change code location" in the Build window toolbar and the detail-screen repo row moves code to a new folder + repoints config; `isInsideProjectsRoot` guard blocks using a Forge workspace as a repo (BUG-IMPL-006) |

---

## Interview Modes

| Mode | Use case | Output |
|---|---|---|
| Build Interview | Greenfield — nothing exists yet | Locked Spec |
| Audit Interview | Existing team or codebase | Current State Spec |

---

## Outputs Per Run

| Output | Description | For |
|---|---|---|
| Locked Spec | Immutable architecture document | Executor agents |
| Bullet Handoff | Human-scannable phase transition summary | The Forge on resume + user |
| Setup Worksheet | Step-by-step human-action checklist for external services | User |
| Handoff Package | JSON summary of the run | Next agent or session |
