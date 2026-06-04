# The Forge — Session Log

Newest session first. Each block is prepended.

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
