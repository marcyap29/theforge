# Bug Prevention Checklist — The Forge

**When to read:** Before coding in any subsystem listed below.
**When to update:** Every time a bug is fixed — add the rule that would have prevented it.

---

## Universal Rules

- **Read before editing** — read every file in full before modifying it. Never edit blind.
- **Linter clean before reporting done** — zero new warnings or errors (`dart analyze lib/`).
- **No committed secrets** — Firebase config, API keys, SwarmSpace tokens are gitignored. Never hardcode.
- **No silent error swallowing** — failed operations must throw or return a typed error. Never discard.
- **No debug logs leaking PII** — user IDs, emails, project content must not appear in print/debugPrint in production paths.

---

## Firestore — Immutability Rules

**Rules:**
- **Never update a spec document.** Specs are written once. Any change produces a new versioned spec. If you find yourself calling `.update()` on a spec document, stop.
- **Never replace the audit log entries array.** Use `arrayUnion` only. Never `set` or `update` with a full replacement.
- **All Firestore writes are transactional on phase completion.** The spec, handoff, and audit log entry for a phase are written in a single transaction. Partial writes leave the project in an inconsistent state.
- **Phase gate checks are mandatory.** Verify `setupWorksheetComplete == true` before allowing spec write in Build mode. Verify interview state is complete (all 8 dimensions resolved) before calling spec generation.

**Past bugs:** *(none yet — initial setup)*

---

## Spec Generation — Concurrency Rules

**Rules:**
- **All 3 variants must complete before any are revealed.** Use `Future.wait([...])` — never present a partial result.
- **Credit deduction happens server-side only.** The Flutter app never writes credit values. The Firebase Function handles billing after successful generation.
- **Timeout on LLM calls.** Each parallel LLM call must have a timeout. If one variant times out, return an error — do not return the two that completed.

**Past bugs:** *(none yet)*

---

## Interview State — Flutter Rules

**Rules:**
- **Interview state never touches Firestore mid-session.** State lives in Riverpod during an interview. The only Firestore write is on phase completion.
- **Conflict detection blocks progression.** A detected conflict must be surfaced and explicitly resolved by the user before the interview advances. Never auto-resolve silently.
- **Confidence at 100% is required before spec generation is triggered.** All 8 dimensions must be resolved. Never allow a partial interview to proceed to spec generation.

**Past bugs:** *(none yet)*

---

## Common Anti-Patterns

- **Catching too broadly** — catch specific types or let it bubble.
- **Race conditions on user input** — disable UI triggers while async work is in flight.
- **Optimistic state without rollback** — if spec write fails, do not update the project state in Flutter.
- **Stale references after refactor** — grep the full repo for old names before declaring a rename done.

---

*This file grows over time. Update after every bug fix.*
