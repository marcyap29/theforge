# The Forge — Active Planner

Active sprint tasks only. Wipe clean when a feature ships. Preserve partial work between sessions.

---

## §1 — Flutter Bootstrap + Local Data Layer — COMPLETE ✅

**Completed:** 2026-05-31

- [x] `flutter create` — Flutter 3.38.7, Dart 3.10.7
- [x] pubspec.yaml — correct deps, no Firebase
- [x] `lib/data/local_db/forge_database.dart` — drift schema + 4 methods
- [x] `lib/data/filesystem/project_file_repository.dart` — 8 methods
- [x] `dart run build_runner build --force-jit` — `forge_database.g.dart` generated
- [x] `dart analyze lib/` — zero issues

**Note:** build_runner requires `--force-jit` flag on Dart 3.10.7 / macOS due to `objective_c` native build hook blocking AOT compilation.

---

## §2 — Riverpod Project State Layer — COMPLETE ✅

**Completed:** 2026-06-01

- [x] `lib/features/projects/providers/project_list_notifier.dart` — scans root dir, syncs to ForgeDatabase
- [x] `lib/features/projects/providers/active_project_notifier.dart` — holds open project, reads README.md
- [x] `lib/features/projects/providers/providers.dart` — 4 Riverpod provider declarations
- [x] `dart analyze lib/` — zero issues
- [x] `grep -ri firebase lib/` — zero matches

### Notes
- `ProjectListNotifier`: `build()` → scan paths → upsert missing → return all. `refresh()` → invalidate + await future.
- `ActiveProjectNotifier`: vanilla `Notifier`, no async lifecycle — `open()` and `close()` are explicit public methods.
- Circular import avoided: notifiers import `providers.dart` for `ref.watch()`, providers.dart imports notifier types — Dart handles this correctly.

---

## §3 — Project Folder Browser Screen — COMPLETE ✅

**Completed:** 2026-06-01

- [x] `lib/main.dart` rewritten — wraps `TheForgeApp` in `ProviderScope`
- [x] `lib/core/app.dart` created — `TheForgeApp` MaterialApp with dark theme + home route
- [x] `lib/core/theme/app_theme.dart` created — macOS dark monospace theme, Forge amber accent
- [x] `lib/features/projects/screens/projects_list_screen.dart` created — `ConsumerWidget` watching `projectListProvider`; rows with name/phase/mode/last-opened; tap → open + navigate; FAB → new project stub; pull-to-refresh
- [x] `dart analyze lib/` — No issues found
- [x] `grep -ri firebase lib/` — zero matches

### Notes
- Detail and New-Project screens are inline stubs (`_ProjectDetailStub`, `_NewProjectStub`) — no separate files. Full implementations land in §7 (artifact viewers) and §5 (interview UI).
- `_ProjectDetailStub` reads `activeProjectProvider` and renders the loaded README.md. No resume logic yet — that's §7.
- Navigator captured to local before `await` to satisfy `use_build_context_synchronously` lint.

---

## §4 — LLM Provider Layer (BYOK + SwarmSpace) — UP NEXT

---

## §5 — Build Interview UI + State (Stage 1A) — COMPLETE ✅

**Completed:** 2026-06-01

- [x] `lib/features/interview/state/interview_state.dart` — 8-dimension enum, `DimensionState`, `InterviewTurn`, `ConflictItem`, `InterviewState` model
- [x] `lib/features/interview/state/interview_notifier.dart` — `FamilyAsyncNotifier` with turn-based stub LLM; `addUserMessage`, `resolveConflict`, `reset` methods
- [x] `lib/features/interview/providers/interview_providers.dart` — `InterviewArgs` (==/hashCode) + `interviewProvider` family
- [x] `lib/features/interview/ui/confidence_meter.dart` — 8-bar meter with resolved/partial/unknown fill levels
- [x] `lib/features/interview/ui/interview_screen.dart` — full screen layout: meter → conflict surface → chat history → composer → Generate Spec button
- [x] `lib/core/app.dart` — `/interview` named route added
- [x] `dart analyze lib/` — No issues found
- [x] `grep -ri firebase lib/` — zero matches

### Notes
- Stub is deterministic and turn-counter driven: 9 user messages cover all 8 dimensions; a `corePurpose ↔ identityModel` conflict is surfaced on turn 3.
- Stub call site is one function call (`stubInterviewStep(state, text)`) — comment marks the swap point for §4.
- `isLoading` gates text input, send button, AND conflict Accept button — prevents races during the 400ms stub latency.
- `InterviewArgs` (path + name) is the family arg; each project gets its own interview state. Switching projects → fresh state, no manual reset.
- Entry-point wiring (button in project list → push `/interview`) is out of scope per the plan. Route is registered and ready.
