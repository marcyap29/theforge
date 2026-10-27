# BUG-UI-005 — RenderFlex overflow in Row with Expanded + long button label causes widget test failures

**Date:** 2026-10-26
**Reporter:** session
**Severity:** High
**Status:** Fixed
**Area:** UI

---

## Bug Description

**Symptom:** Plumbline's `GenerateRequirementsPage extracts pasted text into sidebar` widget test failed with:
```
The following assertion was thrown during layout:
A RenderFlex overflowed by 135 pixels on the right.
The relevant error-causing widget was: Row Row:file:///…/lib/main.dart:581:11
```
After tapping "Use pasted text", `_selectedText` became non-null and the "Generate Requirements" `ElevatedButton.icon` appeared in the 227px-wide source panel header Row. The button's full label ("Generate Requirements" + icon) required ~362px, causing a 135px overflow. Flutter's test framework treats `RenderFlex` overflow as a test failure exception.

**Expected:** Row with `Expanded(title)` + button fits any viewport; no overflow in tests.

**Root causes (compound):**
1. **Layout bug** — A Row containing `Expanded(Text)` alongside `ElevatedButton.icon(label: 'Generate Requirements')` overflows in narrow viewports (400px test device → panel is 227px after sidebar).
2. **Executor diagnosed wrong widget** — The overflow error named `main.dart:581`. The executor instead fixed the *sidebar* header Row (line ~772 — the Clear button) three times, never touching line 581.
3. **Inspector called it "unrelated"** — The Inspector's verdict was "the failing test is unrelated to the new feature," causing the Forge to loop on Fix attempts instead of escalating.

---

## Fix Implementation

**Summary:** Wrapped the `ElevatedButton.icon` at line 581 in `Flexible` AND shortened its label from `'Generate Requirements'` → `'Generate'`. Both changes together are required: `Flexible` alone doesn't prevent overflow when the minimum button width (set by the long label) still exceeds available space.

**Files modified:**
- `lib/main.dart` (Plumbline) — `Flexible` wrapper + label shortened to `'Generate'`

---

## Root Cause Analysis

**Why it happened:**
- `ElevatedButton.icon` with a long label in a Row alongside `Expanded` overflows when the Row's parent is constrained narrower than the button's intrinsic width. `Expanded` absorbs remaining space but cannot give the button *less* than its minimum — so the button overflows instead.
- The executor read the error line number (`581`) but edited a *different* Row in the same file (the sidebar Clear button at ~line 772). The line numbers shifted across edits, and the executor conflated the two Rows.
- The Flutter test device is 400×800px by default; a sidebar-left layout gives the source panel only ~120–227px, far less than desktop where the layout looks fine.

**Prevention:** See rules added to `BUG_PREVENTION.md` — "Flutter Row overflow rules."

---

## Testing & Verification

**Verified by:** `flutter test` — 15/15 passed; `flutter analyze` — no issues.
