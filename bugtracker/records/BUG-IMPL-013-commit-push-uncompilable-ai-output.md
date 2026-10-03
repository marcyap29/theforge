# BUG-IMPL-013 — Pre-build "Commit & push" could commit AI output that doesn't compile

**ID:** BUG-IMPL-013
**Area:** IMPL
**Severity:** High
**Status:** Fixed 2026-10-03

---

## Symptom

Reviewing the AR Mechanic repo, The Forge had left a **stranded, never-compiled
rewrite** of `lib/main.dart` uncommitted in the working tree — a failed
Build-with-AI run (a `_buildInstructionOverlay` redesign that emitted Python-ism
`:.0f` string-format specifiers, `width = …` instead of `width:`, and a
duplicated/merged method body with orphaned fragments). `flutter analyze`
reported dozens of errors.

The dangerous part wasn't the broken code itself — it was the next step. The
pre-build "Uncommitted changes" dialog's **Commit & push** button (added in
v0.4.60) commits whatever is in the tree with the message *"chore: commit work in
progress before AI build"* and pushes it — **with no analysis first**. One tap
would have committed and pushed non-compiling code to the remote. That exact
commit message was already present in AR Mechanic's history (`9609767`).

## Root Cause

**Detection existed; protection did not.** The Build run has an analyze gate
(`ImplRunNotifier._analyzeGate`) that flags `error •` lines, but on failure it
only surfaces the errors for "Fix it" — the broken edits stay applied on disk.
If the run is abandoned, non-compiling code lingers in the working tree.

The pre-build guard that notices leftover work (`_handleUncommittedChanges`) then
treated all uncommitted changes the same and offered to commit+push them
unconditionally. So The Forge's own Standing Rule #4 — *never commit un-analyzed
code* — was enforced for the dev workflow but **not for the product it ships**.

## Fix

`project_file_repository.dart` + `project_tracker_screen.dart`:

1. **Analyze before offering to commit.** `_handleUncommittedChanges` now runs
   `ProjectFileRepository.analyzeClean(repoPath)` (new) on the leftover work
   before building the dialog.
2. **No commit path for broken code.** When analysis reports errors, the
   **Commit & push** button is withheld and replaced with a destructive
   **Discard broken edits** action (`gitDiscardAll` → `git reset --hard HEAD` +
   `git clean -fd`), restoring the last good commit. The dialog retitles to
   "Leftover changes don't compile" and shows the error count. **Build anyway**
   and **Cancel** remain. When analysis is clean (or can't run), the original
   Commit & push flow is unchanged.
3. **Testable core.** The analyzer-output decision is a pure static
   `classifyAnalyzeOutput(out, exitCode)`: counts `error •` lines; treats
   "No issues found!" / "N issue(s) found." / exit 0 as "the analyzer ran",
   otherwise `skipped` so a missing toolchain never masquerades as clean *or*
   broken. Unit-tested in `test/analyze_gate_test.dart` (4 cases).

Net effect: The Forge will not offer to commit code it just determined doesn't
compile, and a failed build is now recoverable with one click instead of
stranding broken edits.

## Prevention Rule

See BUG_PREVENTION.md — "Never commit un-analyzed AI output: gate every
commit/push path on an analyzer check, and when the tree doesn't compile offer
Discard (restore HEAD), never Commit."

## Commit

v0.5.11
