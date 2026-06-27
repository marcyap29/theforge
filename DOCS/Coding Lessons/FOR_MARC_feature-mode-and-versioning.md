# FOR MARC — Feature Mode, Versioning, and "What Happens After V1"

*Sessions: §EX1, §UI1, §FM1 — 2026-06-11 to 2026-06-17*

---

## Step 1 — Approach and reasoning

Three features, one theme: what does The Forge do after a V1 spec is locked and built?

**§EX1 — Executor Timeline.** When the setup worksheet is complete, show a "BUILD SEQUENCE" section in the project detail screen. The user taps "Generate Build Sequence" and gets an LLM-narrated, ordered build plan for their component map — not just a list of components, but "build Component A first because it has no dependencies; build Component B second because it depends on A's interface; Component C last because it integrates both." Persisted to disk on first generation; subsequent opens load from disk without another LLM call.

**§UI1 — Layer Sub-Timeline.** The project detail screen already shows a 3-step Phase Timeline (Interview → Spec → Worksheet). §UI1 added a sub-row of four dots (L1 / L2 / L3 / L4) beneath the Interview step. Dots are gray (not yet reached), amber with a pulse animation (current), or green (done). Also added a compact FUNNEL strip inside the interview screen above the confidence meter — same dots, same state.

**§FM1 — Feature Interview Mode (V2+).** Once V1 is complete, a "Start V2 Interview →" button appears. This runs the same 4-layer Build funnel but pre-loads the prior locked spec and V2 seeds into the system prompt, so the LLM knows what already exists and what was deferred. The interview produces a `_LockedSpec_v2.md` with matching artifacts in the same project folder.

The unifying principle: The Forge manages projects across multiple versions, not just once. Every screen and every feature after V1 completion is about enabling the next cycle.

---

## Step 2 — Roads not taken

**§EX1: Show a plain list of components with a sort order.**
Static and cheap, but not what the user actually needs. The component map tells you *what* to build. The build sequence tells you *in what order* and *why*. An LLM can reason about dependency chains, interface contracts, and risk ordering in a way a static sort can't. The LLM call at t=0.3 (low temperature, procedural) + write-once persistence makes it feel like a generated document, not a dynamic response.

**§UI1: Store layer state in a separate provider.**
We had two options: read layer state from `InterviewState.currentLayer` (already persisted to disk) or create a new provider that writes layer state separately. Using `currentLayer` from `InterviewState` is the right call because it's the single source of truth — the interview notifier already writes it to disk on every transition. A separate provider would duplicate data and create sync problems.

**§FM1: Add a new `ProjectMode.feature` enum value.**
This was the first instinct — "feature interview is a different mode." Rejected. The feature interview uses the same 4-layer funnel as a V1 Build. The only difference is what gets injected at the start. Adding a new enum value would mean forking the notifier, the system prompt, and the spec generation pipeline for what amounts to a one-field difference. The actual trigger is `InterviewArgs.priorSpecVersion != null` — clean and minimal.

**§FM1: Create a new project folder for each version.**
Rejected. V2 artifacts live in the same project folder with a `_v2` suffix in their filenames. `writeLockedSpec()` is already write-once per version (checks file existence before writing), so there's no risk of overwriting V1. The project folder is the project; versions are a detail of the artifact naming.

---

## Step 3 — How the pieces connect

**§EX1 data flow:**

```
ProjectDetailScreen mounts (phase == v1_worksheet_complete)
    ↓
ExecutorTimelineNotifier.build(projectPath) — scans handoffs/ for *_BuildSequence_* file
    ├─ found: load content → display
    └─ not found: show "Generate Build Sequence" button
         ↓ (on tap)
    generate() — reads forge/{name}_LockedSpec_v1.md
               — parseComponentNames() extracts component list
               — buildExecutorTimelinePrompt() builds LLM prompt
               — LLM call (architect role, t=0.3, maxTokens 2048)
               — writes handoffs/{name}_BuildSequence_v1.md
               — displays content
```

`parseComponentNames()` in `spec_generator.dart` extracts component names from the spec's Component Map section using regex. This is how the notifier knows what components to narrate — it doesn't re-interpret the spec, it reads the already-generated document.

**§UI1 data flow:**

The L1–L4 dots read directly from `InterviewState.currentLayer`:
- `project_detail_screen.dart` loads the interview state (via the family provider with the project's path + name) and checks `currentLayer` against the `buildLayers` constants
- `interview_screen.dart` builds the compact funnel strip from `state.currentLayer`

No new state, no new persistence. `currentLayer` is already persisted to disk on every LLM turn because the full `InterviewState` is written to disk. The dots are just a read-only view of existing state.

**§FM1 data flow:**

```
ProjectDetailScreen shows "Start V2 Interview →" button
(condition: phase matches v1_complete and not currently in V2+ interview)
    ↓
InterviewArgs(path, name, mode: build, priorSpecVersion: 'v1')
    ↓
InterviewNotifier.build() reads priorSpecVersion != null
    → readFeatureContext() reads forge/{name}_LockedSpec_v1.md + ingested/{name}_V2Seeds.md
    → featureContext stored in InterviewState.featureContext
    ↓
_featureInterviewSystemPrompt() injects:
    - V1 goal statement
    - V1 component list
    - V2 seed list ("these were deferred from V1, prioritize from here")
    - "Present-first" L1: start from "V1 shipped X; what changes?"
    ↓
Interview runs (same L1→L4 funnel)
    ↓
"Generate V2 Spec" button (labeled with nextSpecVersion() = 'v2')
    ↓
SpecNotifier.generate(targetSpecVersion: 'v2') — writes *_LockedSpec_v2.md etc.
```

`nextSpecVersion()` is a public helper on the notifier: reads the current max spec version from the project folder and returns the next one. "v1" → "v2", "v2" → "v3".

---

## Step 4 — Tools and patterns

**`AutoDisposeFamilyAsyncNotifier` for §EX1:**
The executor timeline notifier takes `String projectPath` as its family arg. Every project gets its own notifier instance. On `build()`, it scans `handoffs/` for a `*_BuildSequence_*` file — if found, loads it; if not, returns the `notGenerated` state. This is the same pattern as the interview notifier (family by `InterviewArgs`) but simpler because it's a single state machine with no user input.

**Disk-as-cache for one-shot generation:**
The build sequence is generated once and persisted. On subsequent mounts, the notifier loads from disk. No re-generation, no stale state. This is the right pattern for LLM-generated documents that are expensive to produce and don't change unless the spec changes.

**`RouteAware.didPopNext()` for auto-refresh:**
The project detail screen implements `RouteAware`. When the interview screen pops back to the detail screen, `didPopNext()` fires and refreshes the phase timeline state. Without this, the layer dots would show stale state after an interview session completes.

**Phase string helpers:**
```dart
static String _stageOf(String phase)  // e.g., 'v1_worksheet_complete' → 'done'
static String _versionOf(String phase) // e.g., 'v2_interview_active' → 'v2'
static String _nextVersion(String current) // 'v1' → 'v2'
```
These small helpers keep the `project_detail_screen.dart` logic readable. Without them, you'd have a wall of `phase.startsWith('v1_')` comparisons inline.

---

## Step 5 — Tradeoffs

**§EX1: Write-once build sequence.**
The build sequence is written once and not regenerated. If the locked spec changes (V2 interview), the existing build sequence becomes stale. Acceptable tradeoff for V1 because the spec is immutable after locking — the sequence can't be wrong for the spec it was generated from. V2 creates a new sequence with a `_v2` suffix.

**§FM1: "Present-first" L1 is slightly redundant.**
The feature interview starts with "V1 shipped [outcome]. What changes?" But L1's job is to establish the outcome, which is already established. In practice this makes L1 faster (user confirms or refines the existing outcome), not redundant. The slight oddness is worth the consistency: every interview runs L1→L4, no special cases.

**§UI1: Layer dots only show during active interview.**
The dots in the project detail screen only show when there's an active interview state loaded. Once the interview is complete and the spec is generated, `currentLayer` is meaningless and the sub-row isn't shown. This is correct — the dots show interview progress, not a permanent record.

---

## Step 6 — Mistakes, dead ends, and wrong turns

**Wide widgets inside a flex Row broke the phase timeline layout.**
The timeline is a Row of `_TimelineStep` + `_TimelineConnector` widgets. Version chips (displaying "V1 ✓ · V2 active") and L1–L4 layer dots needed to go somewhere visible. The first attempt put them inside a Column that was a child of the timeline Row. This broke the connector line alignment — the vertical connector between steps got misaligned because the Column expanded its height independently.

The fix: place any wide or tall widgets BELOW the timeline Row, not inside it. The phase timeline Row stays as a pure horizontal layout. Chips and dots go in a second Row or Column beneath it.

Rule to remember: **wide widgets in flex layouts break layouts**. If your widget needs to span, place it outside the flex — above or below, not nested inside.

**`InterviewArgs` change broke existing interview sessions mid-way.**
Adding `priorSpecVersion: String?` to `InterviewArgs` changed the family key structure. Any in-progress interview (from before the feature landed) would have a stale family key and would lose its state. This is acceptable for a major version change, but worth being aware of: changing the family arg type always invalidates existing family instances.

**`flutter_markdown` discontinued upstream.**
The artifact viewer uses `flutter_markdown` for rendering. It was working fine but has been discontinued — the replacement is `flutter_markdown_plus`. Not urgent (the old package still functions), but migration is on the backlog.

---

## Step 7 — Pitfalls to watch for

**`writeLockedSpec()` is write-once — rely on it.**
The method checks if the file already exists before writing. If you call it twice with the same spec version, the second call is a no-op. This is by design — specs are immutable. Don't try to overwrite; bump the version instead.

**Version strings are case-sensitive in filenames.**
`_LockedSpec_v2.md` not `_LockedSpec_V2.md`. The spec version is always lowercase `v` + number. Consistency matters here because `readFeatureContext()` constructs the file path by string interpolation — one case mismatch and the file isn't found.

**AutoDispose notifiers lose state on navigation.**
`ExecutorTimelineNotifier` is `AutoDispose`. When you navigate away from `ProjectDetailScreen`, the notifier is disposed. When you come back, `build()` runs again and re-scans `handoffs/`. This is correct behavior — the scan is cheap, and you want the screen to pick up any newly generated file. But it also means you can't store in-progress generation state in the notifier and navigate away mid-generation. For generation, always show a loading screen on top (like `SpecGenerationScreen` does) rather than starting generation in a background notifier.

---

## Step 8 — What an expert notices

The `priorSpecVersion != null` trigger for feature mode is an example of **feature flags as field presence checks**. Instead of adding a new enum value (`ProjectMode.feature`) and threading it through the codebase, the feature is triggered by data — a field being non-null. This keeps the codebase simple (one code path, not two), and the feature flag disappears naturally when it's irrelevant (V1 interviews just never have the field set).

The build sequence (§EX1) is a bridge artifact. It doesn't live in the spec and it doesn't live in the executor agent — it's a document that translates between them. The spec tells you what exists (component map). The /goal artifact tells you what to accomplish (completion criteria). The build sequence tells you how to get from nothing to done in what order. These three are complementary: one without the others leaves the executor guessing about sequencing or priority.

The layer dots in both the interview screen and the project detail screen reading from the same `currentLayer` field is an example of the DRY principle applied to UI state: one field, two views. No synchronization problem, no stale state, no "why don't the dots match?"

---

## Step 9 — Transferable lessons

**"Same funnel, different context"** is a powerful pattern for multi-version workflows. Rather than writing separate V1 and V2 interview logic, inject the prior version's output as context. The conversation structure stays the same; what changes is what the LLM already "knows" when it starts. This applies anywhere you have a recurring structured workflow: performance reviews, design critiques, post-mortems.

**"One field drives behavior"** (`priorSpecVersion != null`) is better than new modes, new enums, and new code paths for variations on the same core workflow. Ask: is this really a different mode, or is it the same mode with different input? If it's the same mode, express the difference as data.

**Write-once + version-suffix** is a simple and robust versioning strategy for generated documents. No history, no diffs, no git blame — just `_v1.md`, `_v2.md`, side by side in the same folder. The user can open both in Finder and compare directly. Overkill for frequently changing data; exactly right for immutable milestone documents.

**Disk-as-cache for expensive, one-shot generated content.** The executor timeline is expensive (LLM call) and stable (doesn't change unless the spec changes). Scan for the file on mount; generate only when absent; never regenerate automatically. This pattern is common in documentation generation, code analysis, and report generation — the generated artifact is the asset, not the live query.

---

*Sessions: §EX1 (2026-06-11), §UI1 (2026-06-12), §FM1 (2026-06-17) · The Forge · Orbital AI*
