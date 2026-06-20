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

**Repository root:** `/Volumes/Marc Working Drive/Development/The Forge/`

**Before changing local file structure, spec generation logic, or provider implementations:**
- Read `bugtracker/BUG_PREVENTION.md` and skim `bugtracker/bug_tracker.md` when the area matches.

---

## Quick Reference

| Document | Purpose | Path |
|----------|---------|------|
| **claude.md** | Claude entry point and SOP | `claude.md` |
| **ARCHITECTURE.md** | System architecture | `tracking md files/ARCHITECTURE.md` |
| **FEATURES.md** | Feature catalog | `tracking md files/FEATURES.md` |
| **UI_UX.md** | UI/UX patterns | `tracking md files/UI_UX.md` |
| **CHANGELOG.md** | Version history | `tracking md files/CHANGELOG.md` |
| **backend.md** | Storage model, providers, API reference | `backend.md` |
| **CONFIGURATION_MANAGEMENT.md** | Docs inventory and change log | `operations md files/CONFIGURATION_MANAGEMENT.md` |
| **bugtracker/** | Bug index, prevention, records | `bugtracker/README.md` |
| **context.md** | Session log — read first every session | `tracking md files/context.md` |
| **workflow_template.md** | The Forge interview + spec protocol | `DOCS/forge/workflow_template.md` |
| **positioning_brief.md** | Product positioning and pricing | `DOCS/forge/positioning_brief.md` |

---

## Architecture Overview

### The Forge — High-Level Architecture

**What it is:** A standalone Flutter desktop app (macOS primary). The PM layer for AI-assisted development — structured interview → locked spec → executor handoff.

**Tech stack:** Flutter · Dart · Riverpod · Local filesystem (Markdown + JSON) · SQLite via drift · Pluggable `SpecGenerationProvider` · Firebase (optional, workspace-tier sync only) · SwarmSpace API (billing, SwarmSpace routing provider only)

**Repository layout:**
```
The Forge/
├── lib/
│   ├── core/                        — App bootstrap, routing, theme
│   │   ├── app.dart                 — MaterialApp, named routes, routeObserver
│   │   └── theme/app_theme.dart     — macOS dark theme, Menlo, Forge amber
│   ├── data/
│   │   ├── filesystem/project_file_repository.dart  — all local file I/O
│   │   └── local_db/forge_database.dart             — drift SQLite project index
│   ├── features/
│   │   ├── artifacts/               — ArtifactViewerScreen (read-only markdown)
│   │   ├── interview/
│   │   │   ├── providers/           — InterviewArgs, interviewProvider family
│   │   │   ├── state/               — InterviewState, InterviewNotifier, dimensions
│   │   │   └── ui/                  — InterviewScreen, ConfidenceMeter
│   │   ├── projects/
│   │   │   ├── ingestion/           — Reference doc ingestion (LLM extract → disk)
│   │   │   ├── providers/           — ProjectListNotifier, ActiveProjectNotifier
│   │   │   └── screens/             — ProjectsListScreen, ProjectDetailScreen, NewProjectScreen
│   │   ├── settings/                — SettingsNotifier, EngineerRosterNotifier, GitHubConfigNotifier
│   │   ├── spec_generation/         — SpecNotifier, WorksheetNotifier, ExecutorTimelineNotifier
│   │   └── watch/                   — WatchDashboard, EngineerDetail, WorkspaceHealth, AlertLog
│   ├── services/
│   │   ├── llm/                     — LlmProvider interface + 4 implementations (Claude/OpenAI/Gemini/Ollama)
│   │   │   └── providers/
│   │   └── watch/                   — §W1–§W3 data pipeline
│   │       ├── providers/           — AnthropicUsage, OpenAiUsage, GithubGit, GithubCI
│   │       ├── usage_service.dart
│   │       ├── git_activity_service.dart
│   │       ├── failure_signal_engine.dart
│   │       ├── alert_engine.dart
│   │       └── watch_signal_service.dart
│   └── main.dart
├── DOCS/
│   ├── Coding Lessons/              — FOR_MARC_*.md lesson files
│   └── forge/                       — workflow_template.md, SuperSpec, plans
├── tracking md files/               — context.md, planner.md, backlog.md, etc.
├── agents md files/                 — SOPs and agent guidance
├── operations md files/             — startup.md, CONFIGURATION_MANAGEMENT.md
├── bugtracker/                      — Bug index, prevention rules, records/
├── forge-mcp/                       — TypeScript MCP server (Node.js)
├── audit/                           — The Forge's own audit log
├── backend.md                       — Storage model + provider reference
└── claude.md                        — Claude entry point
```

**Core subsystems:**

- **Interview Engine** (`lib/features/interview/`) — 4-layer deductive funnel (L1 Outcome → L2 Decomposition → L3 PoC → L4 Critical Path). Drives 8-dimension confidence model. State persisted to `audit/{Name}_InterviewState.json` after every LLM response so the session survives app restarts. Layer boundaries tracked for rewind.
- **Project File Repository** (`lib/data/filesystem/project_file_repository.dart`) — All local file reads and writes. Enforces write-once specs, append-only audit log, atomic writes via temp+rename. Central I/O contract — no other code touches the filesystem directly.
- **SQLite Index** (`lib/data/local_db/forge_database.dart`) — Lightweight project browser cache. Phase is the primary field updated at each stage. Rebuilds from filesystem scan if stale.
- **LlmService** (`lib/services/llm/`) — Abstract `LlmProvider` interface with 4 implementations: Claude, OpenAI, Gemini, Ollama. `LlmService` resolves `LlmRole → ModelAssignment → LlmProvider`. Role assignments and model IDs are user-configurable in Settings; API keys in macOS Keychain via SharedPreferences + `forge_config.json`.
- **Spec Generation** (`lib/features/spec_generation/`) — `SpecNotifier` (LLM → locked spec), `WorksheetNotifier` (LLM → setup worksheet), `ExecutorTimelineNotifier` (LLM → build sequence). All gated on prior-phase completion.
- **Watch Mode** (`lib/services/watch/` + `lib/features/watch/`) — §W1 token ingestion, §W2 git/CI correlation, §W3 failure signal engine, §W4 dashboard UI. All data persisted to `forge_config.json`.
- **Reference Doc Ingestion** (`lib/features/projects/ingestion/`) — Multi-file picker → LLM extraction → `ingested/reference_context.md` on disk → injected into interview + spec prompts.

**Key data flow:**
```
Interview (Riverpod + disk persistence)
  → specGenEnabled when L4 gate met (platform+identity+input+output extracted)
  → User taps Generate Spec
  → SpecNotifier: LLM call → SpecParser.clean() → ProjectFileRepository.writeLockedSpec()
  → Writes to disk:
      specs/{Name}_LockedSpec_v1.md         (immutable — abort if exists)
      handoffs/{Name}_BulletHandoff_v1.md
      handoffs/{Name}_HandoffPackage_v1.json
      handoffs/{Name}_goal_v1.md
      forge/{Name}_LockedSpec_v1.md         (forge context copy)
      forge/{Name}_DecisionContext_v1.md
      forge/{Name}_OpenFlags_v1.md
      ingested/{Name}_V2Seeds.md            (written at L3→L4 transition)
      audit/{Name}_AuditLog.md             (appended, never replaced)
      README.md                             (phase updated)
  → DB phase → v1_spec_locked
  → Worksheet → v1_worksheet_complete
  → Executor Timeline → BuildSequence_{version}.md
```

**Local file structure (per project):**
```
~/Documents/The Forge Projects/{Name}/
  ├── README.md                        — phase state, always current
  ├── specs/{Name}_LockedSpec_v1.md    — immutable after creation
  ├── handoffs/
  │   ├── {Name}_BulletHandoff_v1_Interview.md
  │   ├── {Name}_HandoffPackage_v1.json
  │   └── {Name}_goal_v1.md
  ├── worksheets/{Name}_SetupWorksheet_v1.md
  ├── forge/                           — executor context files
  │   ├── {Name}_LockedSpec_v1.md
  │   ├── {Name}_DecisionContext_v1.md
  │   └── {Name}_OpenFlags_v1.md
  ├── ingested/
  │   ├── reference_context.md         — LLM-extracted reference doc facts
  │   └── {Name}_V2Seeds.md            — features deferred from V1
  └── audit/
      ├── {Name}_AuditLog.md           — append-only
      └── {Name}_InterviewState.json   — persisted after every LLM response
```

---

## Key Service Locations

| Service / Module | Path | Notes |
|---|---|---|
| Interview state + notifier | `lib/features/interview/state/` | FamilyAsyncNotifier; persists to disk after every LLM response |
| Project file repository | `lib/data/filesystem/project_file_repository.dart` | All local file I/O; the only code that touches disk |
| SQLite index | `lib/data/local_db/forge_database.dart` | Project browser cache; phase is the key field |
| LLM provider interface | `lib/services/llm/llm_provider.dart` | Abstract LlmProvider + LlmRole enum |
| LLM service | `lib/services/llm/llm_service.dart` | Resolves role → model → provider |
| LLM implementations | `lib/services/llm/providers/` | Claude, OpenAI, Gemini, Ollama |
| LLM model catalog | `lib/services/llm/llm_model_config.dart` | Model IDs, defaults; validated on settings load |
| Spec generation | `lib/features/spec_generation/` | SpecNotifier, WorksheetNotifier, ExecutorTimelineNotifier |
| Project browser | `lib/features/projects/` | Screens, providers, ingestion |
| Settings | `lib/features/settings/` | SettingsNotifier (LLM config), EngineerRosterNotifier, GitHubConfigNotifier |
| Watch Mode data pipeline | `lib/services/watch/` | §W1 token ingestion → §W2 git/CI → §W3 signals → §W4 dashboard |
| Watch Mode screens | `lib/features/watch/` | Dashboard, EngineerDetail, WorkspaceHealth, AlertLog |
| Reference doc ingestion | `lib/features/projects/ingestion/` | Multi-file LLM extraction → `ingested/` folder |
| Artifact viewers | `lib/features/artifacts/` | Read-only markdown display (specs, worksheets, handoffs) |

---

## Coding Standards

- **State management:** Riverpod (matching LUMARA patterns)
- **Naming:** snake_case files, PascalCase classes, camelCase methods
- **Error handling:** Explicit typed exceptions; never swallow errors silently
- **Imports:** Relative imports within a feature; absolute for cross-feature
- **Linter command:** `dart analyze lib/`
- **No committed secrets:** API keys go in macOS Keychain via `flutter_secure_storage`. Never `.env`, never `shared_preferences`, never logged.

---

## Key Invariants

- **Locked specs are immutable.** Never modify a written spec. Amendments produce a new versioned file. Check existence before write — abort if file exists.
- **Audit log is append-only.** Open in append mode only. Never truncate or replace.
- **Interview state IS persisted to disk.** `writeInterviewProgress` is called after every successful LLM response and writes full turn history + extracted data + confidence map to `audit/{Name}_InterviewState.json`. This enables session resume after app close. Do NOT assume interview state is memory-only.
- **`specGenEnabled` fires when L4 gate is met, not just when all 8 dimensions resolve.** The L4 gate (`platform + identityModel + inputModel + outputModel` all non-null in `mergedExtracted`) is sufficient. Individual dimension tracking can silently fail due to LLM parse issues.
- **All LLM JSON list fields must use `is List<dynamic>` check, never hard cast `as List<dynamic>?`.** A hard cast throws `TypeError` if the LLM outputs a string (e.g., `"None"`, `"TBD"`); the outer try/catch then degrades the ENTIRE parse, discarding all extracted data for that turn. See BUG-INTERVIEW-004.
- **Model IDs stored in SharedPreferences must be validated against the current catalog on load.** Retired model IDs (e.g., `gemini-3.5-flash`) must fall back to the first valid model for that provider, not be passed to the API.
- **No executor starts without a complete project folder.** README, locked spec, bullet handoff, and setup worksheet must all exist.
- **`dart analyze` must be clean.** Zero new warnings before reporting done.
- **No committed secrets.**

---

*Last revised: 2026-06-20 — v1.3.0: Updated repo layout (Watch Mode §W1-§W4, ingestion, executor timeline), fixed key invariants for interview persistence and parse safety.*
