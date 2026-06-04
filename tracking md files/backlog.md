# The Forge — Feature Backlog

**Last Updated:** 2026-06-02

Long-term feature pool. Active sprint work lives in `planner.md`.

---

## Critical Path

```
§1 Local data layer ✅
  → §2 Riverpod project state layer ✅
  → §3 Project folder browser ✅
  → §4 LLM provider layer (BYOK + SwarmSpace) ✅
  → §5 Build Interview UI (Stage 1A) ✅
  → §6 Spec generation + artifact writing (Stage 2)
  → §7 Artifact viewers
  → §8 Setup Worksheet generation (Stage 3)
  → §9 Handoff Package + Bullet Handoff (Stage 4)
  → §10 Settings screen ✅
  → First end-to-end Plan Mode run (gate for Watch + Reverse work)
       ↓
  → §W1 Watch Mode: Token Ingestion Engine
  → §W2 Watch Mode: Git Activity Engine + CI Outcome Correlator
  → §W3 Watch Mode: Failure Signal Engine + Alert Engine
  → §W4 Watch Mode: Dashboard UI Shell
  → §W5 Watch Mode: SwarmSpace Briefing + Decision Simulation
  → §W6 Watch Mode: Spec Compliance Monitor + Drift Detector (requires spec)
       ↓
  → §R1 Reverse Mode: Codebase Ingestion Engine
  → §R2 Reverse Mode: Reverse Interview Engine + As-Built Spec Generator
       ↓
  → Configuration C pilot (Qualcomm) — Watch + Reverse on existing codebase
```

**Platform — RESOLVED (2026-06-04):** Flutter desktop macOS for all three modes. Confirmed. See `audit/The_Forge_AuditLog.md` entry 002.

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

**Status:** ✅ Complete 2026-06-02 (worktree wt/llm-provider-layer) — 8 new files in `lib/services/llm/` (provider abstract, model config, service, service provider, 4 provider impls: Ollama / Claude / OpenAI / Gemini); `dart analyze lib/` zero issues; direct HTTP via `package:http` (no SDK deps)

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

**Status:** ✅ Complete 2026-06-02 (worktree wt/llm-provider-layer) — 3 new files in `lib/features/settings/` (notifier, providers, screen); 1 update to `lib/core/app.dart` (added `/settings` route); 1 update to `lib/features/projects/screens/projects_list_screen.dart` (gear icon); `dart analyze lib/` zero issues; API keys → macOS Keychain via `flutter_secure_storage`; base URL + role assignments + model IDs → `SharedPreferences`; Ollama auto-refresh on mount and on URL save

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

---

## Watch Mode (formerly Vigilint) — gated on first end-to-end Plan Mode run

> **Architecture note:** All Watch Mode work should be Flutter macOS (matching Plan Mode), unless the open flag in `audit/The_Forge_AuditLog.md` entry 002 is resolved differently. Watch Mode ingests data via direct HTTP (no server layer) and persists to local SQLite via drift. `observedOutcomes` table must be included in the schema from day one — see Backlog Appendation item 001.

### §W1 — Token Ingestion Engine

**What it is:** Polls the Anthropic API hourly for per-engineer token spend, normalizes into daily and 30-day aggregates, and calculates cost at current model pricing. The foundation data source for all Watch Mode signals.

**Owns:** Anthropic API polling (per-engineer key from Workspace Config), usage normalization, daily/30-day aggregation, cost-in-USD calculation, session-level granularity.

**Demo data bridge:** Ship with the 4 synthetic engineer profiles from the Vigilint spec (The Runaway 9x baseline, The Ghost 0.1x, The High Performer 1.5x, Self 1.0x = $15/day) using fixed-seed RNG (Random(42)) so demos work before any real team is configured.

**Interface contract:**
```
Input:  { engineerHandle: string, apiKey: string, lookbackDays: number }
Output: {
  engineerHandle: string,
  dailyBreakdown: { date: ISO, tokensUsed: number, costUSD: number }[],
  totalCostUSD30d: number,
  sessionCount: number,
  alertFlags: ('spend_threshold' | 'runaway_session')[]
}
```

**Dependencies:** §W0 — Workspace Config extension (add team roster, per-engineer API keys, alert thresholds to existing WorkspaceConfig schema from §10)

**Status:** Not started — gated on Plan Mode end-to-end run

---

### §W2 — Git Activity Engine + CI Outcome Correlator

**What it is:** Pulls commit/PR activity from GitHub GraphQL and correlates token sessions to CI run outcomes (pass/fail/timeout). The correlation is the core differentiator: token spend per successful outcome vs. token spend per failed outcome, per engineer.

**Git Activity owns:** GitHub GraphQL calls, commit attribution per engineer, PR lifecycle tracking, agent-vs-human attribution heuristics (commit message signature scanning).

**CI Correlator owns:** GitHub Actions run outcome ingestion, timestamp-based correlation to token sessions within configurable window (default 4h), correlation confidence scoring (0–1), rolling 7d and 30d token-to-failure ratios.

**Key signal:** Token-to-fail ratio over 30d. High performer = high spend + high CI pass rate. Management decision = high spend + low CI pass rate.

**Interface contracts:** See SuperSpec v1 `DOCS/forge/The_Forge_SuperSpec_v1.md` — CI Outcome Correlator section.

**Dependencies:** §W1 (token sessions required for correlation)

**Status:** Not started

---

### §W3 — Failure Signal Engine + Alert Engine

**What it is:** Derives management-layer signals from correlated data and routes them to an alert log. Loop detection, churn correlation, bug introduction rate, spend threshold alerts, stalled project detection.

**Failure Signal owns:** Token-to-failed-run ratio, loop detection (high-token sessions on same files without commit), code churn correlation (commits substantially reverted within 2–3 pushes), bug introduction rate (issues tagged as bugs traced to authoring commit).

**Alert Engine owns:** Spend threshold evaluation (per-engineer and workspace), runaway session detection, stalled project detection, spec drift alerts (if spec is loaded), alert log.

**Dependencies:** §W2 (correlated data required)

**Status:** Not started

---

### §W4 — Watch Mode Dashboard UI Shell

**What it is:** The management dashboard — screens for per-engineer spend overview, git activity, CI correlation signals, project health summaries, and alert log. All data display, no business logic.

**Scope (v1):** Engineer roster view with spend + CI pass rate, per-engineer drill-down, project health table (stall detection, velocity trending), alert log. Read-only — no action buttons beyond dismissing alerts.

**Architecture:** New `lib/features/watch/` directory · `WatchDashboardScreen` · `EngineerDetailScreen` · `ProjectHealthScreen` · `AlertLogScreen` · all read from Watch Mode providers (Riverpod) · charts via `fl_chart`

**Demo mode:** If no real team configured, show the 4 synthetic profiles automatically. Identical code path — DemoData implements same interface contracts as live data.

**Dependencies:** §W3 (signals and alerts), §W1/§W2 data providers

**Status:** Not started

---

### §W5 — SwarmSpace Briefing + Decision Simulation

**What it is:** Weekly intelligence synthesis via SwarmSpace MCP, and a 50-iteration Monte Carlo decision simulation for management decisions. Both call SwarmSpace's Cloudflare Workers endpoint via direct HTTP.

**Briefing owns:** Assembles Watch Mode data package (token trends, git signals, CI outcomes, alert summary), calls SwarmSpace `deep_research`, renders plain-language weekly narrative.

**Decision Simulation owns:** Decision framing interface (what is the decision? what's the context?), attaches engineering telemetry from Watch Mode, calls SwarmSpace `deep_research` with 50-iteration simulation prompt, renders recommended path + confidence score + regret risk + time-horizon projections.

**SwarmSpace endpoint:** `https://swarmspace-mcp-server.orbitalai.workers.dev/mcp` (live, no additional infrastructure)

**Note on naming:** The Plan Mode variant generator (t=0.2/0.6/1.0) is also called "Monte Carlo" by method. Backlog Appendation item 002 addresses this naming conflict — resolve when both are live in the same surface.

**Dependencies:** §W4 (dashboard data layer), SwarmSpace MCP endpoint (already live)

**Status:** Not started

---

### §W6 — Spec Compliance Monitor + Drift Detector

**What it is:** Evaluates incoming commits against the locked spec component map. Requires a locked spec (from Plan Mode or Reverse Mode) to activate. Surfaces out-of-scope file changes, component boundary violations, and cumulative drift score per repository.

**Spec Compliance Monitor owns:** Commit-to-component-map evaluation, out-of-scope file detection, boundary violation detection, drift score (0–100, cumulative per repo).

**Drift Detector owns:** Trend analysis on drift score over time, threshold-based alerting (wired into Alert Engine), visual drift timeline in dashboard.

**Interface contract:** See SuperSpec v1 `DOCS/forge/The_Forge_SuperSpec_v1.md` — Spec Compliance Monitor section.

**Dependencies:** §W3 (alert routing), §W4 (display), a locked spec (from §6 Plan Mode or §R2 Reverse Mode)

**Status:** Not started — this is Configuration C's unlock (Qualcomm pilot use case)

---

## Reverse Mode — gated on Watch Mode §W1-§W4

### §R1 — Codebase Ingestion Engine

**What it is:** Reads a repository and extracts component structure, interface contracts as implemented, infrastructure choices, and dependency patterns. Identifies gaps — what cannot be determined from code alone — for the Reverse Interview to fill.

**Owns:** Repository read (local filesystem), component structure extraction, interface contract inference from implementation, infrastructure pattern detection, dependency mapping, gap identification.

**Output:** Structured ingestion summary → input to §R2 Reverse Interview Engine.

**Dependencies:** §12 Document Ingestion (Audit Mode doc ingestion shares the same extraction pattern — R1 extends it for whole-repo analysis)

**Status:** Not started

---

### §R2 — Reverse Interview Engine + As-Built Spec Generator

**What it is:** Takes the codebase ingestion summary and runs a targeted interview to fill gaps. Produces an as-built spec in the identical format as a Plan Mode spec — Watch Mode can immediately use it as a reference document.

**Owns:** Targeted question generation from ingestion gaps (only questions about what code doesn't answer), as-built spec production in v1.1 locked spec format, decision rationale capture.

**Key design constraint:** As-built specs are thinner on "alternatives considered" and "drawbacks accepted" sections — code shows what was chosen, not what was rejected. This is documented in the spec's Accepted Decisions table and is expected.

**Output:** `{ProjectName}_LockedSpec_v1_AsBuilt.md` in standard locked spec format. Fully compatible with §W6 Spec Compliance Monitor.

**Configuration C entry point (Qualcomm pilot):** Run §R1+§R2 on existing repos → activate §W6 compliance monitoring against the as-built specs. Full drift detection without any prior Forge usage.

**Dependencies:** §R1 (ingestion required), §6 (spec writing engine shared with Plan Mode)

**Status:** Not started

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

### §4 — LLM Provider Layer (BYOK + SwarmSpace)
✅ Complete 2026-06-02 (worktree wt/llm-provider-layer) — 8 new files in `lib/services/llm/`; `dart analyze lib/` zero issues; 4 provider implementations (Ollama / Claude / OpenAI / Gemini) with hardcoded catalogs; Ollama model list fetched live via `static OllamaProvider.fetchModels`; `LlmService` resolves `role → ModelAssignment → provider`; API contracts match plan verbatim

### §10 — Settings Screen + BYOK Key Storage
✅ Complete 2026-06-02 (worktree wt/llm-provider-layer) — 3 new files in `lib/features/settings/`; API keys → macOS Keychain; base URL + role assignments + model IDs → `SharedPreferences`; live Ollama connection check; masked key entry (`••••••{last4}`); provider dropdown filtered to configured providers; role cards apply changes immediately via `setRoleAssignment`

---

*Sequence items so each tier unblocks the next. §2 → §3 → §4 → §5 → §6 is the critical path to a first working interview-to-spec run.*
