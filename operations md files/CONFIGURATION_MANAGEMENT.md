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


---


## Change Log

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
