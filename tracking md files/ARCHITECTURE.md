# The Forge — Architecture

**Version:** 2.0.0
**Last Updated:** 2026-06-20

---

## What It Is

The Forge is a standalone Flutter desktop app (macOS primary). It is the project management layer for AI-assisted development — sitting above executor agents (Claude Code, Codex, Cursor) and producing the locked specs those agents build against.

Three operating modes:

| Mode | Purpose | Status |
|---|---|---|
| **Plan Mode** | Structured interview → locked spec → /goal artifact → executor handoff | ✅ Fully implemented |
| **Watch Mode** | Token spend + git activity + CI correlation + alerts + SwarmSpace briefings | ✅ §W1–§W4 complete; §W5 next |
| **Reverse Mode** | Reads existing codebase, generates as-built spec | 🔲 Not yet started |

The three modes share one artifact: the locked spec. It is the universal language connecting everything.

---

## Design Principles

**Local-first.** Project data lives on the user's filesystem as human-readable Markdown files. No cloud account required for core functionality.

**Provider-agnostic LLM.** The user configures which LLM powers the interview and spec generation — Gemini, Claude, GPT-4, or a local Ollama model — via the Settings screen. Keys are stored in Application Support (`forge_config.json`), not hardcoded.

**Cloud is optional, not foundational.** Firebase is not used. SwarmSpace integration (§W5) is additive.

---

## Stack

| Layer | Technology |
|---|---|
| Desktop app | Flutter 3.38.7 (macOS primary) |
| State management | Riverpod 2.x (`AsyncNotifier`, `FamilyAsyncNotifier`, `Notifier`, `ConsumerWidget`) |
| Primary storage | Local filesystem (Markdown + JSON files) |
| Local index | SQLite via `drift` (project list cache; not source of truth) |
| LLM layer | Pluggable `LlmProvider` (Gemini, Claude, OpenAI, Ollama) via `LlmService` |
| Charts | `fl_chart` (Watch Mode spend chart) |
| API config | `forge_config.json` in Application Support + `SharedPreferences` for non-secret prefs |
| Linter | `dart analyze lib/` — zero warnings required |

---

## Repository Layout

```
The Forge/
├── lib/
│   ├── core/
│   │   ├── app.dart                          — MaterialApp, named routes, navigatorObserver
│   │   └── theme/
│   │       └── app_theme.dart                — macOS dark monospace theme, amber accent
│   ├── data/
│   │   ├── filesystem/
│   │   │   └── project_file_repository.dart  — all disk reads/writes (single access point)
│   │   └── local_db/
│   │       ├── forge_database.dart           — drift schema: projects table
│   │       └── forge_database.g.dart         — generated (do not edit)
│   ├── features/
│   │   ├── artifacts/
│   │   │   └── artifact_viewer_screen.dart   — read-only markdown viewer (specs, handoffs, etc.)
│   │   ├── interview/
│   │   │   ├── providers/
│   │   │   │   └── interview_providers.dart  — InterviewArgs + interviewProvider family
│   │   │   ├── state/
│   │   │   │   ├── interview_dimension.dart  — DimensionDef (Build/Audit dims) + LayerDef (L1–L4)
│   │   │   │   ├── interview_notifier.dart   — FamilyAsyncNotifier; 4-layer funnel; forge-state parse
│   │   │   │   └── interview_state.dart      — InterviewState (turns, confidence, extracted, layers)
│   │   │   └── ui/
│   │   │       ├── confidence_meter.dart     — 8-bar meter per dimension
│   │   │       └── interview_screen.dart     — chat UI, layer strip, escape hatch, rewind
│   │   ├── projects/
│   │   │   ├── ingestion/
│   │   │   │   ├── ingestion_engine.dart     — LLM extraction prompt + parser
│   │   │   │   ├── ingestion_notifier.dart   — add/remove/rebuild reference docs
│   │   │   │   ├── reference_doc.dart        — ReferenceDoc + IngestedFacts models
│   │   │   │   └── reference_docs_screen.dart — management UI with file picker
│   │   │   ├── providers/
│   │   │   │   ├── active_project_notifier.dart
│   │   │   │   ├── project_list_notifier.dart
│   │   │   │   └── providers.dart
│   │   │   └── screens/
│   │   │       ├── new_project_screen.dart
│   │   │       ├── project_detail_screen.dart — phase timeline, layer dots, CTA, build sequence
│   │   │       └── projects_list_screen.dart  — project list + Watch Mode + Settings nav
│   │   ├── settings/
│   │   │   ├── engineer_roster_notifier.dart  — Watch Mode engineer roster
│   │   │   ├── github_config_notifier.dart    — GitHub org/token/repos config
│   │   │   ├── settings_notifier.dart         — LLM provider settings + BYOK
│   │   │   ├── settings_providers.dart
│   │   │   └── settings_screen.dart
│   │   ├── spec_generation/
│   │   │   ├── executor_timeline_notifier.dart — build sequence generator + reader
│   │   │   ├── generation_widgets.dart         — shared widgets for generation screens
│   │   │   ├── spec_generation_screen.dart     — idle/generating/done/error spec gen UI
│   │   │   ├── spec_generator.dart             — all LLM prompt builders + handoff builders
│   │   │   ├── spec_notifier.dart              — spec generation pipeline
│   │   │   ├── spec_parser.dart                — strip code fences, trim
│   │   │   ├── spec_providers.dart
│   │   │   ├── worksheet_generation_screen.dart
│   │   │   ├── worksheet_generator.dart        — worksheet prompt builder
│   │   │   └── worksheet_notifier.dart         — worksheet generation pipeline
│   │   └── watch/
│   │       ├── alert_log_screen.dart           — active/dismissed alert log
│   │       ├── engineer_detail_screen.dart     — per-engineer drill-down + spend chart
│   │       ├── watch_dashboard_screen.dart     — main Watch Mode screen
│   │       ├── watch_data_notifier.dart        — single orchestrating provider for watch screens
│   │       └── workspace_health_screen.dart    — velocity trend + CI stats
│   ├── main.dart
│   └── services/
│       ├── llm/
│       │   ├── llm_model_config.dart           — ModelInfo, LlmSettings, model catalogs
│       │   ├── llm_provider.dart               — LlmProvider abstract + LlmRole enum
│       │   ├── llm_service.dart                — resolves role → provider → complete()
│       │   ├── llm_service_provider.dart       — llmServiceProvider
│       │   └── providers/
│       │       ├── claude_provider.dart        — Anthropic Messages API
│       │       ├── gemini_provider.dart        — Google Generative Language API
│       │       ├── ollama_provider.dart        — HTTP to local Ollama
│       │       └── openai_provider.dart        — OpenAI Chat Completions
│       └── watch/
│           ├── alert_engine.dart               — deduplicates signals into AlertEntry log
│           ├── alert_log_notifier.dart         — persists alert log to forge_config.json
│           ├── ci_correlator.dart              — joins token sessions + CI runs by day
│           ├── ci_outcome_provider.dart        — CIOutcomeProvider abstract + models
│           ├── demo_usage_provider.dart        — deterministic demo data (4 engineer profiles)
│           ├── failure_signal_engine.dart      — derives FailureSignal from §W1+§W2 data
│           ├── git_activity_provider.dart      — GitActivityProvider abstract + models
│           ├── git_activity_service.dart       — orchestrates git+CI fetch + correlation
│           ├── git_activity_service_provider.dart
│           ├── project_status_aggregator.dart  — workspace health (velocity, stall, CI)
│           ├── providers/
│           │   ├── anthropic_usage_provider.dart
│           │   ├── gemini_usage_provider.dart  — stub (API unsupported)
│           │   ├── github_ci_provider.dart     — GitHub Actions REST API
│           │   ├── github_git_provider.dart    — GitHub GraphQL API
│           │   ├── ollama_usage_provider.dart  — stub (local model)
│           │   └── openai_usage_provider.dart
│           ├── usage_provider.dart             — UsageProvider abstract + models
│           ├── usage_service.dart              — iterates roster, fetches all usage
│           ├── usage_service_provider.dart     — nullable (nil when roster unconfigured)
│           ├── watch_signal_service.dart       — orchestrates §W3: signals + alerts + status
│           └── watch_signal_service_provider.dart
├── DOCS/
│   ├── forge/
│   │   ├── The_Forge_SuperSpec_v1.md           — master product spec (all 3 modes)
│   │   ├── The_Forge_SuperSpec_Backlog_v1.md   — backlog items not yet in scope
│   │   ├── The_Forge_InterviewFunnel_Plan_v1.md — 4-layer funnel design doc [IMPLEMENTED]
│   │   ├── workflow_template.md                — interview process + spec format reference
│   │   ├── positioning_brief.md                — product positioning + pricing
│   │   ├── forge_mcp_build_plans.md            — MCP server build reference
│   │   ├── ex1_executor_timeline_plan.md       — §EX1 executor handoff [COMPLETE]
│   │   ├── interview_funnel_executor_plan_v1.md — §IF1 executor handoff [COMPLETE]
│   │   ├── layer_timeline_executor_plan_v1.md  — §UI1 executor handoff [COMPLETE]
│   │   ├── feature_mode_executor_plan_v1.md    — §FM1 executor handoff [COMPLETE]
│   │   ├── The_Forge_BulletHandoff_v1_PlatformMerge.md — §6+§7 handoff [COMPLETE, archived]
│   │   └── The_Forge_BulletHandoff_v2_Worksheet_Handoff.md — §8+§9 handoff [COMPLETE, archived]
│   └── Coding Lessons/
│       └── FOR_MARC_[topic].md                 — one lesson file per significant task
├── tracking md files/
│   ├── context.md          — session log (newest first)
│   ├── planner.md          — completed + active sprint tasks
│   ├── backlog.md          — feature pool
│   ├── ARCHITECTURE.md     — this file
│   ├── CHANGELOG.md
│   ├── FEATURES.md
│   └── UI_UX.md
├── agents md files/        — Claude SOP files
├── operations md files/    — CONFIGURATION_MANAGEMENT.md, startup.md
├── bugtracker/             — bug records + prevention guide
├── backend.md              — Firebase + SwarmSpace API reference
└── claude.md               — Claude session guide
```

---

## Local Project File Structure

Every Forge project is a folder on the user's machine. Default root: `~/Documents/The Forge Projects/`.

```
~/Documents/The Forge Projects/
└── {ProjectName}/
    ├── README.md                                  — phase, what's done, what's next
    ├── {ProjectName}_HandoffPackage_v1.json       — machine-readable handoff for executor agents
    ├── forge/
    │   ├── {ProjectName}_LockedSpec_v1.md         — immutable after creation
    │   ├── {ProjectName}_DecisionContext_v1.md    — decision rationale + alternatives
    │   └── {ProjectName}_OpenFlags_v1.md          — unresolved items
    ├── handoffs/
    │   ├── {ProjectName}_BulletHandoff_v1_Interview.md
    │   ├── {ProjectName}_goal_v1.md               — /goal artifact for executor harness
    │   └── {ProjectName}_BuildSequence_v1.md      — LLM-narrated build order (§EX1)
    ├── worksheets/
    │   └── {ProjectName}_SetupWorksheet_v1.md
    ├── ingested/
    │   ├── reference_context.md                   — extracted facts from reference docs
    │   └── {ProjectName}_V2Seeds.md               — deferred capabilities list (written at L3)
    └── audit/
        └── {ProjectName}_AuditLog.md              — append-only
```

Version N artifacts use `_vN` suffix (e.g., `_LockedSpec_v2.md`). Same project folder, different version suffix — no new folder created per version.

**The filesystem IS the database.** The app reads and writes files directly. The SQLite drift index (`ForgeDatabase`) is a cache for the project browser — it stores project path, name, mode, and phase. If deleted, it rebuilds from the filesystem.

---

## LLM Layer

All LLM calls flow through `LlmService.complete(role:)`. The service resolves the role to the user's configured provider + model, then delegates to the provider implementation.

```dart
// Roles
enum LlmRole { architect, executor }

// Abstract provider interface
abstract class LlmProvider {
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required String modelId,
    int? maxTokens,
  });
}
```

| Provider | Class | API |
|---|---|---|
| Gemini | `GeminiProvider` | Google Generative Language REST |
| Claude | `ClaudeProvider` | Anthropic Messages REST |
| OpenAI | `OpenAiProvider` | OpenAI Chat Completions REST |
| Ollama | `OllamaProvider` | Local HTTP (`/api/chat`) |

All implementations use `package:http` directly — no SDK dependencies. API keys live in `forge_config.json` (Application Support). Model IDs are validated on load; retired IDs fall back to first valid model for that provider.

---

## Interview Engine

The core product loop. Runs in two modes:

### Build Mode — 4-Layer Deductive Funnel (L1 → L4)

State advances only when the LLM emits a valid `forge-state` JSON block confirming the current layer is complete. Turn-counter advancement was removed in §IF1 (2026-06-11).

| Layer | What it establishes | Exit condition |
|---|---|---|
| **L1 Outcome** | The one thing this app does + who the user is | LLM restates as "For [user], this app [outcome]" and user confirms |
| **L2 Decomposition** | 3-5 capabilities required to deliver L1 | Confirmed list, each traceable to L1 |
| **L3 PoC Reduction** | ONE capability as proof + 3-5 step demo script | Capability chosen, demo confirmed, v2 seeds read back and confirmed |
| **L4 Critical Path** | Platform, identity, input, output, services (deduced from demo) | All defaults confirmed/overridden, blocker scan done |

The 8 original confidence dimensions survive as **spec invariants** — they must all be present in the locked spec. The funnel determines how each is resolved (L1 resolves core purpose + primary user; L4 resolves platform + identity + input + output + external services; L3 auto-resolves scope boundary via default-closed deferral).

**forge-state JSON contract:** Every LLM turn ends with a fenced block that Flutter strips before display and parses to update state:
```
```forge-state
{
  "layer": "L1" | "L2" | "L3" | "L4",
  "extracted": {
    "outcome": null | "string",
    "primaryUser": null | "string",
    "capabilities": [],
    "chosenCapability": null | "string",
    "demoScript": [],
    "v2Seeds": [],
    "platform": null | "string",
    "identityModel": null | "string",
    "inputModel": null | "string",
    "outputModel": null | "string",
    "externalServices": []
  },
  "layerComplete": false,
  "conflicts": []
}
```
```

**Key invariants:**
- Flutter is authoritative for layer advancement — never trust LLM alone
- All list fields use `is List<dynamic>` check before cast (hard `as List<T>` throws on non-list LLM output)
- `specGenEnabled = (allResolved || l4GateMet) && conflicts.isEmpty`
- `_restoreState` always re-derives `specGenEnabled` from data; never trusts saved boolean
- Layer boundaries (`layerBoundaries: Map<String,int>`) track which turn each layer started — used for layer rewind

### Audit Mode — 8 Flat Dimensions

Unchanged from original design. 8 dimensions (project goal, build state, feature ownership, active blockers, blocker blast radius, decision debt, technical debt, AI/token usage). No layer structure. Produces a Current State Spec.

---

## Spec Generation Pipeline

`SpecNotifier.generate()` runs sequentially after the interview completes:

1. Build spec prompt from `InterviewState` + ingested context
2. LLM call (architect role, t=0.6)
3. `SpecParser.clean()` — strip code fences, trim
4. `writeLockedSpec()` — write-once (checks file existence)
5. `buildGoalText()` → write `/goal` artifact
6. `buildHandoffPackage()` → write JSON handoff
7. `buildBulletHandoff()` → write interview→spec bullet handoff
8. `writeForgeFiles()` — DecisionContext + OpenFlags extracted to `forge/` subfolder
9. Update README.md phase
10. Append to audit log
11. Update DB phase

Then the spec generation screen shows "Generate Setup Worksheet →":

12. `WorksheetNotifier.generate()` — reads locked spec from disk, LLM call (t=0.3), writes worksheet, flips README + audit log

Optional (phase-gated on `v1_worksheet_complete`):

13. `ExecutorTimelineNotifier.generate()` — reads component map from spec, LLM call (t=0.3), writes build sequence narrative to `handoffs/`

---

## Watch Mode Architecture

Four layers. Each layer is a separate set of files. `WatchDataNotifier` is the single orchestrating provider the dashboard screens read — they never import §W1/§W2/§W3 providers directly.

| Section | What it does | Files |
|---|---|---|
| **§W1 Token Ingestion** | Fetch per-engineer spend from Anthropic/OpenAI APIs | `usage_service.dart`, `providers/anthropic_usage_provider.dart`, `providers/openai_usage_provider.dart`, `demo_usage_provider.dart` |
| **§W2 Git Activity + CI Correlation** | GitHub GraphQL (commits/PRs) + Actions REST (CI outcomes) + timestamp-based correlation | `git_activity_service.dart`, `providers/github_git_provider.dart`, `providers/github_ci_provider.dart`, `ci_correlator.dart` |
| **§W3 Signal + Alert Engine** | Pure computation — derives 6 signal types, deduplicates into alert log | `failure_signal_engine.dart`, `alert_engine.dart`, `alert_log_notifier.dart`, `project_status_aggregator.dart`, `watch_signal_service.dart` |
| **§W4 Dashboard UI** | 5 screens — engineer cards, spend chart, workspace health, alert log | `watch_data_notifier.dart`, `watch_dashboard_screen.dart`, `engineer_detail_screen.dart`, `workspace_health_screen.dart`, `alert_log_screen.dart` |
| **§W5** | SwarmSpace Briefing + Decision Simulation | 🔲 Not yet started |

**Config stored in `forge_config.json`:**
- `watch_engineer_roster` — list of engineers with handle, provider type, alert threshold
- `watch_github_config` — org, token, repos, engineer→GitHub handle mapping
- `watch_alert_log` — persisted alert entries

---

## Feature Interview Mode (V2+)

Once V1 is complete, a "Start V2 Interview →" button appears. The feature interview uses the exact same 4-layer funnel but pre-loads context:

- `InterviewArgs.priorSpecVersion != null` is the trigger (no new mode enum)
- `readFeatureContext()` reads the prior locked spec + V2 seeds before interview starts
- `_featureInterviewSystemPrompt` injects the prior spec and seeds into the same funnel prompt
- `nextSpecVersion()` computes "v2" from "v1", "v3" from "v2", etc.
- Each version produces its own artifacts with the correct version suffix in the same project folder

---

## Key Invariants

- **No Firebase.** `grep -ri firebase lib/` must return zero matches.
- **No hardcoded API keys.** All secrets via `forge_config.json` / SharedPreferences.
- **`dart analyze lib/` must be clean.** Zero new warnings or errors.
- **Locked specs are write-once.** `writeLockedSpec()` checks file existence; overwrites only on explicit version bump.
- **Interview state persists to disk** on every LLM response (after §5 interview persistence work, 2026-06-18). App close during interview = seamless resume.
- **All LLM list fields use safe `is List` check** before cast. Hard `as List<T>?` throws TypeError on non-list output and silently degrades the entire parse via outer try/catch.
- **Model IDs validated on load** against the current catalog. Retired IDs fall back to the first valid model.

---

_The Forge · Orbital AI — Architecture v2.0.0 · June 2026_
