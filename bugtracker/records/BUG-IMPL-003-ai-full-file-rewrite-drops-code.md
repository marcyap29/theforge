# BUG-IMPL-003 — "Build with AI" full-file rewrite dropped large amounts of code

**ID:** BUG-IMPL-003
**Area:** IMPL
**Severity:** High
**Status:** Fixed 2026-09-10 (root fix v0.4.3; earlier: Mitigated)

---

## Symptom

A "Build with AI" run on theforge itself rewrote `lib/core/app.dart` and
`lib/features/settings/settings_notifier.dart` with full-file content that
**dropped** large amounts of existing code — it gutted `ResetTextScaleIntent`,
removed ~345 lines from `settings_notifier`, and introduced a stray `-` — so the
source no longer compiled. Caught during review; reverted (was uncommitted,
never shipped).

## Root Cause

The agent returns the **complete** new file content per edit (reliable to apply,
but the model can omit or drop code it didn't mean to change). The two-pass loop
(read the file first) reduces this but does not guarantee it.

## Fix

**Root fix (v0.4.3):** switched the edit mechanism from whole-file rewrites to
targeted **find/replace hunks**. The model now returns small `{find, replace}`
snippets for existing files (only brand-new files get full `content`), so
untouched code is never re-emitted and therefore can never be dropped. A hunk
whose `find` doesn't match is skipped with a note rather than corrupting the
file. Also fixed BUG-IMPL-004 (truncation) as a side effect. Earlier mitigations
still apply: two-pass read-then-edit, per-edit Undo, hand-edit + Revise/Fix.

## Prevention Rule

See BUG_PREVENTION.md — "Prefer diff/find-replace edits over whole-file
rewrites, and always `dart analyze` (prefer a build/test) before committing
anything Build-with-AI produced."

## Commit

Incident reverted (never committed). Root fix: v0.4.3.
