# The Forge — Architecture

**Version:** 1.0.0
**Last Updated:** 2026-05-31

---

## What It Is

The Forge is a standalone Flutter desktop app (macOS primary). It is the project management layer for AI-assisted development — sitting above executor agents (Claude Code, Codex, Cursor) and producing the locked specs those agents build against.

It is positioned as SwarmSpace's enterprise tier but is its own product with its own codebase. It shares Firebase infrastructure (same project: `arc-epi`) and calls SwarmSpace's spec generation API, but is not bundled into either LUMARA or SwarmSpace.

---

## Stack

| Layer | Technology |
|---|---|
| Desktop app | Flutter (macOS primary, iOS/Android future) |
| State management | Riverpod |
| Backend database | Firebase Firestore |
| Backend functions | Firebase Cloud Functions (TypeScript) |
| Spec generation API | SwarmSpace (LLM routing + credit billing) |
| Auth | Firebase Auth (email/password + Google OAuth) |
| Linter | `dart analyze lib/` |

---

## Repository Layout

```
The Forge/
├── lib/
│   ├── core/                        — App bootstrap, routing, theme, DI
│   ├── features/
│   │   ├── interview/               — Interview session (the core product)
│   │   │   ├── state/               — Riverpod providers + session cubit
│   │   │   ├── ui/                  — Interview screen, confidence meter, conflict UI
│   │   │   └── ingestion/           — Doc ingestion (future §7)
│   │   ├── projects/                — Project folder browser + resume
│   │   ├── spec_viewer/             — Read-only locked spec display
│   │   └── worksheets/              — Setup worksheet display
│   ├── data/
│   │   ├── firestore/               — Firestore repository layer
│   │   │   └── forge_project_repository.dart
│   │   └── swarmspace/              — SwarmSpace API client
│   │       └── swarmspace_client.dart
│   └── shared/                      — Shared widgets, models, utils, extensions
├── functions/                       — Firebase Cloud Functions
│   └── src/
│       └── generateSpec.ts          — Monte Carlo spec generation (3 parallel LLM calls)
├── DOCS/
│   └── forge/
│       ├── workflow_template.md     — The Forge interview + spec protocol (v3)
│       └── positioning_brief.md    — Product positioning and pricing
├── tracking md files/
├── agents md files/
├── operations md files/
├── bugtracker/
├── backend.md
└── claude.md
```

---

## Firestore Schema

```
forge-projects/{projectId}/
  (root doc)
    name: string
    mode: "build" | "audit"
    currentPhase: "v1_interview" | "v1_build" | "v2_interview" | ...
    specVersion: string           — "v1", "v2", etc.
    setupWorksheetComplete: bool
    createdAt: timestamp
    updatedAt: timestamp
    ownerId: string               — Firebase Auth uid
    workspaceId: string           — billing workspace

  specs/{specVersion}/
    (locked spec document — immutable after write)
    content: string               — full spec markdown
    handoffPackage: map           — JSON handoff schema
    lockedAt: timestamp
    interviewMode: "build" | "audit"

  handoffs/{id}/
    phase: string                 — "interview_to_spec", "spec_to_executor", etc.
    content: string               — bullet handoff markdown
    createdAt: timestamp
    specVersion: string

  worksheets/{version}/
    content: string               — setup worksheet markdown
    complete: bool
    createdAt: timestamp

  audit/log
    (single document, array field — append only, never overwritten)
    entries: [
      {
        phase: string
        interviewMode: string
        date: timestamp
        runId: string
        creditCost: number
        decisions: [{ decision, chosen, confidence }]
        conflictsSurfaced: [string]
        scopeChanges: [string]
      }
    ]
```

---

## Core Subsystems

### Interview Engine (`lib/features/interview/`)

The conversational UI that drives The Forge's value. Runs in two modes:

- **Build mode** — 8 dimensions: core purpose, primary user, identity model, input model, output model, platform, scope boundary, external services
- **Audit mode** — 8 dimensions: project goal, build state, feature ownership, active blockers, blocker blast radius, decision debt, technical debt, AI/token usage

Rules:
- Max 3 questions per turn
- Only questions that materially change the architecture
- Conflict detection stops the interview before proceeding
- Conservative defaults recommended when user is uncertain
- Never accept "all of the above" without pressure-testing

All state lives in Riverpod during the session. Nothing written to Firestore mid-interview. On phase completion (user confirms spec), the full interview state serializes and writes to Firestore in a single transaction.

### Spec Generator (`functions/src/generateSpec.ts`)

Firebase Cloud Function. Receives completed interview JSON. Fires 3 parallel LLM calls:

| Variant | Temperature | Approach |
|---|---|---|
| Conservative | 0.2 | Lowest-risk, proven patterns, minimal surface area |
| Balanced | 0.6 | Pragmatic tradeoffs between stability and capability |
| Experimental | 1.0 | Highest-ceiling, more novel approaches |

All three complete before any are revealed. User evaluates simultaneously and selects one (or nominates a hybrid). Credits billed via SwarmSpace on function completion.

### Project Store (`lib/data/firestore/forge_project_repository.dart`)

Thin repository wrapping Firestore. Enforces:
- Immutable spec writes (no update path, only create)
- Append-only audit log
- Phase-gated writes (interview must be complete before spec can be written)

### Artifact Viewers (`lib/features/spec_viewer/`, `lib/features/worksheets/`)

Read-only. No edit affordance. Locked specs are displayed with a visual "LOCKED" indicator and the timestamp of locking. Bullet handoffs and audit log entries are timestamped and non-interactive.

---

## Data Flow

```
User starts interview
  → Interview Engine (Flutter Riverpod state)
  → User answers questions across N turns
  → 8 confidence dimensions reach 100%
  → User confirms scope + out-of-scope list
  → Flutter serializes complete interview state to JSON
  → POST to generateSpec Firebase Function
      → 3 parallel LLM calls (t=0.2, 0.6, 1.0)
      → All three variants returned
  → User selects variant (or hybrid)
  → Locked spec written to Firestore (immutable)
  → Bullet handoff written to Firestore
  → Setup worksheet generated + written to Firestore
  → Audit log entry appended
  → Project README state updated
  → Credits deducted via SwarmSpace
```

---

## Cross-Repo Dependencies

| Dependency | What it provides | Repo |
|---|---|---|
| Firebase project `arc-epi` | Firestore, Auth, Functions hosting | Shared with LUMARA + SwarmSpace |
| SwarmSpace spec gen API | LLM routing for 3-variant generation | `swarmspace` repo |
| SwarmSpace credit system | Billing per Forge run | `swarmspace` repo |

The Forge does not import or embed code from LUMARA or SwarmSpace. It calls their APIs over HTTP. All shared state is in Firestore.

---

*Version 1.0.0 — Initial architecture. Update when subsystems change.*
