# BUG-UI-003 — macOS folder picker silently does nothing

**ID:** BUG-UI-003
**Area:** UI
**Severity:** Medium
**Status:** Fixed 2026-09-10

---

## Symptom

Pressing "Analyze a repo…" (Import) or "Scan repo" (Tracker) did nothing — no
folder picker appeared and no error was shown. It looked like the button was
never pressed.

## Root Cause

`file_picker`'s macOS `getDirectoryPath` opens an **app-modal** `NSOpenPanel`
via `dialog.runModal()`, which can fail to present depending on window/activation
state (it never attaches to the window). Any exception thrown by the picker was
also swallowed because the call was not wrapped, so the failure was invisible.

## Fix

- Pass `lockParentWindow: true` to `getDirectoryPath` so the panel attaches to
  the window (presents as a sheet) instead of an app-modal panel.
  (`lib/features/import/import_screen.dart`,
  `lib/features/tracker/screens/project_tracker_screen.dart`)
- Wrap the Import picker in try/catch and surface any error as a snackbar so a
  future failure can never look like "nothing happened".

## Prevention Rule

See BUG_PREVENTION.md — "macOS directory pickers must use lockParentWindow, and
picker calls must surface errors — never swallow them."

## Commit

`a11c2a8`
