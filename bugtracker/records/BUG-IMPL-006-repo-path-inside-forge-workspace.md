# BUG-IMPL-006 — Generated code written into the Forge project workspace

**ID:** BUG-IMPL-006
**Area:** IMPL
**Severity:** High
**Status:** Fixed 2026-09-12

---

## Symptom

For the **AR Mechanic** project, Build-with-AI wrote the generated app code
(`lib/main.dart`, `pubspec.yaml`, `android/`, `ios/`, `.flutter-plugins-dependencies`)
**inside the Forge project workspace** — `~/Documents/The Forge Projects/AR Mechanic/`
— in among the deliverables (`.forge/specs`, `handoffs`, `tracker`). A separate
agent (and the user) looking for the code under `~/Development/ar_mechanic` found
that folder empty and couldn't locate what The Forge had generated.

## Root Cause

The project's `.forge/forge/project_config.json` had
`{"repoPath":"/Users/mymac/Documents/The Forge Projects/AR Mechanic"}` — i.e. the
linked **code repo pointed at the project's own Forge workspace**. Build-with-AI
faithfully wrote edits relative to `repoPath`, so all generated code landed in
the workspace root. Nothing in the link/relocate flows prevented selecting a
folder inside the canonical projects root as the repo, and there was no way to
move a mislinked repo's code to the right place afterward.

## Fix

1. **Guard** — `ProjectFileRepository.isInsideProjectsRoot(path)`; the link
   pickers (tracker `_ensureRepoPath`, detail-screen `_pick`) and the new
   relocate flow reject any folder inside `~/Documents/The Forge Projects/`.
2. **Relocate feature** — `relocateRepo` (moves the repo's code to a new folder,
   never touching `.forge`), `createEmptyCodeFolder`, and `relocateRepoFlow`
   (UI). Reachable any time from the Build window toolbar ("Change code
   location") and the detail-screen repo row ("Change →").
3. **Data repair (AR Mechanic)** — the app source was moved to
   `~/Development/ar_mechanic` (git-initialised), the Forge deliverables
   (`.forge/`, project-state `README.md`) left in the workspace, and the config
   repointed to `/Users/mymac/Development/ar_mechanic`.

## Prevention Rule

See BUG_PREVENTION.md — "The canonical projects root holds *workspaces* (docs),
never code repos. Any path a user can pick as a code repo must be validated to
be outside the projects root, and a mislink must be recoverable (relocate +
move), not permanent."

## Commit

v0.4.11
