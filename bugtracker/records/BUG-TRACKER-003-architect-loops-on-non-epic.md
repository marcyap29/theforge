# BUG-TRACKER-003 — Architect loops on a non-epic feature (nests a clone, re-marks epic)

**ID:** BUG-TRACKER-003
**Area:** TRACKER
**Severity:** High
**Status:** Fixed 2026-09-20

---

## Symptom

Running **Architect** on a feature (either from the feature menu or via the
build gate's "Architect it") produced a "Build plan" sheet with **one**
sub-feature and an **"Add 1 to board"** button — it "didn't actually architect
anything." Worse, the user ended up in a **loop**: trying to Build the feature
re-opened the gate → Architect → one clone → Build → gate → Architect… never
producing anything buildable. Seen on AR Mechanic with a single, well-scoped
rendering bug fix ("Fix highlight box alignment on reference photo") that the
model correctly judged **not** an epic (`isEpic: false`).

## Root Cause

`_architectFeature` (`project_tracker_screen.dart`) **ignored `plan.isEpic`.**
After the review sheet it unconditionally:

1. `updateFeature(feature, buildKind: BuildKind.epic)` — marking the parent an
   epic even when the model said it wasn't; and
2. nested the returned sub-feature(s) under it.

For a genuine single feature the model returns `isEpic:false` + one sub-feature
(a near-clone of the parent). The flow then turned that buildable feature into a
non-buildable **epic wrapper** with a clone child. Because the parent was now an
epic, the pre-build gate (`_confirmBuildDespiteKind`, fires when
`!kind.isDirectlyBuildable`) steered every future Build back to Architect, which
again returned `isEpic:false` + one clone → **infinite loop**, one clone added
per pass, nothing ever buildable.

## Fix

Branch the flow on `plan.isEpic`:

- **`isEpic == false`** (single buildable feature): do **not** nest, do **not**
  mark epic. Sharpen the feature **in place** — adopt the single sub-feature's
  description and set the feature's `buildKind` to that sub-feature's kind
  (usually `standard`, which the build gate lets through; `manual` if it's
  really human/ML work). This also **demotes** a feature that was previously
  mis-marked as an epic, breaking the loop. Snackbar tells the user it's ready
  to Build (or to see "How to build this" for manual).
- **`isEpic == true`** (real epic): unchanged — mark the parent epic and nest
  the kept sub-features under it.

The review sheet (`architect_review_sheet.dart`) now adapts to `plan.isEpic`:
the helper text no longer claims a single feature "becomes an epic," and the
button reads **"Mark buildable"** (not "Add N to board") for the non-epic case.

## Prevention Rule

See BUG_PREVENTION.md — "When an LLM classifier returns a judgment
(`isEpic`, feasibility, confidence), **branch on it** — don't run the one true
path and discard the flag. A decomposition that ignores `isEpic:false` turns a
buildable feature into an epic wrapper and, combined with a gate that steers
epics back to the same action, becomes an infinite loop." Also: any state
transition that a gate reads (here `buildKind → epic`) must be reversible by the
same flow, or a misclassification traps the item forever.

## Commit

v0.4.51
