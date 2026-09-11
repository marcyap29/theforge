# BUG-IMPL-003 — "Build with AI" full-file rewrite dropped large amounts of code

**ID:** BUG-IMPL-003
**Area:** IMPL
**Severity:** High
**Status:** Mitigated / Open-risk 2026-09-10

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

## Fix / Mitigation

Two-pass read-then-edit + a "preserve everything you aren't intentionally
changing" instruction + per-edit Undo; the hand-edit and Revise/Fix loops let
the user correct it. **Not fully solved** — the model can still drop code on a
full-file rewrite.

## Prevention Rule

See BUG_PREVENTION.md — "Always `dart analyze` (and prefer a build/test) before
committing anything Build-with-AI produced; never commit AI edits unreviewed.
Future: switch to diff/patch-based edits and add an automatic post-edit compile
check."

## Commit

n/a — incident; the corrupted files were reverted, never committed.
