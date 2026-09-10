# Build with AI — feature-driven implementation agent (Plan v1)

**Status:** Planning (not yet built)
**Date:** 2026-09-10
**Tier:** Pro (paid) — this feature is the subscription hook

## Goal

Let the user stay inside The Forge and watch it *implement a planned feature*: The Forge
calls the LLM, proposes file changes + shell commands, applies what the user approves, runs
commands with **live output streaming into an in-app console**, verifies against the
Handoff checklist, and updates feature/release tracking. No terminal, no external tool.

Unit of work = a **tracked Feature** (status `planned`). The Locked Spec + HandoffPackage
are supplied as *context*, not as the unit.

---

## 1. How the user observes the work — the "Build with AI" window

A dedicated screen (`/implementation`, args `{projectPath, projectName, featureId}`), opened
from a feature's **"Build this"** action. Dark, full-height, three regions:

```
┌───────────────────────────────────────────────────────────────┐
│  ▸ Build: "<feature title>"        <project>   ⏱ 00:42  [Stop] │  header/status bar
│    Phase: Planning → Approve → Applying → Running → Verify → ✓  │
├──────────────────────────────────────────────┬────────────────┤
│  ACTIVITY CONSOLE (monospace, auto-scroll)    │  STEP TIMELINE  │
│  10:02:11  Reading lib/foo.dart               │  ✓ Read files   │
│  10:02:13  Proposing 3 file changes           │  ▸ Edit 3 files │
│  10:02:20  $ flutter pub get                  │  ○ Run cmds     │
│  10:02:21  Resolving dependencies...          │  ○ Verify       │
│  10:02:24  + got 4 packages   (streamed)      │                 │
│  10:02:25  ✓ command succeeded                │                 │
│                                               │                 │
│  ┌── APPROVAL CARD (appears inline) ───────┐  │                 │
│  │ Edit  lib/features/foo/foo_screen.dart  │  │                 │
│  │  <unified diff, before/after>           │  │                 │
│  │  [Approve]  [Skip]      [Approve all]   │  │                 │
│  └─────────────────────────────────────────┘  │                 │
└──────────────────────────────────────────────┴────────────────┘
```

- **Activity console** — the "view window." Monospace (Menlo, reuse `alert_log_screen`
  styling), auto-scrolling, timestamped. Color code: agent narration = amber, commands =
  white bold with `$`, stdout = grey, stderr = red, success = green. **Command output is
  genuinely streamed** via `Process.start` (first use in the app) — that is where the
  "watch it work" terminal feel is real.
- **Approval cards** — the loop is propose-&-approve. When the agent proposes a step the
  console pauses and a card appears inline: edits show a **diff** (Approve / Skip /
  Approve all); commands show the command in plain English + raw form (Run / Skip).
  Every applied edit backs up to `.forge/impl_backups/<runId>/` for **per-step Undo**.
- **Step timeline** — right rail mirroring the plan's steps and the Handoff verification
  checklist, each ○ pending / ▸ active / ✓ done / ✗ failed.

**On the blocking LLM:** `LlmService.complete()` is single-shot (no token streaming). The
*model's* output lands in chunks ("Planning…" → the plan drops in). That's fine for MVP —
the live feel comes from streamed **command** output. Token-streaming the model prose is a
Phase-2 nicety (needs provider streaming, currently `'stream': false`).

---

## 2. Feature + release tracking

### Features (mostly exists — wire up transitions)
The agent drives the existing `FeatureStatus` lifecycle automatically:
- Start a run from a `planned` feature → set **`in_progress`** (write audit note).
- Verification passes + user accepts → prompt to set **`shipped`** and stamp the release
  (`targetVersion`).
- Abandon / verification fails → back to `planned` or **`blocked`** with a reason note.

### Releases (new, lightweight)
`targetVersion` is free text today with no grouping. Add:
- **`Releases` drift table** (schemaVersion **2→3**, create-only migration, same pattern as
  the tracker tables): `id (PK)`, `projectId`, `version`, `status` (`planned`/`released`),
  `releasedAt` (nullable), `notes` (nullable, generated release notes), `gitTag` (nullable).
  Mirror to `.forge/tracker/releases.json`.
- **Releases view** (new tab/section in the tracker): groups features by `targetVersion`,
  shows shipped-vs-pending per version, and a **"Cut release"** action that:
  1. generates **release notes** from the version's shipped features (one LLM call, or a
     deterministic list),
  2. appends them to the project's **CHANGELOG.md** (+ `.forge` copy),
  3. optionally **git-tags** the linked repo and marks the release `released`.
- When the agent ships a feature it can **commit to the linked repo** with a message
  referencing the feature title — so features/releases are tracked in the actual repo too.

---

## 3. What needs to be done now — build phases

Each phase is independently analyzer-clean and shippable.

- **Phase 0 — Entry point + brief.** Add "Build this" to the feature tile popup
  (`project_tracker_screen.dart:462`). Assemble the agent brief: the feature
  (title/description/targetVersion) + the project's current Locked Spec and HandoffPackage
  JSON as context (read from `.forge/`).
- **Phase 1 — Streaming command runner.** A `Process.start` wrapper exposing stdout/stderr
  as a Dart `Stream<ConsoleLine>`; a `RunSession` state model (phases, steps, log buffer).
- **Phase 2 — Agent loop.** LLM (executor role) returns strict JSON:
  `{rationale, fileReads[], edits:[{path, diff}], commands:[{human, raw}]}`. Apply approved
  edits (backup first to `.forge/impl_backups/<runId>/`), run approved commands streamed,
  then run the Handoff **verification checklist** as the success oracle.
- **Phase 3 — The window UI.** Activity console + approval cards + step timeline + header
  (§1). Route `/implementation` in `core/app.dart`.
- **Phase 4 — Feature + release tracking.** Auto status transitions (§2); `Releases` table
  (2→3 migration) + Releases view + release-notes/CHANGELOG generation + optional git
  commit/tag.
- **Phase 5 — Pro gating stub.** An `entitlementProvider` gating the "Build this" entry
  (returns true for now); wired to the managed backend later per the monetization plan.

**MVP = Phases 0–4** (observability + tracking, the two things asked for). Phase 5 is a stub.

---

## Reused, no change
`llmServiceProvider` / `LlmService.complete` (`llm_service.dart:11`); HandoffPackage +
verification checklist (`spec_generator.dart:350,429`); `repoPath` via `readProjectConfig`
(`project_file_repository.dart:338`); `.forge/` layout (`forgeDirName`); tracker DB +
`tracker_repository.dart`; console styling from `alert_log_screen.dart`.

## Net-new confirmed missing
Streaming/tool-calling in providers; any `Process.start`; console/log-stream widget;
entitlement gating; `impl_backups/`; Feature↔spec link; Release entity / release notes /
CHANGELOG generation.

## Open decision
Release granularity: **derive-only from `targetVersion`** vs the **small `Releases` table**
above. Plan assumes the small table (durable release date + notes + git tag). Adjustable.
