# BUG-DATA-001 — Deleting a project could rm-rf a real source repo

**ID:** BUG-DATA-001
**Area:** DATA
**Severity:** Critical
**Status:** Fixed 2026-09-10

---

## Symptom

The project index held rows whose `path` pointed at real source-code folders
(e.g. Sabihin's `lib`, `macos`, `.git`) rather than at Forge project workspaces.
"Delete project" offered to remove the project folder from disk — which, for
those rows, would have recursively deleted the actual code repository, not a
Forge deliverables folder. Flagged by Marc: "I'm worried it will delete the
entire actual repo… not just the project folder."

## Root Cause

Two compounding causes:
1. The Forge Projects root had at one point been pointed at a code repo
   (`~/Development/Sabihin`), so the filesystem scan indexed its subfolders as
   "projects."
2. `deleteProjectCascade` deleted `project.path` on disk with no guard that the
   path was actually inside the canonical Forge Projects root.

## Fix

- **Delete guard:** folder deletion is now allowed only when the project path is
  within the canonical root —
  `p.isWithin(await ProjectFileRepository.canonicalRootPath(), project.path)`.
  Outside that root, the row is removed from the index only; nothing is deleted
  on disk. (`lib/features/projects/project_actions.dart`)
- **Confirmation dialog** now shows the exact absolute path that will be deleted
  (selectable), and destructive delete requires a double confirm.
- **Index hygiene:** `ProjectListNotifier` prunes index rows not found under the
  root, and the root is fixed to the canonical location (no longer settable to a
  code repo). (`lib/features/projects/providers/project_list_notifier.dart`,
  `lib/data/filesystem/project_file_repository.dart`)

## Prevention Rule

See BUG_PREVENTION.md — "Destructive filesystem operations must be fenced to a
known-owned root; never delete a path the app did not create."

## Commit

`5ee6aee`, `a11c2a8`
