# BUG-DATA-002 — Relocating code into a nested folder duplicated the whole repo

**ID:** BUG-DATA-002
**Area:** DATA
**Severity:** High (silent data duplication)
**Status:** Fixed 2026-10-02

---

## Symptom

A user who had already let The Forge put code in one folder changed their mind
about the location: they **created a new folder and told the app to move the
code there** — but the new folder was created **inside the current code repo**.
Instead of relocating, The Forge **duplicated the entire repo's contents into
the new folder** ("it copied the whole drive into the folder I made"). Intent
was *move*; result was *duplicate*.

## Root Cause

`ProjectFileRepository.relocateRepo(fromPath, toPath)` moves each child of the
source into the destination (`_moveEntity` = `rename`, falling back to a
recursive `_copyEntity` + delete when rename fails). Its only guards were
`p.equals(fromPath, toPath)` (same path) and, in the UI, `isInsideProjectsRoot`
(the Forge *workspace*). **Neither blocked the destination being nested inside
the source.** The "Choose an existing folder" picker lets the user navigate into
the current repo and make a subfolder there — exactly the natural "I'll make a
folder for the code" move.

With `from = …/ar_mechanic` and `to = …/ar_mechanic/code`:

1. `from.listSync()` includes the new `code/` folder itself.
2. `lib`, `.git`, `pubspec.yaml`, … are moved into `code/…`.
3. Then it reaches `code` → tries to move `code` into `code/code` → **rename
   into its own subtree fails** → falls back to `_copyEntity(code, code/code)`,
   which **recursively copies the now-populated `code` into itself** → the repo
   is duplicated. With the source high in the tree, that's "contents of the
   drive copied into the new folder."

Same family as BUG-IMPL-006 (code scattered in the workspace): a relocate guard
that was too narrow.

## Fix

A **nesting guard** at the top of `relocateRepo`, on canonicalized paths
(so `./` and symlinks can't slip past), refusing *before* anything moves:

- `p.isWithin(fromC, toC)` → destination inside source (the dup case).
- `p.isWithin(toC, fromC)` → source inside destination (also unsafe).

`RepoRelocation` gains an `error` field + `refused` getter. When refused,
nothing is moved. `relocateRepoFlow` (`relocate_repo.dart`) checks `r.refused`
first: it shows the message and **aborts without repointing the project config**
(so the repo link stays valid). A normal sibling move is unchanged.

## Prevention Rule

See `BUG_PREVENTION.md` — "Any move/copy of a directory tree must reject a
source/destination that NESTS (either direction) before touching the
filesystem — moving a folder into its own subtree, or copying a parent into its
child, duplicates or corrupts the tree. Guard on `p.canonicalize` +
`p.isWithin`, not raw strings."

## Tests

`test/relocate_repo_test.dart` — refuses nested-destination (+ asserts source
untouched, no copy made), refuses source-inside-destination, a sibling move
still moves, same-path is a no-op.

## Commit

v0.5.3
