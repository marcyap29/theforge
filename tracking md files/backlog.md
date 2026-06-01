# The Forge — Feature Backlog

**Last Updated:** 2026-05-31

Long-term feature pool. Active sprint work lives in `planner.md`.

---

## How to use

- **Read first** when picking up new work — pull from High Priority before Medium before Low
- **Add to** when the user agrees a future feature should be done but is not the current focus
- **Mark shipped items** with `✅` and the date; do not delete
- **Do not remove items** without user approval

---

## Critical Path

```
Firestore schema → Flutter project state layer → Interview UI (Build mode)
→ Spec generation function → Artifact viewers → Workspace/billing
```

---

## High Priority

### §1 — Firestore Schema + Project Repository

**What it is:** Define and implement the `forge-projects` Firestore collection with all subcollections (specs, handoffs, worksheets, audit). The data layer everything else writes to.

**Why it matters:** Nothing else can be built without a stable schema. This is the foundation.

**Architecture:** `lib/data/firestore/forge_project_repository.dart` · Firestore rules · schema documented in `backend.md`

**Dependencies:** None — this is first.

**Status:** Not started

---

### §2 — Build Interview — Flutter UI + State

**What it is:** The conversational interview screen for greenfield builds. 8 confidence dimensions, visible confidence meter, conflict surfacing, scope pushback, max 3 questions per turn.

**Why it matters:** This is the core product. Everything else supports it.

**Architecture:** `lib/features/interview/` · Riverpod state · writes to Firestore on phase completion only

**Dependencies:** §1 (Firestore schema)

**Status:** Not started

---

### §3 — Spec Generation Firebase Function

**What it is:** Firebase Cloud Function that takes completed interview JSON and fires 3 parallel LLM calls (conservative t=0.2, balanced t=0.6, experimental t=1.0). Returns all three variants before any are revealed to the user.

**Why it matters:** The Monte Carlo architecture generation step — core differentiator.

**Architecture:** `functions/src/generateSpec.ts` · SwarmSpace credit billing · called from Flutter via Firebase Functions SDK

**Dependencies:** §1 (schema to write results into)

**Status:** Not started

---

### §4 — Project Folder Browser

**What it is:** Screen listing all active and past Forge projects. Resume from last phase — reads README state, most recent bullet handoff, current locked spec.

**Why it matters:** Multi-phase builds require coherent resumption. This is how The Forge remembers.

**Architecture:** `lib/features/projects/` · reads from Firestore project collection

**Dependencies:** §1 (Firestore), §2 (so there are projects to list)

**Status:** Not started

---

### §5 — Artifact Viewers (Spec, Handoff, Worksheet, Audit Log)

**What it is:** Read-only display screens for all four Forge outputs: locked spec, bullet handoff, setup worksheet, audit log.

**Why it matters:** Users and executor agents need to read these artifacts. They must be immutably presented — no edit affordance.

**Architecture:** `lib/features/spec_viewer/` · `lib/features/worksheets/` · reads from Firestore subcollections

**Dependencies:** §1, §3 (so there are artifacts to display)

**Status:** Not started

---

## Medium Priority

### §6 — Audit Interview Mode

**What it is:** The second interview mode — for existing teams and codebases. Different confidence dimensions (build state, feature ownership, blockers, decision debt, technical debt, AI token usage). Produces a Current State Spec, not a Locked Spec.

**Why it matters:** The enterprise use case. Fractional CTOs, team takeovers, Qualcomm-style scenarios.

**Architecture:** Extends `lib/features/interview/` with mode switching · new confidence dimension set · different Firestore spec type

**Dependencies:** §2 (Build Interview must exist first as the template)

**Status:** Not started

---

### §7 — Document Ingestion

**What it is:** Pre-interview doc ingestion — PDF, Word, Markdown. Extracts structured facts, scores initial confidence per dimension, skips established dimensions in the interview.

**Why it matters:** Teams with existing docs shouldn't be asked questions the docs already answer. Speeds enterprise onboarding significantly.

**Architecture:** `lib/features/interview/ingestion/` · Firebase Function for doc parsing

**Dependencies:** §2 (interview must exist to receive ingestion output)

**Status:** Not started

---

### §8 — Workspace + Billing

**What it is:** Workspace model ($150/workspace/month), seat management (up to 10), shared credit pool, credit top-up. Hooks into SwarmSpace billing infrastructure.

**Why it matters:** Required for monetization. SwarmSpace already has the billing rails — this is the connection layer.

**Architecture:** Firebase Functions · SwarmSpace credit API · `lib/features/billing/`

**Dependencies:** §3 (spec gen function must exist to consume credits)

**Status:** Not started

---

### §9 — Setup Worksheet Generation

**What it is:** Auto-generated step-by-step human checklist for every external service the build requires. Firebase, Google Places, Stripe, etc. Includes environment variables table for executor agents.

**Why it matters:** Eliminates hours of console navigation and credential misconfiguration before a build starts.

**Architecture:** Generated during spec phase · stored in Firestore `/worksheets/` · displayed via §5 artifact viewer

**Dependencies:** §3 (generated as part of spec phase)

**Status:** Not started

---

## Low Priority

### §10 — Open Source Executor Path

**What it is:** The locked spec is tool-agnostic JSON. A manifest mapping layer that allows any executor agent (open source runtimes, self-hosted) to consume a Forge spec without routing through commercial APIs.

**Why it matters:** Clients with data sovereignty requirements or cost-at-scale needs. Forward direction — not a launch feature.

**Dependencies:** §3, §5 (spec format must be stable)

**Status:** Future / not started

---

### §11 — Audit Trail Export

**What it is:** Exportable, versioned audit trail package — full interview transcript, all variants (including rejected), user selections and reasons, locked spec at point of approval, all handoff artifacts.

**Why it matters:** Compliance, reproducibility, client deliverables for dev shops.

**Dependencies:** §1, §5

**Status:** Future / not started

---

## Completed ✅

*(none yet — initial backlog)*

---

*Sequence items so each tier unblocks the next. §1 → §2 → §3 is the critical path to a first working interview.*
