# The Forge — Agent Workflow Template

**Version:** 3.0
**Status:** Reference Document
**Purpose:** Defines the standard workflow The Forge follows when working with agents. Use ForkIt as the worked example for the Build Interview. Use the Qualcomm team takeover scenario as the worked example for the Audit Interview.

-----

## Overview

The Forge is a structured multi-phase process that acts as a project manager — pushing back on scope, surfacing conflicts, forcing prioritization decisions, and producing a written record that every agent builds against.

The Forge operates in two interview modes:

| Mode | When to use | Output |
|---|---|---|
| **Build Interview** | Greenfield build — nothing exists yet | Locked Spec defining what to build |
| **Audit Interview** | Existing team or codebase — establish current state | Current State Spec as a locked baseline |

Every Forge run produces four outputs:

| Output | What it is | Who it's for |
|---|---|---|
| **Locked Spec** | Immutable architecture or current state document | Executor agents / team lead |
| **Bullet Handoff** | Human-scannable phase transition summary | The Forge (on resume) + the user |
| **Setup Worksheet** | Human-action checklist for external services | The user |
| **Handoff Package** | JSON summary of the run | Next agent or session |

-----

## Stage 0 — Project Folder Creation

### Folder Structure

```
/{ProjectName}/
  /specs/
    {ProjectName}_LockedSpec_v1.md
    {ProjectName}_LockedSpec_v2.md
  /handoffs/
    {ProjectName}_BulletHandoff_v1_Interview.md
    {ProjectName}_BulletHandoff_v1_SpecToExecutor.md
    {ProjectName}_BulletHandoff_v1_Agent1toAgent2.md
  /worksheets/
    {ProjectName}_SetupWorksheet_v1.md
  /ingested/
    {SourceDoc}_ingested.md
    {ProjectName}_IngestionSummary.md
  /audit/
    {ProjectName}_AuditLog.md
  README.md
```

### README.md Format

```markdown
# {ProjectName} — Project State

**Interview mode:** [Build / Audit]
**Current phase:** [v1 build / v2 interview / etc.]
**Last updated:** [date]
**Spec version:** [v1 / v2 / etc.]
**Setup worksheet:** [Complete / Incomplete]
**Executor status:** [Not started / In progress / Complete]

## What's Done
- [bullet list of completed phases and decisions]

## What's Next
- [next action for the Forge or executor]

## Open Flags
- [any unresolved items from the current spec]
```

### Naming Convention

```
{ProjectName}_LockedSpec_v{N}.md
{ProjectName}_BulletHandoff_v{N}_{Phase}.md
{ProjectName}_SetupWorksheet_v{N}.md
{ProjectName}_AuditLog.md         ← single file, appended not versioned
```

-----

## The Bullet Handoff

Write a bullet handoff at every phase transition:
- Interview complete → spec generation begins
- Spec locked → executor agents begin
- Agent N complete → Agent N+1 begins
- Phase complete → next phase interview begins

### Format

```markdown
# {ProjectName} — Bullet Handoff
**Phase:** [Interview -> Spec / Spec -> Executor / Agent 1 -> Agent 2 / v1 -> v2]
**Interview mode:** [Build / Audit]
**Date:** [date]
**Spec version:** [v1]
**Completion Criteria met:** [list criteria that were verified complete, or "N/A — pre-execution handoff"]

## What Was Decided
- [decision made]

## What Was Explicitly Deferred
- [item deferred + reason]

## Open Items
- [unresolved flag + recommended default]

## What the Next Agent or Session Needs to Know
- [critical context]
```

### ForkIt Example — Build Interview to Spec

```markdown
# ForkIt — Bullet Handoff
**Phase:** Interview -> Spec Generation
**Interview mode:** Build
**Date:** 2026-05-30
**Spec version:** v1

## What Was Decided
- Core product: swiping/restaurant decision tool only (not dating)
- No accounts — ephemeral sessions via share link
- Swipe on cuisine types (abstract), not dishes or restaurants
- Match by plurality: most right-swipes across group wins
- Show ranked list of 3-5 restaurants after match
- Firebase RTDB for real-time sync, Firebase Anonymous Auth
- Google Places Nearby Search for restaurant resolution
- iOS only, Flutter, Riverpod state management
- Host device location used for restaurant search (v1)

## What Was Explicitly Deferred
- Dating / singles / mingling layer
- Android
- User accounts and profiles
- Group location centroid
- Session history

## Open Items
- Session size limit (recommended default: 8)
- Session TTL (recommended default: 24h)
- Restaurant search radius (recommended default: 5km)

## What the Next Agent Needs to Know
- Spec is locked and immutable — do not accept scope additions without a new interview
- Setup Worksheet must be complete before executor starts
- Dating layer is v2 — if the user raises it during the build, document as v2 seed item
```

-----

## Stage 1A — Build Interview

### Goal

Reach a locked V1 spec by deduction, not coverage. Four layers, each unlocks
the next. The interviewer does not advance until the layer's exit condition
is met.

### Rules

- Ask ONE question per turn
- Ask only questions whose answers materially change the architecture
- Push back on conflicts before proceeding — do not silently resolve them
- Make conservative default recommendations when the user is uncertain
- Never accept "all of the above" without pressure-testing it

### The Four Layers

**L1 — Outcome:** Establish the one thing this app does for its user that
nothing they use today does, and who that user is. Exit: interviewer restates
it as "For [user], this app [outcome]" and the user confirms.

**L2 — Decomposition:** Get the 3-5 capabilities required to deliver L1.
Push back on lists over 5 and on anything that doesn't trace to the outcome.
Exit: confirmed list.

**L3 — PoC Reduction:** Force the choice of ONE capability as proof, then
get a 3-5 step demo script ("open the app, do X, see Y"). Every capability
not chosen and every feature mentioned but absent from the demo goes on the
v2 seed list. Read the seed list back for confirmation. Exit: capability
chosen, demo confirmed, seeds confirmed.

**L4 — Critical Path:** Do not ask open questions here. Deduce platform,
identity, input, output, and services from the demo script and propose
conservative defaults the user confirms or corrects. Identity defaults to
none. Run the blocker scan: ask what they already have set up, then propose
stripping every external service that is not itself the chosen capability
(local storage over cloud, mocks over live APIs, no auth over OAuth). Draft
the 1-3 step sequence to a working demo and ask them to correct it. Exit: all
defaults confirmed or overridden, blocker scan done, sequence confirmed.

### The 8 Invariants

The 8 confidence dimensions survive as spec invariants. The funnel decides
how each is resolved:

| Invariant | Where it gets resolved |
|---|---|
| Core purpose | L1 |
| Primary user | L1 |
| Identity model | L4 confirmation (default: none) |
| Input model | L4, read off demo steps |
| Output model | L4, read off demo steps |
| Platform | L4 confirmation |
| Scope boundary | L3 auto-deferral (default-closed) |
| External services | L4 blocker scan |

All 8 must be present in the locked spec. If L3's cut leaves an invariant
thin (a demo that never touches identity, say), the spec records the
conservative default and the reasoning in Accepted Decisions.

### Conflict Detection

When the user's answers conflict with each other, stop and surface the conflict:

> "Your answers on [X] and [Y] pull in opposite directions. [X] implies [consequence]. [Y] implies [different consequence]. I recommend [conservative option] for v1 because [reason]. Do you accept this scope?"

Do not proceed until the user confirms.

### Completion Criteria

- L1 sentence confirmed
- L2 capability list (3-5) confirmed
- L3 chosen capability + demo script (3-5 steps) confirmed
- L3 v2 seed list confirmed
- L4 architectural defaults confirmed or overridden
- L4 blocker scan complete
- All 8 invariants resolved
- All conflicts resolved

-----

## Stage 1B — Audit Interview

### When to Use

Use when an existing team or codebase is the subject. The goal is to establish current state, not define what to build. The primary use case: a team lead or principal engineer taking over one or more teams.

### Confidence Dimensions

| Dimension | Question to resolve |
|---|---|
| Project goal | What is this project actually trying to do, stated plainly? |
| Current build state | What is shipped, what is in progress, what has not started? |
| Feature ownership | Which engineer or sub-team owns each feature or component? |
| Active blockers | What is currently stuck, and for how long? |
| Blocker blast radius | Which other features, engineers, or teams are blocked downstream? |
| Decision debt | What architectural or product decisions were made without documentation? |
| Technical debt | What known shortcuts or deferred fixes exist, where, and who knows? |
| AI and token usage | Which engineers are using AI agents, on what tasks, at what approximate spend? |

### Conflict Detection

Doc/verbal conflicts are treated as Decision Debt until resolved:

> "[Document X] states [claim]. You've described [different claim]. I'm recording both. Which reflects current state, and when did this change?"

### Completion Criteria

- All 8 dimensions at Established or Partial (with gaps noted)
- All doc/verbal conflicts surfaced and recorded
- Feature ownership named to an individual, not a team, wherever possible
- Blocker blast radius mapped for every active blocker

-----

## Stage 2 — Spec Generation

### Build Interview → Locked Spec

Rules:
- The spec is immutable from the moment it is written
- Amendments produce a new versioned spec — nothing is overwritten
- Every decision includes: what was chosen, what was rejected, reasoning, and confidence rating
- Open flags are documented, not silently defaulted

**Spec Structure:**
```
1. Immutable Goal Statement
2. Hard Constraints Table
3. Component Map (single responsibility per component)
4. Interface Contracts (input/output per component)
5. Completion Criteria
6. Static Content Specs (if applicable)
7. Explicit Out-of-Scope List
8. Accepted Decisions (with reasoning + confidence)
9. Open Flags (to be resolved before or during build)
10. v2 Architecture Notes
11. Handoff Package (JSON)
```

**Completion Criteria Format**

The Completion Criteria section is what separates a spec from a /goal.
Each criterion must be verifiable by an executor or judge agent without
human input.

```
| Criterion | Component | How to verify |
| [what must be true when done] | [which component] | [command, check, or observable the agent can run] |
```

Rules:
- Every criterion must be checkable by the agent autonomously
- Prefer `dart analyze`, test commands, and file existence checks over
  subjective descriptions
- If a criterion requires human judgement, it is an Open Flag, not a
  Completion Criterion

### Audit Interview → Current State Spec

**Current State Spec Structure:**
```
1. Project Goal Statement (as understood at time of audit)
2. Current Build State (shipped / in progress / not started)
3. Component and Feature Map with Owner Names
4. Active Blocker Registry
5. Decision Debt Log
6. Technical Debt Log
7. AI and Token Usage Summary
8. Documentation Gaps
9. Confidence Map (per dimension: Established / Partial / Unknown)
10. Next Phase Seeds
11. Handoff Package (JSON)
```

### Accepted Decisions Format (Build mode)

| Decision | Chosen | Rejected | Reasoning | Confidence |
|---|---|---|---|---|
| [What was decided] | [The choice] | [What was not chosen] | [Why] | High / Medium / Low |

### Open Flags Format

| Flag | Component | Options | Recommended default |
|---|---|---|---|
| [What needs deciding] | [Which component] | [The options] | [What to build first] |

-----

## Stage 3 — Setup Worksheet Generation

Generate a Setup Worksheet for every Forge run that touches at least one external service.

### Worksheet Structure

```
1. Before You Start (time estimate, prerequisites)
2. One section per external service
   - Account / project creation
   - Feature enablement
   - API key / credential generation
   - Restriction / security configuration
   - Values to copy out
3. Local project configuration
4. Environment Variables Table (for executor agent)
5. Verification Checklist
6. What Happens Next
7. Free Tier Reference
```

-----

## Stage 4 — Handoff Package

### Schema — Build Mode

```json
{
  "interviewMode": "build",
  "specVersion": "string",
  "appName": "string",
  "platform": "string",
  "framework": "string",
  "lockedAt": "ISO date",
  "goalStatement": "string",
  "components": ["string"],
  "infrastructure": { "service": "implementation" },
  "stateManagement": "string",
  "openFlags": "number",
  "outOfScopeItems": "number",
  "setupWorksheetComplete": "bool",
  "v2SeedItems": ["string"]
}
```

### Schema — Audit Mode

```json
{
  "interviewMode": "audit",
  "specVersion": "string",
  "projectName": "string",
  "auditDate": "ISO date",
  "goalStatement": "string",
  "buildState": {
    "shipped": ["string"],
    "inProgress": ["string"],
    "notStarted": ["string"]
  },
  "activeBlockers": "number",
  "decisionDebtItems": "number",
  "technicalDebtItems": "number",
  "documentationGaps": "number",
  "confidenceMap": {
    "projectGoal": "Established | Partial | Unknown",
    "buildState": "Established | Partial | Unknown",
    "featureOwnership": "Established | Partial | Unknown",
    "activeBlockers": "Established | Partial | Unknown",
    "blockerBlastRadius": "Established | Partial | Unknown",
    "decisionDebt": "Established | Partial | Unknown",
    "technicalDebt": "Established | Partial | Unknown",
    "aiTokenUsage": "Established | Partial | Unknown"
  },
  "docConflictsSurfaced": "number",
  "v2SeedItems": ["string"]
}
```

-----

Stage 4b — /goal Text Output

The /goal text is a fifth output generated alongside the JSON Handoff
Package. It is derived from the locked spec — not a new document, but a
formatted view of the spec written for an autonomous executor harness
(Claude Code /goal, OpenAI Codex, or equivalent).

The user pastes this directly into their executor harness to start the
build loop.

Format

```
# /goal — {ProjectName} v{N}

## Outcome
{Immutable Goal Statement from the locked spec}

## Completion Criteria
{Each criterion from the Completion Criteria section as a checkable item}

## Constraints
{Hard Constraints table — condensed to the non-negotiables}

## Boundaries
- Files: {component file list from the spec}
- Tools: {allowed tools and APIs}
- Off-limits: {explicit out-of-scope list}

## Iteration Policy
Work at low temperature. Resolve ambiguity conservatively. When uncertain
between two valid approaches, choose the one with less surface area. Flag
decisions you are not confident in rather than guessing.

## Stop Conditions
Stop and surface a blocker if:
- A completion criterion cannot be met without a decision not in this spec
- A required external service is unavailable or misconfigured
- The Setup Worksheet variables are missing or invalid

Do not stop because the work is hard. Stop only when genuinely blocked.
```

Write the /goal text to: `/handoffs/{ProjectName}_goal_v{N}.md`

-----

## Stage 5 — Executor Handoff

### Build Mode Checklist

- [ ] Project folder created and README.md current
- [ ] Locked spec written and immutable, filed in /specs/
- [ ] Bullet handoff written for Interview → Spec transition
- [ ] Setup Worksheet complete and all variables filled in
- [ ] Handoff package JSON generated
- [ ] Audit log entry written
- [ ] `setupWorksheetComplete` is `true` in the handoff package
- [ ] All open flags have recommended defaults noted
- [ ] User has confirmed scope
- [ ] Completion Criteria section populated — each criterion verifiable
  by executor without human input
- [ ] /goal text generated and written to `/handoffs/{ProjectName}_goal_v{N}.md`

The executor agent runs at t=0.1. No creative deviation from the locked spec permitted.

-----

## Worked Example Index

| Document | Mode | What it demonstrates |
|---|---|---|
| `ForkIt_LockedSpec_v1.md` | Build | Full locked spec: component map, interface contracts, accepted decisions, open flags |
| `ForkIt_BulletHandoff_v1_Interview.md` | Build | Bullet handoff format |
| `ForkIt_SetupWorksheet_v1.md` | Build | Setup Worksheet: Firebase + Google Places |

-----

*The Forge Workflow Template · v3.0 · Orbital AI*
