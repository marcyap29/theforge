# Path to a sandboxed / Mac App Store–eligible build

**Status:** parked (not scheduled). The Forge currently ships **unsandboxed** for
direct distribution. This document is the plan for *if/when* App Store eligibility
is wanted.

## Why it's blocked today
The Mac App Store **requires** the App Sandbox. The Forge is currently ineligible
because it **spawns the system `git` binary** — the App Sandbox forbids executing
arbitrary external binaries. That is the only hard blocker; everything else
(BYOK API keys, cloud LLM calls over `network.client`, paid apps) is App-Store-fine.

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
