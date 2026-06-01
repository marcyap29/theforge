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

## Local File — Immutability Rules

**Rules:**
- **Never write to a spec path directly.** Write to `_LockedSpec_v1.md.tmp`, verify, then rename. Rename is atomic on macOS. Direct writes can leave a partial file that passes the existence check.
- **Check existence before writing a spec.** `ProjectFileRepository` must call `file.exists()` before any spec write. If it exists, throw `SpecAlreadyExistsException` — do not overwrite.
- **Audit log must be opened in append mode only.** Use `FileMode.append`. `File.writeAsString()` without mode truncates the file first. If the audit log is truncated, the entire history is gone.
- **All phase-completion writes use temp+rename where possible.** Write to `.tmp`, then rename to final path. This prevents a crash from leaving a corrupt partial file.
- **Phase gate checks are mandatory.** Verify `setupWorksheetComplete == true` before spec write in Build mode. Verify all 8 confidence dimensions are resolved before calling spec generation.

**Past bugs:** *(none yet — initial setup)*

---

## Spec Generation — Concurrency Rules

**Rules:**
- **All 3 variants must complete before any are revealed.** Use `Future.wait([...])` — never present a partial result.
- **Credit deduction happens server-side only (SwarmSpace routing).** The Flutter app never writes credit values directly. The SwarmSpace API handles billing; the provider records the cost in the audit log.
- **Timeout on LLM calls.** Each parallel LLM call must have a timeout. If one variant times out, return an error — do not return the two that completed.

**Past bugs:** *(none yet)*

---

## Interview State — Flutter Rules

**Rules:**
- **Interview state never touches disk mid-session.** State lives in Riverpod during an interview. The only file writes happen on phase completion via `ProjectFileRepository`.
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
