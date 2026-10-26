# BUG-IMPL-015 — Partial cross-file integration + dead code left behind after refactor

**Date:** 2026-10-26
**Reporter:** session
**Severity:** High
**Status:** Fixed
**Area:** IMPL

---

## Bug Description

**Symptom:** AR Mechanic had 163 compile errors after a build session. Three root causes:
1. `lib/main.dart` still contained 2808 lines of dead `CameraFeedScreen` class from a prior refactor — the executor that implemented State Controllers replaced the architecture but never deleted the old class.
2. `lib/ui/procedure_screen.dart` imported `layout_profile.dart` and used `_tokens` throughout, but the `_ProcedureScreenState` class was missing the `LayoutTokens get _tokens => context.layoutTokens` getter — partial integration that left the file broken.
3. `lib/session_history_screen.dart` had a class ordering bug: `_EmptyHistory.build` and its closing `}` appeared after `_SessionTile` (lines 144–168) instead of inside `_EmptyHistory` — executor inserted `_SessionTile` inside `_EmptyHistory`'s body and then orphaned the build method outside.

**Expected:** Executor agents leave the codebase in a compilable, linter-clean state after every build session.

**Reproduction steps:**
1. Run a build session that refactors a screen (e.g., State Controllers — removes `CameraFeedScreen`)
2. Executor implements new architecture but doesn't `grep`/`dart analyze` for orphaned class references
3. Later, run `dart analyze lib/` — 163 errors surface

---

## Fix Implementation

**Summary:** Deleted dead `CameraFeedScreen` from `main.dart` (2820 → 10 lines), added missing `_tokens` getter to `_ProcedureScreenState`, reordered classes in `session_history_screen.dart` and added a local `tokens` var to `_SessionTile.build`, removed obsolete `permission_settings_test.dart` that tested the deleted class. Updated `.main_baseline` ratchet from 2820 → 10.

**Files modified:**
- `lib/main.dart` — deleted dead `CameraFeedScreen` class (lines 12–2820)
- `lib/ui/procedure_screen.dart` — added `LayoutTokens get _tokens => context.layoutTokens` to `_ProcedureScreenState`; removed `const` from two widgets that referenced `_tokens`; removed unused `_tokens` getter from `_ProTipsSectionState`
- `lib/session_history_screen.dart` — reordered `_EmptyHistory` (complete with build) before `_SessionTile`; added `final tokens = context.layoutTokens` to `_SessionTile.build` (lost when class was improperly nested)
- `test/architecture/.main_baseline` — updated ratchet 2820 → 10
- `test/permission_settings_test.dart` — deleted (tested deleted `CameraFeedScreen`)

---

## Root Cause Analysis

**Why it happened:** Two separate executor failures composed into one large error batch:
1. **Incomplete refactor teardown** — the executor implementing State Controllers added the new provider architecture but never searched for or removed the old `CameraFeedScreen` that the new architecture replaced. The ratchet test caught line count growth but was set *after* the bloat was committed, so it couldn't flag it.
2. **Partial cross-file integration** — an executor applying `layout_profile.dart` across multiple files touched some call sites but missed the getter declaration in `_ProcedureScreenState`. It also misplaced `_SessionTile` inside `_EmptyHistory`, orphaning `_EmptyHistory.build` outside the class.

**Prevention:** See rule added to `BUG_PREVENTION.md` — "Executor cross-file integration rules."

---

## Testing & Verification

**Verified by:** `dart analyze lib/` — no issues; `flutter test` — 93/93 passed.
