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

## Known limitation

Dedup is by *title*. The scanner sometimes re-phrases the same feature across
runs ("V2: Multi‑Part Highlighting" vs "Part Highlighting & Motion Guidance"),
which exact/punctuation-normalized matching won't catch. Fuzzy/semantic merging
is intentionally out of scope (false merges are worse than a visible dup the
user can delete).

## Prevention Rule

See BUG_PREVENTION.md — "Any repeatable import (scan/check-in) must dedup against
existing records before writing; a stateless generator will re-propose
everything every run."

## Commit

v0.4.11
