# BUG-TRACKER-001 — Re-scanning doubles planned/idea features

**ID:** BUG-TRACKER-001
**Area:** TRACKER
**Severity:** Medium
**Status:** Fixed 2026-09-12

---

## Symptom

Running "Scan Repo and Documents" more than once on a project re-imported the
same features, so planned/idea items accumulated as duplicates (AR Mechanic had
34 rows for 19 real features — mostly triples from three scans).

## Root Cause

`FeatureScanner.scan` is stateless: it re-proposes the full feature list every
run and doesn't know what's already tracked. `_scanRepo` then added every
accepted proposal via `addFeature` with **no dedup**, so each scan appended a
fresh copy. The check-in "new features" path had the same gap.

## Fix

Dedup at import time in `project_tracker_screen.dart` on a normalized title
(`_normTitle` — lowercased, non-alphanumerics collapsed to spaces, trimmed — so
"V2: Multi‑Part" and "v2 multi part" collide):

- **Scan:** filter proposals against existing feature titles *and* within the
  scan itself before showing the review sheet; if nothing is new, say so; the
  import toast reports how many were skipped.
- **Check-in:** skip any selected new feature whose normalized title is already
  tracked.
- **Data cleanup:** AR Mechanic's `features.json` was deduped (34 → 19), keeping
  the entry with the newest `updatedAt`/`createdAt` per title so manual status
  changes (e.g. Camera Permission → in_progress) survived. Backed up to
  `features.json.bak`.

## Cleaning existing / reworded duplicates

The import-time guard is by *title*, so it can't catch the same feature the
scanner **reworded** across runs ("V2: Multi‑Part Highlighting" vs "Part
Highlighting & Motion Guidance"). For those, a **Remove duplicates** tool (broom
icon on the board) runs a conservative LLM pass (`FeatureDeduplicator`,
`feature_dedup.dart`) that clusters same-capability entries, plus the exact
pass, and lets the user review each group (`showDedupReviewSheet`) before
deleting — keeping the most-progressed / most-recently-updated copy. Deletion is
always user-reviewed, never automatic, so a wrong cluster can't silently drop a
real feature.

## Prevention Rule

See BUG_PREVENTION.md — "Any repeatable import (scan/check-in) must dedup against
existing records before writing; a stateless generator will re-propose
everything every run."

## Commit

v0.4.11
