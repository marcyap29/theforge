# BUG-IMPL-002 — "Apply & Run" quit the whole app

**ID:** BUG-IMPL-002
**Area:** IMPL
**Severity:** Critical
**Status:** Fixed 2026-09-10

---

## Symptom

Pressing "Apply & Run" quit the whole app, with no crash report — an OS resource
kill or a self-harming command.

## Root Cause

- Command output was appended to the console unbounded (O(n^2) list growth →
  memory blowup).
- A long-running or interactive command could hang the run.
- Nothing blocked a destructive / self-killing command even if approved.
- `applyAndRun` was not guarded, so any error in it could take down the app.

## Fix

- Console capped at 5000 lines (oldest trimmed).
- `CommandRunner` blocks destructive commands (`rm -rf`, `sudo`, `kill`/
  `killall`/`pkill`, `shutdown`, `dd`, force-push, `git reset --hard`) even if
  approved, and enforces a 3-minute per-command timeout that kills hangs.
- `applyAndRun` is wrapped so any error fails the run gracefully instead of
  crashing the app.

## Prevention Rule

See BUG_PREVENTION.md — "Live output buffers must be bounded; user-approved
shell commands still need a denylist + timeout; long-running operations must be
wrapped so they can never crash the app."

## Commit

`ac9dd0a`
