# The Forge — Architecture

**Version:** 1.1.0
**Last Updated:** 2026-05-31

---

## What It Is

The Forge is a standalone Flutter desktop app (macOS primary). It is the project management layer for AI-assisted development — sitting above executor agents (Claude Code, Codex, Cursor) and producing the locked specs those agents build against.

It is its own product with its own codebase. It uses SwarmSpace's credit billing for SwarmSpace-routed spec generation, but has no hard dependency on Firebase or any cloud service for core functionality.

---

## Design Principles

**Local-first.** Project data lives on the user's filesystem as human-readable Markdown files. The user can open their project folder in Finder, read specs in any text editor, commit the folder to git, and hand it directly to an executor agent by path. No cloud account required to use the core product.

**Provider-agnostic spec generation.** The user chooses which LLM generates spec variants — Claude, GPT-4, a local Ollama model, DeepSeek, Kimi, MiniMax, or anything with an OpenAI-compatible API. The Monte Carlo strategy (3 parallel calls at different temperatures) is model-independent.

**Cloud is optional, not foundational.** Firebase comes in at the workspace tier for team sharing. For single users, the filesystem is the database.

---

## Stack

| Layer | Technology |
|---|---|
| Desktop app | Flutter (macOS primary, iOS/Android future) |
| State management | Riverpod |
| Primary storage | Local filesystem (Markdown + JSON files) |
| Local index | SQLite via `drift` package (project list, resume state) |
| Spec generation | Pluggable `SpecGenerationProvider` (user's choice) |
| Cloud sync (workspace tier) | Firebase Firestore (optional, team sharing only) |
| Billing (SwarmSpace routing only) | SwarmSpace credit API |
| Linter | `dart analyze lib/` |

---

## Repository Layout

```
The Forge/
├── lib/
│   ├── core/                        — App bootstrap, routing, theme, DI
│   ├── features/
│   │   ├── interview/               — Interview session (the core product)
│   │   │   ├── state/               — Riverpod providers + session state
│   │   │   ├── ui/                  — Interview screen, confidence meter, conflict UI
│   │   │   └── ingestion/           — Doc ingestion (future §7)
│   │   ├── projects/                — Project folder browser + resume
│   │   ├── spec_viewer/             — Read-only locked spec display
│   │   ├── worksheets/              — Setup worksheet display
│   │   └── settings/                — LLM provider configuration
│   ├── data/
│   │   ├── filesystem/              — Local file read/write layer
│   │   │   └── project_file_repository.dart
│   │   ├── local_db/                — SQLite index (drift)
│   │   │   └── forge_database.dart
│   │   ├── spec_generation/         — Provider abstraction + implementations
│   │   │   ├── spec_generation_provider.dart      — abstract interface
│   │   │   ├── providers/
│   │   │   │   ├── claude_provider.dart           — Anthropic API
│   │   │   │   ├── openai_provider.dart           — OpenAI API
│   │   │   │   ├── ollama_provider.dart           — local model
│   │   │   │   ├── swarmspace_provider.dart       — SwarmSpace routing + billing
│   │   │   │   └── custom_provider.dart           — user-supplied endpoint
│   │   └── swarmspace/              — SwarmSpace billing client (SwarmSpace routing only)
│   │       └── swarmspace_client.dart
│   └── shared/                      — Shared widgets, models, utils, extensions
├── DOCS/
│   ├── forge/
│   │   ├── workflow_template.md
│   │   └── positioning_brief.md
│   └── Coding Lessons/
├── tracking md files/
├── agents md files/
├── operations md files/
├── bugtracker/
├── backend.md
└── claude.md
```

---

## Local File Structure

Every Forge project is a folder on the user's machine. The default root is `~/Documents/The Forge Projects/`. Each project folder mirrors the workflow template exactly:

```
~/Documents/The Forge Projects/
└── {ProjectName}/
    ├── README.md                              — current phase, what's done, what's next
    ├── specs/
    │   ├── {ProjectName}_LockedSpec_v1.md    — immutable after creation
    │   └── {ProjectName}_LockedSpec_v2.md    — added on phase 2
    ├── handoffs/
    │   ├── {ProjectName}_BulletHandoff_v1_Interview.md
    │   ├── {ProjectName}_BulletHandoff_v1_SpecToExecutor.md
    │   └── {ProjectName}_BulletHandoff_v1_Agent1toAgent2.md
    ├── worksheets/
    │   └── {ProjectName}_SetupWorksheet_v1.md
    ├── handoff_package_v1.json               — machine-readable handoff for executor agents
    └── audit/
        └── {ProjectName}_AuditLog.md         — append-only, never overwritten
```

**The filesystem IS the database.** The Flutter app reads and writes these files directly. No ORM, no query language — just file I/O.

A lightweight SQLite index (via `drift`) tracks project locations and last-opened state so the project browser can list projects without scanning every folder. The index is a cache — the files are the source of truth. If the index is deleted, it rebuilds from the filesystem.

---

## SpecGenerationProvider Interface

The spec generation abstraction is the most important design decision in the codebase. All LLM interaction flows through this interface.

```dart
abstract class SpecGenerationProvider {
  String get displayName;          // "Claude (Anthropic)", "GPT-4o", "Ollama (llama3)", etc.
  bool get requiresApiKey;
  bool get isLocal;                // true for Ollama — no network call

  Future<List<SpecVariant>> generateVariants({
    required InterviewResult interview,
    required GenerationConfig config,   // contains temperatures [0.2, 0.6, 1.0]
  });
}
```

**Implementations:**

| Provider | Class | Key | Network | Billing |
|---|---|---|---|---|
| Claude (Anthropic) | `ClaudeProvider` | User's Anthropic API key | Anthropic API | Direct to Anthropic |
| GPT-4 / GPT-4o | `OpenAIProvider` | User's OpenAI API key | OpenAI API | Direct to OpenAI |
| Local model | `OllamaProvider` | None | Localhost only | Free |
| SwarmSpace routing | `SwarmSpaceProvider` | SwarmSpace token | SwarmSpace API | Credits deducted |
| Custom endpoint | `CustomProvider` | User-supplied key | User-supplied URL | User's problem |

**The Monte Carlo strategy is provider-independent.** All implementations fire 3 parallel calls at t=0.2, t=0.6, t=1.0 and return all three variants before any are revealed to the user. The strategy lives in the interview engine, not the provider.

**Provider selection lives in Settings.** The user configures their preferred provider once. The interview engine calls `providerRef.generateVariants(...)` without knowing which provider is active.

---

## Core Subsystems

### Interview Engine (`lib/features/interview/`)

The conversational UI that drives The Forge's value. Runs in two modes:

- **Build mode** — 8 dimensions: core purpose, primary user, identity model, input model, output model, platform, scope boundary, external services
- **Audit mode** — 8 dimensions: project goal, build state, feature ownership, active blockers, blocker blast radius, decision debt, technical debt, AI/token usage

Rules:
- Max 3 questions per turn
- Only questions that materially change the architecture
- Conflict detection stops the interview and requires explicit resolution before proceeding
- Conservative defaults recommended when user is uncertain

All session state lives in Riverpod during the interview. Nothing written to disk mid-interview. On phase completion, the full interview state is serialized and the file writes happen.

### Project File Repository (`lib/data/filesystem/project_file_repository.dart`)

Handles all filesystem reads and writes. Enforces:
- Spec files are written once and never overwritten (checked before write)
- Audit log is append-only (new content is appended to the file, never replacing existing content)
- All phase-completion writes happen atomically where possible (write to temp file, rename)
- README.md is updated after every phase transition

### SQLite Index (`lib/data/local_db/forge_database.dart`)

Lightweight cache of project metadata for the project browser. Stores:
- Project name, path, current phase, last opened timestamp
- Rebuilds from filesystem scan if stale or missing

### Artifact Viewers (`lib/features/spec_viewer/`, `lib/features/worksheets/`)

Read-only display of local files. Locked specs render with a "LOCKED" badge and the file creation timestamp. No edit affordance anywhere in the artifact viewer.

---

## Data Flow

```
User starts interview
  → Interview Engine holds all state in Riverpod
  → User answers questions across N turns
  → All 8 confidence dimensions reach 100%
  → User confirms scope + out-of-scope list
  → Interview engine calls SpecGenerationProvider.generateVariants()
      → 3 parallel LLM calls (t=0.2, 0.6, 1.0) via configured provider
      → All three variants returned simultaneously
  → User selects variant (or nominates hybrid)
  → Project File Repository writes to disk:
      → specs/{ProjectName}_LockedSpec_v1.md      (immutable — checked before write)
      → handoffs/{ProjectName}_BulletHandoff_v1_Interview.md
      → worksheets/{ProjectName}_SetupWorksheet_v1.md
      → handoff_package_v1.json
      → audit/{ProjectName}_AuditLog.md           (appended, never replaced)
      → README.md                                  (updated with new phase state)
  → SQLite index updated
  → If SwarmSpace provider: credits deducted via SwarmSpace API
```

---

## Cloud Sync — Workspace Tier (Future)

For teams (the Qualcomm use case), a workspace tier adds optional cloud sync on top of the local file structure. The local files remain the source of truth. Cloud sync is a transport layer.

Options in order of complexity:
1. **Shared network folder / iCloud Drive** — zero backend work, the project folder lives somewhere shared
2. **Git repo per project** — the project folder is a git repo; team shares via GitHub/GitLab
3. **Firebase Firestore sync** — proper multi-user, real-time, access controls

The file format is identical across all three. Adding cloud sync does not change the local structure or the Flutter file layer.

---

## Cross-Repo Dependencies

| Dependency | What it provides | Required? |
|---|---|---|
| SwarmSpace credit API | Billing when using SwarmSpace routing | Only for SwarmSpace provider |
| Anthropic API | Claude spec generation | Only if user selects Claude provider |
| OpenAI API | GPT-4 spec generation | Only if user selects OpenAI provider |
| Ollama (local) | Local model inference | Only if user selects Ollama provider |
| Firebase `arc-epi` | Cloud sync for workspace tier | Future / optional |

The Forge has zero hard dependencies on any cloud service for core functionality.

---

*Version 1.1.0 — Revised: local-first filesystem storage, provider-agnostic spec generation, Firebase demoted to optional workspace-tier sync.*
