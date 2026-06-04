# The Forge — Platform SuperSpec v1

**Orbital AI · June 2026 · Confidential**
**Status:** Working spec — pre-build
**Supersedes:** Vigilint_LockedSpec_v1.md · The Forge positioning briefs v1–v4
**Amendment policy:** Changes produce a new versioned spec. Nothing is overwritten.

---

## Naming Decision

This document merges The Forge and Vigilint into a single platform. The Forge is the stronger brand — it implies transformation and permanence. Vigilint becomes the Watch module. The merged platform is **The Forge**. Vigilint-the-product name is retired; Vigilint-the-functionality lives on as Watch mode.

If customer feedback from the Qualcomm pilot or subsequent outreach produces a compelling reason to revisit, do so then. Until that data exists, The Forge is the name.

---

## What The Forge Is Now

A platform with three operating modes and a modular activation system. Every mode produces or consumes the same artifact: the locked spec. The spec is the universal language that connects everything.

> The Forge defines what gets built, monitors whether it is being built correctly, and can reverse-engineer a spec from code that already exists. One platform. Three modes. One artifact format.

---

## The Three Modes

### Plan Mode (formerly The Forge)

**Trigger:** You are about to start building something and want a locked spec before the first line of code is written.

Interview engine runs until 100% confidence. Produces: locked spec, /goal artifact, setup worksheet, bullet handoff, handoff JSON. The locked spec becomes the reference document for Watch mode. The /goal artifact drops directly into Claude Code or Codex to start the executor loop.

### Watch Mode (formerly Vigilint)

**Trigger:** Your team is actively building with AI agents and you need management-layer visibility and drift detection.

Ingests token spend from the Anthropic API, git activity from GitHub, and CI outcomes from GitHub Actions. Correlates token sessions to failed runs, surfacing loop detection and bug introduction signals in real time. Evaluates activity against the locked spec if one exists, flagging out-of-scope commits and component boundary violations. Generates weekly briefings and runs Monte Carlo decision simulations via SwarmSpace.

### Reverse Mode (new)

**Trigger:** You have an existing codebase with no locked spec and want a formal reference document, or you want to onboard an existing project into Watch mode.

The Forge ingests the codebase. It reads component structure, interface contracts as implemented, infrastructure choices, and dependency patterns. It generates questions only about what cannot be determined from the code — undocumented decisions, ambiguous boundaries, rationale behind architecture choices. The interview fills those gaps. Output is a formal as-built spec in the identical format as a Plan mode spec. Watch mode can immediately use it as a reference document.

---

## Module Map

Each module can be independently activated per workspace. Customers pay for what they use.

| Module | Mode | What it does | Activation |
|---|---|---|---|
| Interview Engine | Plan | Structured goal interview, conflict surfacing, confidence scoring | Plan or Reverse |
| Monte Carlo Variants | Plan | Three parallel variants at t=0.2 / 0.6 / 1.0, simultaneous reveal | Plan |
| Spec Generator | Plan + Reverse | Produces locked spec in standard format | Plan or Reverse |
| /goal Artifact | Plan | Formats locked spec as Claude Code / Codex /goal input | Plan |
| Setup Worksheet | Plan | Human-action checklist for all external services | Plan |
| Codebase Ingestion | Reverse | Reads repo, extracts structure, generates targeted questions | Reverse |
| Token Ingestion Engine | Watch | Per-engineer token spend from Anthropic API, hourly polling | Watch |
| Git Activity Engine | Watch | Commits, PRs, agent attribution from GitHub GraphQL | Watch |
| CI Outcome Correlator | Watch | Links token sessions to GitHub Actions run outcomes (pass/fail) | Watch |
| Failure Signal Engine | Watch | Token-to-bug correlation, loop detection, churn ratio | Watch |
| Spec Compliance Monitor | Watch | Evaluates commits against locked spec component map | Watch (requires spec) |
| Drift Detector | Watch | Flags out-of-scope commits, component boundary violations | Watch (requires spec) |
| Alert Engine | Watch | Spend thresholds, runaway sessions, stalled projects | Watch |
| SwarmSpace Briefing | Watch | Weekly plain-language intelligence synthesis | Watch |
| Decision Simulation | Watch | 50-iteration Monte Carlo, confidence score, regret risk | Watch |
| Pre-Mortem Engine | Plan | Anticipates failure points in the locked spec before build starts | Plan (optional) |
| Amendment Interview | Plan | Structured re-interview on a proposed change, produces new versioned spec | Plan |

---

## The Locked Spec as Universal Language

Every mode reads and writes the same artifact format. This is the integration point between modes — not an API, not a database, a document.

```
Plan mode    → produces locked spec
Reverse mode → produces locked spec (as-built variant)
Watch mode   → ingests locked spec as reference document
/goal output → derived view of locked spec, formatted for harness
Amendment    → produces new versioned locked spec
```

A customer who starts in Watch mode with no spec can run Reverse mode to generate one. A customer who starts in Plan mode automatically has a reference document for Watch mode. A customer who only uses one mode gets full value from that mode — the spec is optional for Watch, powerful when present.

### Locked Spec Format (v1.1 — updated from ForkIt v1.1)

All specs include these sections in order:

1. Immutable Goal Statement (problem + solution)
2. Hard Constraints Table
3. Component Map (single responsibility per component)
4. Interface Contracts (input/output per component boundary)
5. **Completion Criteria** _(new — required for /goal compatibility)_
6. Static Content Specs (if applicable)
7. Explicit Out-of-Scope List
8. Accepted Decisions (RFC format: chosen / alternatives considered / drawbacks accepted / confidence)
9. Open Flags
10. v2 Architecture Notes
11. Handoff Package (JSON)
12. **/goal Artifact** _(new — derived from sections 1–5, formatted for harness)_

The Completion Criteria section is what separates a spec from a /goal. Without it, the executor can build everything correctly and still not know it is done.

```
## Completion Criteria

| Criterion | Component | How to verify |
|---|---|---|
| [what must be true] | [which component] | [how agent checks it autonomously] |
```

---

## Component Map (Merged Platform)

### Plan Mode Components

**1. Interview Engine**
Owns: Structured interview session, confidence scoring across 8 dimensions, conflict detection and surfacing, scope pushback, conservative default recommendations, external service identification for setup worksheet.
Does not own: Spec writing, variant generation, UI rendering.

**2. Monte Carlo Engine**
Owns: Three parallel LLM calls at t=0.2 / t=0.6 / t=1.0 via Promise.all, simultaneous reveal to prevent anchoring bias, rejected variant retention in audit trail.
Does not own: Interview logic, spec writing, UI.

**3. Spec Generator**
Owns: Locked spec production in standard format, /goal artifact derivation, RFC-format decision documentation, completion criteria generation, version numbering, immutability enforcement.
Does not own: Interview logic, variant selection, monitoring.

**4. Pre-Mortem Engine**
Owns: Failure probability analysis on the locked spec, top-3 risk components ranked by failure likelihood, pre-build risk brief.
Does not own: Interview logic, spec writing, monitoring.

**5. Amendment Engine**
Owns: Focused re-interview on a proposed change, impact analysis against existing spec, new versioned spec production, audit trail entry.
Does not own: Original spec contents, monitoring, execution.

### Watch Mode Components

**6. Token Ingestion Engine**
Owns: Anthropic API polling (per-engineer key), per-key usage normalization, daily and 30-day aggregation, cost calculation at current model pricing, session-level granularity.
Does not own: Git data, display, alerting, CI data.

**7. Git Activity Engine**
Owns: GitHub GraphQL calls, commit attribution per engineer, PR lifecycle tracking, agent-vs-human attribution heuristics (commit message signature scanning), repository roster.
Does not own: Token data, CI data, display, alerting.

**8. CI Outcome Correlator**
Owns: GitHub Actions run outcome ingestion (pass/fail/timeout), timestamp-based correlation to token sessions within a configurable window, correlation confidence scoring.
Does not own: Token data collection, git data collection, failure signal analysis.

**9. Failure Signal Engine**
Owns: Token-to-failed-run ratio per engineer, loop detection (high-token sessions on same files without commit), code churn correlation (commits substantially reverted within N pushes), bug introduction rate from issue-to-commit attribution.
Does not own: Raw data ingestion, display, alerting.

**10. Project Status Aggregator**
Owns: Per-repo health summary combining token, git, and CI signals, stall detection, velocity trending.
Does not own: Raw data sources, spec compliance.

**11. Spec Compliance Monitor**
Owns: Commit-to-component-map evaluation, out-of-scope file detection, component boundary violation detection, drift score per repository.
Does not own: Raw git data, alerting, display. Requires locked spec to activate.

**12. Alert Engine**
Owns: Spend threshold evaluation (per-engineer and workspace), runaway session detection (token velocity), stalled project detection, spec drift alerts, alert log.
Does not own: Data ingestion, notification delivery (v2).

**13. SwarmSpace Intelligence Layer**
Owns: Data package assembly for SwarmSpace, weekly briefing generation, decision simulation orchestration (50 iterations, confidence score, regret risk, time-horizon projections).
Does not own: Raw data ingestion, alert logic, workspace config.
Infrastructure: SwarmSpace MCP on Cloudflare Workers. No additional infrastructure required.

**14. Decision Simulation Engine**
Owns: Decision framing interface, context and data package assembly, SwarmSpace simulation call, results rendering (recommended path, confidence, regret risk, trajectories, key insights, watch-fors).
Does not own: Raw data ingestion, briefing generation.

### Reverse Mode Components

**15. Codebase Ingestion Engine**
Owns: Repository read, component structure extraction, interface contract inference from implementation, infrastructure pattern detection, dependency mapping, gap identification (what cannot be determined from code alone).
Does not own: Interview logic, spec writing, question generation.

**16. Reverse Interview Engine**
Owns: Targeted question generation from ingestion gaps, as-built spec production in standard format, decision rationale capture for what code shows but doesn't explain.
Does not own: Codebase reading, monitoring, forward interview logic.

### Shared Infrastructure

**17. Workspace Config**
Owns: API key storage (encrypted), team roster, alert thresholds, module activation state per workspace, project folder path, spec version registry.

**18. Project Folder Manager**
Owns: Local filesystem structure creation and maintenance, spec versioning, handoff filing, audit log appending, README.md state tracking.

**19. Dashboard UI Shell**
Owns: Screen routing, view rendering for all Watch mode surfaces. No business logic.

---

## Module Activation Configurations

### Configuration A — Plan Only

For teams starting a new build who want a locked spec and /goal before touching code.

Active: Interview Engine, Monte Carlo Engine, Spec Generator, /goal Artifact, Setup Worksheet, Pre-Mortem Engine.
Optional add: Amendment Engine (activate when requirements change mid-build).

### Configuration B — Watch Only

For teams already building who want management-layer visibility without spec compliance.

Active: Token Ingestion Engine, Git Activity Engine, CI Outcome Correlator, Failure Signal Engine, Project Status Aggregator, Alert Engine, SwarmSpace Briefing, Decision Simulation Engine.
Spec Compliance Monitor and Drift Detector: inactive (no spec to compare against — run Reverse mode to generate one).

### Configuration C — Watch + Reverse (Qualcomm entry point)

For teams with existing codebases who want both visibility and spec compliance.

Phase 1: Run Reverse mode on existing repos to generate as-built specs.
Phase 2: Activate Watch mode with spec compliance against the as-built specs.
Result: Full drift detection without requiring any prior Forge usage.

Active: All Watch modules + Codebase Ingestion Engine + Reverse Interview Engine.

### Configuration D — Full Platform

All modules active. Plan mode for new builds. Watch mode running continuously. Reverse mode available for legacy repos or when a new repo is added to the workspace.

This is the configuration that creates the flywheel: Plan specs become Watch benchmarks. Watch outcomes inform Amendment interviews. Reverse specs bring legacy repos into compliance. Every build cycle tightens.

---

## CI Failure Correlation — Technical Design

This is a new capability not in either prior spec. It is v1-eligible.

**What it does:** Correlates token sessions to CI run outcomes to surface whether spend is producing working code.

**Data sources required:** Anthropic API (token sessions with timestamps) + GitHub Actions API (workflow run outcomes with timestamps + triggering commit SHA).

**Correlation logic:**

1. For each failed CI run, identify the triggering commit and its author.
2. Look back N hours (configurable, default 4h) for token sessions under that engineer's API key.
3. Assign a correlation confidence score based on session-to-commit proximity and file overlap.
4. Aggregate into a per-engineer token-to-failure ratio over rolling 7 and 30-day windows.

**Signals produced:**

- Token spend per successful outcome vs. token spend per failed outcome (ratio, per engineer)
- Loop detection: high-token sessions on the same file tree without an intervening commit
- Churn correlation: commits substantially rewritten within 2–3 subsequent pushes, with the original token spend attributed
- Bug introduction rate: GitHub issues tagged as bugs, traced to authoring commit, correlated to originating session

**Why this matters:** The ratio is more useful than raw spend. An engineer burning 3x tokens with a 90% CI pass rate is a high performer. An engineer burning 3x tokens with a 30% CI pass rate is a management decision. Vigilint's existing spec positioned this as a v2 item. Given the APIs are already in scope and the correlation logic is straightforward, this moves to v1.

---

## Interface Contracts — New Additions

### CI Outcome Correlator

**Ingest CI outcomes**

```
Input:  { org: string, repo: string, token: string, lookbackHours: number }
Output: {
  runId:          string,
  triggeredBy:    string,         // commit SHA
  authorHandle:   string,
  outcome:        'pass' | 'fail' | 'timeout',
  durationSeconds: number,
  triggeredAt:    ISO
}[]
```

**Correlate session to outcome**

```
Input:  {
  engineerName:   string,
  tokenSessions:  { startedAt: ISO, endedAt: ISO, tokensUsed: number }[],
  ciRuns:         CIRun[],
  correlationWindowHours: number
}
Output: {
  engineerName:   string,
  correlatedPairs: {
    sessionStart: ISO,
    ciRunId:      string,
    outcome:      'pass' | 'fail' | 'timeout',
    confidence:   number        // 0–1
  }[],
  tokenToFailRatio:    number,  // rolling 7d
  tokenToFailRatio30d: number   // rolling 30d
}
```

### Spec Compliance Monitor

**Evaluate commit against spec**

```
Input:  {
  commitSHA:     string,
  filesChanged:  string[],
  specManifest: {
    components:  { name: string, ownedPaths: string[] }[],
    outOfScope:  string[]       // explicit out-of-scope items
  }
}
Output: {
  inScope:       bool,
  violations: {
    type:        'out_of_scope' | 'boundary_violation' | 'undeclared_component',
    detail:      string,
    file:        string
  }[],
  driftScore:    number         // 0–100, cumulative per repo
}
```

---

## Explicit Out-of-Scope (Platform v1)

| Item | Note |
|---|---|
| SOP / AGENTS.md compliance engine | v2 — rules engine against custom SOP files |
| Multi-LLM provider support | v2 — Anthropic-first; token normalization layer designed for extension |
| GitLab support | v2 — GitHub GraphQL abstraction layer should be provider-ready |
| Slack / email alert delivery | v2 — in-app alert log sufficient for v1 |
| Mobile view | v2 — management situational awareness requires desktop real estate |
| DORA metrics | v2 — cycle time, deployment frequency deferred |
| Team benchmarking vs. industry norms | v2 — requires SwarmSpace benchmark synthesis at scale |
| Historical data export | v2 |
| Per-repo cost attribution | v2 — per-engineer is the v1 unit |
| Automated spec amendment on drift | v2 — drift detection triggers human Amendment interview, not automatic update |
| Public spec registry | v2 — internal specs only in v1 |

---

## Accepted Decisions (Platform Merge)

| Decision | Chosen | Alternatives Considered | Drawbacks Accepted | Confidence |
|---|---|---|---|---|
| Brand | The Forge absorbs Vigilint | Vigilint absorbs The Forge — rejected: weaker brand, implies surveillance not construction. New name — rejected: no customer data to justify yet. | Vigilint name retired; any existing Vigilint recognition is lost (minimal — pre-customer) | Medium (revisit after Qualcomm) |
| Platform architecture | Three modes, modular activation | Two separate products — rejected: creates go-to-market complexity, misses flywheel compounding. One mode with all features always on — rejected: over-scopes every customer | Customers who only need one mode pay for capability they don't use unless priced correctly | High |
| Integration artifact | Locked spec JSON as universal language | API-based integration — rejected: creates tight coupling. Database-based — rejected: over-engineers for current scale | Spec format changes require migration across all modes | High |
| CI correlation | v1 feature (moved from v2) | Keep as v2 — rejected: APIs already in scope, correlation logic is straightforward, dramatically strengthens the token-to-outcome signal | Adds engineering scope to v1 | High |
| Reverse mode | Separate mode, same spec format output | Different spec format for as-built specs — rejected: breaks Watch mode compatibility | As-built specs thinner on alternatives considered and rejected decisions | High |
| /goal artifact | Required output of Plan mode | Optional add-on — rejected: /goal is the activation mechanism for executor agents; making it optional creates a gap in the workflow | Completion Criteria section adds interview time | High |

---

## Open Flags (Platform v1)

| Flag | Module | Options | Recommended default |
|---|---|---|---|
| CI correlation window | CI Outcome Correlator | 2h, 4h, 8h | 4h |
| Spec compliance strictness | Spec Compliance Monitor | Warn only / Block alert / Hard block | Warn only — customer decides escalation |
| Reverse mode interview depth | Reverse Interview Engine | Structural only / Structural + decision rationale | Structural + decision rationale |
| Pre-mortem activation | Pre-Mortem Engine | Always on / Opt-in | Opt-in — some customers don't want the risk list |
| Module activation granularity | Workspace Config | Per-workspace / Per-repo | Per-workspace in v1 |
| Spec format version | Spec Generator | Lock at v1.1 or allow iteration | Lock at v1.1 until v2 interview |
| Pricing unit for Watch-only customers | Workspace Config | Per-workspace / Per-engineer seat | Per-workspace — consistent with Forge tier |

---

## v2 Architecture Notes

- The Forge integration with the block editor (SwarmSpace flow composer) is the first internal dogfood build. Run Plan mode against the block editor spec. Watch mode monitors the build. This is the closed loop in production.
- SOP compliance engine: ingests AGENTS.md or custom SOP markdown files per repo, evaluates agent commit patterns against declared operating procedures. SwarmSpace synthesis layer is the natural processor.
- Automated amendment trigger: when Drift Detector crosses a configurable threshold, surface a prompt to run an Amendment Interview rather than requiring the manager to notice and initiate it.
- Multi-tool aggregation (Cursor, Codex, Windsurf): Token Ingestion Engine's internal data model already uses provider-agnostic cost-in-USD units. Multi-provider expansion does not require schema migration.
- Pattern library: accumulated spec data across projects becomes calibration input for the interview engine. The Forge should know that ephemeral session apps consistently underestimate deep link cold-start complexity. That signal should surface in the interview before the customer discovers it.
- The Qualcomm pilot is the first real-world test of Configuration C (Watch + Reverse). The as-built spec generated from his existing repos is the first Reverse mode output. Document everything. It becomes the reference implementation.

---

## Handoff Package

```json
{
  "specVersion": "1.0",
  "productName": "The Forge",
  "previousProducts": ["Vigilint", "The Forge (pre-merge)"],
  "platform": "Flutter desktop macOS — all three modes (Plan, Watch, Reverse)",
  "lockedAt": "2026-06-03",
  "goalStatement": "A unified platform that defines what gets built, monitors whether it is being built correctly, and reverse-engineers specs from existing codebases. Three modes — Plan, Watch, Reverse — connected by a single locked spec artifact format.",
  "modes": ["Plan", "Watch", "Reverse"],
  "modules": [
    "InterviewEngine",
    "MonteCarloEngine",
    "SpecGenerator",
    "PreMortemEngine",
    "AmendmentEngine",
    "TokenIngestionEngine",
    "GitActivityEngine",
    "CIOutcomeCorrelator",
    "FailureSignalEngine",
    "ProjectStatusAggregator",
    "SpecComplianceMonitor",
    "DriftDetector",
    "AlertEngine",
    "SwarmSpaceIntelligenceLayer",
    "DecisionSimulationEngine",
    "CodebaseIngestionEngine",
    "ReverseInterviewEngine",
    "WorkspaceConfig",
    "ProjectFolderManager",
    "DashboardUIShell"
  ],
  "integrationArtifact": "Locked Spec JSON (v1.1 format)",
  "goalArtifact": "/goal text block (derived from locked spec)",
  "intelligenceLayer": "SwarmSpace via MCP on Cloudflare Workers",
  "firstCustomerConfig": "Configuration C — Watch + Reverse (Qualcomm pilot)",
  "internalDogfoodBuild": "SwarmSpace block editor — first full Plan+Watch loop",
  "platformRiskWindow": "12-18 months before GitHub/Anthropic absorb basic visibility",
  "moatComponents": [
    "CI-to-token failure correlation (cross-API, management layer)",
    "Spec compliance monitoring (requires locked spec — platform-exclusive artifact)",
    "Cross-tool token aggregation (neither platform builds across competitors)",
    "Decision simulation on proprietary engineering telemetry",
    "Pattern library from accumulated spec data (compounds over time)"
  ],
  "openFlags": 7,
  "outOfScopeItems": 11,
  "v2SeedItems": [
    "SOP / AGENTS.md compliance engine",
    "Automated amendment trigger on drift threshold",
    "Multi-LLM token aggregation (Cursor, Codex, Windsurf)",
    "GitLab support",
    "Pattern library — interview calibration from accumulated spec data",
    "Slack / email alert delivery",
    "SwarmSpace block editor (internal dogfood — first Plan+Watch build)",
    "Regulated hardware vertical (Qualcomm, Nvidia, TI) — v2 tier"
  ]
}
```

---

_The Forge · swarmspace.app · Orbital AI_
_SuperSpec v1.0 · June 2026 · Confidential_
_Amendments produce The\_Forge\_\_\_SuperSpec\_v2.md. This document is not modified._
