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
│   ├── core/                        — App bootstrap, routing, theme, DI
│   ├── features/
│   │   ├── interview/               — Interview session (the core product)
│   │   │   ├── state/               — Riverpod providers + session state
│   │   │   └── ui/                  — Interview screen, confidence meter, conflict UI
│   │   ├── projects/                — Project folder browser + resume
│   │   ├── spec_viewer/             — Read-only locked spec display
│   │   ├── worksheets/              — Setup worksheet display
│   │   └── settings/                — LLM provider configuration
│   ├── data/
│   │   ├── filesystem/              — Local file read/write layer
│   │   │   └── project_file_repository.dart
│   │   ├── local_db/                — SQLite index (drift)
│   │   │   └── forge_database.dart
│   │   ├── spec_generation/         — Provider abstraction + implementations
│   │   │   ├── spec_generation_provider.dart
│   │   │   └── providers/
│   │   │       ├── claude_provider.dart
│   │   │       ├── openai_provider.dart
│   │   │       ├── ollama_provider.dart
│   │   │       ├── swarmspace_provider.dart
│   │   │       └── custom_provider.dart
│   │   └── swarmspace/              — SwarmSpace billing client (SwarmSpace routing only)
│   └── shared/                      — Shared widgets, models, utils, extensions
├── DOCS/
│   └── forge/                       — workflow_template.md, positioning_brief.md
├── tracking md files/               — context.md, planner.md, backlog.md, etc.
├── agents md files/                 — SOPs and agent guidance
├── operations md files/             — startup.md, CONFIGURATION_MANAGEMENT.md
├── bugtracker/                      — Bug tracker index and records
├── backend.md                       — Storage model + provider reference
└── claude.md                        — Claude entry point
```

**Core subsystems:**

- **Interview Engine** (`lib/features/interview/`) — Conversational UI driving the 8-dimension confidence model. Holds all session state in Riverpod. Nothing written to disk mid-interview — only on phase completion.
- **Project File Repository** (`lib/data/filesystem/project_file_repository.dart`) — All local file reads and writes. Enforces write-once specs, append-only audit log, atomic writes via temp+rename.
- **SQLite Index** (`lib/data/local_db/forge_database.dart`) — Lightweight project browser cache. Rebuilds from filesystem scan if stale or missing.
- **SpecGenerationProvider** (`lib/data/spec_generation/`) — Abstract interface for all LLM calls. 5 implementations: Claude, OpenAI, Ollama, SwarmSpace, Custom. Monte Carlo strategy (3 parallel calls at t=0.2/0.6/1.0) lives in the interview engine, not the providers.
- **Artifact Viewers** (`lib/features/spec_viewer/`, `lib/features/worksheets/`) — Read-only display of local files. Locked specs render with a "LOCKED" badge.

**Key data flow:**
```
Interview (Riverpod state) → Phase complete
  → SpecGenerationProvider.generateVariants() — 3 parallel LLM calls
  → User selects variant
  → ProjectFileRepository writes to disk:
      specs/{ProjectName}_LockedSpec_v1.md      (immutable — checked before write)
      handoffs/{ProjectName}_BulletHandoff_v1_Interview.md
      worksheets/{ProjectName}_SetupWorksheet_v1.md
      handoff_package_v1.json
      audit/{ProjectName}_AuditLog.md           (appended, never replaced)
      README.md                                  (updated with new phase state)
  → SQLite index updated
  → If SwarmSpace provider: credits deducted via SwarmSpace API
```

**Local file structure (per project):**
```
~/Documents/The Forge Projects/{ProjectName}/
  ├── README.md
  ├── specs/
  │   └── {ProjectName}_LockedSpec_v1.md   — immutable after creation
  ├── handoffs/
  ├── worksheets/
  ├── handoff_package_v1.json
  └── audit/
      └── {ProjectName}_AuditLog.md        — append-only
```

---

## Key Service Locations

| Service / Module | Path | Notes |
|---|---|---|
| Interview session state | `lib/features/interview/state/` | Riverpod providers, holds all mid-interview state |
| Project file repository | `lib/data/filesystem/project_file_repository.dart` | All local file reads/writes |
| SQLite index | `lib/data/local_db/forge_database.dart` | Project browser cache |
| SpecGenerationProvider interface | `lib/data/spec_generation/spec_generation_provider.dart` | Abstract interface |
| Provider implementations | `lib/data/spec_generation/providers/` | Claude, OpenAI, Ollama, SwarmSpace, Custom |
| SwarmSpace billing client | `lib/data/swarmspace/swarmspace_client.dart` | Credits, SwarmSpace routing only |
| Project browser | `lib/features/projects/` | List + resume projects |
| Settings | `lib/features/settings/` | Provider config, API key entry |

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
- **Interview state stays in Flutter.** Do not write to disk mid-interview. Write only on phase completion.
- **No executor starts without a complete project folder.** README, locked spec, bullet handoff, and setup worksheet must all exist.
- **`dart analyze` must be clean.** Zero new warnings before reporting done.
- **No committed secrets.**

---

*Last revised: 2026-05-31 — v1.1.0: Updated to local-first filesystem architecture, SpecGenerationProvider interface, Firebase demoted to optional workspace-tier sync.*
