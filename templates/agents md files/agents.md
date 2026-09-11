<!-- TEMPLATE — replace {{PLACEHOLDERS}} and delete this line. Part of the Docs Templates system. -->
# Agent Instructions — {{PROJECT_NAME}}

## For each prompt / task

1. Create an agent that analyzes the prompt, plans how to fulfill it, and breaks work into sub-tasks assignable to sub-agents. The overseer defines **definition of done** before assigning work.
2. Create enough sub-agents to handle the tasks.
3. Assign each sub-agent its sub-tasks.
4. Create a review agent that shares the definition of done and reviews completed work as sub-agents finish.
5. When implementation is complete, output a short summary and review.

---

## {{PROJECT_NAME}} — Documentation Context Guide

**Purpose:** Orient assistants and contributors to this repo.

**Repository root:** `{{REPO_ROOT}}`

**Before changing {{HIGH_RISK_AREAS — e.g. core data layer, generation logic, provider implementations}}:**
- Read the project's bug-prevention notes and skim the bug tracker when the area matches.

---

## Quick Reference

<!-- Fill in one row per canonical doc in this repo. Delete rows that don't apply. -->

| Document | Purpose | Path |
|----------|---------|------|
| **{{ENTRY_POINT_DOC}}** | Agent/assistant entry point and SOP | `{{PATH}}` |
| **ARCHITECTURE** | System architecture | `{{PATH}}` |
| **FEATURES** | Feature catalog | `{{PATH}}` |
| **UI_UX** | UI/UX patterns | `{{PATH}}` |
| **CHANGELOG** | Version history | `{{PATH}}` |
| **backend** | Storage model, providers, API reference | `{{PATH}}` |
| **CONFIGURATION_MANAGEMENT** | Docs inventory and change log | `{{PATH}}` |
| **bug tracker** | Bug index, prevention, records | `{{PATH}}` |
| **context / session log** | Read first every session | `{{PATH}}` |

---

## Architecture Overview

### {{PROJECT_NAME}} — High-Level Architecture

**What it is:** {{ONE-TO-TWO SENTENCE DESCRIPTION — what the app does and its primary platform.}}

**Tech stack:** {{STACK — languages, frameworks, state management, storage, external services}}

**Repository layout:**
```
{{PROJECT_NAME}}/
├── {{dir}}/                 — {{one-line purpose}}
│   ├── {{subdir}}/          — {{one-line purpose}}
│   └── {{file}}             — {{one-line purpose}}
├── {{dir}}/                 — {{one-line purpose}}
└── {{entry_point_file}}     — {{one-line purpose}}
```
<!-- Replace the tree above with the real top-level layout. Keep it to the directories a
     newcomer needs to navigate the codebase; do not enumerate every file. -->

**Core subsystems:**
<!-- One bullet per subsystem: name, path, and the single most important thing to know
     about it (its contract, invariant, or responsibility). -->

- **{{Subsystem 1}}** (`{{path}}`) — {{what it does + the key contract/invariant}}
- **{{Subsystem 2}}** (`{{path}}`) — {{what it does + the key contract/invariant}}
- **{{Subsystem 3}}** (`{{path}}`) — {{what it does + the key contract/invariant}}

**Key data flow:**
```
{{Entry point / trigger}}
  → {{step}}
  → {{step}}
  → {{persisted output / side effect}}
```
<!-- Replace with the primary end-to-end flow: what happens from a user action to the
     durable result (files written, DB rows changed, API calls made). -->

**{{Local data / storage structure}}:**
```
{{root path or namespace}}/
  ├── {{artifact}}           — {{purpose / lifecycle note}}
  └── {{artifact}}           — {{purpose / lifecycle note}}
```
<!-- If the app persists structured data (files, tables, buckets), describe the shape
     and note anything immutable or append-only. Delete this block if not applicable. -->

---

## Key Service Locations

<!-- Map each major service/module to its path and a one-line note. This is the fast
     lookup table for "where does X live?". -->

| Service / Module | Path | Notes |
|---|---|---|
| {{Service}} | `{{path}}` | {{note}} |
| {{Service}} | `{{path}}` | {{note}} |
| {{Service}} | `{{path}}` | {{note}} |

---

## Coding Standards

<!-- Keep these; edit to match the project's real conventions. -->

- **State management / architecture pattern:** {{PATTERN}}
- **Naming:** {{file / class / method conventions}}
- **Error handling:** Explicit typed exceptions; never swallow errors silently
- **Imports:** {{project import convention}}
- **Linter command:** `{{LINT_COMMAND}}`   <!-- e.g. `dart analyze lib/` -->
- **No committed secrets:** {{Where secrets live and where they must NOT go.}}

---

## Key Invariants

<!-- The rules that must never be broken. Each should be phrased as an absolute a
     reviewer can check. Replace the examples below with the project's real invariants. -->

- **{{Immutability rule — e.g. "Locked artifacts are never modified; amendments produce a new versioned file. Check existence before write."}}**
- **{{Append-only rule — e.g. "Audit log is append-only. Never truncate or replace."}}**
- **{{Persistence rule — where durable state lives and when it is written.}}**
- **{{Parse-safety / defensive rule — any known footgun with external/LLM/user input.}}**
- **{{Preconditions — what must exist before a downstream step may run.}}**
- **`{{LINT_COMMAND}}` must be clean.** Zero new warnings before reporting done.
- **No committed secrets.**

---

*Last revised: YYYY-MM-DD — {{version / summary of change}}.*
