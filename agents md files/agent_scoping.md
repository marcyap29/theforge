# Agent Scoping — The Forge

See Starter Repo `agents md files/agent_scoping.md` for the full framework, agent registry, and ranking system.

The Forge-specific agent registry will be populated here as external agents are evaluated and used.

---

## Agent Registry

| Agent | Model | Rank | Strengths | Weaknesses | Last used |
|---|---|---|---|---|---|
| DeepSeek v4 Pro | deepseek-v4-pro | **1 — Executor** | Linter separation, scope discipline, invariant accuracy | Needs invariants spelled out in prompt; leaves dead deps | 2026-05-31 |
| GLM-5.2 | glm-5.2 | **1 — Executor** | Ran full STEP 6 close-out unprompted; thorough coding lesson; proactive self-correction; inferred API constraints from behaviour | Design-level gaps when spec is ambiguous (alert flag ownership, redundant constructor fields) | 2026-06-17 |

---

### DeepSeek v4 Pro (via DeepSeek API / interface)

**Rank: 1 — Executor**

| Assignment | Test Type | Scores (Spec / Integration / Self-correct / Scope / Prompt-dep) | Overall | Notes |
|---|---|---|---|---|
| §1 Flutter Bootstrap + Local Data Layer — pubspec, ForgeDatabase, ProjectFileRepository, tracking doc updates | T2 | 5 / 4 / 5 / 5 / 4 | **4.6 → Rank 1** | Proactively removed flutter_lints + cupertino_icons not in spec. Correctly separated pre-codegen drift errors. Async/sync mix in writeLockedSpec (functional). writeHandoffPackage writes to project root not handoffs/ (spec didn't specify). |
| §2 Riverpod Project State Layer — ProjectListNotifier, ActiveProjectNotifier, 4 providers | T2 | 5 / 4 / 3 / 5 / 4 | **4.2 → Rank 1** | 4 rewrites on standard Riverpod setup (riverpod_annotation, constructor injection type error, circular import, .readOnly doesn't exist). All caught without overseer. open() takes repo as param — works but awkward for callers. split('/').last vs p.basename inconsistency. |

**Calibrated rank:** Rank 1 for scoped data-layer and service implementation tasks with invariants provided inline.

**Observed strengths:**
- Linter discipline: correctly scoped `dart analyze` to non-drift files to separate expected codegen errors from real bugs
- Scope discipline: touched exactly required files, deleted auto-generated README correctly
- Invariant accuracy: write-once spec (existsSync + atomic temp→rename) and append-only audit log (FileMode.append) both implemented correctly
- Proactive self-correction: caught analysis_options/flutter_lints conflict and fixed before reporting

**Observed weaknesses:**
- Invariants must be spelled out inline in the prompt — deduces them correctly when given, but likely to miss undocumented invariants
- Minor async/sync inconsistency in file write patterns (functional, not a bug)

**Assignment rules for DeepSeek v4 Pro:**
- Use Rank 1 template for: data layer, service implementation, single-subsystem Flutter tasks
- Always include: key invariants inline (write patterns, atomic operations, error cases)
- Always include: verification checklist — runs it reliably
- Do not assign without: explicit file paths and method signatures for any contracts it must honour

---

### GLM-5.2 (via GLM API)

**Rank: 1 — Executor**

| Assignment | Test Type | Scores (Spec / Integration / Self-correct / Scope / Prompt-dep) | Overall | Notes |
|---|---|---|---|---|
| §W1 Token Ingestion Engine — UsageProvider abstract + 4 providers + demo profiles + engineer roster | T2 | 5 / 4 / 5 / 5 / 4 | **4.6 → Rank 1** | Ran full STEP 6 close-out (tracking docs + coding lesson) unprompted. Caught and fixed import path bug after first linter run. Inferred OpenAI per-day loop from API behaviour. Two reviewer fixes: constructor `apiKey` shadowed by method param (redundant stored field); alert flag evaluation was in DemoUsageProvider instead of UsageService (wrong layer — should use entry.alertThreshold). |
| §W2 Git Activity Engine + CI Outcome Correlator — GitHub GraphQL + Actions REST + SHA-based correlation | T2 | 5 / 4 / 5 / 5 / 4 | **4.6 → Rank 1** | Full STEP 6 close-out again unprompted (2nd consecutive). Caught 4 bugs: import path (same cross-directory pattern as §W1), `firstWhere(null as dynamic)` type lie → `firstOrNull`, unused `myShaSet`, `const` vs `final` for string literals. One reviewer fix: `authorLogin` stored git email (`head_commit.author.email`) instead of GitHub username (`actor.login`) — doesn't break SHA-based join but semantically wrong. Correctly inferred `firstOrNull` as the Dart 3 pattern without it being in the spec. |
| §W3 Failure Signal Engine + Alert Engine + Workspace Status — pure computation layer | T2 | 5 / 5 / 5 / 5 / 5 | **5.0 → Rank 1** | First perfect score. Zero reviewer fixes. Caught `DailyUsage.tokenSpend` field access error (should be `DailyCorrelation`) immediately after first linter run. Preemptively avoided `firstWhere(null as dynamic)` anti-pattern (used map lookup instead). All 6 signal rules correct: severity escalation (critical OR warning, not both), longest-run loop detection, one runaway signal per engineer (worst day), workspace-level stalled uses `'workspace'` literal + `stalledDays=999` sentinel. Full STEP 6 close-out (3rd consecutive). Pure-computation insight: made provider non-nullable because no config deps. |

**Calibrated rank:** Rank 1 — equivalent to DeepSeek v4 Pro. Slightly stronger on STEP 6 close-out discipline; slightly weaker on design-layer decisions when spec is ambiguous.

**Observed strengths:**
- STEP 6 discipline: ran context, planner, backlog, CONFIGURATION_MANAGEMENT, and coding lesson updates without being prompted — no other agent has done this
- Self-correction: caught import path bug (`../usage_provider.dart` → `usage_provider.dart`) immediately after first `dart analyze` run; also deleted an unnecessary `copyWith` extension unprompted
- API inference: correctly deduced that OpenAI's `/v1/usage` takes a single `date` and built a `Future.wait` loop — this was not in the spec
- Coding lesson quality: 9-step format lesson was thorough and genuinely useful

**Observed weaknesses:**
- Design ambiguity: when the spec is unclear about which layer owns a responsibility (alert flag evaluation), picks the closer/more obvious layer (provider) rather than the architecturally correct one (service)
- Constructor field shadowing: didn't notice that storing `apiKey` in the constructor is dead when the interface also passes it as a method param

**Assignment rules for GLM-5.2:**
- Use Rank 1 template for: service layer, data ingestion, multi-file Flutter tasks requiring STEP 6 close-out
- Always include: explicit ownership rules when a responsibility could live in multiple layers (e.g. "flag evaluation belongs in UsageService, not providers")
- Always include: verification checklist — runs it reliably
- Do not assign without: explicit interface contracts and which layer owns each business rule
