<!-- TEMPLATE — replace {{PLACEHOLDERS}} and delete this line. Part of the Docs Templates system. -->
# Bug Prevention Checklist — {{PROJECT_NAME}}

**When to read:** Before coding in any subsystem listed below.
**When to update:** Every time a bug is fixed — add the rule that would have prevented it.

---

## Universal Rules

- **Read before editing** — read every file in full before modifying it. Never edit blind.
- **Linter clean before reporting done** — zero new warnings or errors (`{{LINT_COMMAND}}`).
- **No committed secrets** — config files, API keys, and tokens are gitignored. Never hardcode.
- **No silent error swallowing** — failed operations must throw or return a typed error. Never discard.
- **No debug logs leaking PII** — user IDs, emails, and user content must not appear in logs on production paths.

---

## {{Subsystem}} Rules

**Rules:**
- *(Add a rule here after the first bug in this subsystem — phrase it as the discipline that would have prevented the bug.)*

**Past bugs:** *(none yet)*

*After each fixed bug, add a subsystem section like this (or extend an existing one) with the rule that would have prevented it, and record the bug on the `**Past bugs:**` line.*

---

## Common Anti-Patterns

- **Catching too broadly** — catch specific types or let it bubble.
- **Race conditions on user input** — disable UI triggers while async work is in flight.
- **Optimistic state without rollback** — if a write fails, do not update in-memory state.
- **Stale references after refactor** — grep the full repo for old names before declaring a rename done.
- **Multiple initializers on shared state** — do not trigger state-writing methods from more than one place when sharing a global mutable object; concurrent async writers produce interleaved updates. Secondary consumers should observe passively; only the owner triggers explicit loads.

---

*This file grows over time. Update after every bug fix.*
