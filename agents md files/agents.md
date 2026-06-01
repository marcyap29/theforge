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

**Before changing Firestore schema, spec generation logic, or auth:**
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
| **backend.md** | Firebase + SwarmSpace API | `backend.md` |
| **CONFIGURATION_MANAGEMENT.md** | Docs inventory and change log | `operations md files/CONFIGURATION_MANAGEMENT.md` |
| **bugtracker/** | Bug index, prevention, records | `bugtracker/README.md` |
| **context.md** | Session log — read first every session | `tracking md files/context.md` |
| **workflow_template.md** | The Forge interview + spec protocol | `DOCS/forge/workflow_template.md` |
| **positioning_brief.md** | Product positioning and pricing | `DOCS/forge/positioning_brief.md` |

---

## Architecture Overview

### The Forge — High-Level Architecture

**What it is:** A standalone Flutter desktop app (macOS primary). The PM layer for AI-assisted development — structured interview → locked spec → executor handoff.

**Tech stack:** Flutter · Dart · Firebase (Firestore + Cloud Functions) · SwarmSpace API (spec generation, credit billing)

**Repository layout:**
```
The Forge/
├── lib/                        — Flutter app source
│   ├── core/                   — App bootstrap, routing, theme
│   ├── features/
│   │   ├── interview/          — Interview session UI + state
│   │   ├── projects/           — Project folder browser + resume
│   │   ├── spec_viewer/        — Read-only locked spec display
│   │   └── worksheets/         — Setup worksheet display
│   ├── data/
│   │   ├── firestore/          — Firestore read/write layer
│   │   └── swarmspace/         — SwarmSpace API client
│   └── shared/                 — Shared widgets, models, utils
├── functions/                  — Firebase Cloud Functions (spec generation)
├── DOCS/
│   └── forge/                  — The Forge protocol docs (workflow, brief)
├── tracking md files/          — context.md, planner.md, backlog.md, etc.
├── agents md files/            — SOPs and agent guidance
├── operations md files/        — startup.md, CONFIGURATION_MANAGEMENT.md
├── bugtracker/                 — Bug tracker index and records
├── backend.md                  — Firebase + SwarmSpace reference
└── claude.md                   — Claude entry point
```

**Core subsystems:**

- **Interview Engine** (`lib/features/interview/`) — Conversational UI driving the 8-dimension confidence model. Holds all session state in Flutter (Riverpod). Writes to Firestore only on phase completion.
- **Project Store** (`lib/data/firestore/`) — Firestore read/write for forge-projects collection. Append-only audit trail. Immutable spec writes.
- **Spec Generator** (`functions/`) — Firebase Cloud Function. Receives completed interview JSON, fires 3 parallel LLM calls (conservative/balanced/experimental), returns variants. Billed via SwarmSpace credits.
- **SwarmSpace Client** (`lib/data/swarmspace/`) — API client for spec generation calls and credit tracking.
- **Artifact Viewers** (`lib/features/spec_viewer/`, `lib/features/worksheets/`) — Read-only display of locked specs, bullet handoffs, setup worksheets, audit log.

**Key data flow:**
```
Interview (Flutter state) → Phase complete → Firestore write
                                          → SwarmSpace spec gen call
                                          → Variants returned → User selects
                                          → Locked spec written (immutable)
                                          → Audit log appended
```

**Firestore schema:**
```
forge-projects/{projectId}/
  ├── (doc)                    — metadata: name, mode, phase, createdAt, updatedAt
  ├── specs/{specVersion}      — immutable locked spec documents
  ├── handoffs/{id}            — bullet handoffs at each phase transition
  ├── worksheets/{version}     — setup worksheets
  └── audit/log                — append-only run log (never modified)
```

---

## Key Service Locations

| Service / Module | Path | Notes |
|---|---|---|
| Interview session cubit/bloc | `lib/features/interview/` | Holds all mid-interview state |
| Firestore project layer | `lib/data/firestore/forge_project_repository.dart` | All Firestore reads/writes |
| SwarmSpace API client | `lib/data/swarmspace/swarmspace_client.dart` | Spec gen + credit calls |
| Spec generation function | `functions/src/generateSpec.ts` | Firebase Function, 3-parallel LLM |
| Project browser | `lib/features/projects/` | List + resume projects |

---

## Coding Standards

- **State management:** Riverpod (matching LUMARA patterns)
- **Naming:** snake_case files, PascalCase classes, camelCase methods
- **Error handling:** Explicit typed exceptions; never swallow errors silently
- **Imports:** Relative imports within a feature; absolute for cross-feature
- **Linter command:** `dart analyze lib/`
- **No committed secrets:** Firebase config and API keys via `.env` (gitignored)

---

## Key Invariants

- **Locked specs are immutable.** Never modify a written spec. Amendments produce a new versioned document.
- **Audit trail is append-only.** The `/audit/log` Firestore doc is only ever appended — never overwritten.
- **Interview state stays in Flutter.** Do not push mid-interview state to Firestore. Write only on phase completion.
- **No executor starts without a complete project folder.** README, locked spec, bullet handoff, and setup worksheet must all exist.
- **`dart analyze` must be clean.** Zero new warnings before reporting done.
- **No committed secrets.**

---

*Last revised: 2026-05-31 — Initial setup.*
