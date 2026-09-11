# BUG-IMPL-001 — Stop during planning + "Try again" crashed the build window

**ID:** BUG-IMPL-001
**Area:** IMPL
**Severity:** High
**Status:** Fixed 2026-09-10

---

## Symptom

Hitting Stop during planning and then "Try again" crashed the build window or
produced corrupt state.

## Root Cause

Stop cannot hard-cancel an in-flight HTTP stream, so the old stream's
continuation (and its `onDelta` callbacks) raced the restarted run, mutating
newer state. `_setStreamLine` could `removeLast()` an empty console.

## Fix

- A generation counter `_gen` is bumped on start/stop/reset; stale deltas and
  post-await continuations are ignored when `gen != _gen`.
- Console mutation guards against an empty list before `removeLast()`.
- Froze the elapsed timer on terminal state via `endedAt`.

## Prevention Rule

See BUG_PREVENTION.md — "Any async work that can be superseded (streams you
can't cancel) must carry a generation token; ignore results whose generation is
stale."

## Commit

`21813f8`
