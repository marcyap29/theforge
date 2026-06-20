# BUG-INTERVIEW-004 — LLM List Field Parse TypeError Silently Degrades Entire Parse

**ID:** BUG-INTERVIEW-004
**Area:** INTERVIEW
**Severity:** Critical
**Status:** Fixed 2026-06-19

---

## Symptom

The Generate Spec button never appeared even after completing all 4 interview layers. The confidence meter showed 7/8 dimensions resolved with `externalServices` stuck at Unknown. The LLM's responses indicated the interview was complete, but the app remained stuck.

## Root Cause

`parseForgeState` used a hard cast:
```dart
'externalServices':
    (extractedRaw['externalServices'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        <Map<String, dynamic>>[],
```

LLMs frequently output `"externalServices": "None"` or `"externalServices": "N/A"` (a string) for projects with no external services. The `as List<dynamic>?` cast throws a `TypeError` at runtime. The outer `try/catch` in `parseForgeState` catches this and returns `degradedResult()` — with `extracted: null`.

This means **every turn** where the LLM outputs a non-list value for ANY field causes the entire parse result to be discarded. `mergedExtracted` is not updated; `_confidenceFromExtracted` never sees the correct data; `externalServices` stays Unknown; `allResolved = false`; `specGenEnabled` never fires.

The same pattern affected `capabilities`, `demoScript`, and `v2Seeds` (BUG-INTERVIEW-005).

## Fix

**1. Safe parsing in `parseForgeState`:**
```dart
'externalServices': extractedRaw['externalServices'] is List<dynamic>
    ? (extractedRaw['externalServices'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList()
    : <Map<String, dynamic>>[],
```

**2. Semantic confidence resolution:**
`_confidenceFromExtracted` was checking `extracted['externalServices'] is List` — but the initial state value is already `[]` (always a List), so this resolved from turn 1 in theory, but in practice the corrupt string value had been merged and overwritten it. Changed to: resolve `externalServices` when the other L4 fields (platform, identityModel, inputModel, outputModel) are all non-null — the semantically correct signal.

**3. Gate relaxation:**
`specGenEnabled = (allResolved || _layerGateMet('L4', mergedExtracted)) && newConflicts.isEmpty`

**4. Restore re-evaluation:**
`_restoreState` now re-evaluates `specGenEnabled` via `_layerGateMet('L4', ...)` rather than trusting the saved boolean (which may have been `false` if the interview was completed with buggy code).

## Prevention Rule

See BUG_PREVENTION.md — "All LLM JSON list fields must use `is List<dynamic>` check, NOT `as List<dynamic>?` hard cast."

## Commits

- `7390568` — initial externalServices fix
- `0c2f4b1` — extended to all list fields + gate relaxation
- `3721a29` — restore re-evaluation fix
