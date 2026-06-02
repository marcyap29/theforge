# The Forge — Session Log

Newest session first. Each block is prepended.

---

## Session: 2026-06-01 — §5 Build Interview UI + State

### What was done
- Created `lib/features/interview/state/interview_state.dart` — `ConfidenceDimension` enum (8 values, with `.label` and `.question` extensions), `DimensionState` enum (unknown/partial/resolved), `InterviewTurn`, `ConflictItem`, `InterviewState` model (with `.empty()` factory and `copyWith`)
- Created `lib/features/interview/state/interview_notifier.dart` — `FamilyAsyncNotifier<InterviewState, InterviewArgs>` + `stubInterviewStep()` top-level function (turn-based deterministic stub: 9 user messages cycle through the 8 dimensions, surface a `corePurpose ↔ identityModel` conflict on turn 3). Single call site flagged with `// §5 LLM STUB:` comment for §4 swap.
- Created `lib/features/interview/providers/interview_providers.dart` — `InterviewArgs` class (with `==`/`hashCode` for family equality) + `interviewProvider` (`AsyncNotifierProvider.family<InterviewNotifier, InterviewState, InterviewArgs>`)
- Created `lib/features/interview/ui/confidence_meter.dart` — `ConfidenceMeter` widget with 8 horizontal `LinearProgressIndicator` bars; bar fill = 0% unknown / 50% partial / 100% resolved; track color `#1F2937`, state colors gray/amber/green
- Created `lib/features/interview/ui/interview_screen.dart` — `ConsumerStatefulWidget` watching `interviewProvider(args)`; layout: `AppBar` (with restart icon) → `ConfidenceMeter` → optional `_ConflictSurface` (only when `openConflicts.isNotEmpty`) → `Expanded` chat history (`_TurnBubble` per turn) → `_Composer` (text input + send button, disabled while `isLoading`) → `FilledButton.icon` "Generate Spec" (only when `specGenEnabled`, click shows §6 SnackBar)
- Updated `lib/core/app.dart` — added `'/interview'` named route; route builder reads `ModalRoute.settings.arguments`, casts to `InterviewArgs`, falls back to `_MissingRouteArgs` helper screen if args absent
- Verified: `dart analyze lib/` → No issues found
- Verified: zero Firebase imports

### Architectural decisions
- Family provider with `InterviewArgs` (path + name) — one interview state per project; switching projects gets its own state for free
- Stub LLM is a pure top-level function `stubInterviewStep(state, userMessage)` returning a record `({String interviewerText, Map confidenceUpdates, List newConflicts})`. Notifier is the only caller. §4 swap = replace one function call with `await llmProvider.complete(...)` and JSON-parse the result.
- Stub is turn-counter driven (count user turns), not message-content driven — keeps the stub deterministic and the test path short (9 user messages = 8 resolved + 1 surfaced conflict)
- Conflict text follows Workflow Template pattern verbatim: "Your answers on [X] and [Y] pull in opposite directions. [X] implies [consequence]. [Y] implies [consequence]. I recommend [conservative option] for v1 because [reason]. Do you accept this scope?"
- `specGenEnabled` is a stored field on the state, recomputed on every transition (all 8 resolved + 0 open conflicts). Not a getter — explicit state machine field.
- `isLoading` gates the text input, send button, AND conflict Accept button — prevents race conditions where user resolves a conflict during the 400ms stub latency
- Composer is a `SafeArea(top: false)` so the iOS-style home indicator doesn't overlap the input on macOS
- Send button shows a `CircularProgressIndicator` (not a static icon) while `isLoading` — visual feedback that the LLM call is in flight
- Chat bubbles: user right-aligned (`#1F2937`), interviewer left-aligned (`#1C1C1E`); max width 640px; role label "YOU" / "INTERVIEWER" in 10px gray
- Auto-scroll to bottom on new turn via `WidgetsBinding.instance.addPostFrameCallback` — guard with `hasClients` check
- Entry point (button in project list to push `/interview`) deliberately out of scope — user can add in §6, §7, or hot-reload. Route is registered and ready.

### Open items / next
- §4 LLM Provider Layer (replaces the stub)
- §6 Spec Generation (the "Generate Spec" button action)
- Entry-point wiring: project list or detail stub → push `/interview` with `InterviewArgs`

---

## Session: 2026-06-01 — §3 Project Folder Browser

### What was done
- Rewrote `lib/main.dart` to wrap `TheForgeApp` in `ProviderScope`
- Created `lib/core/app.dart` — `TheForgeApp` MaterialApp with dark theme + `ProjectsListScreen` as home
- Created `lib/core/theme/app_theme.dart` — macOS dark theme, Menlo monospace, Forge amber (`#E8A04C`) primary, minimal chrome
- Created `lib/features/projects/screens/projects_list_screen.dart` — `ConsumerWidget` with:
  - `AsyncValue<List<Project>>` states (loading / error+retry / empty / data)
  - List rows showing name, phase, mode, last-opened date
  - `_ModeBadge` chip (amber for Build, slate for Audit)
  - Pull-to-refresh + AppBar refresh icon → `projectListProvider.notifier.refresh()`
  - Tap row → `activeProjectProvider.open(path, repo)` → push `_ProjectDetailStub` reading `activeProjectProvider`
  - FAB → push `_NewProjectStub` placeholder
- Verified: `dart analyze lib/` → No issues found
- Verified: zero Firebase imports

### Architectural decisions
- Inline `_ProjectDetailStub` and `_NewProjectStub` in the list screen file — keeps the §3 file count to 4 per the task scope
- Detail stub reads `activeProjectProvider` and renders the README.md content as monospace text
- `ActiveProjectState` exposes `readmeContent` only — no `error` field — detail stub simply shows `(no README.md found)` when null
- Navigator captured to local before `await` to avoid `use_build_context_synchronously` lint
- Theme: `ColorScheme.dark` with explicit `primary`/`surface`/`onSurface`/`error`; `Card` + `Divider` + `ListTile` themes set for flat dark macOS feel
- `floatingActionButtonTheme` uses primary as background, background as foreground (inverse) for contrast

### Open items / next
- §4 LLM Provider Layer (BYOK + SwarmSpace)
- §10 Settings screen (provider config UI; back-end to read it lives in §4)
- Detail screen will need real resume logic (read README + most recent bullet handoff + locked spec) once §9 lands

---

## Session: 2026-06-01 — Build order strategy + agent registry updates

### What was done
- Scored Minimax M3 on /goal integration task: 5/4/4/5/4 = 4.4 → Rank 1; added to agent registry in `agents md files/agent_scoping.md`
- Added strategic priority block to backlog.md: build order gate (Forge #1 → SwarmSpace Builder #2 → Iterix #3) — every §N on the critical path now explicitly unblocks the full product roadmap
- Bootstrapped Iterix repo at `/Volumes/Marc Working Drive/Development/Iterix/` from Starter Repo scaffold: CLAUDE.md, backlog §1–§9, ARCHITECTURE.md, agents.md, planner.md, context.md, all SOP boilerplate, git init + initial commit

### Key decisions
- Iterix is product #3: built after The Forge (#1) and SwarmSpace Visual Builder (#2)
- The Forge is used to dogfood the spec for SwarmSpace Builder; SwarmSpace Blocks used to build Iterix
- Iterix stack is an explicit open flag — no code until The Forge interview produces the locked spec
- Minimax M3 confirmed Rank 1 for doc-layer / multi-file markdown update tasks

### Next
- §3: Project folder browser screen (Flutter macOS UI, lists projects from `projectListProvider`)

---

## Session: 2026-06-01 — /goal integration updates

### What was done
- Applied /goal integration brief to The Forge workflow documentation
- Added Completion Criteria section to Locked Spec format (Stage 2) in
  both repo workflow_template.md and Obsidian source copy
- Added Stage 4b (/goal text output) to workflow_template.md — format,
  naming convention, and write path defined
- Updated Stage 5 executor handoff checklist — two new required items
- Updated Bullet Handoff format — Completion Criteria met field added
- Updated backlog.md §6 (spec structure +1 item) and §9 (3 outputs, not 2)

### Key decisions
- The /goal text is written to /handoffs/ alongside the Bullet Handoff,
  not as a separate artifact type — same write path, different filename
- Completion Criteria is inserted at position 5 in the spec structure,
  after Interface Contracts and before Static Content Specs
- Bullet Handoff gains "Completion Criteria met" field for v2 interview
  context — executor loop results travel forward through the audit trail

### Next
- §3: Project folder browser screen (Flutter UI)

---

---

## Session: 2026-06-01 — §2 Riverpod Project State Layer

### What was done
- Created `lib/features/projects/providers/project_list_notifier.dart` — `ProjectListNotifier` (AsyncNotifier) scans filesystem via `ProjectFileRepository.scanProjectPaths()`, upserts missing entries into `ForgeDatabase`, returns `getAllProjects()`. `refresh()` method invalidates self and awaits future.
- Created `lib/features/projects/providers/active_project_notifier.dart` — `ActiveProjectNotifier` (Notifier) with `ActiveProjectState` (projectPath, projectName, readmeContent, isLoading). `open()` sets isLoading → reads README.md → populates state. `close()` resets to empty.
- Created `lib/features/projects/providers/providers.dart` — 4 providers: `projectFileRepositoryProvider`, `forgeDatabaseProvider`, `projectListProvider` (AsyncNotifierProvider), `activeProjectProvider` (NotifierProvider).
- Verified: `dart analyze lib/` = zero issues
- Verified: zero Firebase references in lib/

### Architectural decisions
- `ProjectListNotifier` uses `ref.watch()` to pull `projectFileRepositoryProvider` and `forgeDatabaseProvider` — idiomatic Riverpod, avoids constructor injection complexity with `.new` factory
- `ActiveProjectNotifier` is a vanilla `Notifier` (not `AsyncNotifier`) — state transitions are explicit via the `ActiveProjectState` model
- All 4 providers in a single `providers.dart` barrel — not scattered across files

### Next
- §3: Project folder browser screen (Flutter UI — list projects, create new project)

---

## Session: 2026-06-01 — Backlog rewrite from product documentation

### What was done
- Read all product docs in Obsidian: Agent Workflow Template v3.0, Positioning Brief v4.0, Locked Spec (ForkIt v1.1), Setup Worksheet (ForkIt v1), Bullet Handoff (ForkIt v1 Interview)
- Rewrote `tracking md files/backlog.md` from 11 items → 16 items, grounded in actual product stages
- Removed all stale Firestore/Firebase Function references from §2–§9
- Reordered critical path: project folder browser now precedes interview (was reversed)
- Added missing items: §2 Riverpod state layer, §4 LLM provider layer (BYOK + SwarmSpace), §9 Handoff Package + Bullet Handoff generation, §10 Settings screen + BYOK Keychain storage, §14 Monte Carlo spec generation (separated from single-call §6)
- Each backlog item now references the Workflow Template stage it maps to and the ForkIt worked example as ground truth for correct output
- Corrected agent review scoring: DeepSeek v4 Pro scored 4.6/5 (not 4.4) — `← Edit` in DeepSeek UI shows old content, not new; DeepSeek had correctly removed flutter_lints
- Registered DeepSeek v4 Pro in `agents md files/agent_scoping.md` as Rank 1 Executor

### Key decisions
- Monte Carlo spec generation (3 parallel LLM calls at t=0.2/0.6/1.0) is §14, not part of §6 — single-call spec gen ships first
- §4 LLM provider layer is the pivot point for the entire app: all LLM calls route through one interface regardless of provider
- Worked examples (ForkIt spec, worksheet, handoff) are named as reference outputs in each backlog item for future executor prompts

### Next
- §2: Riverpod project state layer — `ProjectListNotifier` + `ActiveProjectNotifier`

---

## Session: 2026-05-31 — §1 Review + Codegen complete

### What was done
- Reviewed DeepSeek v4 Pro's §1 output — scored 4.6/5 → Rank 1 Executor
- Correction: `← Edit` format in DeepSeek UI shows OLD content; DeepSeek correctly removed `flutter_lints` + `cupertino_icons` in the pubspec edit (no dead dep, score revised upward)
- Fixed AOT/build-hook incompatibility: `objective_c 9.4.1` (transitive via path_provider on macOS) has a native build hook that blocks `dart compile aot-snapshot` in Dart 3.10.7 + build_runner 2.15.0. Solution: `--force-jit` flag
- Ran `dart run build_runner build --force-jit` → `forge_database.g.dart` generated, 10 outputs written in 8s
- `dart analyze lib/` → zero issues
- Registered DeepSeek v4 Pro in The Forge's `agents md files/agent_scoping.md`
- Updated backlog.md §1 → ✅ Complete; fixed stale Critical Path ("Firestore schema" → "Local data layer")
- Updated planner.md → §1 marked COMPLETE with --force-jit note

### Key finding
`dart run build_runner build` must always use `--force-jit` in this repo on macOS due to the `objective_c` native build hook. Document this in any future executor prompts for The Forge.

### Next
- §2: Build Interview — Flutter UI + State (Riverpod providers for project list + active project; interview screen scaffold)

---

## Session: 2026-05-31 — §1 Flutter Bootstrap + Local Data Layer

### What was done
- Ran `flutter create . --project-name the_forge --org ai.orbitalai` — Flutter 3.38.7, Dart 3.10.7
- Replaced pubspec.yaml dependencies: flutter_riverpod 2.6.1, riverpod 2.6.1, path_provider 2.1.5, path 1.9.0, uuid 4.5.1, drift 2.22.0, drift_flutter 0.2.1, build_runner 2.4.13, drift_dev 2.22.0
- Created `lib/data/local_db/forge_database.dart` — drift schema with Projects table (8 columns) + 4 method contracts (getAllProjects, upsertProject, removeProject, getProjectById)
- Created `lib/data/filesystem/project_file_repository.dart` — 8 method contracts including write-once locked spec with atomic temp→rename, append-only audit log, project folder creation with full structure
- Verified: `dart analyze lib/data/filesystem/ lib/main.dart` = zero issues
- Verified: zero Firebase references in pubspec.yaml

### Build-time requirements
- `build_runner` must be run before the app compiles: `dart run build_runner build`
- Only `forge_database.dart` needs codegen — the g.dart missing error is expected until build_runner runs

### Next
- Run `dart run build_runner build` to generate `forge_database.g.dart`
- §2: Riverpod providers (project list provider, active project provider)

### Warnings / open items
- `forge_database.g.dart` not yet generated — drift codegen must run before full `dart analyze lib/` passes
- analysis_options.yaml replaced flutter_lints with explicit rule set (flutter_lints was removed as dev_dependency)

---

## Session: 2026-05-31 — Repo bootstrap

### What was done
- Created The Forge repo at `/Volumes/Marc Working Drive/Development/The Forge/` from Starter Repo
- Wrote `claude.md` (Forge-specific SOPs, invariants, conditional triggers)
- Wrote `agents md files/agents.md` (architecture, subsystems, Firestore schema, data flow)
- Wrote `tracking md files/ARCHITECTURE.md` (full system architecture)
- Wrote `tracking md files/backlog.md` (§1–§11, prioritized, critical path defined)
- Wrote `backend.md` (Firebase + SwarmSpace reference)
- Wrote `tracking md files/FEATURES.md`, `UI_UX.md`, `CHANGELOG.md`, `planner.md`
- Copied all Starter Repo agent SOPs and bugtracker files
- Copied The Forge protocol docs (workflow_template.md, positioning_brief.md) into `DOCS/forge/`
- Initialized git and pushed to `https://github.com/marcyap29/theforge.git`

### Next
- Start §1: Firestore schema + `forge_project_repository.dart`
- Start Flutter project scaffold (`flutter create`)

### Warnings / open items
- Flutter project not yet created — repo is docs + config only at this stage
- Firebase project `arc-epi` shared with LUMARA + SwarmSpace — no new Firebase project needed
- SwarmSpace spec gen function does not exist yet — will need to add route to swarmspaceRouter or create standalone `generateSpec` function
