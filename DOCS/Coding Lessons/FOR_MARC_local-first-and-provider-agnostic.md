# FOR MARC: Why We Switched to Local Files and Made LLMs Swappable

*Session 1 · 2026-05-31 · Architecture Revision*

---

## Step 1 — Approach and reasoning

Two decisions got made in quick succession today that changed the whole shape of the backend. Worth understanding both because they're not just tactical — they change what The Forge *is* as a product.

**Decision 1: Local filesystem over Firebase.**

The original design had Firestore as the database. Project specs, handoffs, audit logs — all of it living in Firebase documents. Then you asked the right question: does this *need* to be in the cloud?

The answer was no, and the reasons stacked up fast. The core users are developers and technical founders. Their tools (Claude Code, Cursor, Codex) already work with files. When you finish a Forge interview and get a locked spec, the most natural next step is: point your executor agent at the spec file. You can't do that if the spec lives in Firestore — you'd need a Firebase export step, or a special download, or an API call. The friction is pointless.

Local files also mean zero cloud dependency for the core product. No Firebase account needed to install and run The Forge. No internet required. The project folder is just a folder — you can git it, open it in Finder, read the spec in any text editor, commit it to your repo. That's a feature, not a limitation.

**Decision 2: Provider-agnostic spec generation.**

The original design had a single Firebase Function calling Anthropic. That's a fine starting point but it breaks for a huge slice of the target market: developers who already pay for OpenAI, developers who want to run locally with Ollama, developers at companies where Anthropic isn't an approved vendor.

The fix is an abstract interface — `SpecGenerationProvider` — that the interview engine calls without caring what's behind it. Claude, GPT-4, a local Llama3, DeepSeek via their API, a company-internal endpoint — all valid, all interchangeable, same contract.

---

## Step 2 — Roads not taken

**Keeping Firebase as storage but adding a local export.**

You could keep Firestore as the source of truth and add a "download project files" button. This is how a lot of SaaS products work — the canonical data lives in the cloud, you can export if you want.

We rejected it because it's backwards for the target user. A developer running Claude Code doesn't want to export from a web app before every sprint. They want to point their agent at a folder. Making the local copy a derived artifact (export from cloud) instead of the source of truth (cloud is the backup) would make the product feel like a consumer tool, not a developer tool. The whole positioning is that The Forge sits *above* executor agents in the stack. If it requires a cloud round-trip to hand off work, it's not above anything.

**One provider, user supplies key.**

The simplest alternative: support only one LLM (Claude), let users bring their own Anthropic key. This is what a lot of "claude-powered" developer tools do.

The problem is the market. OpenAI users are not going to sign up for an Anthropic account just to use The Forge's interview feature. Local model users (privacy-conscious, enterprise with data residency requirements, developers who just like Ollama) get excluded entirely. The `SpecGenerationProvider` interface costs roughly the same amount of code as hardwiring one provider — the abstraction layer is thin. The payoff is that every LLM ecosystem is a potential market.

**Firebase Functions even for non-SwarmSpace providers.**

When SwarmSpace routing is selected, billing happens server-side and that makes sense — you need to charge credits somewhere trustworthy. But running all spec generation through a Firebase Function even when the user is using their own Claude or OpenAI key adds latency, costs Firebase compute, and requires a backend that does nothing except pass messages. We dropped it. Direct API calls from Flutter for all non-SwarmSpace providers.

---

## Step 3 — How the pieces connect

The filesystem is the spine. Everything hangs off a project folder:

```
~/Documents/The Forge Projects/
└── MyApp/
    ├── README.md              ← current phase, what's next
    ├── specs/
    │   └── MyApp_LockedSpec_v1.md   ← immutable after creation
    ├── handoffs/
    │   └── MyApp_BulletHandoff_v1_Interview.md
    ├── worksheets/
    │   └── MyApp_SetupWorksheet_v1.md
    ├── handoff_package_v1.json      ← machine-readable for executor agents
    └── audit/
        └── MyApp_AuditLog.md        ← append-only, never overwritten
```

The Flutter app reads and writes these files directly. No ORM, no query layer. When the interview finishes, `ProjectFileRepository` writes the spec, handoff, worksheet, audit entry, and README in a single sequence. Atomic where possible (temp file + rename).

The SQLite index (drift) is just a project browser cache. It exists so the app can show a list of projects on startup without scanning every folder. If you delete the index, it rebuilds from the filesystem. The files are the truth — the index is a convenience.

`SpecGenerationProvider` sits between the interview engine and whatever LLM you're using:

```
Interview Engine
  → calls providerRef.generateVariants(interview, temperatures)
  → doesn't know or care which provider is active
  ← gets back List<SpecVariant> with conservative / balanced / experimental

The active provider:
  → fires 3 parallel LLM calls at t=0.2, t=0.6, t=1.0
  → returns all three simultaneously
  → the interview engine reveals them to the user
```

The Monte Carlo strategy (3 temperatures, simultaneous reveal) lives in the interview engine. Every provider does it the same way. You can't accidentally ship a provider that only returns one variant.

---

## Step 4 — Tools, methods, and frameworks

**`flutter_secure_storage` for API keys.**

API keys go in the macOS Keychain, full stop. Not in `shared_preferences`, not in `.env` files, not in git. The code looks like:

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

The reason this matters: `shared_preferences` on macOS writes to a plist file in the app's container. It's readable by anyone with filesystem access. The Keychain requires authentication. For API keys that bill to the user's account, that's the right security model.

**`shared_preferences` for non-sensitive settings.**

Root folder path, active provider ID, model overrides — these go in `UserDefaults` via `shared_preferences`. They're not secrets. This is appropriate.

**`drift` for the SQLite index.**

Drift is Flutter's recommended SQLite layer. The schema is a single `projects` table with name, path, phase, mode, last_opened, created_at. The table is rebuilt from filesystem scan when stale. Simple and boring — that's right for a cache.

**Atomic writes via temp file + rename.**

macOS rename is atomic. Writing to `specs/MyApp_LockedSpec_v1.md.tmp` and then renaming to `specs/MyApp_LockedSpec_v1.md` means you never have a partial spec on disk. If the process dies mid-write, you have either the old file (nothing) or the complete new file. No corrupt state.

---

## Step 5 — Tradeoffs

**Local files vs. cloud storage**

Local:
- Pro: zero cloud dependency, works offline, executor agents can read files directly, developer-native
- Con: no automatic backup, no multi-device without extra setup, if the drive dies the projects are gone

Cloud (Firebase):
- Pro: automatic backup, multi-device, sync for teams
- Con: requires cloud account, requires internet, adds a step to hand off to executor agents

We chose local for v1. Cloud sync is on the roadmap as an optional workspace-tier feature — iCloud Drive, git repo, or Firestore are all compatible with the same file format. You can add any of them without changing the local structure.

**Abstract interface vs. hardwired provider**

Abstract interface:
- Pro: any LLM ecosystem works, user brings their own key/account, market expands
- Con: each provider needs its own implementation + testing, more code to maintain

Hardwired Claude:
- Pro: simpler, one thing to test
- Con: excludes OpenAI users, Ollama users, enterprise with specific vendor requirements

The interface is the right call. The implementation overhead per provider is maybe 100 lines each. The market expansion is orders of magnitude larger than 100 lines.

**SwarmSpace routing vs. direct API for billing**

SwarmSpace routing:
- Pro: user doesn't need individual API keys, credit system works, one payment relationship
- Con: adds latency, SwarmSpace dependency, only one of five provider paths

Direct API:
- Pro: lower latency, no dependency, user's existing billing relationships work
- Con: The Forge doesn't participate in billing (fine — user pays Anthropic/OpenAI directly)

Both are right for their use cases. SwarmSpace is the right answer for users who want simplicity and don't want multiple API accounts. Direct API is right for developers who already have accounts.

---

## Step 6 — Mistakes, dead ends, and wrong turns

**The original architecture had spec generation in a Firebase Function because of billing.**

This was correct reasoning for SwarmSpace routing. Billing should happen server-side so you can't skip it. But the reasoning got applied too broadly — it became "all spec generation needs to be a server function" instead of "billing needs to be server-side."

The fix: server-side only for the billing path. Direct API calls from Flutter for all other providers. The billing requirement is real and doesn't change. The scope of what needs a server function shrinks dramatically.

**The write-once invariant was originally a Firestore Security Rule.**

First version: `allow update, delete: if false` in Firestore rules enforced spec immutability at the server. Clean. Hard to break accidentally.

With local files, the enforcement is now in `ProjectFileRepository`:

```dart
// Before writing, check if file exists
if (await specFile.exists()) {
  throw SpecAlreadyExistsException(specFile.path);
}
// Only if it doesn't exist, proceed with write
```

It's application-level enforcement rather than server-level. That means a bug in the Flutter code could theoretically overwrite a spec. The mitigation is that the check is centralized in one place (`ProjectFileRepository`) and documented as an invariant. The cloud approach was "even if the code has a bug, the server rejects it." The local approach is "the code must be correct, and it's checked in one place." Slightly weaker but acceptable for v1.

---

## Step 7 — Pitfalls to watch for

**Never write to the spec file path — write to a temp path first.**

The atomic write pattern exists for a reason. If you write directly to `_LockedSpec_v1.md` and the process crashes at 60% through, you have a corrupt spec that looks like it exists. The existence check will then prevent a retry. Always write to `_LockedSpec_v1.md.tmp`, verify the write completed, then rename.

**The SQLite index is a cache. Do not treat it as a source of truth.**

If a project folder was moved or deleted in Finder while the app wasn't running, the index will be stale on next launch. The app should validate that index entries still exist on disk and remove stale ones. Don't show the user a project that doesn't exist because the index says it does.

**API keys are never logged.**

This sounds obvious but LLM calls often have verbose error logging. If the API call fails with an auth error, make sure the error handler doesn't log `request.headers` or the raw response which might include the key in error messages. Log the status code and error type, not the request content.

**The audit log is append-only — never open it in write mode.**

`File.writeAsString()` truncates before writing. Use `File.writeAsString(content, mode: FileMode.append)` or append to the raw bytes. If you use the wrong mode once, the entire audit history is gone. Put a linter rule or assertion on this.

**Ollama requires local setup — check before starting interview.**

The app should ping `localhost:11434/api/tags` on startup when Ollama is selected as the provider. If it's unreachable, show a warning before the user starts a 20-minute interview that will fail at the end. Fail fast, fail loudly.

---

## Step 8 — What an expert notices

**The filesystem structure *is* the API.**

When The Forge writes `MyApp_LockedSpec_v1.md` to the `specs/` folder, it's not just saving a file. It's publishing a spec that Claude Code, Codex, Cursor, or any other executor can read directly. The file path convention *is* the handoff protocol. An expert looks at the folder structure and sees an interface, not just a storage choice.

**The abstract provider is a seam for testing.**

`SpecGenerationProvider` can have a mock implementation for tests. The interview engine can be integration-tested against a fake provider that returns predetermined variants. Without the abstraction, testing the interview engine requires either hitting real APIs or mocking HTTP at a lower level. The interface makes clean testing possible.

**Temp file + rename is the correct primitive for local file atomicity.**

A lot of code just writes directly to the target path. The rename approach is what filesystem databases (SQLite, LevelDB) use internally. On macOS, `rename()` is POSIX-atomic — either the old file is there or the new file is there, never a half-written state. It's the same guarantee as a database transaction for single-file writes.

**Provider as a first-class user choice, not a config option.**

Putting provider selection in Settings with its own configuration UI (one section per provider: API key field, model override, test button) treats it as a product feature rather than a developer config. That's the right call. Users think about "I use Claude" or "I use ChatGPT" as an identity choice, not a config file entry. The Settings UI should match that mental model.

---

## Step 9 — Transferable lessons

**The file is often the right API.**

Cloud-first thinking pushes developers toward APIs and databases for everything. But when your users are developers and your product creates artifacts (specs, docs, code), files are often cleaner than APIs. Files are readable by humans, by any tool, by any editor. A Markdown spec file has zero dependencies. Ask: "does this need to be in a database, or can it just be a file?"

**Separate billing from computation.**

The original architecture mixed billing and LLM calls into one Firebase Function. The revised architecture separates them: LLM calls happen wherever is efficient (client for direct APIs, server for SwarmSpace routing), billing happens only where it needs to (server-side for SwarmSpace, not at all for bring-your-own-key). Mixing billing and computation creates unnecessary dependencies and makes non-billing paths more complex. Separate concerns stay separate.

**Abstract the seam, not the implementation.**

`SpecGenerationProvider` is abstract. The implementations (`ClaudeProvider`, `OpenAIProvider`, etc.) are concrete and specific. The abstraction is one layer: the interface the interview engine calls. No attempt to share code between providers, no "base class" with partial implementations. Each provider does its own thing; they just all satisfy the same contract. This is the right level of abstraction — thin interface, fat implementations.

**Invariants enforced in one place are maintainable. Invariants enforced everywhere are bugs waiting to happen.**

The write-once spec rule, the append-only audit rule — both enforced in `ProjectFileRepository` and nowhere else. Any other code that wants to write project files goes through `ProjectFileRepository`. Centralizing invariant enforcement means there's one place to audit, one place to write tests for, one place to fix if something goes wrong. Distributed invariant enforcement (each caller checks for themselves) drifts over time as some callers forget the check.
