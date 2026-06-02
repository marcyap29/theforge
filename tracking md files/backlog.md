# The Forge — Feature Backlog

**Last Updated:** 2026-06-01

Long-term feature pool. Active sprint work lives in `planner.md`.

---

## Strategic Priority — Build Order Gate

The Forge is **product #1** in the Orbital AI build sequence. It is not just a product — it is the instrument used to spec and build the next two products (dogfooding).

```
The Forge (#1) → ships → used to interview + spec → SwarmSpace Builder (#2)
SwarmSpace Builder (#2) → ships → Iterix built on SwarmSpace Blocks → Iterix (#3)
```

Every §N that brings The Forge closer to a working interview-to-spec run unblocks the entire product roadmap. Prioritise the critical path above everything else.

---

## How to use

- **Read first** when picking up new work — pull from High Priority before Medium before Low
- **Add to** when the user agrees a future feature should be done but is not the current focus
- **Mark shipped items** with `✅` and the date; do not delete
- **Do not remove items** without user approval

---

## Critical Path

```
§1 Local data layer ✅
  → §2 Riverpod project state layer ✅
  → §3 Project folder browser ✅
  → §4 LLM provider layer (BYOK + SwarmSpace)
  → §5 Build Interview UI (Stage 1A) ✅
  → §6 Spec generation + artifact writing (Stage 2)
  → §7 Artifact viewers
  → §8 Setup Worksheet generation (Stage 3)
  → §9 Handoff Package + Bullet Handoff (Stage 4)
  → §10 Settings screen
  → First end-to-end Forge run
```

---

## High Priority

### §1 — Flutter Bootstrap + Local Data Layer

**What it is:** Bootstrap the Flutter app, add core dependencies (Riverpod, drift, path_provider), and implement the local file data layer: `ProjectFileRepository` (filesystem read/write with atomic writes + append-only audit) and `ForgeDatabase` (drift SQLite project index).

**Why it matters:** Nothing else can be built without a stable data layer. This is the foundation. No Firebase — primary storage is local filesystem (`~/Documents/The Forge Projects/`).

**Architecture:** `lib/data/filesystem/project_file_repository.dart` · `lib/data/local_db/forge_database.dart` · schema documented in `backend.md`

**Dependencies:** None — this is first.

**Status:** ✅ Complete 2026-05-31 — `dart analyze lib/` zero issues; `forge_database.g.dart` generated

---

### §2 — Riverpod Project State Layer

**What it is:** The Riverpod providers that expose project state to the UI: a `ProjectListNotifier` that scans the root directory via `ProjectFileRepository.scanProjectPaths()` and syncs to `ForgeDatabase`, and an `ActiveProjectNotifier` that holds the currently open project and reads its README.md on load.

**Why it matters:** Every screen in the app reads from these providers. Nothing can be rendered without a project state layer.

**Architecture:** `lib/features/projects/providers/` · `ProjectListNotifier` (AsyncNotifier, drift-backed) · `ActiveProjectNotifier` (StateNotifier, reads README.md) · `lib/data/` layer is the only allowed I/O path — providers never touch the filesystem directly

**Key contracts:**
- `ProjectListNotifier.refresh()` — rescans `~/Documents/The Forge Projects/`, diffs against `ForgeDatabase`, updates index
- `ActiveProjectNotifier.open(String projectPath)` — sets active project, reads README into state
- `ActiveProjectNotifier.close()` — clears active project
- State shape mirrors `ProjectFileRepository` folder structure: `path`, `name`, `mode`, `phase`, `specVersion`, `lastOpened`

**Dependencies:** §1

**Status:** ✅ Complete 2026-06-01 — `dart analyze lib/` zero issues; all 4 providers declared


---


### §3 — Project Folder Browser

**What it is:** The home screen. Lists all projects in `~/Documents/The Forge Projects/` — name, mode (Build / Audit), current phase, last opened date. Tap to resume from last phase. "New Project" button starts the interview flow.

**Why it matters:** Multi-phase builds require coherent resumption. The folder browser is how The Forge remembers across sessions.

**Architecture:** `lib/features/projects/screens/projects_list_screen.dart` · reads from `ProjectListNotifier` · on tap: reads README.md + most recent bullet handoff, routes to active phase screen

**Resumption order (mirrors Workflow Template §Resumption Pattern):**
1. Read README.md — current phase, what's done, what's next
2. Read most recent Bullet Handoff in `/handoffs/`
3. Read current Locked Spec in `/specs/`
4. Route to the correct phase screen

**Dependencies:** §2

**Status:** ✅ Complete 2026-06-01 — 4 new files (`main.dart` rewrite, `core/app.dart`, `core/theme/app_theme.dart`, `features/projects/screens/projects_list_screen.dart`); `dart analyze lib/` zero issues; inline detail + new-project stubs

---

### §4 — LLM Provider Layer

**What it is:** The abstraction that makes The Forge provider-agnostic. Supports three modes: (1) BYOK via direct API call (Claude / OpenAI / any OpenAI-compatible endpoint), (2) Ollama for local models, (3) SwarmSpace routing. All LLM calls in the app go through this layer. The rest of the app never knows which provider is active.

**Why it matters:** This is what makes the Standalone (BYOK) tier work. Without it, spec generation is impossible. The provider layer must exist before any interview-to-spec flow can be built.

**Architecture:** `lib/services/llm/` · `LlmProvider` interface · `ClaudeDirectProvider`, `OpenAiProvider`, `OllamaProvider`, `SwarmSpaceProvider` implementations · `LlmProviderNotifier` (Riverpod — reads active provider from Settings) · API keys stored in macOS Keychain, never in files

**Key contracts:**
```
LlmProvider.complete({
  required String systemPrompt,
  required String userPrompt,
  required double temperature,
  int? maxTokens,
}) → Future<String>
```

**Temperature values used by The Forge:** 0.1 (executor), 0.2 (conservative spec), 0.6 (balanced spec), 1.0 (experimental spec)

**Dependencies:** §1 (keychain storage via secrets layer), §10 (settings screen reads provider config) — but can stub provider selection for interview development

**Status:** Not started

---

### §5 — Build Interview UI + State (Stage 1A)

**What it is:** The conversational interview screen for greenfield builds. Tracks 8 confidence dimensions, shows a visible confidence meter, enforces max 3 questions per turn, surfaces conflicts before proceeding, makes conservative default recommendations.

**Why it matters:** This is the core product loop. Everything else is either setup or output.

**Architecture:** `lib/features/interview/` · `InterviewNotifier` (StateNotifier — tracks confidence map, turn history, detected conflicts) · `InterviewScreen` widget · writes completed interview JSON to `ProjectFileRepository` on phase completion (not incrementally)

**8 confidence dimensions (Build mode — from Workflow Template):**

| Dimension | Question to resolve |
|---|---|
| Core purpose | What is the single primary job this product does? |
| Primary user | Who is this built for first? |
| Identity model | Accounts required, optional, or none? |
| Input model | What does the user interact with? |
| Output model | What does the product produce? |
| Platform | What does it run on? |
| Scope boundary | What is explicitly out of scope for this version? |
| External services | What third-party APIs or services does it touch? |

**Conflict detection pattern (verbatim from Workflow Template):**
> "Your answers on [X] and [Y] pull in opposite directions. [X] implies [consequence]. [Y] implies [different consequence]. I recommend [conservative option] for v1 because [reason]. Do you accept this scope?"

**Completion criteria:** All 8 dimensions resolved + all conflicts resolved + out-of-scope list confirmed → enables "Generate Spec" button

**Reference output:** `ForkIt_BulletHandoff_v1_Interview.md` in Obsidian — use as ground truth for what correct interview output looks like

**Dependencies:** §2 (project must be open), §4 (LLM calls for interview turns)

**Status:** ✅ Complete 2026-06-01 — 5 new files in `lib/features/interview/`, 1 update to `lib/core/app.dart` (interview route); `dart analyze lib/` zero issues; stub LLM at single call site ready for §4 swap

---

### §6 — Spec Generation + Artifact Writing (Stage 2)

**What it is:** Takes the completed interview JSON and generates the Locked Spec. Calls the LLM provider with the interview transcript and produces a structured Locked Spec document. Writes the result immutably to `ProjectFileRepository.writeLockedSpec()`. Updates README.md and Audit Log.

**Why it matters:** The Locked Spec is the immutable source of truth for the executor. Without it, no build can start.

**Architecture:** `lib/features/spec_generation/` · calls `LlmProvider.complete()` · parses response into spec structure · writes to `/specs/{ProjectName}_LockedSpec_v{N}.md` via `ProjectFileRepository.writeLockedSpec()` (write-once enforced at repo layer)

**Spec structure (from Workflow Template Stage 2):**
1. Immutable Goal Statement
2. Hard Constraints Table
3. Component Map (single responsibility per component)
4. Interface Contracts
5. Completion Criteria (verifiable by executor/judge agent without human input)
6. Static Content Specs (if applicable)
7. Explicit Out-of-Scope List
8. Accepted Decisions (chosen / rejected / reasoning / confidence)
9. Open Flags (format: Flag / Component / Options / Recommended default)
10. v2 Architecture Notes
11. Handoff Package (JSON — generated by §9)

**Monte Carlo mode (future, see §14):** Three parallel calls at t=0.2 / t=0.6 / t=1.0. Single-call at t=0.6 for v1.

**Reference output:** `Locked Spec — ForkIt v1.1.md` in Obsidian — use as ground truth for what a correct spec looks like

**Dependencies:** §4 (LLM provider), §5 (completed interview to send)

**Status:** Not started

---

### §7 — Artifact Viewers

**What it is:** Read-only display screens for all four Forge outputs: Locked Spec, Bullet Handoff, Setup Worksheet, Audit Log. Accessed from the project detail screen. No edit affordance on any of them — these are immutable records.

**Why it matters:** Users need to review what was produced. Executor agents read the spec. The Forge reads the bullet handoff to resume. The audit log is the compliance record.

**Architecture:** `lib/features/artifacts/` · `SpecViewerScreen` · `BulletHandoffViewerScreen` · `WorksheetViewerScreen` · `AuditLogViewerScreen` · each reads from `ProjectFileRepository` · rendered as scrollable markdown (package: `flutter_markdown`)

**Scroll-to-section nav required for:** Locked Spec (10 sections), Audit Log (multi-phase entries)

**Dependencies:** §3 (project must be open), §6 (spec must exist to view it)

**Status:** Not started

---

### §8 — Setup Worksheet Generation (Stage 3)

**What it is:** Auto-generates a step-by-step human-action checklist for every external service the build requires. Firebase, Google Places, Stripe, etc. Includes an environment variables table for the executor agent.

**Why it matters:** Eliminates the manual console setup that blocks builds from starting. The executor agent cannot run until `setupWorksheetComplete` is true.

**Architecture:** `lib/features/spec_generation/worksheet_generator.dart` · triggered after spec generation · calls `LlmProvider.complete()` with spec content + external services list · writes to `ProjectFileRepository.writeWorksheet()`

**Worksheet structure (from Workflow Template Stage 3):**
1. Before You Start (time estimate, prerequisites)
2. One section per external service (account creation, API key, restriction config, values to copy)
3. Local project configuration
4. Environment Variables Table (for executor agent)
5. Verification Checklist
6. What Happens Next
7. Free Tier Reference

**Triggering conditions:** Generate a section for any service requiring account creation, API key, billing enablement, credentials download, console config, or env vars.

**Reference output:** `ForkIt_SetupWorksheet_v1.md` in Obsidian — use as ground truth for format and depth

**Dependencies:** §6 (spec must exist to extract external services from)

**Status:** Not started

---

### §9 — Handoff Package + Bullet Handoff Generation (Stage 4)

**What it is:** Three distinct outputs generated at each phase transition. The **Handoff Package** is a structured JSON summary of the Forge run (consumed by executor agents). The **Bullet Handoff** is a human-scannable markdown summary (consumed by The Forge on resume and by the user). The **/goal text** is a formatted view of the locked spec written for an autonomous executor harness (Claude Code /goal, OpenAI Codex, or equivalent).

**Why it matters:** These are what make multi-phase builds coherent. Without them, each new session re-derives context. With them, the next agent or session starts fully informed. The /goal text lets a user paste directly into an executor harness to start the build loop.

**Architecture:** `lib/features/spec_generation/handoff_generator.dart` · `BulletHandoff` generated at: Interview → Spec, Spec → Executor, Agent N → Agent N+1, Phase → Phase · JSON Handoff Package written via `ProjectFileRepository.writeHandoffPackage()` · Bullet Handoff written via `ProjectFileRepository.writeHandoff()` · /goal text written via `ProjectFileRepository.writeHandoff()` to `/handoffs/{ProjectName}_goal_v{N}.md`

**Bullet Handoff format (from Workflow Template):**
- What Was Decided
- What Was Explicitly Deferred
- Open Items
- Completion Criteria met (added 2026-06-01 — lists criteria verified complete, or "N/A — pre-execution handoff")
- What the Next Agent or Session Needs to Know

**Handoff Package schema (Build mode — from Workflow Template Stage 4):**
```json
{
  "interviewMode": "build",
  "specVersion": "string",
  "appName": "string",
  "platform": "string",
  "framework": "string",
  "lockedAt": "ISO date",
  "goalStatement": "string",
  "components": ["string"],
  "infrastructure": { "service": "implementation" },
  "stateManagement": "string",
  "navigation": "string",
  "openFlags": "number",
  "outOfScopeItems": "number",
  "setupWorksheetComplete": "bool",
  "v2SeedItems": ["string"]
}
```

**Reference outputs:** `ForkIt_BulletHandoff_v1_Interview.md` + handoff JSON in ForkIt Locked Spec — use as ground truth

**Dependencies:** §6 (spec must be generated first)

**Status:** Not started

---

### §10 — Settings Screen + BYOK Key Storage

**What it is:** The settings screen where users configure their LLM provider, API key, model selection, and root project directory. API keys are stored in the macOS Keychain — never in files or env vars.

**Why it matters:** Without provider configuration, The Forge can't make any LLM calls. This is what enables the Standalone (BYOK: Free) tier.

**Architecture:** `lib/features/settings/` · `SettingsNotifier` (persists to UserDefaults / NSUserDefaults via `shared_preferences`) · API key stored via `flutter_secure_storage` → macOS Keychain · provider options: Claude (model select), OpenAI (model select), Ollama (base URL + model), SwarmSpace (OAuth token)

**Provider options:**
- **Claude (Anthropic)** — direct API key, model selector (claude-opus-4-7, claude-sonnet-4-6, etc.)
- **OpenAI** — direct API key, model selector
- **OpenAI-compatible** — custom base URL + API key (DeepSeek, Kimi-K, self-hosted vLLM)
- **Ollama** — base URL (default: localhost:11434), model selector (local models, no network call)
- **SwarmSpace** — OAuth token, credit balance display

**Root directory setting:** Default `~/Documents/The Forge Projects/` · user-configurable · passed to `ProjectFileRepository._rootDirProvider`

**Dependencies:** §4 (provider layer reads from settings)

**Status:** Not started

---

## Medium Priority

### §11 — Audit Interview Mode (Stage 1B)

**What it is:** The second interview mode — for existing teams and codebases. Goal is to establish current state, not define what to build. Produces a Current State Spec, not a Locked Spec.

**Why it matters:** The enterprise use case. Fractional CTOs, team takeovers, codebase audits.

**Architecture:** Extends `lib/features/interview/` with mode switching · new confidence dimension set · Current State Spec structure differs from Locked Spec

**8 confidence dimensions (Audit mode — from Workflow Template):**

| Dimension | Question to resolve |
|---|---|
| Project goal | What is this project actually trying to do, stated plainly? |
| Current build state | What is shipped, what is in progress, what has not started? |
| Feature ownership | Which engineer or sub-team owns each feature or component? |
| Active blockers | What is currently stuck, and for how long? |
| Blocker blast radius | Which other features / engineers are blocked downstream? |
| Decision debt | What architectural decisions were made without documentation? |
| Technical debt | What known shortcuts or deferred fixes exist, where, and who knows? |
| AI and token usage | Which engineers use AI agents, on what tasks, at what spend? |

**Current State Spec structure (distinct from Locked Spec):**
1. Project Goal Statement
2. Current Build State (shipped / in progress / not started)
3. Component and Feature Map with Owner Names
4. Active Blocker Registry (table: Blocker / Component / Owner / Blocked Since / Downstream Impact / Engineers Affected)
5. Decision Debt Log (table: Decision / What Was Decided / Documented? / Source / Conflict?)
6. Technical Debt Log
7. AI and Token Usage Summary
8. Documentation Gaps
9. Confidence Map (per dimension: Established / Partial / Unknown)
10. Next Phase Seeds
11. Handoff Package (JSON)

**Doc/verbal conflict pattern:** When an engineer's answer contradicts a document, surface with: "[Document X] states [claim]. You've described [different claim]. Which reflects current state, and when did this change?" Record both under Decision Debt.

**Dependencies:** §5 (Build Interview must exist as the template), §6 (spec generation handles both modes)

**Status:** Not started

---

### §12 — Document Ingestion

**What it is:** Pre-interview doc ingestion — PDF, Word, Markdown, Confluence exports, architecture diagrams. Extracts structured facts, scores initial confidence per dimension, skips established dimensions in the interview. Required first step for Audit mode; optional for Build mode.

**Why it matters:** Teams with existing docs shouldn't be asked questions the docs already answer. In Audit mode, doc/doc conflicts are the most important signals — surfacing where two documents contradict each other before the interview begins.

**Architecture:** `lib/features/interview/ingestion/` · doc picker (macOS file dialog) · calls `LlmProvider.complete()` for extraction · produces `{SourceDoc}_ingested.md` + `{ProjectName}_IngestionSummary.md` in `/ingested/` · outputs confidence map per dimension (Established / Partial / Unknown)

**Ingestion rules:**
- Extract structured facts only — no inference or interpretation
- Score each dimension: Established (clear), Partial (touches but has gaps), Unknown (no signal)
- Established dimensions skip interview questions entirely
- Partial dimensions get targeted gap-fill questions only
- Unknown dimensions get full question set
- Flag doc/doc conflicts before interview begins

**Dependencies:** §5 and §11 (interviews must exist to receive ingestion output)

**Status:** Not started

---

### §13 — Workspace + Billing (SwarmSpace tier)

**What it is:** Workspace model ($150/workspace/month), seat management (up to 10), shared credit pool, credit top-up. Connects to SwarmSpace billing infrastructure. Credit consumption tracked in audit log.

**Why it matters:** Required for the Forge Workspace tier and monetization. SwarmSpace has the billing rails — this is the connection layer.

**Architecture:** `lib/features/billing/` · SwarmSpace credit API · credit balance display in Settings · credit cost recorded in Audit Log per run · `setupWorksheetComplete` gate enforced before any spec generation that costs credits

**Credit reference (from Positioning Brief):**
- Full Forge run (interview through locked spec): 20–35 credits
- Single variant generation: 4–6 credits
- Executor agent run (per agent): 8–15 credits

**Dependencies:** §4 (LLM provider layer — SwarmSpace provider must exist), §9 (handoff package records credit cost)

**Status:** Not started

---

## Low Priority

### §14 — Monte Carlo Spec Generation

**What it is:** Three architectural variants generated in parallel at different temperatures: Conservative (t=0.2), Balanced (t=0.6), Experimental (t=1.0). All three complete before any is shown. User evaluates them simultaneously and selects one or nominates a hybrid before the spec is locked. Rejected variants are retained in the audit log as the "alternatives considered" record.

**Why it matters:** The core differentiator. Monte Carlo generation is what makes the spec an RFC-grade document rather than a one-shot output.

**Architecture:** `lib/features/spec_generation/monte_carlo_generator.dart` · 3 parallel `LlmProvider.complete()` calls · `VariantSelectionScreen` to compare and select · rejected variants written to `/audit/` · selected variant proceeds to `writeLockedSpec()`

**Note:** §6 implements single-call spec generation at t=0.6. Monte Carlo is an upgrade to §6, not a replacement. Both use the same `writeLockedSpec()` write path.

**Dependencies:** §6 (single-call generation must exist and be stable first)

**Status:** Future / not started

---

### §15 — Open Source Executor Path

**What it is:** The locked spec is tool-agnostic JSON. A manifest mapping layer that allows any executor agent (open source runtimes, self-hosted) to consume a Forge spec without routing through commercial APIs.

**Why it matters:** Clients with data sovereignty requirements or cost-at-scale needs. The architecture supports it; the integration path is a manifest mapping, not a re-architecture.

**Dependencies:** §6, §7 (spec format must be stable)

**Status:** Future / not started

---

### §16 — Audit Trail Export

**What it is:** Exportable, versioned audit trail package — full interview transcript, all spec variants (including rejected), user selections and reasons, locked spec at point of approval, all handoff artifacts, run metadata (timestamps, provider, credit cost, agent temperatures).

**Why it matters:** Compliance, reproducibility, client deliverables for dev shops. The export is the paper trail that normally takes a week to produce — packaged in one action.

**Architecture:** Reads from the project folder (all existing files) + packages into a versioned zip or folder · no new server-side state needed · macOS share sheet or save panel

**Dependencies:** §7 (artifact viewers), §9 (handoff package)

**Status:** Future / not started

---

## Completed ✅

### §1 — Flutter Bootstrap + Local Data Layer
✅ Complete 2026-05-31 — `dart analyze lib/` zero issues; `forge_database.g.dart` generated via `dart run build_runner build --force-jit`

### §2 — Riverpod Project State Layer
✅ Complete 2026-06-01 — 3 provider files (`project_list_notifier`, `active_project_notifier`, `providers`); 4 providers declared; `dart analyze lib/` zero issues; zero Firebase

### §3 — Project Folder Browser
✅ Complete 2026-06-01 — 4 files (`main.dart` rewrite, `core/app.dart`, `core/theme/app_theme.dart`, `features/projects/screens/projects_list_screen.dart`); `dart analyze lib/` zero issues; macOS dark monospace theme; inline detail + new-project stubs

### §5 — Build Interview UI + State (Stage 1A)
✅ Complete 2026-06-01 — 5 new files in `lib/features/interview/` (`state/interview_state.dart`, `state/interview_notifier.dart`, `providers/interview_providers.dart`, `ui/confidence_meter.dart`, `ui/interview_screen.dart`) + 1 update to `lib/core/app.dart` (added `/interview` named route); `dart analyze lib/` zero issues; stub LLM in single call site (turn-based: 9 user messages cover 8 dimensions, surfaces 1 conflict on turn 3); conflict surface follows Workflow Template pattern verbatim

---

*Sequence items so each tier unblocks the next. §2 → §3 → §4 → §5 → §6 is the critical path to a first working interview-to-spec run.*
