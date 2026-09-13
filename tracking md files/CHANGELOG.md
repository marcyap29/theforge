# The Forge — Changelog

---

## v0.4.11 — 2026-09-12

- **Set / move a project's code location, front and centre.** The feature board now has an always-visible **Code:** bar at the top showing where the project's code lives, with **Set code location** (when none is linked) or **Change** + **Scan** (when it is). This is the entry point for pointing a project at a repo — so you can immediately scan an existing codebase or set where new source gets generated. The same **Change code location** action is also in the Build-with-AI window's toolbar and the project detail screen's repo row.
- **Relocate moves the code for you.** Creating a fresh folder under `~/Development` or picking an existing one **moves the existing code across** and repoints the project. The Forge deliverables (`.forge/` and the project-state `README.md`) stay in the workspace.
- **Guard: a Forge project workspace can no longer be used as a code repo.** Linking/relocating now rejects any folder inside `~/Documents/The Forge Projects/`. Root fix for **BUG-IMPL-006**: AR Mechanic's `repoPath` had been pointed at its own Forge workspace, so Build-with-AI wrote `lib/`, `pubspec.yaml`, `android/`, `ios/` in among the specs/handoffs — and a separate agent looking under `~/Development/ar_mechanic` couldn't find the generated code. (AR Mechanic's code has been moved to `~/Development/ar_mechanic` and its config repointed.)
- New repository helpers: `relocateRepo` (safe move, never touches `.forge`), `createEmptyCodeFolder`, and `isInsideProjectsRoot`.
- **Re-scanning no longer doubles features (BUG-TRACKER-001).** A scan (and check-in) now dedups proposed features against what's already tracked — matched on a normalized title (case-/punctuation-insensitive) — so running the scan repeatedly can't re-add the same planned/idea items. The import toast now reports how many were skipped as already tracked. (AR Mechanic's existing duplicates — 34 rows down to 19 — were cleaned up, keeping the most-recently-updated copy of each so manual status changes survived.)

---

## v0.4.10 — 2026-09-12

- **The build AI can now pull the right docs on demand.** As a project accumulates reference documents and prior-build records, they can outgrow what fits in every prompt. The build agent's "scout" pass now sees a compact **manifest** of the whole document pool and requests, by name, the specific reference doc or prior feature it needs for the task — the same way it already picks which code files to read. Retrieved material is fed into the plan and de-duplicated against what's already shown.
- **Small projects are unchanged.** This only kicks in when a pool is too large to show in full; below that, everything is already always-on, so nothing changes. The console now names any reference docs it pulled (`… · N reference doc(s): …`).

---

## v0.4.9 — 2026-09-11

- **Builds now remember what you built before.** When you **ship** a feature, The Forge saves a durable record — what was built, why, and which files changed — into a per-project **build-memory** pool (`.forge/build_memory/`). Every later build reads that pool back, so the AI follows the patterns and file layout it already established instead of starting cold. This is the "context that's gained and remains" — the same way a human (or Claude Code) carries forward what it learned earlier in a project.
- **Re-shipping updates, never duplicates.** Each feature keeps one record (overwritten on re-build), so the memory stays clean as you iterate.
- **Visible in the console.** A build now logs `Loaded build memory (N prior features)` when planning, and `Saved to build memory…` when you ship — so you can see context accumulating.

---

## v0.4.8 — 2026-09-11

- **Builds now start with your reference docs, not just code.** The Build-with-AI agent reads the project's **ingested reference context** — the same document pool the interview and spec stages already use — on every planning round. Previously the builder only saw the locked spec (silently cut at 6k chars), a fixed doc whitelist, and the code file list; the intake docs never reached it. Add docs on the project and they now ground every feature build.
- **You can see the context load.** The build console prints `Loaded reference context (~N words)` (or a nudge to add docs if the pool is empty), so it's no longer a mystery whether the app had your context.
- **No more silent truncation.** Over-budget spec/reference context is now marked with a visible `…(trimmed — N chars dropped)` note instead of being cut without warning, and the spec cap was raised from 6k to 12k chars.

---

## v0.4.7 — 2026-09-11

- **Build with AI no longer auto-runs.** Opening the window now shows a **compose screen** with on-screen hints — nothing is sent to the AI until you choose. Type what you want done in the prompt box (pre-filled with the feature's description) and press ↑, or use the new right-side **action buttons**.
- **Right-side action buttons** for the things you do over and over: **Build this feature**, **Run checks** (analyze + tests), **Fix errors**, and **Commit & push** (stages/commits the linked repo and pushes to origin — deterministic git, no AI). Buttons + the manual prompt box share one input.

---

## v0.4.6 — 2026-09-11

- Fixed "Mark shipped" doing nothing in the build window (BUG-IMPL-005) — when a run was re-attached (the common case for a finished run), the shipped result was discarded, so you had to exit and ship from the board. Shipping is now applied from the persistent run state on both the fresh and re-attach paths.

---

## v0.4.5 — 2026-09-11

- **Copy from the build console** — the console is now selectable (`SelectionArea`: drag-select + ⌘C) and there's a **Copy-all** button in the header, so you can grab an error/output and paste it back for a fix.
- **See why planning failed** — on a "did not return valid JSON" failure the console now prints the model's **raw output** (selectable/copyable) instead of just a generic error, so the actual cause is visible. Plan token ceiling raised to 16000 so heavy reasoning can't starve the answer.

---

## v0.4.4 — 2026-09-11

- **Vibecode in the app** — the Build window now has a **persistent prompt box** at the bottom (like Claude Code): type an instruction any time the agent is idle (awaiting approval, or after a run finished/failed) and it re-plans with your message. Replaces the phase-limited "Revise" box.
- **Esc to interrupt** — pressing Escape stops the running task, like Ctrl-C in a terminal.
- **Re-edit shipped features** — "Build with AI" is now available on shipped features too (labelled "Re-build / edit with AI"), so a finished feature can be re-opened and edited/extended instead of being locked.

---

## v0.4.3 — 2026-09-10

- **Build with AI now edits via targeted find/replace hunks, not full-file rewrites.** The model returns small `{find, replace}` hunks (exact snippets) for existing files and only returns full `content` for brand-new files. This fixes at the root both the truncation-driven "did not return valid JSON" failures (BUG-IMPL-004 — the model was asked to reproduce a whole file it only saw the first 6k chars of) and the full-file-rewrite corruption that dropped code (BUG-IMPL-003). Files are now read at a much larger cap (24k/file, 90k total) so hunks match reliably. Unlocatable hunks are skipped with a note instead of failing the run.
- The build STEPS timeline no longer shows every step green when a run actually failed.

---

## v0.4.2 — 2026-09-10

- Fixed Build with AI "Planning failed: did not return valid JSON" (BUG-IMPL-004) on heavy reasoning models — the model spent its turn thinking and never emitted JSON. Ollama now sends `num_predict` (generous ceiling so thinking can't starve the answer), the plan pass budget is larger (8000; scout 4000), the prompt forbids "asking for more files" and forces JSON-only output, and the agent auto-retries once before failing. Tip: prefer an instruction-following/coder model for Build with AI.

---

## v0.4.1 — 2026-09-10

- Create a code folder from inside The Forge — the "Link Repo" row and the Build-with-AI "no repo" prompt now offer **"Create a new code folder"**, which makes `~/Development/<name>`, `git init`s it, and links it automatically (or **"Link an existing folder"**). Closes the onboarding gap where a non-technical user had no repo for Build with AI to write into. New helpers `ProjectFileRepository.createCodeRepo` / `defaultCodeRoot`.
- Hardening — the sandbox guard for agent writes (`ImplWorkspace.isPathSafe`) rejects absolute/`..` paths so a model-supplied edit can never escape the linked repo; folder pickers now pass `lockParentWindow` (BUG-UI-003).

---

## v0.4.0 — 2026-09-10

- Build with AI (§BWAI, Pro) — from a tracked feature, The Forge itself calls the LLM to implement it: a propose-&-approve loop that applies approved edits with per-step Undo (`.forge/impl_backups/<runId>/`), runs approved commands with live streamed output (`Process.start`), and verifies against the Handoff checklist; new `lib/features/implementation/` module
- Two-pass read-then-edit loop — scout picks files → The Forge reads them → the agent plans edits grounded in real code (plus repo docs: README/ARCHITECTURE/CLAUDE.md/agents.md)
- Real token streaming across all LLM providers — `LlmDelta{text,thinking}` + `completeStream`; reasoning models (glm-5.3, gpt-oss:120b) stream their chain-of-thought live (Ollama `message.thinking`)
- Build console — visible scrollbar + smart stick-to-bottom, reasoning as real scrollable lines, internal thinking (dim) vs external presentation (green), collapsible inline "thinking" block, guaranteed green Summary, active-model chip + wait-heartbeat + elapsed timer
- Modify / Revise / Fix — hand-edit a proposed file's content or a command; **Revise** (steer the AI → re-plan); **Fix-on-failure** (feed command failures + failed checklist items back to the agent for a corrective plan)
- Runs survive navigation (keepAlive) and re-attach on reopen; per-feature board status dots; tap an in-progress feature to open its run
- Release tracking — new `Releases` drift table (schemaVersion 2→3), a per-version Releases view, and "Cut release" → deterministic notes → CHANGELOG.md + optional git tag
- New Project reduced to two vibecoder choices (§NP2) — "Describe a new app" (Import→Spec, Paste/Guided sub-toggle) and "Bring in existing code" (onboarding); audit-interview retired from the picker
- Forge design kit (§UIK) — new `ForgeTheme` (navy + ember/brass metals), the Hearth Dial mark (`lib/core/widgets/hearth_dial.dart`), a launch splash driven by real boot steps, a first-run onboarding screen, a portfolio digest ("what changed since you last looked"), and `ForgeAppHeader`; design language v2: `rust (#7A3826)` marks blocked/stuck

### Fixed

- BUG-LLM-001 — reasoning models showed nothing while streaming (only `content` was read; now reads the thinking channel too)
- BUG-IMPL-001 — Stop → Try again crashed (stale-stream race; fixed with a generation counter)
- BUG-IMPL-002 — app quit on Apply & Run (unbounded console + unsafe/hung command; fixed with a console cap + command denylist + 3-min timeout + guarded run)
- BUG-IMPL-003 — a Build-with-AI run on The Forge corrupted `app.dart` + `settings_notifier.dart` via a full-file rewrite that dropped code; caught in review and reverted (never shipped); real fix (diff-based edits) tracked as a follow-up

## v0.3.0 — 2026-09-10

- Portfolio Tracker — new home dashboard plus per-project feature board with status tracking (idea/planned/in_progress/blocked/shipped/archived)
- Auto-scan + virtual-PM check-ins — `FeatureScanner` proposes features from `.forge` docs and/or a linked repo; `CheckinService` diffs git since last review into status changes, new features, and flags
- Import → Spec + existing-repo onboarding — paste a description/doc/transcript or analyze a repo (Quick docs+structure / Deep code-reading), with a compressed CONFIRM/gap form, into the existing spec pipeline
- Doc-based feature scan — features distilled directly from a project's own `.forge` documents
- `.forge` deliverable layout — all generated artifacts moved under a hidden `.forge/` folder with a fixed canonical projects root; "Export docs…" copies deliverables to `<chosen>/forge-docs/`
- Project deletion (safe) — double-confirm, index+folder cascade, guarded to the canonical root
- Provider layer — Ollama Cloud (`gpt-oss:120b-cloud`) is the default; Gemini removed entirely
- Dictation input via the `theforge://paste` URL scheme
- Cross-platform app icon
- Deploy scripts (`tool/deploy_{macos,ios,android}.sh`) + macOS unsandboxed, direct Developer ID distribution
- Fixed BUG-SETTINGS-002, BUG-UI-003, BUG-DATA-001

## v0.2.0 — 2026-06-01

- Backlog rewritten from 11 items to 16 items, grounded in Obsidian product docs (Workflow Template v3.0, Positioning Brief v4.0, ForkIt worked examples)
- Stale Firestore/Firebase Function references removed from §2–§9
- Critical path corrected: project folder browser now precedes interview
- New backlog items: §2 Riverpod state layer, §4 LLM provider layer, §9 Handoff Package, §10 Settings + BYOK, §14 Monte Carlo spec generation
- DeepSeek v4 Pro registered in agent registry as Rank 1 Executor (4.6/5)
- §1 Flutter Bootstrap + Local Data Layer — complete ✅

## v0.1.0 — 2026-05-31

- Initial repo bootstrap from Starter Repo
- Architecture defined, backlog seeded, docs scaffolded
- No Flutter code yet — docs and config only
