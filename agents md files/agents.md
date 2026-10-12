# Agent Instructions — The Forge

## For each prompt / task

1. Create an agent that analyzes the prompt, plans how to fulfill it, and breaks work into sub-tasks assignable to sub-agents. The overseer defines **definition of done** before assigning work.
2. Create enough sub-agents to handle the tasks.
3. Assign each sub-agent its sub-tasks.
4. Create a review agent that shares the definition of done and reviews completed work as sub-agents finish.
5. When implementation is complete, output a short summary and review.

---

## The Forge — Documentation Context Guide

**Purpose:** Orient assistants and contributors to this repo.

**Repository root:** `/Users/mymac/Development/theforge`

**Before changing local file structure, LLM service, or provider implementations:**
- Read `bugtracker/BUG_PREVENTION.md` and skim relevant bug records.

---

## Quick Reference

| Document | Purpose | Path |
|----------|---------|------|
| **CLAUDE.md** | Claude entry point and SOP | `CLAUDE.md` |
| **agents_sop.md** | All SOPs (PLAN, ERROR, REVIEW, ROLE, GATE, etc.) | `agents md files/agents_sop.md` |
| **ARCHITECTURE.md** | System architecture | `tracking md files/ARCHITECTURE.md` |
| **FEATURES.md** | Feature catalog (what's shipped, removed, backlogged) | `tracking md files/FEATURES.md` |
| **CHANGELOG.md** | Version history | `tracking md files/CHANGELOG.md` |
| **context.md** | Session log — read first every session | `tracking md files/context.md` |
| **UI_UX.md** | UI/UX patterns | `tracking md files/UI_UX.md` |
| **BUG_PREVENTION.md** | Check before coding in risky areas | `bugtracker/BUG_PREVENTION.md` |

---

## Architecture Overview

**What it is:** A standalone Flutter desktop app (macOS primary). An AI-assisted app development tool — feature tracker board + Build-with-AI implementation agent + planning and quality tools. BYOK LLM providers.

**Tech stack:** Flutter · Dart · Riverpod · Local filesystem (Markdown + JSON) · SQLite via drift · BYOK LLM (Ollama / Claude / OpenAI / Gemini) · macOS Keychain (API keys)

**Current version:** v0.5.36

**Repository layout:**
```
theforge/
├── lib/
│   ├── core/                    — App bootstrap, routing, ForgeTheme
│   ├── data/
│   │   ├── filesystem/
│   │   │   └── project_file_repository.dart  — all local file I/O
│   │   └── local_db/forge_database.dart       — drift SQLite project + feature index
│   ├── features/
│   │   ├── game/                — BaseView (StarCraft-style project metaphor)
│   │   ├── implementation/      — Build-with-AI implementation agent
│   │   │   ├── data/            — ImplAgent, CompletionGuard, CommandRunner
│   │   │   ├── models/          — RunSession, ProposedEdit, AgentPlan
│   │   │   ├── providers/       — ImplRunNotifier, implementation_providers
│   │   │   └── screens/         — ImplementationScreen, BuildAdviceScreen
│   │   ├── projects/            — Portfolio, new project creation, goal interview
│   │   │   ├── providers/       — ProjectListNotifier
│   │   │   └── screens/         — ProjectsListScreen, NewProjectScreen,
│   │   │                          GoalInterviewScreen
│   │   ├── run/                 — RunController, RunPreviewScreen (flutter run + mirror)
│   │   ├── settings/            — SettingsNotifier, SettingsScreen, BYOK config
│   │   └── tracker/             — Feature board and all tracker tooling
│   │       ├── checkin/         — CheckinService, CheckinReviewDialog
│   │       ├── models/          — tracker_enums (FeatureStatus, BuildKind…)
│   │       ├── providers/       — FeatureListNotifier, tracker_providers
│   │       ├── releases/        — Release tracking
│   │       ├── scan/            — FeatureScanner, FeatureDeduplicator
│   │       ├── screens/         — ProjectTrackerScreen, RefineFeaturesScreen
│   │       └── widgets/         — ForgeFilesPanel, BuildBriefDialog,
│   │                              ArchitectReviewSheet, ScanReviewSheet…
│   ├── services/
│   │   ├── inspector_service.dart   — quality checks on AI-generated output
│   │   ├── llm/                     — LlmProvider interface + 4 providers
│   │   │   ├── llm_provider.dart    — LlmRole enum (architect/executor/inspector)
│   │   │   ├── llm_service.dart     — resolves role → model → provider
│   │   │   ├── llm_model_config.dart — model catalog, LlmSettings, defaults
│   │   │   └── providers/           — OllamaProvider, ClaudeProvider,
│   │   │                              OpenAiProvider, GeminiProvider
│   │   ├── diag_log.dart
│   │   ├── crash_diagnostics.dart
│   │   └── paste_receiver.dart      — theforge://paste URL scheme
│   └── main.dart
├── tracking md files/           — context.md, planner.md, backlog.md, FEATURES.md…
├── agents md files/             — SOPs, agent guidance, security checklist
├── operations md files/         — startup.md, CONFIGURATION_MANAGEMENT.md
├── bugtracker/                  — Bug index, prevention rules, records/
├── DOCS/                        — Coding Lessons, positioning brief
└── templates/                   — Reusable doc scaffold for seeded projects
```

**Core subsystems:**

- **Feature Tracker** (`lib/features/tracker/`) — Kanban board (idea/planned/in_progress/blocked/shipped/archived). `FeatureListNotifier` is the primary state notifier. Features are drift rows; board groups them by status or build order. All AI tools (Recommend, Scan, Architect, Refine, Checkin) live here.

- **Build-with-AI** (`lib/features/implementation/`) — Two-pass scout→plan, propose-approve-verify, streamed build window. `ImplRunNotifier` owns run state (keepAlive — survives navigation). `CompletionGuard` is a deterministic honesty check on the applied diff. `ImplBrief.goalStatement` carries the approved build brief into the run.

- **LLM Service** (`lib/services/llm/`) — Abstract `LlmProvider` interface with 4 implementations. `LlmService` resolves `LlmRole → ModelAssignment → LlmProvider`. Three roles: `architect` (planning, decomposition, interview), `executor` (Build-with-AI code generation), `inspector` (quality checks on AI output — always runs in a fresh independent context). API keys in macOS Keychain.

- **Inspector Service** (`lib/services/inspector_service.dart`) — Evaluates AI-generated output (build briefs, goal statements) for specificity and scope. Always runs in an independent context window — it never sees the generation context, which prevents self-rationalization. Fails gracefully (returns passing verdict on error). Uses `Forge/examples/` as format anchors when available.

- **Project File Repository** (`lib/data/filesystem/project_file_repository.dart`) — All local file reads and writes for project artifacts. No other code touches the filesystem directly. Manages `Forge/` subdirectories: `specs/`, `handoffs/`, `worksheets/`, `ingested/`, `audit/`, `build_memory/`, `impl_backups/`, `examples/`.

- **New Project Goal Interview** (`lib/features/projects/screens/goal_interview_screen.dart`) — Fires immediately after new project creation. Five questions → Architect AI proposes 4-8 seed features → user checks/unchecks → confirmed features land on the board. Replaces the blank-board new-project experience.

- **Build Brief Dialog** (`lib/features/tracker/widgets/build_brief_dialog.dart`) — Gates every Build-with-AI run after `_preBuildChecks`. Optional developer notes → Architect generates a one-paragraph brief → Inspector evaluates it live. Returns three-state: `null` (cancel), `''` (skip), `String` (approved brief injected as `goalStatement`).

- **SQLite Index** (`lib/data/local_db/forge_database.dart`) — drift tables: `Projects`, `Features`, `Releases`. Lightweight browser cache + feature state. Phase field tracks project progress.

- **Run & Preview** (`lib/features/run/`) — `RunController` runs `flutter run -d <device>`, streams console, hot reload/restart. Device picker auto-boots iOS Simulators and Android AVDs.

**Current Build-with-AI flow:**
```
User taps Build on a feature
  → _buildFeature() in ProjectTrackerScreen
  → _preBuildChecks() — uncommitted changes? already built?
  → showBuildBriefDialog() — optional brief + Inspector badge
      null → abort  |  '' → skip  |  String → goalStatement
  → ImplBrief constructed (featureTitle, description, goalStatement,
      lockedSpec, buildMemory, ingestedContext)
  → ImplementationScreen pushes
  → ImplRunNotifier._plan() — scout pass → plan pass (streamed)
  → User approves plan
  → ImplRunNotifier._apply() — edits written to disk
  → dart analyze gate
  → dart fix + format
  → CompletionGuard.inspect() — deterministic honesty check
  → User ships → shipFeature() → CHANGELOG + DEVELOPMENT_LOG +
      ARCHITECTURE refresh → git commit + push
      → Forge/build_memory/<featureId>.md written
```

**Local file structure (per project):**
```
~/Development/<ProjectName>/
  Forge/
  ├── specs/              — versioned locked specs (immutable once written)
  ├── handoffs/           — handoff packages (JSON + markdown)
  ├── worksheets/         — setup worksheets
  ├── ingested/
  │   └── reference_context.md   — LLM-extracted reference doc facts
  ├── audit/              — audit log (append-only)
  ├── build_memory/       — one .md per shipped feature (accumulated context)
  ├── impl_backups/       — pre-apply file backups (one-click revert)
  ├── tracker/            — tracker JSON mirror
  ├── conversations/      — RefineFeaturesScreen chat history
  └── examples/           — curated format anchors for Inspector
      └── build_brief.md  — gold-standard brief (set via ForgeFilesPanel long-press)
```

---

## Key Service Locations

| Service / Module | Path | Notes |
|---|---|---|
| Project file repository | `lib/data/filesystem/project_file_repository.dart` | All local file I/O; the only code that touches disk |
| SQLite index | `lib/data/local_db/forge_database.dart` | Projects + Features + Releases tables |
| LLM role enum | `lib/services/llm/llm_provider.dart` | `LlmRole { architect, executor, inspector }` |
| LLM service | `lib/services/llm/llm_service.dart` | Resolves role → model → provider |
| LLM implementations | `lib/services/llm/providers/` | Claude, OpenAI, Gemini, Ollama |
| LLM model catalog | `lib/services/llm/llm_model_config.dart` | Model IDs + `LlmSettings.defaults`; validated on load |
| Inspector service | `lib/services/inspector_service.dart` | `InspectorVerdict`, independent-context quality check |
| Settings | `lib/features/settings/` | `SettingsNotifier`; LLM role cards; keys in Keychain |
| Feature tracker | `lib/features/tracker/` | Board, scan, architect, refine, checkin |
| Feature list notifier | `lib/features/tracker/providers/tracker_providers.dart` | `FeatureListNotifier.addFeature()` |
| Tracker screen | `lib/features/tracker/screens/project_tracker_screen.dart` | `_buildFeature()`, `_preBuildChecks()` |
| Build brief dialog | `lib/features/tracker/widgets/build_brief_dialog.dart` | Pre-build gate; three-state return |
| Forge Files panel | `lib/features/tracker/widgets/forge_files_panel.dart` | `endDrawer`; long-press → Set as example |
| Implementation agent | `lib/features/implementation/` | `ImplRunNotifier`, `ImplAgent`, `ImplBrief` |
| Completion guard | `lib/features/implementation/data/completion_guard.dart` | Deterministic diff honesty check |
| Goal interview | `lib/features/projects/screens/goal_interview_screen.dart` | 5Q → seed features on new project |
| New project screen | `lib/features/projects/screens/new_project_screen.dart` | pushReplacement → GoalInterviewScreen after create |
| Run & Preview | `lib/features/run/` | `RunController`, `RunPreviewScreen` |
| Game view | `lib/features/game/` | BaseView (StarCraft metaphor) |

---

## Coding Standards

- **State management:** Riverpod (`AsyncNotifier`, `FamilyNotifier`, `Provider`)
- **Naming:** snake_case files, PascalCase classes, camelCase methods
- **Error handling:** Explicit typed exceptions; never swallow errors silently
- **Imports:** Relative within a feature; absolute for cross-feature
- **Linter:** `dart analyze lib/`
- **No committed secrets:** API keys in macOS Keychain via `flutter_secure_storage`. Never `.env`, never logged.

---

## Key Invariants

- **`dart analyze` must be clean.** Zero new warnings before reporting done.
- **No committed secrets.** API keys go in macOS Keychain. Never hardcoded, never in `.env`.
- **LLM JSON list fields: use `is List<dynamic>` check, never hard cast `as List<dynamic>?`.** A hard cast throws `TypeError` if the LLM outputs a string ("None", "TBD"); the outer try/catch then discards all extracted data for that turn. See BUG-INTERVIEW-004.
- **Model IDs in SharedPreferences must be validated against the current catalog on load.** Retired or misspelled IDs fall back to the first valid model for that provider so the app never starts with a model the API will reject. Ollama accepts any id (local or cloud) so it is not validated.
- **Inspector always runs in an independent context window.** Never pass generation history, prior reasoning, or the generating agent's context to the Inspector. It receives only: criteria + (optional) example + the output to evaluate. This is what makes the check meaningful — a validator that can see how the output was made will rationalize rather than critique.
- **Build brief dialog is three-state.** `null` = user cancelled (abort build). `''` = user skipped (proceed without brief). Non-empty `String` = approved brief (inject as `goalStatement` into `ImplBrief`). Never collapse skip and cancel into the same return value.
- **`ProjectFileRepository` is the only code that touches the filesystem.** No feature code reads or writes files directly — always go through the repository. This enforces consistent path resolution and atomic writes.

---

*Last revised: 2026-10-12 — v2.0.0: Full rewrite for v0.5.36. Removed stale interview engine, spec generation, Watch Mode, and artifact viewer references. Added current subsystems: Inspector, BuildBriefDialog, GoalInterviewScreen, ForgeFilesPanel examples.*
