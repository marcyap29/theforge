# BUG-IMPL-005 — "Mark shipped" in the build window didn't update the board

**ID:** BUG-IMPL-005
**Area:** IMPL
**Severity:** Medium
**Status:** Fixed 2026-09-11

---

## Symptom

When a build reached "Run complete" and the user clicked **Mark shipped** in the
build window, nothing happened on the board — the feature stayed un-shipped. The
user had to exit the window and mark it shipped from the board's status menu.

## Root Cause

Shipping was handled only from the `pop()` result of the **fresh** navigation
path in `_buildFeature` (`if (shipped == true) …`). The **re-attach** path —
taken whenever a run already exists in the keepAlive registry (very common:
re-opening a finished/in-progress run) — did `await push(...); return;` and
**discarded the result**, so the "Mark shipped" pop was ignored.

## Fix

Extracted `_handleBuildResult(feature)` which reads the keepAlive run state's
`featureShipped` flag (set by `markFeatureShipped()` when the user taps Mark
shipped) and applies it: set the feature `shipped` and ensure a release row for
its target version. It's now called after **both** navigation paths (fresh and
re-attach), so shipping works from the window regardless of how it was opened.

## Prevention Rule

See BUG_PREVENTION.md — "Don't rely on one navigation path's `pop()` result for
state a screen can be reached through multiple ways; read the persistent
(keepAlive) state and handle the result on every path that opens the screen."

## Commit

v0.4.6
