# Path to a sandboxed / Mac App Store–eligible build

**Status:** effectively **not viable** (was "parked"). The Forge ships
**unsandboxed** for direct distribution (Developer ID + notarization via
`tool/release_macos.sh`). This document records why the App Store is off the
table and what it would cost.

## Why it's blocked — and why the gap WIDENED (2026-09)
The Mac App Store **requires** the App Sandbox, which forbids executing external
binaries not shipped inside the app bundle. When this doc was written the only
offender was the system `git` binary (4 read-only call sites, replaceable with an
in-process git library — see WS1 below). **That is no longer the situation.** The
app's core now spawns the user's dev toolchain, none of which can run in-process:

| Feature | Spawns | In-process substitute? |
|---|---|---|
| Build with AI (executor) | arbitrary shell, `flutter analyze`, `dart fix` (`command_runner.dart`) | ❌ none |
| Make runnable / scaffold | `flutter create` | ❌ none |
| Run & Preview | `flutter run`/`devices`/`emulators`, `xcrun simctl`, `adb`, `open` (`run_controller.dart`) | ❌ none |
| Deploy kit | `flutter build`, `pod install`, `xcodebuild` | ❌ none |
| Scan / Check-in / repos | `git …` | ⚠️ possible (in-process git) |

So App Store eligibility would require **removing Build with AI and Run &
Preview** (the product's hands-on-keyboard half) — not an acceptable trade.
Everything else (BYOK keys, cloud LLM over `network.client`, paid apps) is
App-Store-fine, but that's moot while the toolchain spawning stays.

**Decision: distribute direct + notarized; do not pursue the Mac App Store.** The
git-only workstreams below are retained for reference only — they no longer get
you to eligibility on their own.

## The git subprocess surface (small + read-only)
Watch Mode already uses the **GitHub REST/GraphQL API over HTTP** (sandbox-legal).
The only local-`git` usage is 4 call sites in 2 files:

| File | Call | Purpose |
|---|---|---|
| `lib/data/filesystem/project_file_repository.dart` | `git log --name-only --since` | changed files since a date |
| `lib/data/filesystem/project_file_repository.dart` | `git log --oneline --since` | commit messages since a date |
| `lib/data/filesystem/project_file_repository.dart` | `git rev-parse HEAD` | current commit SHA |
| `lib/features/tracker/scan/feature_scan.dart` | `git ls-files` | list tracked files |

Two other subprocesses exist (`Process.run('open', ['-R', …])` reveal-in-Finder in
`project_detail_screen.dart`) — also disallowed in the sandbox; see WS3.

## Workstreams

### WS1 — Replace the git subprocess with an in-process git engine
- **`feature_scan.dart` (trivial):** drop `git ls-files`; the scanner already has a
  filesystem-walk fallback (`_listFiles`) — always use it. No new dependency.
- **`project_file_repository.dart` (the real work):** put the 3 read-only ops behind
  a small `GitReader` interface with two implementations, selected by build flavor:
  - `SubprocessGitReader` — today's behavior (unsandboxed builds).
  - `DartGitReader` — pure-Dart (`package:dart_git`): read HEAD from refs; for
    "commits / changed files since date" walk the commit graph filtering by commit
    date and diff each commit against its parent tree.
  - Alternative: `libgit2dart` (FFI + bundled `libgit2`) if `dart_git` is too slow
    on large repos — but that requires bundling + code-signing a native dylib in the
    app bundle (the nested-signing dance Sabihin does for llama-server).
- **Spike first:** confirm `dart_git` gives "commits + changed files since date" at
  acceptable speed on a large repo. This is the main risk.

### WS2 — Sandbox-legal file access (security-scoped bookmarks)
Even in-process git must *read* a repo's `.git`, which lives outside the container.
- Add `package:macos_secure_bookmarks`.
- On folder pick (the file picker triggers macOS powerbox and grants access), create
  a security-scoped bookmark, persist it, and on later launches resolve it +
  `startAccessingSecurityScopedResource()` before reading.
- Entitlements (sandbox back ON): add
  `com.apple.security.files.user-selected.read-write` and
  `com.apple.security.files.bookmarks.app-scope`.
- Default project root (container `Documents`) needs no bookmark.

### WS3 — Replace reveal-in-Finder subprocesses
Swap `Process.run('open', ['-R', …])` for a sandbox-safe platform channel calling
`NSWorkspace.activateFileViewerSelectingURLs`. Two call sites.

### WS4 — App Store packaging (process, not code)
App Store distribution certificate + App Store Connect record, hardened runtime,
sandbox on, upload via Transporter/`notarytool`.

## Effort / sequencing
1. WS1 easy win (scanner) + `GitReader` seam — ~1 hour.
2. `dart_git` spike + `DartGitReader` — ~1 day (gated on the spike).
3. WS2 bookmarks — ~half a day.
4. WS3 + WS4 — small.

None of this is required for the current unsandboxed direct-distribution path.
