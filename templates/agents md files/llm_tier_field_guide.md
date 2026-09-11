<!-- TEMPLATE — replace {{PLACEHOLDERS}} and delete this line. Part of the Docs Templates system. -->
# LLM Tier Field Guide — {{PROJECT_NAME}}

Practical guidance for matching a task to the right tier of LLM (and the right prompt
style) when assigning work to sub-agents. Pairs with `agent_scoping.md`, which tracks
how specific agents have actually performed on this repo.

---

## Tier Framework

Pick a tier by matching the task's difficulty to the model's capability, not by defaulting
to the strongest model available.

| Tier | Use for | Prompt style | Review depth |
|---|---|---|---|
| **Frontier** | Ambiguous design work, cross-subsystem changes, tasks needing judgment about architecture. | High-level goal + constraints; trust it to fill gaps and surface tradeoffs. | Review decisions, not syntax. |
| **Mid** | Well-scoped single-subsystem implementation with clear contracts. | Full spec + invariants inline + verification checklist. | Review the diff and linter output. |
| **Fast/Cheap** | Mechanical/boilerplate work: renames, format-driven edits, repetitive scaffolding. | Exact steps, exact paths, nothing left implicit. | Review every change. |

---

## Matching Rules

1. **Downshift when the task is bounded.** A cheaper tier that ships a well-specified task
   correctly beats a frontier model doing the same work at higher cost.
2. **Upshift when the spec is ambiguous.** If the right answer depends on judgment about
   ownership or architecture, use a stronger tier — weaker tiers pick the *obvious* layer,
   not always the *correct* one.
3. **The weaker the tier, the more the prompt must be spelled out.** Move effort from the
   model to the prompt: inline invariants, exact signatures, explicit ownership.
4. **Always require a verification checklist** regardless of tier (linter command, tests,
   done-conditions).

---

## Tier Notes

<!-- Record per-tier or per-model observations as usage patterns emerge on this repo.
     Keep entries short and tied to concrete assignments; cross-reference agent_scoping.md
     for full scores. -->

- **{{Tier / model}}** — {{observation from a real assignment; what to include or avoid in its prompts}}
