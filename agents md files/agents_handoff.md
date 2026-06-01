# Cross-Model Handoff Protocol — The Forge

## Session Block Format

Prepend to `tracking md files/context.md` at the end of every session.

```markdown
## Session: YYYY-MM-DD — [Short description of what was done]

**Branch:** [main / wt/<id>]

### What was done
- [bullet: what was built/changed]
- [bullet: what was decided]

### Verification
- [linter result]
- [tests run]

### LUMARA/SwarmSpace dependency
[None / or: what the other repo needs to do]

---
```

## Handoff Checklist

Before ending a session:

- [ ] `context.md` prepended with session block
- [ ] `planner.md` tasks crossed off (or partial work preserved as-is)
- [ ] `backlog.md` updated if new items agreed
- [ ] `CONFIGURATION_MANAGEMENT.md` updated if docs changed
- [ ] Linter clean (`dart analyze lib/`)
- [ ] If on worktree branch: pushed, NOT merged to main
- [ ] Open flags and blockers documented

## Context Window Discipline

In long sessions, summarize completed steps into `context.md` before the window fills. The session block is the canonical record. Do not rely on conversation history surviving across sessions.
