# The Forge — Feature Catalog

**Last Updated:** 2026-09-10

---

## Core Features

| Feature | Status | Notes |
|---|---|---|
| Build Interview (8-dimension confidence model) | Planned | §2 in backlog |
| Audit Interview (current state spec) | Planned | §6 in backlog |
| Monte Carlo spec generation (3 parallel variants) | Planned | §3 in backlog |
| Locked spec (immutable, versioned) | Planned | Part of §3 |
| Bullet handoff (phase transition summary) | Planned | Part of §3 |
| Setup worksheet (external services checklist) | Planned | §9 in backlog |
| Handoff package (JSON, for executor agents) | Planned | Part of §3 |
| Project folder browser (list + resume) | Planned | §4 in backlog |
| Artifact viewers (spec, handoff, worksheet, audit) | Planned | §5 in backlog |
| Document ingestion (PDF, Word, Markdown) | Planned | §7 in backlog |
| Workspace + billing ($150/workspace/month) | Planned | §8 in backlog |
| Audit trail export (versioned, client deliverable) | Future | §11 in backlog |
| Open source executor path (tool-agnostic JSON spec) | Future | §10 in backlog |

---

## Portfolio Tracker

| Feature | Status | Notes |
|---|---|---|
| Portfolio dashboard | Shipped | Home route `/`; old project list moved to `/projects` |
| Feature board (status tracking) | Shipped | Grouped by idea/planned/in_progress/blocked/shipped/archived; providers in `lib/features/tracker/**` |
| Auto-scan features (docs + repo) | Shipped | `FeatureScanner` proposes features from `.forge` docs and/or a linked repo |
| Virtual-PM check-ins | Shipped | `CheckinService` diffs git since last review → status changes/new features/flags + staleness banner |
| Import → Spec | Shipped | Paste description/doc/transcript → `ImportService` → existing `SpecGenerationScreen` |
| Repo onboarding (Quick/Deep) | Shipped | Quick = docs+structure; Deep also reads code via `scanProjectCodebase`+`analyzeFileBatch`; unknowns → gaps |
| Export docs | Shipped | `doc_export.dart` copies `.forge` deliverables to `<chosen>/forge-docs/` |
| Project deletion (safe) | Shipped | Index + folder cascade, guarded to the canonical projects root |
| Dictation (`theforge://paste`) | Shipped | URL scheme → `lib/services/paste_receiver.dart` |

---

## Build with AI — Implementation Agent

| Feature | Status | Notes |
|---|---|---|
| Build with AI (implementation agent) | Shipped v0.4.0 | `lib/features/implementation/**`; two-pass scout→plan, propose-approve-verify, streamed build window |
| Ingested reference context in builds | Shipped v0.4.8 | Builder reads `.forge/ingested/reference_context.md` (same pool as interview/spec) each planning round; always-on `## Reference context` slot in `ImplAgent.buildUserContext`; console shows `Loaded reference context (~N words)`; visible over-budget trim markers; spec cap 6k→12k |
| Feature-build memory (gained + remains) | Shipped v0.4.9 | Shipping a feature writes a "what/why/files" record to `.forge/build_memory/<featureId>.md` (one per feature, overwritten on re-ship); every later build reads them back via `readBuildMemory` into a `## Prior builds` slot; console logs `Loaded build memory (N prior features)` / `Saved to build memory…` |
| Doc-aware scout (unified manifest) | Shipped v0.4.10 | `gatherDocManifest` builds one `DocPoolEntry` per ingested doc + build-memory record; scout receives the manifest for pools that overflow their always-on cap and returns a `docs` array; `readDocEntry` (sandboxed) fetches full text into a `## Retrieved reference material` Pass-2 block, de-duped against always-on context. No change for small pools |
| Live reasoning streaming | Shipped v0.4.0 | `LlmService.completeStream` + `LlmDelta{text, thinking}`; Ollama/Claude/OpenAI real streaming; reasoning shown in collapsible `thinking` console line |
| Modify-plan (edit / revise) | Shipped v0.4.0 | Edit the proposed plan inline or revise via free-text feedback → re-plan through shared revision block |
| Fix-on-failure | Shipped v0.4.0 | Verify failure (e.g. `dart analyze`) routes back through `_plan` in fix mode for a corrective plan |
| Undo (edit backups) | Shipped v0.4.0 | Applied edits backed up to `.forge/impl_backups/`; one-click revert |
| Streamed command runner | Shipped v0.4.0 | `Process.start` streaming + denylist + 3-min timeout; first streamed subprocess in the app |
| keepAlive per-feature runs | Shipped v0.4.0 | Live build resumes on navigate-back; generation counter discards stale streams |
| Entitlement gate | Stub v0.4.0 | Entitlement check present as a stub in `implementation_providers.dart`; not yet enforced/monetized |

---

## Releases

| Feature | Status | Notes |
|---|---|---|
| Release tracking | Shipped v0.4.0 | `Releases` drift table (schemaVersion 2→3, create-only); mirrored to `.forge/tracker/releases.json` |
| Cut release | Shipped v0.4.0 | `release_providers.dart` — group features by version → notes → CHANGELOG + git tag; feature status auto-transitions on ship |

---

## Design System & Onboarding (v0.4.0)

| Feature | Status | Notes |
|---|---|---|
| ForgeTheme (design language v2) | Shipped v0.4.0 | `lib/core/theme/forge_theme.dart` — navy + ember/brass; replaced `AppTheme`; `rust #7A3826` = blocked/stuck |
| Hearth Dial brand mark | Shipped v0.4.0 | `lib/core/widgets/hearth_dial.dart` — `CustomPainter` |
| Launch splash + launch→home routing | Shipped v0.4.0 | `lib/features/launch/launch_screen.dart`; `/` splash → `/home` |
| First-run onboarding | Shipped v0.4.0 | `lib/features/onboarding/first_run_screen.dart` |
| Portfolio digest | Shipped v0.4.0 | `lib/features/tracker/widgets/portfolio_digest.dart` — `portfolioDigestProvider` + panel + `ForgeAppHeader` |
| Active model chip | Shipped v0.4.0 | `lib/features/tracker/widgets/active_model_chip.dart` |
| New Project 2-up | Shipped v0.4.0 | `new_project_screen.dart` reduced to two modes |
| Create a code folder | Shipped v0.4.1 | `ProjectFileRepository.createCodeRepo` — makes `~/Development/<name>`, `git init`, links it; offered in the Link-Repo row and the Build-with-AI no-repo prompt |
| Vibecode prompt + Esc interrupt | Shipped v0.4.4 | Persistent input in the Build window (`notifier.steer`); Escape stops the running task |
| Copyable build console + raw-output on failure | Shipped v0.4.5 | `SelectionArea` + Copy-all; failed planning prints the model's raw output for diagnosis |
| Build-with-AI compose screen | Shipped v0.4.7 | No auto-run; on-screen hints + prompt box; nothing sent until the user acts |
| Build action buttons | Shipped v0.4.7 | Right-side: Build this feature / Run checks / Fix errors / Commit & push (git) |
| Re-edit shipped features | Shipped v0.4.4 | "Build with AI" available on non-archived features, incl. shipped ("Re-build / edit with AI") |
| Relocate code repo (any time) | Shipped v0.4.11 | `relocateRepoFlow` + `ProjectFileRepository.relocateRepo`/`createEmptyCodeFolder`; "Change code location" in the Build window toolbar and the detail-screen repo row moves code to a new folder + repoints config; `isInsideProjectsRoot` guard blocks using a Forge workspace as a repo (BUG-IMPL-006) |

---

## Interview Modes

| Mode | Use case | Output |
|---|---|---|
| Build Interview | Greenfield — nothing exists yet | Locked Spec |
| Audit Interview | Existing team or codebase | Current State Spec |

---

## Outputs Per Run

| Output | Description | For |
|---|---|---|
| Locked Spec | Immutable architecture document | Executor agents |
| Bullet Handoff | Human-scannable phase transition summary | The Forge on resume + user |
| Setup Worksheet | Step-by-step human-action checklist for external services | User |
| Handoff Package | JSON summary of the run | Next agent or session |
