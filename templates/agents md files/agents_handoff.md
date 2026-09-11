<!-- TEMPLATE — replace {{PLACEHOLDERS}} and delete this line. Part of the Docs Templates system. -->
# Cross-Model Handoff Protocol — {{PROJECT_NAME}}

## Session Block Format

Prepend to the session log (`{{SESSION_LOG_PATH}}`) at the end of every session.

```markdown
## Session: YYYY-MM-DD — [Short description of what was done]

**Branch:** [main / wt/<id>]

### What was done
- [bullet: what was built/changed]
- [bullet: what was decided]

### Verification
- [linter result]
- [tests run]

### External dependencies
[None / or: what another repo or service needs to do]

---
```

## Handoff Checklist

Before ending a session:

- [ ] Session log prepended with session block
- [ ] Planner tasks crossed off (or partial work preserved as-is)
- [ ] Backlog updated if new items agreed
- [ ] Docs inventory / configuration-management doc updated if docs changed
- [ ] Linter clean (`{{LINT_COMMAND}}`)   <!-- e.g. `dart analyze lib/` -->
- [ ] If on worktree branch: pushed, NOT merged to main
- [ ] Open flags and blockers documented

## Context Window Discipline

In long sessions, summarize completed steps into the session log before the window fills. The session block is the canonical record. Do not rely on conversation history surviving across sessions.
