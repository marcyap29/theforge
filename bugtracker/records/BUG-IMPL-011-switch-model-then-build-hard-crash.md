# BUG-IMPL-011 — Switching the Ollama model then pressing Build hard-crashes the app

**ID:** BUG-IMPL-011
**Area:** IMPL
**Severity:** High (hard crash / quit-to-desktop)
**Status:** OPEN — instrumented, awaiting a reproduction trace (v0.5.4)

---

## Symptom

In a single session: change the model **within Ollama** (e.g. `kimi-k2.6` → another
tag) in Settings, then press **Build** on a feature. The app **quits to the
desktop instantly** — the moment Build is pressed, before the model responds.

**Reliable workaround (confirmed by the user):** switch the model, then **fully
quit and relaunch The Forge (Cmd-Q, reopen), THEN Build.** No crash. So the
trigger is the *in-session* state after a model switch, not the model or the
feature.

## What's known

- **It's a NATIVE crash**, not a Dart exception: `main` installs
  `FlutterError.onError` + `platformDispatcher.onError` → `DiagLog.error`, yet
  `diag.log` shows **no error** at the crash times, and there is **no `.ips`
  crash report** either. A Dart throw would be logged and would show a grey error
  screen, not kill the process. A hard quit with nothing logged ⇒ an abort below
  Dart (FFI / isolate), à la BUG-IMPL-008 (drift/sqlite3 FFI teardown SIGABRT).
- **The only difference** between the crashing path (switch → Build) and the
  working path (switch → relaunch → Build) is the **in-session provider rebuild**
  that a model switch triggers: `setRoleAssignment` → `settingsProvider` changes
  → `llmServiceProvider` rebuilds → `implAgentProvider` rebuilds (it `watch`es the
  service). The build window (`implementation_screen.dart`) also `watch`es
  `llmServiceProvider` / `settingsProvider`, so it rebuilds on the switch.
- Reading the source did **not** reveal the exact aborting line — consistent with
  the crash being native (invisible to source-level Dart review).

## Instrumentation added (v0.5.4) — to capture the cause

`DiagLog.breadcrumb(line)` writes **synchronously + flushed** (`writeAsStringSync`,
`flush: true`), so a crumb survives a native abort that an async write would lose.
Breadcrumbs mark each step of the build-start sequence in `ImplRunNotifier.start`
/ `_plan`:

```
start: resolve executor model
plan: enter (phase→planning)
plan: read repo provider
plan: readIngestedSummary
plan: readBuildMemory
plan: gatherDocManifest
plan: read implAgentProvider
plan: agent.proposePlan (→ LLM call)
```

**Reproduce after updating:** switch the Ollama model → Build → let it crash →
the **LAST `CRUMB` line in `diag.log`** names the operation that was running when
the process died. (Running the app from Terminal
(`/Applications/the_forge.app/Contents/MacOS/the_forge`) additionally prints the
native abort reason to stderr.)

## Suspected root cause (to confirm with the trace)

The in-session provider churn from a model switch re-touches a native-backed
resource (most likely the drift/sqlite3 DB on the wrong isolate — the
BUG-IMPL-008 class) during Build-start, aborting the process. The last breadcrumb
will say whether it dies at a DB read (`readBuildMemory` / `gatherDocManifest`),
at a provider read (`read implAgentProvider`), or in the LLM call.

## Next step

Fix once the breadcrumb/stderr trace pins the operation. Until then, the
quit-and-relaunch workaround is the documented guidance.
