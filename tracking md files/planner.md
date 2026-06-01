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

## §3 — Project Folder Browser Screen — UP NEXT
