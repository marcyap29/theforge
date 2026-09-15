# BUG-IMPL-009 — Reopening a feature greys out repo actions (Make runnable / Commit & push)

**ID:** BUG-IMPL-009
**Area:** IMPL
**Severity:** Medium
**Status:** Fixed 2026-09-15

---

## Symptom

"I don't see the ability to Make Runnable." The **Make runnable** and **Commit
& push** actions were disabled (greyed) whenever a feature with an existing run
was reopened — e.g. any feature already built/shipped in the session.

## Root Cause

`_buildFeature`'s re-attach branch (taken when a run already exists in
`implActiveRunsProvider`) built the `ImplBrief` with `repoPath: ''`. The Build
window computes `hasRepo = widget.brief.repoPath.isNotEmpty`, and the repo-
dependent action buttons are disabled when `!hasRepo`. So reopening any feature
with a prior run passed an empty repo path → those buttons greyed out, even
though the project had a linked repo.

## Fix

The re-attach branch now reads the project's linked `repoPath` from config and
passes it in the `ImplBrief` (same as the fresh path), so `hasRepo` is correct
and the buttons stay enabled when reopening a feature.

## Prevention Rule

See BUG_PREVENTION.md — "A re-attach/reopen path must carry the same context
(repo path, etc.) as the fresh path; passing placeholder empties silently
disables UI that depends on that context."

## Commit

v0.4.22
