# The Forge — Session Log

Newest session first. Each block is prepended.

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
