# Docs Templates — a reusable project documentation system

A drop-in documentation-and-process scaffold for a new repo. It is the generalized form of the system used in **The Forge**: a set of living-log docs, agent SOPs, a bugtracker, and a coding-lessons habit that together let an AI agent (or a human) pick up any project cold, orient in three files, and work to a consistent standard.

Every file here is a **template**. Each begins with an HTML comment:

```
<!-- TEMPLATE — replace {{PLACEHOLDERS}} and delete this line. Part of the Docs Templates system. -->
```

Placeholders use `{{DOUBLE_BRACES}}`. Living-log files ship as empty skeletons with exactly one `(example — replace or delete)` entry so the format is obvious.

---

## What's in the system

```
CLAUDE.md                         Agent onboarding + the per-session SOP workflow (start here)
backend.md                        Backend / external-API reference skeleton

agents md files/
  agents.md                       Codebase-orientation skeleton (architecture, layout, invariants)
  agents_sop.md                   SOP-PLAN / SOP-ERROR / SOP-REVIEW / SOP-AGENT / SOP-WORKTREE
  agents_handoff.md               Session-block format + end-of-session handoff checklist
  agent_scoping.md                Framework for ranking + scoping external/sub-agents
  llm_tier_field_guide.md         Which model tier to use for which kind of sub-task
  SECURITY_CHECKLIST.md           Pre-commit security review

tracking md files/                The living logs — updated every session
  context.md                      Session log (newest block prepended each session) — READ FIRST
  planner.md                      Active sprint tasks
  backlog.md                      Long-term feature pool + critical-path diagram
  ARCHITECTURE.md                 System architecture + Key Invariants
  FEATURES.md                     Feature inventory by area
  UI_UX.md                        UI/UX conventions and open questions
  CHANGELOG.md                    Release changelog (Keep a Changelog style)

operations md files/
  startup.md                      Orientation runbook for non-Claude agents
  CONFIGURATION_MANAGEMENT.md     Doc inventory + change log (living)

bugtracker/
  README.md                       How the bugtracker works (BUG-<AREA>-<NNN> scheme)
  BUG_PREVENTION.md               Universal rules + per-subsystem rules grown from fixed bugs
  BUGTRACKER_MASTER_INDEX.md      Open / Fixed index of all bugs
  records/_TEMPLATE_BUG_RECORD.md Canonical per-bug record template

DOCS/Coding Lessons/
  README.md                       The 9-step "teach the owner" lesson format
  _TEMPLATE_LESSON.md             Blank lesson to copy per significant task
```

### The three-tier mental model
- **Process docs** (`CLAUDE.md`, `agents md files/*`, `bugtracker/README.md`, `DOCS/Coding Lessons/README.md`, `startup.md`) — reusable rules. Genericize the placeholders once and mostly leave them alone.
- **Living logs** (`tracking md files/*`, `CONFIGURATION_MANAGEMENT.md`, `BUGTRACKER_MASTER_INDEX.md`) — updated every session. Start empty; grow with the project.
- **Grow-on-demand docs** (`BUG_PREVENTION.md` subsystem sections, `bugtracker/records/*`, `DOCS/Coding Lessons/FOR_{{OWNER}}_*.md`) — you add one entry each time a bug is fixed or a significant task lands.

---

## How to adopt this in a new repo

1. **Copy the tree** into the new repo's root (keep the folder names, including the spaces — the SOP paths reference `agents md files/`, `tracking md files/`, `operations md files/` literally):
   ```sh
   rsync -a --exclude README.md "/Users/mymac/Development/Docs Templates/" /path/to/new-repo/
   ```
   (Skip this file — it documents the template system, not your project.)

2. **Fill the placeholders.** Find them all:
   ```sh
   grep -rn "{{" /path/to/new-repo --include="*.md"
   ```
   Common ones: `{{PROJECT_NAME}}`, `{{STACK}}`, `{{OWNER}}`, `{{LINT_COMMAND}}`, `{{TEST_COMMAND}}`, `{{BACKEND}}`, `{{SECRET_STORE}}`, and `YYYY-MM-DD` dates.

3. **Delete the TEMPLATE banner lines** once each file is filled:
   ```sh
   grep -rln "<!-- TEMPLATE" /path/to/new-repo --include="*.md"
   ```

4. **Seed the skeletons.** Write the first real `ARCHITECTURE.md` overview, a first `context.md` session block, and your starting `backlog.md`/`planner.md` items. Delete every `(example — replace or delete)` entry once you have real ones.

5. **Rename `CLAUDE.md` if needed.** Claude Code reads `CLAUDE.md` at the repo root — keep the name. If your project already uses lowercase `claude.md`, pick one; the SOP text refers to it as `claude.md`.

6. **Adopt the loop.** From then on, `CLAUDE.md` is the contract: orient in three files (`CLAUDE.md` → `agents.md` → `context.md`), state scope/agents/definition-of-done before coding, and close every session by updating the living logs.

---

## Conventions worth keeping

- **Section tags (`§N`).** A short, stable label per workstream (e.g. `§AUTH`, `§W1`) threaded through `planner.md`, `backlog.md`, `context.md`, and commits. Pick any scheme; be consistent.
- **Bug IDs (`BUG-<AREA>-<NNN>`).** One record per bug in `bugtracker/records/`; add a row to the master index and a prevention rule to `BUG_PREVENTION.md` when you fix it.
- **Ship markers.** Backlog/planner items get `✅` + `YYYY-MM-DD` when done; nothing is deleted without owner approval.
- **Coding lessons.** After any significant task, write `DOCS/Coding Lessons/FOR_{{OWNER}}_<topic>.md` in the 9-step format — the habit that turns work into learning.

---

*Generalized from The Forge's documentation system. Keep this file in the template folder; do not copy it into project repos.*
