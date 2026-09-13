# BUG-IMPL-008 — App aborts (SIGABRT) via drift/sqlite3 FFI teardown on the background isolate

**ID:** BUG-IMPL-008
**Area:** IMPL / DATA
**Severity:** High
**Status:** Fixed (indicated) 2026-09-12

---

## Symptom

"The app is quitting when I try to build features." A macOS crash report shows a
hard **SIGABRT** (`abort() called`) on a **`DartWorker`** thread:

```
dart::Assert::Fail → DLRT_GetFfiCallbackMetadata
sqlite3 functionDestroy → sqlite3LeaveMutexAndCloseZombie → sqlite3Close
```

i.e. the Dart FFI runtime asserted while `sqlite3` destroyed a user-defined
function callback during database close on a background isolate — aborting the
whole process instead of exiting cleanly.

## Root Cause

The local index used `drift_flutter`'s `driftDatabase(name: 'forge_index')`,
which runs the database on a **background isolate** (`NativeDatabase
.createInBackground`). `sqlite3`'s function/collation destructors are
`NativeCallable.isolateLocal` FFI callbacks. When that worker isolate's DB is
closed, the destructor runs in an isolate context the FFI runtime rejects →
`DLRT_GetFfiCallbackMetadata` assertion → `abort()`. The close happens during
teardown, so an upstream hiccup surfaces as a full-app abort.

## Fix

Open the index on the **main isolate** instead. `forge_database.dart` now uses a
`LazyDatabase(() async => NativeDatabase(File(<docs>/forge_index.sqlite)))`
pointing at the **same file** drift_flutter already used
(`~/Documents/forge_index.sqlite`), so no data moves and no migration is needed.
With the DB on the main isolate there is no cross-isolate FFI callback teardown,
eliminating this abort class. The index is tiny (projects/features/tracking/
releases), so main-isolate access has no meaningful cost.

Verified: `dart analyze lib` clean; `flutter test` 33/33 green (incl. build-memory
and doc-manifest suites that exercise the DB layer indirectly).

Note: the crash could not be reproduced live after the analyze-gate build (the
build→analyze→fix loop ran clean), so this is the fix *indicated by the crash
stack*. If a SIGABRT recurs, capture a fresh `.ips` and re-open.

## Prevention Rule

See BUG_PREVENTION.md — "Run drift/sqlite3 on the main isolate unless a workload
truly needs a background isolate; `sqlite3`'s FFI-callback destructors abort the
process if torn down cross-isolate."

## Commit

v0.4.16
