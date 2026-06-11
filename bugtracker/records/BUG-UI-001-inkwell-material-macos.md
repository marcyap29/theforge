---
id: BUG-UI-001
area: UI
status: Fixed
date_found: 2026-06-10
date_fixed: 2026-06-10
---

# BUG-UI-001 — InkWell unresponsive on macOS Flutter desktop

## Symptom
The "Manage →" button in `_ReferenceDocsRow` (`project_detail_screen.dart`) was completely unresponsive on macOS. No visual feedback, no navigation. No error or crash in logs.

## Root cause
Flutter macOS desktop requires an **immediate `Material` ancestor** in the widget subtree for `InkWell` ink gesture recognition to work. A `Scaffold` or any `Material` widget higher in the tree is NOT sufficient — the ink system walks up looking for a nearby ancestor. `_ReferenceDocsRow` used `InkWell` with no local `Material`, so taps were silently dropped.

## Fix
Wrapped the `InkWell` (and its contents) with `Material(color: Colors.transparent)` in `_ReferenceDocsRow`.

**File:** `lib/features/projects/screens/project_detail_screen.dart`

## Prevention rule
See `bugtracker/BUG_PREVENTION.md` — Flutter Navigation / State Rules:
> `InkWell` on macOS Flutter desktop requires an immediate `Material` ancestor. Wrap with `Material(color: Colors.transparent)`.
