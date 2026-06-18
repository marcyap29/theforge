# The Forge — Session Log

Newest session first. Each block is prepended.

---

## Session: 2026-06-17 — Claude Code [§W1 Watch Mode: Token Ingestion Engine]

**Branch:** main

### Done
- **§W1 — Watch Mode Token Ingestion Engine — shipped:** 9 new files implementing the abstract `UsageProvider` layer + 4 provider implementations + demo profiles + engineer roster. This is the foundation data source for all Watch Mode signals (§W2–§W6 consume `EngineerUsage` only, never a provider directly).
  - `lib/services/watch/usage_provider.dart` — `UsageProvider` abstract + `EngineerUsage`/`DailyUsage` `@immutable` models
  - `lib/services/watch/providers/anthropic_usage_provider.dart` — HTTP GET `api.anthropic.com/v1/usage` with `start_date`/`end_date` query; blended $9/MTok (`$0.000009/token`); defensive parse catches `FormatException` + `TypeError` → returns empty `EngineerUsage` with `['api_error']` flag (never crashes)
  - `lib/services/watch/providers/openai_usage_provider.dart` — HTTP GET `api.openai.com/v1/usage?date=YYYY-MM-DD` per day in lookback window, `Future.wait` parallel; blended $5/MTok; same defensive parse pattern
  - `lib/services/watch/providers/gemini_usage_provider.dart` — stub returning `['api_unsupported']` (no reliable per-engineer usage API exists as of 2026; keeps code path alive without crashing)
  - `lib/services/watch/providers/ollama_usage_provider.dart` — stub returning `['local_model_unsupported']` (local models have no central usage API; proxy/sidecar out of scope for v1)
  - `lib/services/watch/demo_usage_provider.dart` — 4 synthetic profiles (runaway 9×=$135/day, ghost 0.1×=$1.50/day, highperformer 1.5×=$22.50/day, self 1.0×=$15/day); `Random(42)` fixed seed = deterministic output every run; ±20% variance per day; alert flags: `spend_threshold` when 30d total >$200, `runaway_session` when any day >$100; `sessionCount = dailyBreakdown.length`
  - `lib/services/watch/usage_service.dart` — `UsageService.fetchAllUsage()` iterates roster, resolves each entry to a provider via `switch` on `providerType`, isolates failures to a `fetch_error` `EngineerUsage` (never crashes the whole batch)
  - `lib/features/settings/engineer_roster_notifier.dart` — `EngineerRosterEntry` model (handle/providerType/apiKey/alertThreshold) + `AsyncNotifier` persisting to `forge_config.json` under key `watch_engineer_roster`; mirrors `SettingsNotifier`'s read/write pattern exactly; default `demo` entry auto-present on first launch so app never shows empty state before configuration
  - `lib/services/watch/usage_service_provider.dart` — `Provider<UsageService?>` watching `engineerRosterProvider`; nullable so consumers can gate on loading state
- **Committed:** `feat(§W1): token ingestion engine — UsageProvider layer + 4 providers + demo profiles + engineer roster` (9 files, 516 insertions)

### Key Technical Findings
- **Interface segregation:** `UsageProvider` is the single abstract surface; §W2–§W6 never touch a provider directly — they consume the normalized `EngineerUsage` shape only. Same pattern as `LlmProvider` → `LlmService` in §4. Keeps provider swap-cost at zero.
- **Error isolation over propagation:** `UsageService.fetchAllUsage()` catches per-entry failures and returns an `EngineerUsage` with `alertFlags: ['fetch_error']` rather than throwing. One bad API key doesn't poison the whole batch — the dashboard can still render the other engineers. This is the right default for a telemetry ingestion layer (vs. a request-response layer where you want the error to surface).
- **Defensive parse pattern for LLM-billable APIs:** HTTP usage APIs are inconsistent and under-documented. The Anthropic response shape (`data[].aggregation_key.date` + `input_tokens` + `output_tokens`) is approximate; the OpenAI shape (`data[].aggregation_timestamp` as Unix epoch + `n_context_tokens_total` + `n_generated_tokens_total`) differs. Both providers catch `FormatException` + `TypeError` and fall back to an `api_error` flag rather than crashing — models for these APIs will shift, and the parser must not be brittle.
- **OpenAI `/v1/usage` takes a single `date`, not a range:** Unlike Anthropic's `start_date`/`end_date`, the OpenAI endpoint requires one `date` per call. Implementation loops over each day in the lookback window with `Future.wait` for parallelism. This is a real API constraint, not a design choice.
- **Config-file reuse:** `EngineerRosterNotifier` writes to the same `forge_config.json` as `SettingsNotifier` under a new top-level key (`watch_engineer_roster`). One file, multiple concerns — matches the existing settings storage pattern. No new database table, no SharedPreferences for roster data (secrets stay in the same file as API keys for settings, by the existing convention).
- **Default-entry-on-first-launch pattern:** `build()` returns `[_defaultEntry]` (handle=`demo`, providerType=`demo`, alertThreshold=200.0) when the config key is missing or empty. The app never shows an empty state before configuration — demo data is always available. This is the same "ship with synthetic data" principle as the 4 demo profiles themselves.
- **`Random(42)` determinism is a feature, not a hack:** Same seed → same sequence → same 30-day breakdown every run. Demo dashboards (§W4) will render identical charts across launches, which is what you want for screenshots, demos, and regression tests. Changing the seed would change the output — the seed is part of the contract.

### Next
- §W2 — Watch Mode: Git Activity Engine + CI Outcome Correlator (next on critical path; requires §W1 ✅)
- Manual smoke test: instantiate `UsageService` with the default demo roster, call `fetchAllUsage()`, verify 4 `EngineerUsage` entries return with correct alert flags (runaway should trigger both `spend_threshold` and `runaway_session`; ghost should trigger neither)

### Modified
- `lib/services/watch/usage_provider.dart` — NEW
- `lib/services/watch/providers/anthropic_usage_provider.dart` — NEW
- `lib/services/watch/providers/openai_usage_provider.dart` — NEW
- `lib/services/watch/providers/gemini_usage_provider.dart` — NEW
- `lib/services/watch/providers/ollama_usage_provider.dart` — NEW
- `lib/services/watch/demo_usage_provider.dart` — NEW
- `lib/services/watch/usage_service.dart` — NEW
- `lib/features/settings/engineer_roster_notifier.dart` — NEW
- `lib/services/watch/usage_service_provider.dart` — NEW
- `tracking md files/context.md` — this block
- `tracking md files/planner.md` — §W1 COMPLETE block + §W2 next-up
- `tracking md files/backlog.md` — §W1 ✅ in critical path + status line + Completed section
- `operations md files/CONFIGURATION_MANAGEMENT.md` — inventory + changelog

---

## Session: 2026-06-17 — Claude Code [§FM1 Implementation + UX Iteration + Merge]

**Branch:** main (merged from `wt/feature-mode`)

### Done
- **§FM1 — Feature Interview Mode — COMPLETE:** V2+ interviews implemented and merged. 10 files, 1097 insertions. Full feature working on Forkit (v1_worksheet_complete → Start V2 Interview → V2 funnel with V1 context).
- **Core architecture:** `InterviewArgs.priorSpecVersion` → `InterviewNotifier.build()` loads prior spec + V2 seeds from disk → `_featureInterviewSystemPrompt` (present-first L1, scope enforcement referencing V1 goal, L2 from V2 seeds, incremental L4)
- **Interview screen UX:** `_V1BuiltHeader` (dark green panel, goal + chips); "V2 FUNNEL" label on layer strip; "Generate V2 Spec" button label; `targetSpecVersion` threaded through to `SpecGenerationScreen` → `spec_notifier` → `worksheet_notifier`
- **Version-aware phase strings:** `_stageOf`/`_versionOf`/`_nextVersion` helpers replace all hardcoded `v1_*` checks throughout project_detail_screen; `spec_notifier` writes `${specVersion}_spec_locked`; `worksheet_notifier` writes `${specVersion}_worksheet_complete`
- **Project detail screen UX (iterated):**
  - Removed BUILD INTERVIEW badge (redundant with V2+)
  - V1 SHIPPED integrated INTO `_PhaseTimeline` dot: checkmark stays, "V1 SHIPPED" replaces "Interview" label, chips + "Interview L1-L4" row below timeline row (not inside it — key fix for connector alignment)
  - Collapsed strip for prior versions: V1 ✓ pills appear when V2+ ships; latest version chips always expanded
  - `_allComponents: Map<String, List<String>>` loads component map from each completed version's spec async on initState
  - **BUG fixed mid-session:** Chips inside Interview Column (inside timeline Row) made the column ~350px wide, breaking connector alignment. Fix: moved chips + pills + Interview+L1-L4 to a `Column` below the timeline `Row`.
- **Projects list:** Goal statement between project name and phase row; loaded async from locked spec per project row; omitted when no spec exists
- **Project detail AppBar:** Goal statement as subtitle under project name; loaded async from locked spec; maxLines: 1, truncated
- **`readFeatureContext()`** added to `ProjectFileRepository` — reads prior spec + V2Seeds.md, returns formatted context block for the feature prompt
- **`nextSpecVersion()` public helper** — `v1 → v2`, `v2 → v3` etc; used in interview notifier + interview screen
- **Worktree `wt/feature-mode` merged → main → pushed to origin**

### Key Technical Findings
- Chips and wide widgets must NOT live inside a Column that is itself inside a horizontal timeline Row — they make the column wide, shifting the connector far from the dot. Always render timeline-adjacent detail in a separate Column below the Row.
- `_VersionHistoryLane` (separate panel approach) was wrong UX — integrating version history INTO the timeline step is cleaner than a floating panel above it.
- Goal statement parsing: look for `## \d*\.?\s*(Immutable )?Goal Statement` heading, take first non-empty non-heading line. Component map: look for `## \d*\.?\s*Component\s+(Map|List)`, parse first column of table rows past the separator.
- `ConsumerWidget → ConsumerStatefulWidget` conversion: all widget fields become `widget.field` in state; `ref` is still available; callbacks like `onRename` need `widget.onRename()` not direct call.

### Next
- §W1: Watch Mode Token Ingestion Engine (next on critical path)
- Or: continue testing V2 interview end-to-end (generate V2 spec, verify v2_spec_locked phase, Start V3 button appears)

### Modified
- `lib/data/filesystem/project_file_repository.dart` — `readFeatureContext()`
- `lib/features/interview/providers/interview_providers.dart` — `priorSpecVersion` on `InterviewArgs`
- `lib/features/interview/state/interview_notifier.dart` — feature prompt + helpers + scope guard
- `lib/features/interview/state/interview_state.dart` — `featureContext` field
- `lib/features/interview/ui/interview_screen.dart` — `_V1BuiltHeader`, V2 FUNNEL label, targetSpecVersion
- `lib/features/projects/screens/project_detail_screen.dart` — major rewrite of `_PhaseTimeline` + helpers + AppBar title + projects list goal
- `lib/features/projects/screens/projects_list_screen.dart` — goal text in project rows
- `lib/features/spec_generation/spec_generation_screen.dart` — `targetSpecVersion` param
- `lib/features/spec_generation/spec_notifier.dart` — version-aware phase strings
- `lib/features/spec_generation/worksheet_notifier.dart` — version-aware phase string
- `tracking md files/context.md` — this block

---

## Session: 2026-06-13 — Claude Code [§FM1 Plan + UX Polish + Bug Fixes + Sidebar Fix]

**Branch:** main

### Done
- **§FM1 plan written:** `DOCS/forge/feature_mode_executor_plan_v1.md` — full 9-file executor prompt for DeepSeek V4 Pro. Feature Interview mode lets a completed V1 project run V2, V3, … interviews against the same folder with the prior spec and V2 seeds injected into the system prompt. Worktree `wt/feature-mode` created, ready for implementation.
- **BUG-INTERVIEW-001 (layerComplete gate):** Flutter side is now authoritative for layer advancement. Models copied the hardcoded `false` in the system prompt literally — layerComplete was never true. Fix: advance when Flutter's own gate conditions pass, ignore `parse.layerComplete`.
- **BUG-INTERVIEW-002 (specGenEnabled gate):** `specGenEnabled` was also gated on `parse.layerComplete`. Simplified to `allResolved && newConflicts.isEmpty`.
- **BUG-INTERVIEW-003 (forge-state regex):** Lenient regex now handles trailing whitespace before closing fence — was causing `parseDegraded` every turn.
- **Interview loop fix:** Three root causes — (1) LLM received only the current message, not full history; every turn it saw `extracted={outcome:null}` and re-asked L1. Now all prior turns are prepended. (2) `parseDegraded` froze state instead of falling back to stub + `_layerFromConfidence`. (3) `llmUnavailable` stuck true after one failure; now resets on each successful call.
- **Bugtracker:** BUG-INTERVIEW-001/002/003 records filed; `BUG_PREVENTION.md` updated.
- **UX — generation screens:** `generation_widgets.dart` NEW (`GenerationPhaseBar` with amber-pulse on current step, `ArtifactInfoCard`, `TipRotator` with 5s crossfade, 6–7 tips each); `spec_generation_screen.dart` + `worksheet_generation_screen.dart` both updated with phase bar, artifact cards, rotating tip strip in generating state.
- **Sidebar fix:** `writeHandoffPackage` was writing to project root (invisible). Now writes to `handoffs/`. `ingested/` folder added to sidebar so V2Seeds.md and reference_context.md are visible.

### Key Technical Findings
- Flutter-side authority over LLM-side flags: when a model is given a hardcoded example value (`layerComplete: false`) in a system prompt, it will often reproduce it literally every turn — never setting true. Gate logic for state advancement must live in Flutter, not be delegated to the LLM's JSON output.
- Full conversation history must be passed every turn for stateless LLM calls. Without it, every turn looks like the first turn to the model.
- `parseDegraded` must degrade gracefully — fall back to stub inference + derive state from what's resolvable — never freeze.

### Next
- §FM1 implementation in `wt/feature-mode` — 9 files, DeepSeek V4 Pro

### Modified
- `lib/features/interview/state/interview_notifier.dart` — loop fix (3), gate fix (BUG-001/002/003)
- `lib/features/spec_generation/generation_widgets.dart` — NEW
- `lib/features/spec_generation/spec_generation_screen.dart` — phase bar + artifact cards
- `lib/features/spec_generation/worksheet_generation_screen.dart` — phase bar + cards
- `lib/data/filesystem/project_file_repository.dart` — writeHandoffPackage path fix
- `lib/features/projects/screens/project_detail_screen.dart` — ingested/ sidebar folder
- `bugtracker/bug_tracker.md` — BUG-INTERVIEW-001/002/003
- `bugtracker/records/BUG-INTERVIEW-001-layercomplete-gate.md` — NEW
- `bugtracker/records/BUG-INTERVIEW-002-specgen-layercomplete.md` — NEW
- `bugtracker/records/BUG-INTERVIEW-003-forgestate-regex.md` — NEW
- `bugtracker/BUG_PREVENTION.md` — interview gate + history rules added
- `DOCS/forge/feature_mode_executor_plan_v1.md` — NEW
- `tracking md files/context.md` — this block

---

## Session: 2026-06-12 — DeepSeek/Claude Code [§UI1 Layer Sub-Timeline]

**Branch:** main (merged from `wt/layer-timeline`)

### Done
- **§UI1 — project detail sub-timeline:** Stacked L1–L4 dot row added under the Interview step in `_PhaseTimeline` on `project_detail_screen.dart`. Dots: gray (future), amber-pulse (current), green (done). Connected by a thin vertical line; connector alignment fixed post-merge. Layer state persists across navigation via `currentLayer` in `InterviewState`.
- **§UI1 — interview screen funnel strip:** Compact FUNNEL strip (L1 Outcome → L2 Decomposition → L3 PoC → L4 Critical Path) added above the confidence meter in `interview_screen.dart`. Matching dot style. Build mode only; Audit interviews unchanged.
- **Plan doc:** `DOCS/forge/layer_timeline_executor_plan_v1.md` NEW.

### Key Technical Findings
- The `currentLayer` field on `InterviewState` (added in §IF1) is the single source of truth for which dot is lit. Both the project detail sub-row and the interview screen funnel strip read from the same provider — no separate state needed.
- Connector alignment: the vertical line between dots is a `Container` inside a `Column`; must be wrapped in a sized box to prevent overflow when dot sizes differ.

### Next
- Bug fixes for IF1 gate issues (resolved in same day — see session above)

### Modified
- `lib/features/projects/screens/project_detail_screen.dart` — L1–L4 sub-row in `_PhaseTimeline`
- `lib/features/interview/ui/interview_screen.dart` — FUNNEL strip (163 insertions)
- `DOCS/forge/layer_timeline_executor_plan_v1.md` — NEW
- `tracking md files/context.md` — this block

---

## Session: 2026-06-11/12 — DeepSeek [§IF1 Interview Funnel Redesign — Implementation]

**Branch:** main (merged from `wt/interview-funnel`)

### Done
- **§IF1 implemented:** Converted Build Interview from flat 8-dimension list to 4-layer deductive funnel (L1 Outcome → L2 Decomposition → L3 PoC reduction → L4 Critical Path). The 8 dimensions survive as spec invariants; confidence resolution is now content-driven, not stub-driven.
- **`interview_dimension.dart`** NEW — `LayerDef` data class + `buildLayers` (L1–L4 definitions with exit conditions).
- **`interview_state.dart`** — added `currentLayer` (`LayerDef`), `extracted` (`Map<String, dynamic>` cumulative map), `parseDegraded` (`bool`) fields and `copyWith` updates.
- **`interview_notifier.dart`** — full Build system prompt rewritten to 4-layer funnel with forge-state JSON contract; `parseForgeState` parser added; stub demoted to LLM-unavailable fallback only (scripted conflict deleted); confidence resolution now content-driven from `extracted` map; v2 seed file written to `ingested/` at L3→L4 transition.
- **`spec_generator.dart`** — funnel data block (layers + extracted map) injected into spec prompt; L3 demo script seeds Completion Criteria.
- **`project_file_repository.dart`** — `writeIngestedFile()` added for V2Seeds.md (and future per-doc files).
- **`workflow_template.md`** — Stage 1A fully rewritten to 4-layer funnel + new invariants (one question per turn, forge-state mandatory every response).
- **parseForgeState fixes:** Catches `TypeError` in addition to `FormatException`; lenient regex for trailing whitespace (fixed post-merge).

### Key Technical Findings
- `parseForgeState` must catch `TypeError` not just `FormatException` — Dart's `json.decode` can succeed on malformed LLM output but subsequent map access throws `TypeError` when a field's type doesn't match the expected shape.
- The `forge-state` fenced block regex must be lenient about whitespace before the closing ` ``` ` — models sometimes emit trailing spaces or newlines that a strict pattern won't match, causing every turn to fall through to `parseDegraded`.
- `writeIngestedFile` is a general-purpose write to `ingested/`; it's not limited to V2Seeds — the same method will serve any future per-doc ingestion artifacts.

### Next
- §UI1: Layer sub-timeline to visualize L1–L4 progress (see session above)

### Modified
- `lib/features/interview/state/interview_dimension.dart` — NEW
- `lib/features/interview/state/interview_notifier.dart` — 493-line delta (system prompt rewrite, forge-state parser, content-driven confidence)
- `lib/features/interview/state/interview_state.dart` — `currentLayer`, `extracted`, `parseDegraded` added
- `lib/features/spec_generation/spec_generator.dart` — funnel data block in spec prompt
- `lib/data/filesystem/project_file_repository.dart` — `writeIngestedFile()`
- `DOCS/forge/workflow_template.md` — Stage 1A rewritten
- `tracking md files/context.md` — this block

---

## Session: 2026-06-11 — Cowork [Interview Funnel Redesign Plan]

**Branch:** main (docs only, no code)

### Done
- **DOCS/forge/The_Forge_InterviewFunnel_Plan_v1.md — NEW:** Planning doc for converting the Build Interview from a flat 8-dimension list into a 4-layer deductive funnel (L1 Outcome → L2 Decomposition → L3 PoC reduction via demo script → L4 Critical Path confirmations + blocker scan). The 8 dimensions survive as spec invariants. Includes revised system prompt draft and a structured-output contract (fenced `forge-state` JSON block per turn) to replace stub-driven confidence resolution.
- **Key finding:** `stubInterviewStep` in `interview_notifier.dart` drives the confidence map by user-turn count and injects a scripted conflict at turn 3 regardless of content — the LLM only supplies chat text. Stub confidence updates merge in even when the LLM call succeeds (lines 177–181). Any interview redesign is cosmetic until resolution is content-driven; the plan's §5 specifies the fix.
- **Inconsistency flagged:** workflow_template.md Stage 1A says max 3 questions per turn; `_interviewSystemPrompt` says exactly one. Plan standardizes on one.

### Next
- Marc marks up The_Forge_InterviewFunnel_Plan_v1.md; open questions in §11 (L2 cap, demo length, seed persistence, v2 funnel variant)
- On approval: execute plan §9 file list (interview_dimension/state/notifier, spec_generator, workflow_template Stage 1A rewrite)

### Modified
- `DOCS/forge/The_Forge_InterviewFunnel_Plan_v1.md` — NEW
- `operations md files/CONFIGURATION_MANAGEMENT.md` — inventory row added
- `tracking md files/context.md` — this block

---

## Session: 2026-06-11 — Claude Code [Open Items + §EX1 Executor Timeline]

**Branch:** main

### Done
- **§DOC E2E code verification:** Confirmed both injection paths are correctly wired — `interview_notifier.dart:162` reads `readIngestedSummary()` from disk each turn and injects as REFERENCE CONTEXT block; `spec_notifier.dart:42` does the same before `buildSpecPrompt()`. Manual UI run still needed to fully confirm end-to-end.
- **FOR_MARC_reference-doc-ingestion.md:** 9-step coding lesson written — disk-as-cache pattern, three roads not taken, per-doc facts file architecture, three post-merge bugs (allowMultiple, InkWell/Material, state race), macOS entitlement pitfall, transferable patterns.
- **forge-mcp/ silenced in .gitignore:** forge-mcp has its own git history and origin remote — kept repos independent, removed `??` noise from parent `git status`.
- **§EX1 Executor Timeline — shipped:** `buildExecutorTimelinePrompt()` added to `spec_generator.dart`; `executor_timeline_notifier.dart` created (AutoDisposeFamilyAsyncNotifier by projectPath — scans handoffs/ on build, loads from disk if found); `_BuildSequenceSection` widget added to `ProjectDetailScreen` behind `phase == v1_worksheet_complete` gate; all 4 states (notGenerated/generating/done/error).
- **§EX1 post-review fixes:** Two lint issues from Gemma left unfixed — `super.key` unused parameter on private widget + import not sorted alphabetically. Both fixed; `dart analyze lib/` → zero issues.
- **Bugtracker updated:** BUG-UI-001 (InkWell/Material macOS) and BUG-UI-002 (IngestionNotifier state race) recorded; BUG_PREVENTION.md updated with macOS InkWell rule and multiple-initState-writers rule.

### Key Technical Findings
- `AutoDisposeFamilyAsyncNotifier<State, Arg>` is the correct base class for autoDispose family providers in Riverpod 2.x — `FamilyAsyncNotifier` without the AutoDispose prefix fails the type bounds check at `AsyncNotifierProvider.autoDispose.family<>`.
- Private widgets (`_Foo`) don't need `super.key` — they're never constructed externally with a key. Always omit `super.key` from private widget constructors to avoid the `unused_element_parameter` warning.
- When an external agent adds an import, it tends to append at the bottom rather than insert alphabetically — always check import ordering lint after agent work.

### Next
- Manual end-to-end test: create project → add reference doc → run interview → generate spec → verify context in both prompts; then test BUILD SEQUENCE generation
- §W1 Watch Mode: Token Ingestion Engine (next on critical path)

### Modified
- `.gitignore` — forge-mcp/ excluded
- `DOCS/Coding Lessons/FOR_MARC_reference-doc-ingestion.md` — NEW
- `DOCS/forge/ex1_executor_timeline_plan.md` — NEW (Gemma handoff, now executed)
- `lib/features/spec_generation/spec_generator.dart` — `buildExecutorTimelinePrompt()` added
- `lib/features/spec_generation/executor_timeline_notifier.dart` — NEW
- `lib/features/projects/screens/project_detail_screen.dart` — `_BuildSequenceSection` + import fix
- `bugtracker/bug_tracker.md` — BUG-UI-001, BUG-UI-002 added
- `bugtracker/records/BUG-UI-001-inkwell-material-macos.md` — NEW
- `bugtracker/records/BUG-UI-002-ingestion-state-race.md` — NEW
- `bugtracker/BUG_PREVENTION.md` — macOS InkWell rule + multiple initState writers rule added

---

## Session: 2026-06-10 — Claude Code [§DOC Merge + Post-Merge Bug Fixes]

**Branch:** main (merged from wt/reference-doc-ingestion)

### Done
- **§9.5 committed to main:** All uncommitted §9.5 changes committed before worktree rebase. Key: the entitlements file in the worktree was stale (still had `keychain-access-groups`) — committed HEAD was the correct source of truth.
- **Worktree rebase:** `wt/reference-doc-ingestion` rebased onto committed §9.5. 4 merge conflicts resolved manually: `project_file_repository.dart` (kept both `forge/` + `ingested/`), both `.entitlements` files (kept `user-selected.read-only`, dropped `keychain-access-groups`), `project_detail_screen.dart` (took §9.5 two-panel layout, then separately inserted `_ReferenceDocsRow`).
- **§DOC merged to main:** `wt/reference-doc-ingestion` merged into main with all conflicts resolved.
- **Post-merge fix 1 — Multi-file picker:** `reference_docs_screen.dart`: added `allowMultiple: true` to `pickFiles()` call and changed single-file path to loop over `result.files`.
- **Post-merge fix 2 — Material wrapper for InkWell:** `_ReferenceDocsRow` in `project_detail_screen.dart`: wrapped `InkWell` with `Material(color: Colors.transparent)` — macOS Flutter desktop requires an immediate Material ancestor; Scaffold-level Material is NOT sufficient. "Manage →" button was unresponsive without it.
- **Post-merge fix 3 — Redundant loadDocs removed:** `interview_screen.dart` `initState` was calling `loadDocs()` concurrently with in-flight `addDoc` LLM calls — state race on the global `IngestionNotifier`. Removed initState call entirely; interview screen now watches provider passively via `_DocCountChip`.
- **Build error resolved:** `flutter clean && flutter pub get` required after merge added `file_picker` dependency.

### Key Technical Findings
- Git worktrees must be created from a **committed** HEAD. Uncommitted changes on main do not carry into the worktree — they appear as conflicts at merge time. Commit first, then create or rebase the worktree.
- `InkWell` on macOS Flutter desktop requires `Material(color: Colors.transparent)` in its immediate subtree. A `Scaffold` or `Material` higher in the tree is insufficient — ink effects require a local Material ancestor.
- Global non-AutoDispose `Notifier` concurrent state race: do NOT call state-writing methods (e.g., `loadDocs`) from multiple widget `initState` callbacks simultaneously. Two concurrent async writers on one shared state object produce interleaved updates. Watch the provider passively from secondary screens.
- `file_picker` `NSOpenPanel` is silently blocked by macOS sandbox without `com.apple.security.files.user-selected.read-only` in both `.entitlements` files.

### Next
- End-to-end test: create project → add reference doc → run interview → generate spec → verify context injected in both prompts
- Write `FOR_MARC_reference-doc-ingestion.md` coding lesson
- §EX1: Executor Timeline (parse spec §3 Component Map → LLM-narrated build sequence)

### Modified
- `lib/features/projects/ingestion/reference_docs_screen.dart` — multi-file picker
- `lib/features/projects/screens/project_detail_screen.dart` — Material wrapper for InkWell in `_ReferenceDocsRow`
- `lib/features/interview/ui/interview_screen.dart` — removed redundant `loadDocs` from `initState`

---

## Session: 2026-06-09 — Claude Code [Reference Doc Ingestion Engine — §DOC v1]

**Branch:** wt/reference-doc-ingestion (merged to main 2026-06-10)

### Done
- **§DOC-1 — Entitlements + deps + filesystem layer:** Added `file_picker` 8.3.7 to pubspec.yaml; added `com.apple.security.files.user-selected.read-only` to both entitlement files; `createProject()` now creates `/ingested/` subfolder; 4 new methods in `ProjectFileRepository`: `writeIngestedSummary()`, `readIngestedSummary()`, `listReferenceDocs()`, `copyReferenceDoc()`
- **§DOC-2 — Ingestion engine + notifier:** Created `lib/features/projects/ingestion/` with 3 files: `reference_doc.dart` (ReferenceDoc + IngestedFacts model), `ingestion_engine.dart` (LLM prompt builder + output parser), `ingestion_notifier.dart` (project-scoped `IngestionNotifier` with add/remove/rebuildContext pipeline). Ingestion uses architect role at t=0.2 for precision extraction.
- **§DOC-3 — Interview prompt injection:** `_interviewSystemPrompt()` accepts optional `ingestedContext` param; `InterviewNotifier.addUserMessage()` reads from disk via `readIngestedSummary()` each turn; context injected as "REFERENCE CONTEXT" block in system prompt
- **§DOC-4 — Spec generation prompt injection:** `buildSpecPrompt()` accepts optional `ingestedContext` param; `SpecNotifier.generate()` reads from disk before building prompt (same pattern as `readLockedSpec()`); context injected between confidence map and spec structure instructions
- **§DOC-5 — UI:** Created `reference_docs_screen.dart` (full management UI with file picker, doc cards with remove, error/empty/loading states); added `_ReferenceDocsRow` to `project_detail_screen.dart` (count + "Manage →" link); added `_DocCountChip` to interview_screen.dart AppBar (shows `N docs` when >0)
- All 4 amendments applied: text-only (.md/.txt), project-scoped notifier, disk-persisted context, macOS entitlement

### Key Technical Findings
- `file_picker` 8.3.7 resolves as the latest compatible version with Flutter 3.38.7; 11.x requires newer analyzer
- `NSOpenPanel` on macOS sandbox requires `user-selected.read-only` entitlement — without it the file picker dialog is silently blocked. Added to both .entitlements files.
- Persisting ingested context to `reference_context.md` on disk is the right pattern — both the interview notifier (AutoDisposeNotifier) and spec notifier read from disk independently. Same architecture as `readLockedSpec()`.
- `IngestionNotifier` is a vanilla `Notifier` (not `AsyncNotifier`) — all async work happens in public methods, not in `build()`. Matches `ActiveProjectNotifier` pattern.
- The interview chip shows doc count only when >0 — avoids clutter for projects without reference docs. The project detail row always shows (0 or N) with a "Add →" / "Manage →" link.
- Ingestion engine uses `LlmRole.architect` at t=0.2 for precision extraction of definitions, equations, and constraints. The prompt instructs verbatim quoting — no interpretation or inference.

### Next
1. User review: `git diff main..HEAD` in worktree — approve to merge
2. After merge: end-to-end test — create project, add a .md reference doc, run interview, generate spec, verify context appears in both prompts
3. Write `FOR_MARC_reference-doc-ingestion.md` coding lesson

### Modified (all in worktree)
- `pubspec.yaml` — added `file_picker: ^8.0.0`
- `macos/Runner/DebugProfile.entitlements` — added `user-selected.read-only`
- `macos/Runner/Release.entitlements` — added `user-selected.read-only`
- `lib/data/filesystem/project_file_repository.dart` — `/ingested/` folder + 4 new methods
- `lib/features/projects/ingestion/reference_doc.dart` — NEW: model
- `lib/features/projects/ingestion/ingestion_engine.dart` — NEW: LLM prompt + parser
- `lib/features/projects/ingestion/ingestion_notifier.dart` — NEW: project-scoped notifier
- `lib/features/projects/ingestion/reference_docs_screen.dart` — NEW: management UI
- `lib/features/interview/state/interview_notifier.dart` — disk read + prompt injection
- `lib/features/interview/ui/interview_screen.dart` — doc count chip in AppBar
- `lib/features/spec_generation/spec_generator.dart` — optional ingestedContext param
- `lib/features/spec_generation/spec_notifier.dart` — disk read before spec prompt
- `lib/features/projects/screens/project_detail_screen.dart` — Reference Docs row

### Warnings
- `file_picker` 11.x exists but requires newer analyzer — staying on 8.x for Flutter 3.38.7 compatibility
- Binary formats (PDF, DOCX) are explicitly out of scope for v1 — only .md and .txt supported
- Ingestion costs one LLM call per document added — the result is cached to disk and only re-parsed on explicit rebuild
- The `reference_context.md` file aggregates all extracted facts from all docs — adding/removing a doc triggers a full rebuild of this file

---

## Session: 2026-06-05 — Claude Code [Plan Mode v1 — End-to-End Complete + UX Polish]

### Done
- **forge-mcp post-grade fixes**: removed dead variable `sessionsByAgent` in `queryApi.ts`; fixed `percentComplete` math bug (divided by wrong denominator); removed duplicate `deriveContextFiles` in `index.ts`
- **Compressed `forge_mcp_build_plans.md`**: 1,292 lines → ~100 lines; Plans 1–6 replaced with status table (all ✅ Complete)
- **§9.5 Flutter amendment**: `createProject()` now creates `forge/` subdir; `writeForgeFiles()` writes LockedSpec + DecisionContext + OpenFlags to `forge/`; `writeHandoffPackage()` updated to include `projectName`, `components`, `contextFiles`; `spec_notifier.dart` wired to call all new methods
- **macOS build signing**: removed `keychain-access-groups` entitlement (required provisioning profile); fixed 2 Manual → Automatic signing entries in `project.pbxproj`
- **`flutter_secure_storage` → `SharedPreferences`**: sandbox `-34018 errSecMissingEntitlement` error after entitlement removal; replaced API key storage with SharedPreferences throughout `settings_notifier.dart`
- **Settings Save button fix**: `_controller.addListener(() => setState(() {}))` in `_ByokCardState.initState()` — button was always disabled because text was evaluated at build time without listening
- **Gemini model IDs**: fixed `gemini-3.5-flash-preview` → `gemini-3.5-flash` / `gemini-2.5-flash` / `gemini-2.5-pro`; WebFetch confirmed current stable model IDs
- **Back button on spec error screen**: added "Back to Projects" `TextButton` using `popUntil(r.isFirst)`
- **File sidebar**: `project_detail_screen.dart` rewritten as two-panel layout; `_FilesSidebar` (220px) scans all 5 folders (forge/specs/handoffs/worksheets/audit) with amber selection highlighting; `ArtifactViewMode.forge` added to artifact viewer
- **API key gate on New Project**: `new_project_screen.dart` checks architect role's API key; red banner + "Settings →" link + disabled Create button when no key configured
- **Interactive phase timeline**: 3-step timeline (Interview → Worksheet → Ready) with amber pulse animation on current step; green ✓ with click-to-open artifact when done; pending steps gray; `ProjectDetailScreen` watches `projectListProvider` for live phase; `WorksheetGenerationScreen` now sets `v1_worksheet_complete` phase in DB
- **Sidebar auto-refresh**: `RouteObserver` registered in `app.dart`; `_FilesSidebarState` subscribes via `RouteAware.didPopNext()` — sidebar rescans whenever a sub-route is popped
- **CTA button phase-aware**: "Start Interview" → "Generate Setup Worksheet →" → "Ready for executor" green badge based on project phase
- **`vv1` filename bug**: `writeHandoffPackage` had `v$version` where version already included `v` prefix → fixed to `$version`
- **API key persistence via config file**: `settings_notifier.dart` dual-writes to `forge_config.json` in Application Support dir; file is authoritative on next launch; auto-migrates keys from SharedPreferences if found only there
- **First end-to-end Plan Mode test**: Testapp project — interview → spec → worksheet → all artifacts generated and verified; all 5 folders populated correctly

### Key Technical Findings
- macOS sandbox + `keychain-access-groups` entitlement requires a provisioning profile with `$(AppIdentifierPrefix)` — unusable without paid Apple Developer account in dev. Removed entirely; `flutter_secure_storage` was a casualty, replaced with SharedPreferences + config file.
- `NSUserDefaults` (SharedPreferences on macOS) can be cleared during development container resets. Config file in Application Support is more durable.
- `FutureBuilder(future: _scan())` in a `StatefulWidget.build()` creates a new Future every build — correct, but only fires on rebuild. RouteAware subscription needed for cross-route refresh.
- Interview state is `AutoDisposeNotifier` — disposed when navigated away from. If spec generation fails and user presses back, interview state is lost. Noted as backlog item.

### Next
1. Executor timeline: parse spec § 3 Component Map → generate LLM-narrated timeline steps per component (unique per project, shown when phase = `v1_worksheet_complete`)
2. Watch Mode §W1 — Token Ingestion Engine (gate: end-to-end run ✅ now passed)
3. First MCP end-to-end: register Testapp in `~/.forge/registry.json`, test `forge_session_start` + `forge_check_scope` via MCP
4. Backlog: interview state persistence across navigation (survives spec gen failure)

### Modified
- `forge-mcp/src/index.ts`, `forge-mcp/src/lib/queryApi.ts` — post-grade fixes
- `DOCS/forge/forge_mcp_build_plans.md` — compressed to status table
- `lib/data/filesystem/project_file_repository.dart` — §9.5: forge/ dir, writeForgeFiles(), writeHandoffPackage() with projectName; vv1 fix
- `lib/features/spec_generation/spec_generator.dart` — §9.5: parseComponentNames(), buildContextFiles(), buildDecisionContext(), buildOpenFlags(), buildHandoffPackage() fields
- `lib/features/spec_generation/spec_notifier.dart` — §9.5 wiring; projectListProvider.refresh() call
- `lib/features/spec_generation/worksheet_notifier.dart` — v1_worksheet_complete phase update + projectListProvider.refresh()
- `lib/features/spec_generation/spec_generation_screen.dart` — Back to Projects button on error
- `lib/features/settings/settings_notifier.dart` — SharedPreferences + forge_config.json dual-write; correct Gemini model IDs
- `lib/features/settings/settings_screen.dart` — Save button controller listener fix
- `lib/services/llm/llm_model_config.dart` — correct Gemini model IDs and defaults
- `lib/features/artifacts/artifact_viewer_screen.dart` — ArtifactViewMode.forge added
- `lib/features/projects/screens/project_detail_screen.dart` — full rewrite: two-panel layout, _PhaseTimeline, _FilesSidebar with RouteAware, phase-aware CTA
- `lib/features/projects/screens/new_project_screen.dart` — API key gate
- `lib/core/app.dart` — routeObserver added
- `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements` — keychain-access-groups removed
- `macos/Runner.xcodeproj/project.pbxproj` — Manual → Automatic signing

### Warnings
- Testapp HandoffPackage is named `vv1` (old run before fix). New projects will generate `_v1.json` correctly.
- Interview state lost on spec gen failure + back navigation — user must redo interview. Backlog item.
- `flutter_markdown` 0.7.7+1 is discontinued upstream; non-blocking, migrate to `flutter_markdown_plus` when needed.
- Worksheets/handoffs folders are normal write (not write-once) — can be regenerated.

---

## Session: 2026-06-04 — Claude Code [Forge MCP Server — Gap Analysis + 6 Executor Plans]

### Done
- Full repo review: Plan Mode §1–§9 all complete; backlog and context read
- Read all ForkIt example files (5-file system reference implementation)
- Compared Flutter app current output vs MCP server expected input — identified all gaps
- Wrote 6 DeepSeek executor prompts for the MCP server build
- Saved plans to `DOCS/forge/forge_mcp_build_plans.md`

### Key Gap Analysis Findings
- **File 1 path mismatch**: app writes to `specs/`, MCP expects `forge/` subfolder — plans include fallback
- **Files 2 + 5 missing**: app doesn't generate `DecisionContext` or `OpenFlags` as separate files yet
- **HandoffPackage missing fields**: `components` and `contextFiles` not generated by current app
- **HandoffPackage filename**: app writes `handoff_package_v1.json`, MCP expects `{ProjectName}_HandoffPackage_v1.json` — plans include 3-pattern filename resolution
- Plans adapt the MCP server to be forward-compatible (works with target state) AND include graceful fallbacks for current state

### Next
1. Run Plan 1 in DeepSeek → bring back for evaluation
2. Run Plans 2–6 sequentially, each evaluated before next
3. After MCP server is built → §9.5 Flutter app amendment to generate full 5-file system
4. After §9.5 → first end-to-end Plan Mode run (interview → spec → MCP server → executor build)

### Modified
- `DOCS/forge/forge_mcp_build_plans.md` — NEW: 6 DeepSeek executor prompts + gap analysis

### Warnings
- MCP server goes in `forge-mcp/` subfolder inside The Forge repo
- The ForkIt example files represent TARGET state, not current app output — plans bridge the gap
- DeepSeek must be given full context files from previous plan on each subsequent call (append-on, not greenfield)
- `forge_check_scope` uses exact section headings from File 5 (`## Explicit Out-of-Scope`, `## V2 Architecture Seeds`) — do not rename

---

## Session: 2026-06-04 — DeepSeek V4 Pro [Session 2 — §8 Setup Worksheet + §9 Handoff Package + /goal text]

### Done
- `spec_generator.dart` extended — `buildGoalText()`, `buildHandoffPackage()`, `_extractSection()`, `_countTableRows()`, `_countListItems()`
- `spec_notifier.dart` extended — calls `buildGoalText()` + `buildHandoffPackage()` after `writeLockedSpec()`; `specVersion` added to `SpecGenState`
- `project_file_repository.dart` — added `readLockedSpec()` for reading spec from disk
- `worksheet_generator.dart` created — `buildWorksheetPrompt()`, `buildWorksheetAuditEntry()`
- `worksheet_notifier.dart` created — `WorksheetNotifier`, `WorksheetGenState`, `worksheetNotifierProvider`
- `worksheet_generation_screen.dart` created — full UI with idle/generating/done/error states (mirrors SpecGenerationScreen)
- `spec_generation_screen.dart` — done state updated: "Generate Worksheet →" primary button + "Back to Projects" secondary
- `dart analyze lib/` — zero issues
- `grep -ri firebase lib/` — zero matches

### Next
1. First end-to-end Plan Mode run: Project → Interview → Spec → Worksheet → Artifacts
2. Gate opens for Watch Mode (§W1 Token Ingestion Engine)
3. Then: §W2–§W6 → Reverse Mode → Configuration C pilot (Qualcomm)

### Modified
- `lib/features/spec_generation/spec_generator.dart` — added §9 builders
- `lib/features/spec_generation/spec_notifier.dart` — wired §9 calls + specVersion
- `lib/data/filesystem/project_file_repository.dart` — added readLockedSpec()
- `lib/features/spec_generation/worksheet_generator.dart` — NEW
- `lib/features/spec_generation/worksheet_notifier.dart` — NEW
- `lib/features/spec_generation/worksheet_generation_screen.dart` — NEW
- `lib/features/spec_generation/spec_generation_screen.dart` — worksheet button

### Warnings
- `_countTableRows` filter checks for `---` and `--` (without dashes) — handles both `|---|` and `---|---|---|` patterns
- Worksheet temperature is 0.3 (procedural) vs spec generation 0.6 (creative)
- `readLockedSpec()` throws if file doesn't exist — WorksheetNotifier catches it via try/catch

---

## Session: 2026-06-04 — DeepSeek V4 Pro [Session 1 — §6 SpecParser + §7 Artifact Viewers complete]

### Done
- `spec_parser.dart` created — strips code fences, trims whitespace from LLM output before writing spec
- Wired `SpecParser.clean()` into `spec_notifier.dart` → LLM raw output is cleaned before `writeLockedSpec()`
- `flutter_markdown` added to `pubspec.yaml`; `flutter pub get` completed
- `artifact_viewer_screen.dart` created — single reusable viewer with `ArtifactViewMode` enum (spec/handoff/worksheet/audit)
- `project_detail_screen.dart` updated — all artifact rows now tappable with folder-aware routing to viewer
- `dart analyze lib/` — zero issues
- `grep -ri firebase lib/` — zero matches

### Next
1. §8 — Setup Worksheet Generation (Stage 3): generate a worksheet from the spec's external services list
2. §9 — Handoff Package + Bullet Handoff + /goal text (Stage 4)
3. After §8+§9 → first end-to-end Plan Mode run → gate opens for Watch Mode

### Modified
- `lib/features/spec_generation/spec_parser.dart` — NEW: SpecParser.clean() strips code fences
- `lib/features/spec_generation/spec_notifier.dart` — wired SpecParser.clean() into generate()
- `lib/features/artifacts/artifact_viewer_screen.dart` — NEW: single reusable artifact viewer
- `lib/features/projects/screens/project_detail_screen.dart` — artifact rows now tappable
- `pubspec.yaml` — added flutter_markdown

### Warnings
- Routes used via `MaterialPageRoute` directly (Navigator.push) rather than named routes — matches existing codebase pattern (project_detail_screen uses same approach for /interview)
- All 4 artifact types (spec/handoff/worksheet/audit) share one `ArtifactViewerScreen` — mode is determined by `_ArtifactEntry.folder`

---

## Session: 2026-06-03 — Platform merge: Vigilint absorbed; SuperSpec v1 filed; Watch + Reverse Mode backlog added

### What was done
- **Product merger decision:** Vigilint retired as standalone product name. Its capabilities become Watch Mode within The Forge. Brand rationale in `audit/The_Forge_AuditLog.md` entry 002.
- **SuperSpec filed:** `DOCS/forge/The_Forge_SuperSpec_v1.md` — defines the merged three-mode platform (Plan / Watch / Reverse), 19 modules, 4 activation configurations (A=Plan only, B=Watch only, C=Watch+Reverse, D=Full)
- **Backlog appendation filed:** `DOCS/forge/The_Forge_SuperSpec_Backlog_v1.md` — two backlog items: first-party decision simulation engine (long-term moat), Monte Carlo naming disambiguation
- **Audit log created:** `audit/The_Forge_AuditLog.md` — entry 002 documents merger decision and the open platform flag
- **Backlog updated:** Critical path now shows Plan Mode → Watch Mode (§W1–§W6) → Reverse Mode (§R1–§R2) → Qualcomm pilot gate; all 8 new phase specs added
- **Handoff created:** `DOCS/forge/The_Forge_BulletHandoff_v1_PlatformMerge.md` — ready for DeepSeek Flash (next: §6 Spec Generation)

### What does NOT change
- §1–§5 codebase is unchanged. `dart analyze lib/` passing. The existing Interview Engine, LLM Provider Layer, Settings, and Project screens are Plan Mode and continue as-is.
- Next coding work remains §6 Spec Generation — unchanged from before the merge.

### Open flag — resolve before Watch Mode build
SuperSpec draft said Watch/Reverse = web-based. The Forge = Flutter macOS. Recommended: Flutter desktop for all three modes. **Must be confirmed before §W1 starts.** See audit log entry 002.

### Next
1. Resolve the Flutter-vs-web platform flag (user decision)
2. §6 — Spec Generation + Artifact Writing (Plan Mode critical path continues)
3. §7 — Artifact Viewers
4. After §6+§7+§8+§9 complete → first end-to-end Plan Mode run → gate opens for Watch Mode

### Modified
- `DOCS/forge/The_Forge_SuperSpec_v1.md` — new
- `DOCS/forge/The_Forge_SuperSpec_Backlog_v1.md` — new
- `DOCS/forge/The_Forge_BulletHandoff_v1_PlatformMerge.md` — new
- `audit/The_Forge_AuditLog.md` — new (entry 002)
- `tracking md files/backlog.md` — critical path updated, §W1–§W6 and §R1–§R2 added
- `tracking md files/context.md` — this entry

---

## Session: 2026-06-02 — §5 Extension: Dual Interview Mode UI (Build + Audit) (worktree wt/llm-provider-layer)

### What was done
- **Architectural pivot**: replaced the typed `ConfidenceDimension` enum with a generic `DimensionDef` data class (`id`, `label`, `question`). The central change that unlocks both Build and Audit modes. `Map<ConfidenceDimension, DimensionState>` → `Map<String, DimensionState>`, keyed by `DimensionDef.id`. `InterviewState` now carries `List<DimensionDef> dimensions` so every consumer (meter, notifier, system-prompt builder) looks up labels/questions from the active list.
- Created `lib/features/interview/state/interview_dimension.dart` — `DimensionDef` immutable class + `buildDimensions` (8 Build dims) + `auditDimensions` (8 Audit dims) + `dimensionsFor(ProjectMode)` helper
- Rewrote `lib/features/interview/state/interview_state.dart` — removed `ConfidenceDimension` enum and its label/question extension; `ConflictItem` now uses `String dimensionALabel` / `String dimensionBLabel`; `InterviewState` carries `dimensions` list
- Updated `lib/features/interview/providers/interview_providers.dart` — `InterviewArgs` gains `ProjectMode mode`; `==` and `hashCode` updated
- Rewrote `lib/features/interview/state/interview_notifier.dart` — stub now uses `state.dimensions[N-1]` / `state.dimensions[N-2]` (preserves original conflict-offset behavior so turn 4 re-resolves `dim[2]` from partial back to resolved; uniform `N-1` would have left `dim[2]` stuck partial and `specGenEnabled` permanently false — this was the subtle bug I caught and fixed before merge). `build()` uses `dimensionsFor(args.mode)`. `_interviewSystemPrompt` uses dimension lookups from `state.dimensions` and computes the mode label by `state.dimensions == buildDimensions` (works because both lists are const-equal)
- Updated `lib/features/interview/ui/confidence_meter.dart` — new signature `List<DimensionDef>` + `Map<String, DimensionState>`; iterates `dimensions` (not a hardcoded enum); label width bumped 120→140px to fit longer Audit labels (e.g. "Blocker blast radius", "AI & token usage")
- Updated `lib/features/interview/ui/interview_screen.dart` — `InterviewScreen` now takes `InterviewArgs args` directly (was `projectPath` + `projectName`); AppBar shows "Build Interview — {name}" or "Audit Interview — {name}"; `_EmptyChat` uses the live `state.dimensions.length`; `_ConflictSurface` reads `dimensionALabel` / `dimensionBLabel`
- Created `lib/features/projects/screens/new_project_screen.dart` — `ConsumerStatefulWidget`; name input + two `_ModeCard`s (Build / Audit) with amber border + 0x1A amber background when selected, slate border when unselected; "Create" button disabled until name is non-empty; on tap: `repo.createProject(name, mode)` → `db.upsertProject(ProjectsCompanion.insert(...))` → `projectListProvider.notifier.refresh()` → `Navigator.pop()`. `ProjectAlreadyExistsException` surfaces a red SnackBar "A project named '$name' already exists." General exceptions surface "Failed to create project: $e"
- Created `lib/features/projects/screens/project_detail_screen.dart` — `ConsumerWidget` taking `Project project`; mode badge (amber for Build, slate for Audit) + "Phase: v1_interview" line + parsed README sections ("What's Done", "What's Next", "Open Flags") in a bordered card + "Start Build/Audit Interview" FilledButton (amber, full width) → `Navigator.pushNamed('/interview', arguments: InterviewArgs(...))`; artifacts list scans `specs/`, `handoffs/`, `worksheets/` via `Directory.listSync()` in a `FutureBuilder`; Close button calls `activeProjectProvider.notifier.close()` then pops
- Updated `lib/features/projects/screens/projects_list_screen.dart` — removed inline `_ProjectDetailStub` and `_NewProjectStub`; navigation now uses `MaterialPageRoute` to `NewProjectScreen()` and `ProjectDetailScreen(project: ...)`; empty-state copy updated to mention both interview modes
- Updated `lib/core/app.dart` — `/interview` route now passes full `InterviewArgs` to `InterviewScreen(args: args)` (was unpacking into `projectPath`/`projectName`)
- Verified: `dart analyze lib/` → No issues found
- Verified: `grep -rn "ConfidenceDimension" lib/` → zero matches
- Verified: `grep -rn "_ProjectDetailStub\|_NewProjectStub" lib/` → zero matches
- Verified: zero Firebase imports

### Architectural decisions
- **String-keyed map is the central refactor** — once `Map<String, DimensionState>` keyed by dimension ID, every other change (meter iteration, notifier lookups, system prompt, conflict labels) follows naturally. `InterviewState.dimensions` is the single source of truth for what's in the map.
- **`_stubConflictFor(state)` is mode-agnostic** — it reads `state.dimensions[0].label` and `state.dimensions[2].label`, so Build mode gets `corePurpose ↔ identityModel` and Audit mode gets `projectGoal ↔ currentBuildState` from the same function. Description text is generic ("X implies one direction. Y implies another. I recommend the conservative reading for v1…") but follows the Workflow Template pattern verbatim. The original Build-specific "user-account system adds friction" wording is gone — it didn't generalize to Audit.
- **Stub preserves the conflict-offset pattern**: turn 3 surfaces the conflict and marks `dim[2]` partial; turn 4 re-resolves `dim[2]` (because the user just accepted the conflict via the Accept button) and prompts `dim[3]`. Turns 5..9 continue with `dim[N-2]`. This is the same logic as the original §5 stub — the uniform `dim[N-1]` rule in the prompt's spec was too simplistic and would have broken Generate Spec enablement.
- **`InterviewScreen` takes `InterviewArgs` directly** — not just `projectPath` + `projectName`. Adding `mode` to the args signature made the constructor change necessary. Cleaner than three separate fields that have to stay in sync.
- **No LLM-parsed mode label needed** — `state.dimensions == buildDimensions` does a const-equality check on the dimension list, which is O(n) but n=8, so it's effectively free. Cleaner than threading the mode through to the notifier for a single string comparison.
- **Artifacts list includes worksheets too** — the prompt said "specs/, handoffs/ contents" but the project folder structure also creates `worksheets/`, and listing all three gives a more honest view of "what's been generated." Tappable rows are intentionally non-tappable (no viewer yet — that's §7).
- **`ProjectDetailScreen` is a `ConsumerWidget`, not stateful** — it reads `activeProjectProvider` (which is the existing source of truth for README content, loaded by `_ProjectRow.onTap` before navigation). No need to re-load the README on the detail screen.
- **README parsing is local to the detail screen** — `_ReadmeContent._extractSection(content, header)` does a simple `indexOf` + `indexOf('\n## ', ...)` to slice out H2 sections. No markdown parser dependency added; this is sufficient for the README shape that `ProjectFileRepository.createProject` writes.
- **Two `_ModeCard`s, not a dropdown** — the spec called for "two side-by-side (or stacked) cards" and cards give a more honest preview of the mode (you can read the 4 sample dimensions and decide). Side-by-side on wide screens, stacked on narrow — the layout flows naturally with `ListView`.
- **Drift's `insert()` for nullable columns is `Value.absent()` by default** — `ProjectsCompanion.insert(...)` doesn't need explicit `lastOpened: const Value(null)` etc. (I added them initially, then removed; drift handles it.) The existing `project_list_notifier.dart` confirmed this pattern.

### Out of scope (verified — matches prompt's "What is NOT in scope")
- Doc ingestion UI
- Model configuration (Settings §10) — already done
- Resuming a project mid-interview
- Rendering spec/handoff artifacts in a viewer (§7)
- Audit-specific stub conflict text — generic conflict works for both modes

### Open items / next
- §6 Spec Generation (the Generate Spec button — currently SnackBar)
- §7 Artifact Viewers (the project_detail_screen artifacts list is read-only display only)
- §11 Audit Interview Mode — the dimension lists are wired but the `Current State Spec` structure (different from Locked Spec) is a §6/§11 dependency
- End-to-end test: open app → FAB → name "AuditTest" → Audit card → Create → tap row → Start Audit Interview → meter shows 8 Audit dimensions (Project goal, Active blockers, etc.)

---

## Session: 2026-06-02 — §4 Change: Gemini 3.5 Flash as default (worktree wt/llm-provider-layer)

### What was done
- **Bug fix**: `GeminiProvider` was sending `system_instruction` (snake_case) to the Gemini REST API v1beta. The API silently ignores unknown field names, so the system prompt was being dropped. Changed to `systemInstruction` (camelCase) — the field name the API actually reads. Also added explicit `'role': 'user'` to the `contents` entry.
- **Default flip**: `LlmSettings.defaults` now points both Architect and Executor roles to `LlmProviderType.gemini` with modelId `gemini-3.5-flash-preview`.
- **First-run logic**: `SettingsNotifier.build()` no longer falls back to `LlmProviderType.ollama` when no role assignment is saved. New code distinguishes first-run (`providerStr == null`) and uses Gemini as the fallback provider and `gemini-3.5-flash-preview` as the fallback modelId. The `orElse:` in the `firstWhere` also falls back to Gemini (was Ollama).
- **Model catalog**: Added `gemini-3.5-flash-preview` as the first entry in `geminiModels`. Display name: `Gemini 3.5 Flash`.
- **Settings UI reorder**: Provider cards now go Gemini → Claude → OpenAI → Ollama. Gemini card has `isDefault: true`, which appends ` (default)` to the title.
- **Role card always-shows-all**: `availableProviders` changed from a filtered list (only Ollama + providers with saved keys) to `LlmProviderType.values` (all four). Missing keys surface as runtime errors via `LlmService.complete()` — the user sees `Gemini API key not configured. Open Settings.` in the chat bubble rather than the option being hidden.
- Verified: `dart analyze lib/` → No issues found
- Verified: `grep -n "system_instruction"` → no matches (bug fix confirmed)
- Verified: `LlmSettings.defaults` uses `gemini-3.5-flash-preview` for both roles

### Model ID note
Used `gemini-3.5-flash-preview` as the model ID. **Did not verify against https://aistudio.google.com/** — LUMARA Desktop uses `gemini-3-flash-preview` (no `.5`), and the user specified "3.5 Flash". The `.5-flash-preview` string is a best-guess following Google's preview-versioning pattern. If Google rejects the ID at call time, the error will surface in the chat bubble as `Gemini error 404: ...` and the user can pick a working model from the dropdown.

### Ollama is still supported
Ollama card stays in the UI (just last, not first). `OllamaProvider` is untouched. The user can still pick Ollama from any role's provider dropdown; the connection check still runs on mount and on URL save; models still fetch live from `/api/tags`. The only thing that changed is the default.

### Why this matters
- More reliable default: Ollama needs the user to have a local server running; Gemini just needs one API key.
- Out-of-the-box UX: the user pastes one Gemini key and the app works for all 8 interview dimensions + future spec/worksheet generation.
- Bug fix is invisible until the user actually invokes Gemini — but it would have caused every interview response to lose the system prompt (the interviewer would be un-primed, asking generic questions, missing the dimension-tracking scaffolding in the prompt).

### Next
- End-to-end test: open the app, add a Gemini key, run an interview turn, verify the response uses the system prompt (e.g., mentions the project's 8 confidence dimensions).
- §6 Spec Generation (Generate Spec button action)
- Merge worktree → main

---

## Session: 2026-06-02 — §4 LLM Provider Layer + §10 Settings (worktree wt/llm-provider-layer)

### What was done
- Added deps: `http: ^1.2.2`, `flutter_secure_storage: ^9.2.4`, `shared_preferences: ^2.3.3` (resolved to 1.6.0, 9.2.4, 2.5.5)
- Created `lib/services/llm/` — 8 files (provider abstract, model config, service, service provider, 4 provider implementations)
- Created `lib/features/settings/` — 3 files (notifier, providers, screen)
- Modified `lib/features/interview/state/interview_notifier.dart` — replaced stub with `llmService.complete(role: LlmRole.executor, ...)`; kept stub for confidence-map updates (per §5.1 split); added `_interviewSystemPrompt` helper
- Modified `lib/core/app.dart` — added `/settings` named route; renamed `_MissingRouteArgs` → `_MissingInterviewArgs`
- Modified `lib/features/projects/screens/projects_list_screen.dart` — added settings gear icon to AppBar
- Verified: `dart analyze lib/` → No issues found
- Verified: zero Firebase imports (all 4 LLM providers are direct HTTP)

### Architecture decisions
- Two-layer design: `LlmService` resolves `LlmRole → ModelAssignment → LlmProvider`. The notifier (and future spec generator, worksheet generator) never knows which provider is active.
- API keys in `flutter_secure_storage` (macOS Keychain) ONLY. Base URL, role assignments, model IDs in `SharedPreferences`. No key ever written to a `prefs` key.
- `llmServiceProvider` watches `settingsProvider` (via derived `llmSettingsProvider`) — service rebuilds on every settings change. No manual invalidation needed.
- Interview wire-in: real LLM call drives `interviewerTurn.content`; stub still drives `confidenceMap` updates and `newConflicts` until §5.1 prompt engineering parses LLM output. This is the plan's explicit "stub stays for dimension tracking" carve-out.
- Error path: `try/catch` around `llmService.complete` surfaces a clear "Connection error: ... Open Settings" message in the chat bubble. No crash, no silent failure.
- Ollama always available in provider list (no key required). `OllamaProvider.fetchModels` is a static method — `SettingsNotifier.refreshOllama` calls it on `setOllamaBaseUrl` and on demand from the UI.
- Provider constructors are non-`const` (LlmProvider is an abstract class with no const default constructor, so subclasses can't be const).
- Role card is a `ConsumerWidget` (not stateful) — the provider is the source of truth, dropdown changes apply immediately via `setRoleAssignment`. No "Save" button.

### Out of scope (verified)
- No SwarmSpace provider (§13 billing tier)
- No OpenAI-compatible custom base URL in UI
- No model list validation
- No streaming responses (Ollama `stream: false`)
- No LLM-parsed dimension updates (stub counter stays)

### Critical invariants upheld
- API keys never logged or displayed in full — masked as `••••••{last4}` in hintText
- LlmService rebuilt on settings change (Riverpod watch chain)
- Clear error if no model for role (don't crash)
- Ollama always in provider list
- `dart analyze lib/` zero issues
- No build_runner needed (no drift changes)

### Next
- §6 Spec Generation (the "Generate Spec" button action — currently SnackBar)
- §7 Artifact Viewers
- Merge worktree `wt/llm-provider-layer` → `main` after review
- End-to-end test: Settings → add Ollama (or other) → Interview → real LLM response in chat

---

## Session: 2026-06-01 — §5 Build Interview UI + State

### What was done
- Created `lib/features/interview/state/interview_state.dart` — `ConfidenceDimension` enum (8 values, with `.label` and `.question` extensions), `DimensionState` enum (unknown/partial/resolved), `InterviewTurn`, `ConflictItem`, `InterviewState` model (with `.empty()` factory and `copyWith`)
- Created `lib/features/interview/state/interview_notifier.dart` — `FamilyAsyncNotifier<InterviewState, InterviewArgs>` + `stubInterviewStep()` top-level function (turn-based deterministic stub: 9 user messages cycle through the 8 dimensions, surface a `corePurpose ↔ identityModel` conflict on turn 3). Single call site flagged with `// §5 LLM STUB:` comment for §4 swap.
- Created `lib/features/interview/providers/interview_providers.dart` — `InterviewArgs` class (with `==`/`hashCode` for family equality) + `interviewProvider` (`AsyncNotifierProvider.family<InterviewNotifier, InterviewState, InterviewArgs>`)
- Created `lib/features/interview/ui/confidence_meter.dart` — `ConfidenceMeter` widget with 8 horizontal `LinearProgressIndicator` bars; bar fill = 0% unknown / 50% partial / 100% resolved; track color `#1F2937`, state colors gray/amber/green
- Created `lib/features/interview/ui/interview_screen.dart` — `ConsumerStatefulWidget` watching `interviewProvider(args)`; layout: `AppBar` (with restart icon) → `ConfidenceMeter` → optional `_ConflictSurface` (only when `openConflicts.isNotEmpty`) → `Expanded` chat history (`_TurnBubble` per turn) → `_Composer` (text input + send button, disabled while `isLoading`) → `FilledButton.icon` "Generate Spec" (only when `specGenEnabled`, click shows §6 SnackBar)
- Updated `lib/core/app.dart` — added `'/interview'` named route; route builder reads `ModalRoute.settings.arguments`, casts to `InterviewArgs`, falls back to `_MissingRouteArgs` helper screen if args absent
- Verified: `dart analyze lib/` → No issues found
- Verified: zero Firebase imports

### Architectural decisions
- Family provider with `InterviewArgs` (path + name) — one interview state per project; switching projects gets its own state for free
- Stub LLM is a pure top-level function `stubInterviewStep(state, userMessage)` returning a record `({String interviewerText, Map confidenceUpdates, List newConflicts})`. Notifier is the only caller. §4 swap = replace one function call with `await llmProvider.complete(...)` and JSON-parse the result.
- Stub is turn-counter driven (count user turns), not message-content driven — keeps the stub deterministic and the test path short (9 user messages = 8 resolved + 1 surfaced conflict)
- Conflict text follows Workflow Template pattern verbatim: "Your answers on [X] and [Y] pull in opposite directions. [X] implies [consequence]. [Y] implies [consequence]. I recommend [conservative option] for v1 because [reason]. Do you accept this scope?"
- `specGenEnabled` is a stored field on the state, recomputed on every transition (all 8 resolved + 0 open conflicts). Not a getter — explicit state machine field.
- `isLoading` gates the text input, send button, AND conflict Accept button — prevents race conditions where user resolves a conflict during the 400ms stub latency
- Composer is a `SafeArea(top: false)` so the iOS-style home indicator doesn't overlap the input on macOS
- Send button shows a `CircularProgressIndicator` (not a static icon) while `isLoading` — visual feedback that the LLM call is in flight
- Chat bubbles: user right-aligned (`#1F2937`), interviewer left-aligned (`#1C1C1E`); max width 640px; role label "YOU" / "INTERVIEWER" in 10px gray
- Auto-scroll to bottom on new turn via `WidgetsBinding.instance.addPostFrameCallback` — guard with `hasClients` check
- Entry point (button in project list to push `/interview`) deliberately out of scope — user can add in §6, §7, or hot-reload. Route is registered and ready.

### Open items / next
- §4 LLM Provider Layer (replaces the stub)
- §6 Spec Generation (the "Generate Spec" button action)
- Entry-point wiring: project list or detail stub → push `/interview` with `InterviewArgs`

---

## Session: 2026-06-01 — §3 Project Folder Browser

### What was done
- Rewrote `lib/main.dart` to wrap `TheForgeApp` in `ProviderScope`
- Created `lib/core/app.dart` — `TheForgeApp` MaterialApp with dark theme + `ProjectsListScreen` as home
- Created `lib/core/theme/app_theme.dart` — macOS dark theme, Menlo monospace, Forge amber (`#E8A04C`) primary, minimal chrome
- Created `lib/features/projects/screens/projects_list_screen.dart` — `ConsumerWidget` with:
  - `AsyncValue<List<Project>>` states (loading / error+retry / empty / data)
  - List rows showing name, phase, mode, last-opened date
  - `_ModeBadge` chip (amber for Build, slate for Audit)
  - Pull-to-refresh + AppBar refresh icon → `projectListProvider.notifier.refresh()`
  - Tap row → `activeProjectProvider.open(path, repo)` → push `_ProjectDetailStub` reading `activeProjectProvider`
  - FAB → push `_NewProjectStub` placeholder
- Verified: `dart analyze lib/` → No issues found
- Verified: zero Firebase imports

### Architectural decisions
- Inline `_ProjectDetailStub` and `_NewProjectStub` in the list screen file — keeps the §3 file count to 4 per the task scope
- Detail stub reads `activeProjectProvider` and renders the README.md content as monospace text
- `ActiveProjectState` exposes `readmeContent` only — no `error` field — detail stub simply shows `(no README.md found)` when null
- Navigator captured to local before `await` to avoid `use_build_context_synchronously` lint
- Theme: `ColorScheme.dark` with explicit `primary`/`surface`/`onSurface`/`error`; `Card` + `Divider` + `ListTile` themes set for flat dark macOS feel
- `floatingActionButtonTheme` uses primary as background, background as foreground (inverse) for contrast

### Open items / next
- §4 LLM Provider Layer (BYOK + SwarmSpace)
- §10 Settings screen (provider config UI; back-end to read it lives in §4)
- Detail screen will need real resume logic (read README + most recent bullet handoff + locked spec) once §9 lands

---

## Session: 2026-06-01 — Build order strategy + agent registry updates

### What was done
- Scored Minimax M3 on /goal integration task: 5/4/4/5/4 = 4.4 → Rank 1; added to agent registry in `agents md files/agent_scoping.md`
- Added strategic priority block to backlog.md: build order gate (Forge #1 → SwarmSpace Builder #2 → Iterix #3) — every §N on the critical path now explicitly unblocks the full product roadmap
- Bootstrapped Iterix repo at `/Volumes/Marc Working Drive/Development/Iterix/` from Starter Repo scaffold: CLAUDE.md, backlog §1–§9, ARCHITECTURE.md, agents.md, planner.md, context.md, all SOP boilerplate, git init + initial commit

### Key decisions
- Iterix is product #3: built after The Forge (#1) and SwarmSpace Visual Builder (#2)
- The Forge is used to dogfood the spec for SwarmSpace Builder; SwarmSpace Blocks used to build Iterix
- Iterix stack is an explicit open flag — no code until The Forge interview produces the locked spec
- Minimax M3 confirmed Rank 1 for doc-layer / multi-file markdown update tasks

### Next
- §3: Project folder browser screen (Flutter macOS UI, lists projects from `projectListProvider`)

---

## Session: 2026-06-01 — /goal integration updates

### What was done
- Applied /goal integration brief to The Forge workflow documentation
- Added Completion Criteria section to Locked Spec format (Stage 2) in
  both repo workflow_template.md and Obsidian source copy
- Added Stage 4b (/goal text output) to workflow_template.md — format,
  naming convention, and write path defined
- Updated Stage 5 executor handoff checklist — two new required items
- Updated Bullet Handoff format — Completion Criteria met field added
- Updated backlog.md §6 (spec structure +1 item) and §9 (3 outputs, not 2)

### Key decisions
- The /goal text is written to /handoffs/ alongside the Bullet Handoff,
  not as a separate artifact type — same write path, different filename
- Completion Criteria is inserted at position 5 in the spec structure,
  after Interface Contracts and before Static Content Specs
- Bullet Handoff gains "Completion Criteria met" field for v2 interview
  context — executor loop results travel forward through the audit trail

### Next
- §3: Project folder browser screen (Flutter UI)

---

---

## Session: 2026-06-01 — §2 Riverpod Project State Layer

### What was done
- Created `lib/features/projects/providers/project_list_notifier.dart` — `ProjectListNotifier` (AsyncNotifier) scans filesystem via `ProjectFileRepository.scanProjectPaths()`, upserts missing entries into `ForgeDatabase`, returns `getAllProjects()`. `refresh()` method invalidates self and awaits future.
- Created `lib/features/projects/providers/active_project_notifier.dart` — `ActiveProjectNotifier` (Notifier) with `ActiveProjectState` (projectPath, projectName, readmeContent, isLoading). `open()` sets isLoading → reads README.md → populates state. `close()` resets to empty.
- Created `lib/features/projects/providers/providers.dart` — 4 providers: `projectFileRepositoryProvider`, `forgeDatabaseProvider`, `projectListProvider` (AsyncNotifierProvider), `activeProjectProvider` (NotifierProvider).
- Verified: `dart analyze lib/` = zero issues
- Verified: zero Firebase references in lib/

### Architectural decisions
- `ProjectListNotifier` uses `ref.watch()` to pull `projectFileRepositoryProvider` and `forgeDatabaseProvider` — idiomatic Riverpod, avoids constructor injection complexity with `.new` factory
- `ActiveProjectNotifier` is a vanilla `Notifier` (not `AsyncNotifier`) — state transitions are explicit via the `ActiveProjectState` model
- All 4 providers in a single `providers.dart` barrel — not scattered across files

### Next
- §3: Project folder browser screen (Flutter UI — list projects, create new project)

---

## Session: 2026-06-01 — Backlog rewrite from product documentation

### What was done
- Read all product docs in Obsidian: Agent Workflow Template v3.0, Positioning Brief v4.0, Locked Spec (ForkIt v1.1), Setup Worksheet (ForkIt v1), Bullet Handoff (ForkIt v1 Interview)
- Rewrote `tracking md files/backlog.md` from 11 items → 16 items, grounded in actual product stages
- Removed all stale Firestore/Firebase Function references from §2–§9
- Reordered critical path: project folder browser now precedes interview (was reversed)
- Added missing items: §2 Riverpod state layer, §4 LLM provider layer (BYOK + SwarmSpace), §9 Handoff Package + Bullet Handoff generation, §10 Settings screen + BYOK Keychain storage, §14 Monte Carlo spec generation (separated from single-call §6)
- Each backlog item now references the Workflow Template stage it maps to and the ForkIt worked example as ground truth for correct output
- Corrected agent review scoring: DeepSeek v4 Pro scored 4.6/5 (not 4.4) — `← Edit` in DeepSeek UI shows old content, not new; DeepSeek had correctly removed flutter_lints
- Registered DeepSeek v4 Pro in `agents md files/agent_scoping.md` as Rank 1 Executor

### Key decisions
- Monte Carlo spec generation (3 parallel LLM calls at t=0.2/0.6/1.0) is §14, not part of §6 — single-call spec gen ships first
- §4 LLM provider layer is the pivot point for the entire app: all LLM calls route through one interface regardless of provider
- Worked examples (ForkIt spec, worksheet, handoff) are named as reference outputs in each backlog item for future executor prompts

### Next
- §2: Riverpod project state layer — `ProjectListNotifier` + `ActiveProjectNotifier`

---

## Session: 2026-05-31 — §1 Review + Codegen complete

### What was done
- Reviewed DeepSeek v4 Pro's §1 output — scored 4.6/5 → Rank 1 Executor
- Correction: `← Edit` format in DeepSeek UI shows OLD content; DeepSeek correctly removed `flutter_lints` + `cupertino_icons` in the pubspec edit (no dead dep, score revised upward)
- Fixed AOT/build-hook incompatibility: `objective_c 9.4.1` (transitive via path_provider on macOS) has a native build hook that blocks `dart compile aot-snapshot` in Dart 3.10.7 + build_runner 2.15.0. Solution: `--force-jit` flag
- Ran `dart run build_runner build --force-jit` → `forge_database.g.dart` generated, 10 outputs written in 8s
- `dart analyze lib/` → zero issues
- Registered DeepSeek v4 Pro in The Forge's `agents md files/agent_scoping.md`
- Updated backlog.md §1 → ✅ Complete; fixed stale Critical Path ("Firestore schema" → "Local data layer")
- Updated planner.md → §1 marked COMPLETE with --force-jit note

### Key finding
`dart run build_runner build` must always use `--force-jit` in this repo on macOS due to the `objective_c` native build hook. Document this in any future executor prompts for The Forge.

### Next
- §2: Build Interview — Flutter UI + State (Riverpod providers for project list + active project; interview screen scaffold)

---

## Session: 2026-05-31 — §1 Flutter Bootstrap + Local Data Layer

### What was done
- Ran `flutter create . --project-name the_forge --org ai.orbitalai` — Flutter 3.38.7, Dart 3.10.7
- Replaced pubspec.yaml dependencies: flutter_riverpod 2.6.1, riverpod 2.6.1, path_provider 2.1.5, path 1.9.0, uuid 4.5.1, drift 2.22.0, drift_flutter 0.2.1, build_runner 2.4.13, drift_dev 2.22.0
- Created `lib/data/local_db/forge_database.dart` — drift schema with Projects table (8 columns) + 4 method contracts (getAllProjects, upsertProject, removeProject, getProjectById)
- Created `lib/data/filesystem/project_file_repository.dart` — 8 method contracts including write-once locked spec with atomic temp→rename, append-only audit log, project folder creation with full structure
- Verified: `dart analyze lib/data/filesystem/ lib/main.dart` = zero issues
- Verified: zero Firebase references in pubspec.yaml

### Build-time requirements
- `build_runner` must be run before the app compiles: `dart run build_runner build`
- Only `forge_database.dart` needs codegen — the g.dart missing error is expected until build_runner runs

### Next
- Run `dart run build_runner build` to generate `forge_database.g.dart`
- §2: Riverpod providers (project list provider, active project provider)

### Warnings / open items
- `forge_database.g.dart` not yet generated — drift codegen must run before full `dart analyze lib/` passes
- analysis_options.yaml replaced flutter_lints with explicit rule set (flutter_lints was removed as dev_dependency)

---

## Session: 2026-05-31 — Repo bootstrap

### What was done
- Created The Forge repo at `/Volumes/Marc Working Drive/Development/The Forge/` from Starter Repo
- Wrote `claude.md` (Forge-specific SOPs, invariants, conditional triggers)
- Wrote `agents md files/agents.md` (architecture, subsystems, Firestore schema, data flow)
- Wrote `tracking md files/ARCHITECTURE.md` (full system architecture)
- Wrote `tracking md files/backlog.md` (§1–§11, prioritized, critical path defined)
- Wrote `backend.md` (Firebase + SwarmSpace reference)
- Wrote `tracking md files/FEATURES.md`, `UI_UX.md`, `CHANGELOG.md`, `planner.md`
- Copied all Starter Repo agent SOPs and bugtracker files
- Copied The Forge protocol docs (workflow_template.md, positioning_brief.md) into `DOCS/forge/`
- Initialized git and pushed to `https://github.com/marcyap29/theforge.git`

### Next
- Start §1: Firestore schema + `forge_project_repository.dart`
- Start Flutter project scaffold (`flutter create`)

### Warnings / open items
- Flutter project not yet created — repo is docs + config only at this stage
- Firebase project `arc-epi` shared with LUMARA + SwarmSpace — no new Firebase project needed
- SwarmSpace spec gen function does not exist yet — will need to add route to swarmspaceRouter or create standalone `generateSpec` function
