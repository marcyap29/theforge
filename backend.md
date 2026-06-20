# The Forge — Backend Reference

**Last Updated:** 2026-05-31
**Version:** 1.1.0

---

## Storage Model

The Forge is local-first. Project data lives on the user's filesystem as human-readable Markdown and JSON files. No cloud account is required for core functionality.

**Primary storage:** Local filesystem
**Local index:** SQLite via `drift` (project list cache — rebuilds from filesystem if deleted)
**Cloud sync:** Firebase Firestore (optional, workspace/team tier only)
**Server-side:** SwarmSpace credit API (only when using SwarmSpace routing)

---

## Local File Structure

Default root: `~/Documents/The Forge Projects/`
Can be changed in Settings. The app scans this folder for project directories on launch.

```
~/Documents/The Forge Projects/
└── {ProjectName}/
    ├── README.md                                    — phase state, always current
    ├── specs/
    │   ├── {ProjectName}_LockedSpec_v1.md           — immutable after creation
    │   └── {ProjectName}_LockedSpec_v2.md           — added on V2 interview
    ├── handoffs/
    │   ├── {ProjectName}_BulletHandoff_v1_Interview.md
    │   ├── {ProjectName}_HandoffPackage_v1.json     — structured executor handoff
    │   └── {ProjectName}_goal_v1.md                 — /goal text for executor harness
    ├── worksheets/
    │   └── {ProjectName}_SetupWorksheet_v1.md
    ├── forge/                                        — executor context files
    │   ├── {ProjectName}_LockedSpec_v1.md
    │   ├── {ProjectName}_DecisionContext_v1.md
    │   └── {ProjectName}_OpenFlags_v1.md
    ├── ingested/
    │   ├── reference_context.md                     — LLM-extracted reference doc facts
    │   └── {ProjectName}_V2Seeds.md                 — features deferred from V1
    └── audit/
        ├── {ProjectName}_AuditLog.md                — append-only
        └── {ProjectName}_InterviewState.json        — persisted after every LLM response
```

### File Invariants

- **Spec files are write-once.** Before writing `_LockedSpec_v1.md`, check if the file already exists. If it does, abort — do not overwrite. A locked spec is immutable.
- **Audit log is append-only.** New entries are appended to `_AuditLog.md`. Never truncate or replace the file. Use file append mode.
- **Writes are atomic where possible.** Write to a temp file (`.tmp` suffix), then rename to final path. Rename is atomic on macOS. This prevents partial writes leaving a corrupt spec.
- **README.md is always current.** Updated after every phase transition to reflect current state.

### README.md Format

```markdown
# {ProjectName} — Project State

**Interview mode:** Build | Audit
**Current phase:** v1_interview | v1_build | v2_interview | ...
**Last updated:** YYYY-MM-DD
**Spec version:** v1 | v2 | ...
**Setup worksheet:** Complete | Incomplete
**Executor status:** Not started | In progress | Complete

## What's Done
- [completed phases and decisions]

## What's Next
- [next action]

## Open Flags
- [unresolved items from current spec]
```

### Audit Log Format

```markdown
# {ProjectName} — Audit Log

---

## Phase: Interview -> v1 Spec
**Interview mode:** Build | Audit
**Date:** YYYY-MM-DD
**Run ID:** [uuid]
**Provider:** Claude (claude-opus-4-5) | GPT-4o | Ollama (llama3) | SwarmSpace | ...
**Credit cost:** N credits (SwarmSpace routing only; 0 for direct API or local)
**Duration:** N minutes

### Decisions Made
| Decision | Chosen | Confidence |
|---|---|---|
| [decision] | [choice] | High / Medium / Low |

### Conflicts Surfaced
- [description and resolution]

### Scope Changes
- [anything added or removed during this phase]

---
```

### Handoff Package JSON Schema

Unchanged from v1.0.0. Written to `handoff_package_v{N}.json`.

**Build mode:**
```json
{
  "interviewMode": "build",
  "specVersion": "string",
  "appName": "string",
  "platform": "string",
  "framework": "string",
  "lockedAt": "ISO date",
  "provider": "string",
  "goalStatement": "string",
  "components": ["string"],
  "infrastructure": { "service": "implementation" },
  "stateManagement": "string",
  "openFlags": "number",
  "outOfScopeItems": "number",
  "setupWorksheetComplete": "bool",
  "v2SeedItems": ["string"]
}
```

**Audit mode:**
```json
{
  "interviewMode": "audit",
  "specVersion": "string",
  "projectName": "string",
  "auditDate": "ISO date",
  "provider": "string",
  "goalStatement": "string",
  "buildState": {
    "shipped": ["string"],
    "inProgress": ["string"],
    "notStarted": ["string"]
  },
  "activeBlockers": "number",
  "decisionDebtItems": "number",
  "technicalDebtItems": "number",
  "documentationGaps": "number",
  "confidenceMap": {
    "projectGoal": "Established | Partial | Unknown",
    "buildState": "Established | Partial | Unknown",
    "featureOwnership": "Established | Partial | Unknown",
    "activeBlockers": "Established | Partial | Unknown",
    "blockerBlastRadius": "Established | Partial | Unknown",
    "decisionDebt": "Established | Partial | Unknown",
    "technicalDebt": "Established | Partial | Unknown",
    "aiTokenUsage": "Established | Partial | Unknown"
  },
  "docConflictsSurfaced": "number",
  "v2SeedItems": ["string"]
}
```

---

## SQLite Index (drift)

A lightweight local cache so the project browser doesn't need to scan the filesystem on every launch.

**Table: `projects`**

```sql
CREATE TABLE projects (
  id          TEXT PRIMARY KEY,    -- uuid
  name        TEXT NOT NULL,
  path        TEXT NOT NULL,       -- absolute path to project folder
  mode        TEXT NOT NULL,       -- "build" | "audit"
  phase       TEXT NOT NULL,       -- current phase string
  spec_version TEXT,               -- "v1", "v2", etc.
  last_opened INTEGER,             -- unix timestamp
  created_at  INTEGER NOT NULL
);
```

The index is a cache. If a project folder exists on disk but is missing from the index, it gets added on next scan. If an index entry points to a path that no longer exists, it gets removed.

---

## SpecGenerationProvider Interface

All LLM calls flow through this interface. The interview engine calls `generateVariants()` without knowing which provider is active.

```dart
abstract class SpecGenerationProvider {
  String get id;                   // "claude" | "openai" | "ollama" | "swarmspace" | "custom"
  String get displayName;          // shown in Settings UI
  bool get requiresApiKey;
  bool get isLocal;                // true = no network call (Ollama)

  Future<List<SpecVariant>> generateVariants({
    required InterviewResult interview,
    required List<double> temperatures,   // [0.2, 0.6, 1.0]
  });
}

class SpecVariant {
  final String label;        // "conservative" | "balanced" | "experimental"
  final double temperature;
  final String content;      // spec markdown
}
```

### Provider Implementations

#### ClaudeProvider

- **API:** Anthropic Messages API (`https://api.anthropic.com/v1/messages`)
- **Auth:** User's Anthropic API key (stored in macOS Keychain, never in files)
- **Model:** Configurable — default `claude-opus-4-6`, user can change in Settings
- **Billing:** Direct to Anthropic. The Forge does not touch billing.
- **Parallel calls:** `Future.wait([call(t:0.2), call(t:0.6), call(t:1.0)])`

#### OpenAIProvider

- **API:** OpenAI Chat Completions (`https://api.openai.com/v1/chat/completions`)
- **Auth:** User's OpenAI API key (macOS Keychain)
- **Model:** Configurable — default `gpt-4o`
- **Billing:** Direct to OpenAI.
- **Compatible with:** Any OpenAI-compatible API (DeepSeek, MiniMax, Kimi-K, etc.) via custom base URL

#### OllamaProvider

- **API:** Ollama local API (`http://localhost:11434/api/generate`)
- **Auth:** None — local only
- **Model:** Whatever model the user has pulled locally (`ollama pull llama3`, `ollama pull deepseek-coder`, etc.)
- **Billing:** Free. No network call.
- **Requirement:** Ollama must be running. The app checks `localhost:11434/api/tags` on startup and shows a warning if Ollama is unreachable when this provider is selected.

#### SwarmSpaceProvider

- **API:** SwarmSpace MCP endpoint (`https://swarmspace-mcp-server.orbitalai.workers.dev/mcp`) — live Cloudflare Workers, no additional infrastructure
- **Auth:** SwarmSpace API token (macOS Keychain)
- **Billing:** Credits deducted per call via SwarmSpace billing system
- **Advantage:** SwarmSpace handles model selection and routing — user doesn't need individual API keys
- **This is the only provider that involves server-side billing.**

#### CustomProvider

- **API:** User-supplied base URL (OpenAI-compatible)
- **Auth:** User-supplied API key (macOS Keychain)
- **Model:** User-supplied model name
- **Use cases:** DeepSeek API, MiniMax, Kimi-K2, self-hosted vLLM, company-internal LLM endpoint

### API Key Storage

All API keys are stored in the **macOS Keychain**, not in files or environment variables.

```dart
// Write
await FlutterSecureStorage().write(
  key: 'forge_provider_key_claude',
  value: apiKey,
);

// Read
final key = await FlutterSecureStorage().read(
  key: 'forge_provider_key_claude',
);
```

Never write API keys to disk, `.env` files, or log output.

---

## SwarmSpace API (SwarmSpace provider only)

Only relevant when the user selects the SwarmSpace routing provider.

**Base URL:** `https://swarmspace.app/api/` — confirm current endpoint in SwarmSpace repo

**Credit costs (estimated):**
| Action | Credits |
|---|---|
| Full Forge run (interview through locked spec) | 20–35 |
| Single variant generation | 4–6 |

**The Forge never deducts credits directly.** The SwarmSpaceProvider sends the generation request and SwarmSpace handles billing server-side. The provider returns the variants and the credit cost; The Forge records the credit cost in the audit log.

---

## Firebase (Workspace Tier — Future)

Firebase is not required for v1. It comes in at the workspace/team tier to enable project sharing across multiple users.

When implemented, the sync model is:
- Local filesystem remains the source of truth
- Firestore mirrors the local file structure (same document names, same content)
- Conflict resolution: last-write-wins on spec content (specs are immutable so conflicts shouldn't occur; if they do, the local file wins)
- Auth: Firebase Auth (email/password + Google OAuth)

The Firestore schema (when added) mirrors the local folder structure exactly. No new data model needed.

---

## Settings Stored Locally

User preferences are stored in macOS `UserDefaults` (via Flutter's `shared_preferences` package):

| Key | Type | Description |
|---|---|---|
| `forge_projects_root` | String | Root folder path for projects |
| `forge_active_provider` | String | Selected provider ID |
| `forge_provider_model_claude` | String | Claude model override |
| `forge_provider_model_openai` | String | OpenAI model override |
| `forge_provider_model_ollama` | String | Ollama model name |
| `forge_provider_custom_url` | String | Custom provider base URL |
| `forge_provider_custom_model` | String | Custom provider model name |

API keys are **not** stored here — they go in macOS Keychain only.

---

*Version 1.1.0 — Revised: local filesystem as primary storage, SpecGenerationProvider interface with 5 implementations, Firebase demoted to future workspace-tier sync, API keys in macOS Keychain.*
