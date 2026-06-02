# Configuration Management — The Forge

**Last Updated:** 2026-06-01
**Status:** ✅ Synced

---

## Documentation Inventory

| Document | Location | Last Reviewed | Status |
|----------|----------|---------------|--------|
| claude.md | root | 2026-05-31 | ✅ Synced |
| agents.md | agents md files/ | 2026-05-31 | ✅ Synced |
| ARCHITECTURE.md | tracking md files/ | 2026-05-31 | ✅ Synced |
| FEATURES.md | tracking md files/ | 2026-05-31 | ✅ Synced |
| UI_UX.md | tracking md files/ | 2026-05-31 | ✅ Synced |
| CHANGELOG.md | tracking md files/ | 2026-05-31 | ✅ Synced |
| backend.md | root | 2026-05-31 | ✅ Synced |
| context.md | tracking md files/ | 2026-05-31 | ✅ Synced |
| planner.md | tracking md files/ | 2026-05-31 | ✅ Synced |
| backlog.md | tracking md files/ | 2026-06-01 | ✅ Synced |
| BUG_PREVENTION.md | bugtracker/ | 2026-05-31 | ✅ Synced |
| workflow_template.md | DOCS/forge/ | 2026-05-31 | ✅ Synced |
| positioning_brief.md | DOCS/forge/ | 2026-05-31 | ✅ Synced |
| pubspec.yaml | root | 2026-05-31 | ✅ Synced |
| analysis_options.yaml | root | 2026-05-31 | ✅ Synced |
| forge_database.dart | lib/data/local_db/ | 2026-05-31 | ✅ Synced |
| project_file_repository.dart | lib/data/filesystem/ | 2026-05-31 | ✅ Synced |
| project_list_notifier.dart | lib/features/projects/providers/ | 2026-06-01 | ✅ Synced |
| active_project_notifier.dart | lib/features/projects/providers/ | 2026-06-01 | ✅ Synced |
| providers.dart | lib/features/projects/providers/ | 2026-06-01 | ✅ Synced |
| main.dart | lib/ | 2026-06-01 | ✅ Synced |
| app.dart | lib/core/ | 2026-06-01 | ✅ Synced |
| app_theme.dart | lib/core/theme/ | 2026-06-01 | ✅ Synced |
| projects_list_screen.dart | lib/features/projects/screens/ | 2026-06-01 | ✅ Synced |
| interview_state.dart | lib/features/interview/state/ | 2026-06-01 | ✅ Synced |
| interview_notifier.dart | lib/features/interview/state/ | 2026-06-01 | ✅ Synced |
| interview_providers.dart | lib/features/interview/providers/ | 2026-06-01 | ✅ Synced |
| confidence_meter.dart | lib/features/interview/ui/ | 2026-06-01 | ✅ Synced |
| interview_screen.dart | lib/features/interview/ui/ | 2026-06-01 | ✅ Synced |


---


## Change Log

### 2026-06-01 — §5 Build Interview UI + State

**Action:** Core product loop — 8-dimension interview state machine + visual confidence meter + conflict surface + Generate Spec gating. 5 new files, 1 update, zero analyzer issues.

**Files created:**
- `lib/features/interview/state/interview_state.dart` — `ConfidenceDimension` enum (8 values with `.label` and `.question` extensions), `DimensionState` enum, `InterviewTurn`, `ConflictItem`, `InterviewState` model
- `lib/features/interview/state/interview_notifier.dart` — `FamilyAsyncNotifier<InterviewState, InterviewArgs>` with `addUserMessage`, `resolveConflict`, `reset` methods; top-level `stubInterviewStep()` function returns structured `({String, Map, List})` record. Single call site flagged with `// §5 LLM STUB:` comment for §4 swap.
- `lib/features/interview/providers/interview_providers.dart` — `InterviewArgs` (with `==`/`hashCode`) + `interviewProvider` (`AsyncNotifierProvider.family`)
- `lib/features/interview/ui/confidence_meter.dart` — 8-bar `LinearProgressIndicator` meter; resolved/partial/unknown fill levels
- `lib/features/interview/ui/interview_screen.dart` — `ConsumerStatefulWidget` with AppBar (restart icon), `ConfidenceMeter`, `_ConflictSurface` (gated on `openConflicts.isNotEmpty`), chat history (`_TurnBubble` per turn, user right / interviewer left), `_Composer` (text input + send button), `Generate Spec` button (gated on `specGenEnabled`, shows §6 SnackBar)

**Files modified:**
- `lib/core/app.dart` — added `'/interview'` named route; reads `ModalRoute.settings.arguments` as `InterviewArgs`; falls back to `_MissingRouteArgs` helper screen if args absent
- `tracking md files/context.md` — session block prepended
- `tracking md files/planner.md` — §5 marked COMPLETE ✅
- `tracking md files/backlog.md` — §5 status set to ✅ Complete; §5 added to Completed section; Critical Path updated with ✅ on §5

**Key design choices:**
- Family provider with `InterviewArgs` (path + name) — one interview state per project; switching projects = fresh state for free
- Stub is turn-counter driven (9 user messages = 8 dimensions + 1 surfaced conflict) — deterministic, fast to test, no message parsing required
- Conflict text follows Workflow Template pattern verbatim ("Your answers on X and Y pull in opposite directions...")
- `isLoading` gates text input + send button + conflict Accept button — prevents races during the 400ms stub latency
- `specGenEnabled` is a stored field on state, recomputed on every transition (all 8 resolved + 0 open conflicts)
- Entry-point wiring (button in project list → push `/interview`) deliberately out of scope per the §5 plan; route is registered and ready for any future caller

### 2026-06-01 — §3 Project Folder Browser

**Action:** App bootstrap + first screen implemented — 1 file rewritten, 3 new files, zero analyzer issues.

**Files created:**
- `lib/core/app.dart` — `TheForgeApp` MaterialApp wrapping the dark theme + `ProjectsListScreen` home route
- `lib/core/theme/app_theme.dart` — macOS dark theme, Menlo monospace, Forge amber (`#E8A04C`) primary, flat surfaces, minimal chrome
- `lib/features/projects/screens/projects_list_screen.dart` — `ConsumerWidget` for project list; `AsyncValue` states (loading/error/empty/data); `_ProjectRow` + `_ModeBadge`; tap row → `activeProjectProvider.open()` + push detail stub; FAB → push new-project stub; pull-to-refresh + AppBar refresh icon

**Files modified:**
- `lib/main.dart` — rewritten to `runApp(ProviderScope(child: TheForgeApp()))` (replaces stock counter)
- `tracking md files/context.md` — session block prepended
- `tracking md files/planner.md` — §3 marked COMPLETE ✅; §4 set as UP NEXT
- `tracking md files/backlog.md` — §3 status set to ✅ Complete; §3 added to Completed section; Critical Path updated with ✅ on §1, §2, §3

**Key design choices:**
- Detail and new-project screens are inline private widgets (`_ProjectDetailStub`, `_NewProjectStub`) in the list screen file — keeps §3 file count to 4 per task scope
- Detail stub reads `activeProjectProvider` and renders README.md as monospace text
- Navigator captured to local before `await` to satisfy `use_build_context_synchronously` lint
- `ColorScheme.dark` with explicit `primary`/`surface`/`onSurface`/`error`; FAB uses primary/background inverse for contrast

### 2026-06-01 — /goal integration: workflow template + backlog updates

**Action:** Applied /goal primitive integration to The Forge workflow docs.

**Files modified:**
- `DOCS/forge/workflow_template.md` — Completion Criteria section added
  to Stage 2 spec format; Stage 4b /goal text artifact added; Stage 5
  checklist updated; Bullet Handoff format updated
- Obsidian `The Forge — Agent Workflow Template v3.0.md` — same changes
- `tracking md files/backlog.md` — §6 spec structure updated, §9 outputs
  updated to include /goal text artifact
- `tracking md files/context.md` — session block prepended

**Reason:** The /goal primitive in Claude Code and OpenAI Codex maps
directly to the Locked Spec. The spec now explicitly produces a /goal
text artifact and includes verifiable Completion Criteria so judge agents
can confirm completion autonomously.

### 2026-06-01 — §2 Riverpod Project State Layer

**Action:** Riverpod state layer implemented — 3 new files, 4 providers, zero issues.

**Files created:**
- `lib/features/projects/providers/project_list_notifier.dart` — `ProjectListNotifier` (AsyncNotifier): scans filesystem, syncs to SQLite, `refresh()` method
- `lib/features/projects/providers/active_project_notifier.dart` — `ActiveProjectNotifier` (Notifier): manages open project state, reads README.md on `open()`
- `lib/features/projects/providers/providers.dart` — 4 provider declarations: `projectFileRepositoryProvider`, `forgeDatabaseProvider`, `projectListProvider`, `activeProjectProvider`

**Files modified:**
- `tracking md files/context.md` — session block prepended
- `tracking md files/planner.md` — §2 marked COMPLETE ✅
- `tracking md files/backlog.md` — §2 marked ✅ Complete

### 2026-06-01 — Backlog rewrite from product documentation

**Action:** Backlog fully rewritten from 11 items to 16 items based on Obsidian product docs.

**Files modified:**
- `tracking md files/backlog.md` — complete rewrite: stale Firestore refs removed, critical path corrected, §2/§4/§9/§10/§14 added as new items
- `tracking md files/context.md` — session block prepended
- `tracking md files/planner.md` — §2 added as next sprint task
- `agents md files/agent_scoping.md` — DeepSeek v4 Pro registered as Rank 1 Executor (4.6/5)

**Reason:** Old backlog described Firestore-primary architecture (superseded by local-first pivot on 2026-05-31). New backlog maps to actual Workflow Template stages and references ForkIt worked examples as ground truth for each output.

### 2026-05-31 — §1 Flutter Bootstrap + Local Data Layer

**Action:** Flutter project created, dependencies added, data layer implemented.

**Files created:**
- All Flutter platform scaffolds via `flutter create`
- `pubspec.yaml` — replaced deps with Riverpod, drift, path_provider, uuid
- `analysis_options.yaml` — replaced flutter_lints with explicit rule set
- `lib/data/local_db/forge_database.dart` — drift schema, 4 method contracts
- `lib/data/filesystem/project_file_repository.dart` — 8 method contracts

**Files modified:**
- `tracking md files/context.md` — session block prepended
- `tracking md files/planner.md` — §1 task added, sub-tasks checked off
- `tracking md files/backlog.md` — §1 status updated to In Progress

**Deleted:**
- `README.md` (auto-generated Flutter template — project has its own SOP docs)

### 2026-05-31 — Initial repo bootstrap

**Action:** Repo created from Starter Repo template.

**Files created:**
- All core docs (claude.md, agents.md, ARCHITECTURE.md, backlog.md, backend.md, etc.)
- Bugtracker scaffold
- Agent SOPs
- The Forge protocol docs (workflow_template.md, positioning_brief.md)
- .gitignore (Flutter + Firebase + macOS)
- Git initialized and pushed to github.com/marcyap29/theforge
