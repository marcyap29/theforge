<!-- TEMPLATE — replace {{PLACEHOLDERS}} and delete this line. Part of the Docs Templates system. -->
# {{PROJECT_NAME}} — Session Log

Newest session first. Each block is prepended.

> **How to use this file**
> - At the end of every working session, **prepend** a new `## Session:` block to the top (do not append to the bottom, do not edit past sessions).
> - Header format: `## Session: YYYY-MM-DD — {{OWNER or agent name}} [<Sprint/Epic name> (§<TAG>)]`.
> - Group `### Done` work under the sprint tag you are using (e.g. `§N`). A tag is just a short stable label for a workstream — pick your own scheme; it does not need to match anyone else's.
> - Keep `### Key Technical Findings`, `### Modified`, and `### Next` even if short — they are what the next session reads first.
> - This is an append-only log. Never delete or rewrite an old session block.

---

## Session: YYYY-MM-DD — {{OWNER}} [Example Sprint (§EX)]   (example — replace or delete)

**Branch:** main

### Done

**§EX1 — <short workstream name>:**
- One-line summary of what shipped, with the concrete files touched. Files: `path/to/file_a`, `path/to/file_b`.

**§EX2 — <short workstream name>:**
- Another self-contained chunk of work and its files.

**Bug fixes:**
- BUG-<AREA>-001 (one-line description of the root cause and the fix)

### Key Technical Findings
- A non-obvious fact learned this session that the next session should not have to rediscover.
- A gotcha in the {{STACK}} toolchain and its workaround.

### Modified
- `path/to/file_a` (NEW)
- `path/to/file_b` (MODIFIED)
- `path/to/file_c` (DELETED)

### Next
- The single most important thing to pick up next session.
- A secondary follow-up or known-deferred item.

---
