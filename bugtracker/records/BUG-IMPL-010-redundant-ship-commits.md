# BUG-IMPL-010 — Shipping several features back-to-back makes redundant, duplicate-titled commits

**ID:** BUG-IMPL-010
**Area:** IMPL
**Severity:** Medium
**Status:** Fixed 2026-09-20

---

## Symptom

After building AR Mechanic's "Segmented steps" epic and marking its sub-features
shipped one after another, the app repo's git history filled with near-empty,
duplicate-titled commits — four separate commits titled *"feat: Sequential
Verification Logic & Reverse Mode + docs"*, most of them touching only
`docs/ARCHITECTURE.md`:

```
3222a66  …Reverse Mode + docs   (ARCHITECTURE.md only)
ae7a81e  …Reverse Mode + docs   (ARCHITECTURE.md only)
54d8031  …Reverse Mode + docs   (ARCHITECTURE.md only)
848a73a  …Reverse Mode + docs   (the real code + docs)
```

The code was correct and fully committed; the noise was pure churn.

## Root Cause

`ImplRunNotifier._documentAndCommit` runs on **every** ship and, before the
commit, unconditionally calls `_updateArchitectureDoc`, which asks the architect
LLM to regenerate the **entire** `ARCHITECTURE.md`. That output is
non-deterministic — the model returns slightly different prose each time — so
`ARCHITECTURE.md` changes on *every* ship even when nothing material changed.

On a repeat/redundant ship (same feature shipped again, or several ships in a
row after one already swept the whole working tree via `git add -A`), the
deterministic docs dedup to no-ops (`_prepend` skips an entry already present),
but the ARCHITECTURE rewrite is always a diff. `gitCommitAll` therefore finds
something to commit and produces a spurious "docs-only" commit — carrying the
current window's `brief.featureTitle`, hence the duplicate titles.

There was also no guard against re-running the ship flow for a feature the
window had already shipped.

## Fix

`implementation_notifier.dart` + `project_file_repository.dart`:

1. **Redundant-ship guard (durable).** In `_documentAndCommit`, after the
   deterministic CHANGELOG/DEVELOPMENT_LOG updates but **before** the ARCHITECTURE
   refresh, check `ProjectFileRepository.gitHasChanges(repoPath)` (new helper:
   `git status --porcelain`, non-empty ⇒ something to commit). If the tree is
   clean — code already committed, doc entries deduped — stop: skip the LLM
   ARCHITECTURE rewrite *and* the commit, logging "Already shipped & documented
   — nothing new to commit." Placed before the refresh so its churn can't mask
   an otherwise-clean tree. A legitimate re-build with real new code still has a
   dirty tree here, so it commits normally.
2. **In-session guard (cheap).** `shipFeature` returns early if
   `state.featureShipped` is already true, so a double-click / re-entry in the
   same window doesn't re-run docs + an LLM call at all.

Net effect: one clean commit per feature that actually changes something; repeat
ships are no-ops instead of duplicate-titled churn commits.

## Prevention Rule

See BUG_PREVENTION.md — "A non-deterministic doc regeneration (LLM-rewritten
ARCHITECTURE.md) must never be the sole reason a commit exists. Gate any
auto-commit on a real working-tree change (`git status --porcelain`) checked
*before* the non-deterministic step, and make idempotent actions like ship
no-ops when there's nothing new."

## Commit

v0.4.55
