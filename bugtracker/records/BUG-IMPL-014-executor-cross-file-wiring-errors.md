# BUG-IMPL-014 — Executor ships cross-file wiring errors undetected

**ID:** BUG-IMPL-014
**Area:** IMPL
**Severity:** High
**Status:** Fixed 2026-10-23

---

## Symptom

After The Forge built the "State Controllers (Scan, Procedure Session, Settings)"
feature in AR Mechanic, `dart analyze lib/` reported 4 errors that blocked
compilation entirely — even though the build's `flutter test` command reported
all tests passing. The user had to manually diagnose and fix the errors.

---

## Root Cause (all four errors share the same underlying cause)

The executor ran `flutter test` but **not `dart analyze lib/`**. `flutter test`
only compiles files reachable from test imports. The new state controller files
(`lib/state/procedure_session_controller.dart`, `lib/app/container.dart`) had
zero test coverage yet, so `flutter test` passed while the lib/ had hard errors.

The four specific errors:

### Error 1 — Named vs. positional parameter mismatch (`container.dart:28`)

`GeminiService.analyze` uses named parameters:
```dart
static Future<AnalysisResult> analyze({
  required LlmProvider provider,
  required Uint8List jpegBytes,
})
```

The new `ScanController.analyzeImage` field was typed with *positional* params:
```dart
final Future<AnalysisResult> Function(LlmProvider, Uint8List) analyzeImage;
```

The executor wired them directly (`analyzeImage: GeminiService.analyze`) without
noticing the calling-convention mismatch. This is invisible to `flutter test`
because no test calls `ScanController.analyzeImage`.

**Fix:** Adapter lambda in `container.dart`:
```dart
analyzeImage: (provider, jpegBytes) =>
    GeminiService.analyze(provider: provider, jpegBytes: jpegBytes),
```

---

### Error 2 — Reference to a file-private symbol across files (`main.dart:301`)

The executor moved the `_encodeJpegResized` top-level function into
`container.dart` (correct), but left the old `_compressAndResize` method in
`main.dart` calling `_encodeJpegResized` — a Dart `_`-prefixed (file-private)
symbol that is invisible outside `container.dart`.

**Fix:** Added `_encodeJpegResizedMain` as a distinct top-level function in
`main.dart` with the same implementation.

---

### Error 3 — Missing import (`procedure_session_controller.dart:44,172`)

`ProcedureSessionController` uses `LlmProvider` in two method signatures but
the executor never added `import '../llm_provider.dart'` to the file.

**Fix:** Added the missing import.

---

### Error 4 — Nullable type passed to non-null parameter (`procedure_session_controller.dart:223`)

`_stateMachine` is `ProcedureStateMachine?`. The executor stored it into a local
`sm` and then passed it directly to `stepVerifier.nextState(stateMachine: sm, ...)`
which requires non-null. A null guard already existed four lines above (`if
(step == null) return;` — which fires when `sm` is null), but the executor did
not use `sm!` to communicate that to the type system.

**Fix:** `stateMachine: sm!` at the call site.

---

## Why `flutter test` didn't catch this

`flutter test` compiles only files reachable from test file imports. All four
broken files were new and had no tests yet. The test suite passed 87/87 while
the library had 4 hard errors — a false-negative safety signal.

`dart analyze lib/` analyses the *entire* library regardless of test coverage,
and would have caught all four errors immediately.

---

## Fix Summary

| File | Change |
|---|---|
| `lib/app/container.dart` | Adapter lambda for `GeminiService.analyze`; removed dead private methods; removed orphaned imports |
| `lib/main.dart` | Added `_encodeJpegResizedMain` top-level function; removed duplicate `flutter/material` import |
| `lib/state/procedure_session_controller.dart` | Added `import '../llm_provider.dart'`; `sm!` at call site; removed unused imports |

---

## Grep to catch this class of bug

```bash
# Missing imports (undefined names)
dart analyze lib/ 2>&1 | grep "undefined_"

# Signature mismatches at wiring points
dart analyze lib/ 2>&1 | grep "argument_type_not_assignable"

# Nullable passed to non-null
dart analyze lib/ 2>&1 | grep "argument_type_not_assignable\|null_check"
```

All four errors would have been caught by a single `dart analyze lib/` run.
