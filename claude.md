# Claude Context Guide — The Forge

**Version:** 1.0.0
**Last Updated:** 2026-05-31
**Stack:** Flutter (desktop-first, macOS primary) · Firebase (Firestore + Functions) · SwarmSpace API

This is the Claude-specific onboarding and SOP file. Non-Claude agents should use `operations md files/startup.md` instead.

---

## Standard Procedure — Follow This Every Session

```
PROMPT RECEIVED
      │
      ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 1 — ORIENT (always, before anything else)                  │
│                                                                 │
│  Read: claude.md               ← you are here                  │
│  Read: agents md files/agents.md  ← codebase architecture      │
│  Read: tracking md files/context.md ← last session's state     │
└─────────────────────────────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 2 — UNDERSTAND THE TASK                                    │
│                                                                 │
│  Read: tracking md files/planner.md   ← active tasks           │
│  Read: tracking md files/backlog.md   ← priority queue         │
│                                                                 │
│  Identify task type:                                            │
│    • New feature / multi-file change  → STEP 3A                │
│    • Bug fix                          → STEP 3B                │
│    • Assign work to an external agent → STEP 3C                │
│    • Documentation update             → STEP 3D                │
│    • Security / DevSecOps             → STEP 3E                │
└─────────────────────────────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 2.5 — DECIDE: SCOPE · AGENTS · DEFINITION OF DONE          │
│  (mandatory — output this block in chat before touching files)  │
│                                                                 │
│  1. SCOPE — Classify the task:                                  │
│     ≤ 2 files, self-contained  → 1 agent, stay on main          │
│     3+ files, one subsystem    → 1 agent, worktree              │
│     3+ subsystems              → multi-agent → STEP 3C          │
│     Parallel independent tracks→ multi-agent → STEP 3C          │
│                                                                 │
│  2. AGENTS (if multi-agent) — declare before acting:            │
│     • Count: 1 lead + N workers                                 │
│     • Types: coder / reviewer / doc / security / test           │
│     • Ownership: one file set per agent, no overlaps            │
│                                                                 │
│  3. DONE — Write the definition of done (one sentence):         │
│     "Complete when [observable outcome]."                       │
│                                                                 │
│  Do not proceed until all three are stated in chat.            │
└─────────────────────────────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 3A — PLAN (feature / multi-file change)                    │
│                                                                 │
│  Read:  agents md files/agents_sop.md → SOP-PLAN               │
│  Read:  bugtracker/BUG_PREVENTION.md                           │
│  Do:    State definition of done (one sentence)                 │
│  Do:    List exact files to modify                              │
│  Do:    Break into ordered sub-tasks; state what's out of scope │
│  Decide: worktree needed? → SOP-WORKTREE (criteria + lifecycle)│
│                                                                 │
│  If task spans 3+ subsystems → also go to STEP 3C              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ STEP 3B — DIAGNOSE (bug fix)                                    │
│                                                                 │
│  Read:  bugtracker/BUG_PREVENTION.md                           │
│  Read:  bugtracker/README.md                                    │
│  Read:  agents md files/agents_sop.md → SOP-ERROR              │
│  Do:    Gather facts before guessing; one hypothesis at a time  │
│  Do:    File a record in bugtracker/records/ after fixing       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ STEP 3C — SCOPE & RANK (assigning work to an external agent)    │
│                                                                 │
│  Read:  agents md files/agent_scoping.md                        │
│    → Check Agent Registry → pick rank → select template         │
│    → Apply all Prompt Quality Rules                             │
│  Read:  agents md files/agents_sop.md → SOP-AGENT              │
│  Write the scoped prompt → hand off to agent                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ STEP 3D — DOCUMENT                                              │
│                                                                 │
│  Read:  agents md files/agents_doc_backup.md                   │
│  Do:    Update CONFIGURATION_MANAGEMENT.md after doc changes    │
│  Do:    Archive deprecated content; append session block        │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ STEP 3E — AUDIT                                                 │
│                                                                 │
│  Read:  agents md files/agents_devsecops.md                    │
│  Read:  agents md files/SECURITY_CHECKLIST.md                  │
└─────────────────────────────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 4 — IMPLEMENT                                              │
│                                                                 │
│  Read every file before touching it (use the Read tool)        │
│  Implement against the plan; check Key Invariants while coding  │
│  Resolve ambiguity before writing code, not after              │
└─────────────────────────────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 5 — REVIEW (do not skip any item)                          │
│                                                                 │
│  Linter:  dart analyze lib/[affected directory]/                │
│           zero new warnings or errors from your changes         │
│  Tests:   flutter test (affected area); fix any failures caused │
│  Verify:  check each item in the STEP 2.5 definition of done    │
│  Done?    confirm every user-requested function actually works  │
└─────────────────────────────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 6 — CLOSE SESSION                                          │
│                                                                 │
│  Write:  tracking md files/context.md → prepend session block   │
│  Update: tracking md files/planner.md → cross off tasks         │
│  Update: tracking md files/backlog.md → mark shipped items ✅   │
│  Update: operations md files/CONFIGURATION_MANAGEMENT.md        │
│  Write:  DOCS/Coding Lessons/FOR_MARC_[topic].md                │
│          → after any significant task (investigation, plan,     │
│            fix, feature). Follow the 9-step format in           │
│            DOCS/Coding Lessons/README.md.                       │
│          → coffee-chat tone, no textbook voice.                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quick Reference

| Document | Purpose | Path |
|----------|---------|------|
| **agents.md** | Codebase orientation + architecture | `agents md files/agents.md` |
| **agents_sop.md** | SOP-PLAN, SOP-ERROR, SOP-REVIEW, SOP-AGENT | `agents md files/agents_sop.md` |
| **agents_handoff.md** | Session block format, handoff checklist | `agents md files/agents_handoff.md` |
| **agent_scoping.md** | Agent ranking framework and registry | `agents md files/agent_scoping.md` |
| **context.md** | Session log — read first every session | `tracking md files/context.md` |
| **planner.md** | Active sprint tasks | `tracking md files/planner.md` |
| **backlog.md** | Long-term feature pool | `tracking md files/backlog.md` |
| **ARCHITECTURE.md** | System architecture | `tracking md files/ARCHITECTURE.md` |
| **CONFIGURATION_MANAGEMENT.md** | Docs inventory and change log | `operations md files/CONFIGURATION_MANAGEMENT.md` |
| **BUG_PREVENTION.md** | Check before coding in risky areas | `bugtracker/BUG_PREVENTION.md` |
| **backend.md** | Firebase + SwarmSpace API reference | `backend.md` |
| **llm_tier_field_guide.md** | Tier-based guidance for sub-agents | `agents md files/llm_tier_field_guide.md` |

---

## Code Quality Principles

**1. Think before coding.** State assumptions explicitly. Present interpretations — do not pick silently. Surface tradeoffs before writing, not after.

**2. Simplicity first.** Minimum code that solves the problem. No abstractions for single-use code. Ask: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

**3. Surgical changes.** Touch only what you must. Match existing style. Remove orphans (unused imports, dead variables). Every changed line must trace to the user's request.

**4. Goal-driven execution.** Transform every task into a verifiable goal. For multi-step tasks: `1. [Step] → verify: [check]`.

---

## Key Invariants

- **Locked specs are immutable.** Once written, a locked spec is never modified. Amendments produce a new versioned spec. Never overwrite.
- **No executor starts without a complete project folder.** The `README.md`, locked spec, bullet handoff, and setup worksheet must all exist before any executor agent is invoked.
- **Firestore writes are append-only for audit trail.** The `/audit/` subcollection is never modified — only appended. Same pattern as CHRONICLE.
- **Secrets are never hardcoded.** Firebase config, API keys, and SwarmSpace tokens are read from environment variables or `.env` files that are gitignored.
- **`dart analyze` must be clean.** Zero new warnings or errors before reporting done.
- **Interview state lives in the Flutter app.** Do not push mid-interview state to Firestore — only write on phase completion (spec locked, worksheet complete, handoff generated).

---

## Conditional File Triggers

| Situation | Files to read |
|---|---|
| Touching Firestore schema or data layer | `backend.md`, `bugtracker/BUG_PREVENTION.md` |
| Touching interview logic or confidence dimensions | `DOCS/forge/workflow_template.md` |
| Touching spec generation (Firebase Function) | `backend.md`, `bugtracker/BUG_PREVENTION.md` |
| Touching UI / UX | `tracking md files/UI_UX.md` |
| Touching auth or billing | `bugtracker/BUG_PREVENTION.md`, `agents md files/SECURITY_CHECKLIST.md` |
| Refactoring / simplifying | `agents md files/agents_code_simplifier.md` |
| Bugtracker work | `agents md files/agents_bugtracker.md`, `bugtracker/BUGTRACKER_MASTER_INDEX.md` |
| Assigning work to an external agent | `agents md files/agent_scoping.md`, `agents md files/llm_tier_field_guide.md` |

---

## SOPs Summary

**SOP-PLAN:** Read before writing → define done → list files → sub-tasks → risks → out of scope

**SOP-ERROR:** Symptom verbatim → last good state → one hypothesis at a time → check bugtracker → document fix

**SOP-REVIEW:** Linter clean → no scope creep → no debug logs → context.md updated → planner crossed off → commit message clear

**SOP-AGENT:** Spec doc first → single file ownership per agent → linter required before merge → one fix cycle max → overseer merges

**SOP-WORKTREE:** Decide isolation → create `wt/<id>` off main → implement → user review → user approval → merge `--no-ff` → status-clean teardown

---

*Version 1.0.0 — Initial setup from Starter Repo. The Forge — Orbital AI.*
