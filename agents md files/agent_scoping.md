# Agent Scoping — The Forge

See Starter Repo `agents md files/agent_scoping.md` for the full framework, agent registry, and ranking system.

The Forge-specific agent registry will be populated here as external agents are evaluated and used.

---

## Agent Registry

| Agent | Model | Rank | Strengths | Weaknesses | Last used |
|---|---|---|---|---|---|
| DeepSeek v4 Pro | deepseek-v4-pro | **1 — Executor** | Linter separation, scope discipline, invariant accuracy | Needs invariants spelled out in prompt; leaves dead deps | 2026-05-31 |

---

### DeepSeek v4 Pro (via DeepSeek API / interface)

**Rank: 1 — Executor**

| Assignment | Test Type | Scores (Spec / Integration / Self-correct / Scope / Prompt-dep) | Overall | Notes |
|---|---|---|---|---|
| §1 Flutter Bootstrap + Local Data Layer — pubspec, ForgeDatabase, ProjectFileRepository, tracking doc updates | T2 | 5 / 4 / 5 / 5 / 4 | **4.6 → Rank 1** | Proactively removed flutter_lints + cupertino_icons not in spec. Correctly separated pre-codegen drift errors. Async/sync mix in writeLockedSpec (functional). writeHandoffPackage writes to project root not handoffs/ (spec didn't specify). |

**Calibrated rank:** Rank 1 for scoped data-layer and service implementation tasks with invariants provided inline.

**Observed strengths:**
- Linter discipline: correctly scoped `dart analyze` to non-drift files to separate expected codegen errors from real bugs
- Scope discipline: touched exactly required files, deleted auto-generated README correctly
- Invariant accuracy: write-once spec (existsSync + atomic temp→rename) and append-only audit log (FileMode.append) both implemented correctly
- Proactive self-correction: caught analysis_options/flutter_lints conflict and fixed before reporting

**Observed weaknesses:**
- Invariants must be spelled out inline in the prompt — deduces them correctly when given, but likely to miss undocumented invariants
- Minor async/sync inconsistency in file write patterns (functional, not a bug)

**Assignment rules for DeepSeek v4 Pro:**
- Use Rank 1 template for: data layer, service implementation, single-subsystem Flutter tasks
- Always include: key invariants inline (write patterns, atomic operations, error cases)
- Always include: verification checklist — runs it reliably
- Do not assign without: explicit file paths and method signatures for any contracts it must honour
