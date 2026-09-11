<!-- TEMPLATE — replace {{PLACEHOLDERS}} and delete this line. Part of the Docs Templates system. -->
# Agent Scoping — {{PROJECT_NAME}}

Framework for scoping work to external coding agents (LLMs), ranking them by observed
performance, and selecting the right prompt template per rank. Populate the Agent
Registry below as agents are evaluated on real tasks.

---

## Ranking Framework

Assign each agent a rank based on how much scaffolding it needs to ship correct work:

| Rank | Name | Meaning | How to prompt |
|---|---|---|---|
| **1** | Executor | Ships scoped, single-subsystem work correctly with invariants provided inline. Self-corrects after linter runs. | Full spec + invariants inline + verification checklist. Trust it to run the checklist. |
| **2** | Assisted | Correct on well-bounded tasks but needs tighter constraints and more review. | Narrow scope, spell out every contract, review each diff. |
| **3** | Supervised | Useful for boilerplate/mechanical work under close supervision. | Tiny tasks, exact file+method signatures, review every step. |

Rank is **earned from test results**, not assumed from model reputation. Re-rank after
each assignment.

---

## Scoring Dimensions

Score each assignment 1–5 on these five axes, then average for an overall:

| Dimension | Question |
|---|---|
| **Spec** | Did it satisfy the written spec / definition of done? |
| **Integration** | Does the work fit the existing architecture and contracts? |
| **Self-correct** | Did it catch and fix its own errors (e.g. after a linter run) without the overseer? |
| **Scope** | Did it touch only the files it was told to, and remove orphans? |
| **Prompt-dep** | How little did it depend on the prompt spelling out the obvious? (higher = more autonomous) |

Test-type tag (e.g. `T1` trivial, `T2` single-subsystem, `T3` multi-subsystem) records
how demanding the assignment was, so scores are comparable.

---

## Prompt Quality Rules

Apply all of these when writing a scoped prompt for any external agent:

1. **State the definition of done** in one observable sentence.
2. **Give exact file paths and method/interface signatures** for every contract it must honour.
3. **Spell out invariants inline** — do not assume the agent will read them elsewhere.
4. **State ownership explicitly** when a responsibility could live in more than one layer.
5. **Include a verification checklist** (linter command, tests, done-conditions).
6. **State what is out of scope** to prevent scope creep.
7. **Name known footguns** relevant to the task (linter-undetectable bugs, parse traps).

---

## Agent Registry

<!-- Add one summary row per agent. Rank is earned from the per-agent detail sections
     below. Replace the example row once a real agent has been evaluated. -->

| Agent | Model | Rank | Strengths | Weaknesses | Last used |
|---|---|---|---|---|---|
| Example Agent (example — replace) | example-model-v1 | **1 — Executor** | Linter separation, scope discipline, invariant accuracy | Needs invariants spelled out inline; leaves dead deps | YYYY-MM-DD |

---

### Example Agent (example — replace)

**Rank: 1 — Executor**

| Assignment | Test Type | Scores (Spec / Integration / Self-correct / Scope / Prompt-dep) | Overall | Notes |
|---|---|---|---|---|
| {{Task name — what it built}} | T2 | 5 / 4 / 5 / 5 / 4 | **4.6 → Rank 1** | {{What it did well; what a reviewer had to fix; any inferred behaviour}} |

**Calibrated rank:** {{one sentence — for what kinds of task this rank holds}}

**Observed strengths:**
- {{strength}}
- {{strength}}

**Observed weaknesses:**
- {{weakness}}

**Assignment rules for {{agent}}:**
- Use its rank template for: {{task categories}}
- Always include: {{what must be inline in the prompt}}
- Do not assign without: {{hard preconditions}}
