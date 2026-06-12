# §IF1 — Interview Funnel Redesign

## Scoped Executor Prompt for DeepSeek V4 Pro

**Source design doc:** `DOCS/forge/The_Forge_InterviewFunnel_Plan_v1.md` (Fable). This brief is the executor handoff.

**Feature:** Rewrite the Build Interview from a flat 8-dimension list to a 4-layer deductive funnel (L1 Outcome → L2 Decomposition → L3 PoC + demo script → L4 Critical Path). The LLM emits a fenced `forge-state` JSON block on every turn that drives all state advancement. The scripted turn-counter stub stays only as a fallback when the LLM is unavailable.

**Definition of done:** Build Interview runs four layers L1→L4, each advanced by LLM-emitted `forge-state` JSON; the demo script from L3 reaches the spec generator and seeds the Completion Criteria; Audit mode is untouched; `dart analyze lib/` returns zero issues; worktree `wt/interview-funnel` ready for review.

---

## ⚠ Read this first (Marc — review before handoff)

Four design choices were baked in using Fable's recommended defaults (§11 of the source plan). Override these BEFORE pasting to DeepSeek if you disagree:

| # | Decision | Baked-in default |
|---|---|---|
| 1 | L2 capability list cap | **Hard cap at 5.** Interviewer pushes back on lists over 5. |
| 2 | L3 demo script length | **3 to 5 steps.** Pushback if 6+. |
| 3 | Mid-interview seed persistence | **Yes — write `{ProjectName}_V2Seeds.md` to `/ingested/` at L3 confirmation.** Survives a crash. |
| 4 | v2 interview shortened variant | **Deferred to backlog.** Not in scope here. |

If any of those change, edit the relevant section below before handoff.

---

## Project Context

- **Stack:** Flutter 3.38.7 / Dart 3.10.7 / Riverpod / local filesystem (no Firebase)
- **Repo root:** `/Volumes/Marc Working Drive/Development/The Forge/`
- **Worktree to create:** `wt/interview-funnel` off committed `main`
- **State management:** Riverpod — `FamilyAsyncNotifier` for interview
- **Linter:** `dart analyze lib/` — zero warnings required before done
- **LLM service:** `llmServiceProvider.complete(systemPrompt, userPrompt, temperature, role, maxTokens?)` returns `Future<String>`

### Existing patterns to match

| Pattern | Where to find it |
|---|---|
| Build Interview state object | `lib/features/interview/state/interview_state.dart` |
| Family AsyncNotifier wired to LLM | `lib/features/interview/state/interview_notifier.dart` |
| LLM call site (interview) | `interview_notifier.dart:166` — `llmService.complete(...)` |
| System prompt builder | `interview_notifier.dart:97` — `_interviewSystemPrompt(state, ingestedContext)` |
| Mode detection | `state.dimensions == buildDimensions` (const-equality check) |
| Disk-as-cache pattern | `ingested/reference_context.md` written/read by `ProjectFileRepository` |
| Spec prompt builder | `lib/features/spec_generation/spec_generator.dart:4` — `buildSpecPrompt(state, ingestedContext)` |

---

## Worktree Setup (run before any code change)

```bash
cd "/Volumes/Marc Working Drive/Development/The Forge"
git status --short                              # MUST be empty before continuing
git worktree add ../the-forge-interview-funnel -b wt/interview-funnel
cd ../the-forge-interview-funnel
flutter pub get
```

All code changes happen in `../the-forge-interview-funnel`. Never push to `main` directly — overseer merges after review.

---

## Files to Modify (5 files)

### 1. `lib/features/interview/state/interview_dimension.dart`

**Add** — keep the existing `DimensionDef`, `buildDimensions`, `auditDimensions`, and `dimensionsFor()` exports unchanged (downstream consumers depend on them as invariants).

Add a new immutable class and constant list **below** the existing exports:

```dart
@immutable
class LayerDef {
  final String id;          // 'L1' | 'L2' | 'L3' | 'L4'
  final String label;       // 'Outcome' | 'Decomposition' | 'PoC Reduction' | 'Critical Path'
  final String purpose;     // one-sentence summary shown to the user
  const LayerDef({
    required this.id,
    required this.label,
    required this.purpose,
  });
}

const buildLayers = <LayerDef>[
  LayerDef(
    id: 'L1',
    label: 'Outcome',
    purpose: 'The one thing this app does for its user that nothing they use today does.',
  ),
  LayerDef(
    id: 'L2',
    label: 'Decomposition',
    purpose: '3 to 5 capabilities required to deliver the outcome.',
  ),
  LayerDef(
    id: 'L3',
    label: 'PoC Reduction',
    purpose: 'One capability chosen as the proof; a 3 to 5 step demo script bounds V1.',
  ),
  LayerDef(
    id: 'L4',
    label: 'Critical Path',
    purpose: 'Platform, identity, IO, services deduced from the demo; blockers stripped.',
  ),
];
```

**Do not delete** the existing 8-dimension `buildDimensions` list. It survives as a set of spec invariants — see §4 of the source plan.

---

### 2. `lib/features/interview/state/interview_state.dart`

Three additions to `InterviewState`:

**(a)** Add fields:
```dart
final String currentLayer;        // 'L1' | 'L2' | 'L3' | 'L4'; defaults to 'L1' for Build, '' (empty) for Audit
final Map<String, dynamic> extracted;   // mirror of the forge-state contract (§ "JSON Contract" below)
final bool parseDegraded;         // true if the last LLM turn failed the forge-state contract
```

**(b)** Update `InterviewState.empty()` factory to initialize:
```dart
currentLayer: dimensions == buildDimensions ? 'L1' : '',
extracted: const <String, dynamic>{
  'outcome': null,
  'primaryUser': null,
  'capabilities': <String>[],
  'chosenCapability': null,
  'demoScript': <String>[],
  'v2Seeds': <String>[],
  'platform': null,
  'identityModel': null,
  'inputModel': null,
  'outputModel': null,
  'externalServices': <Map<String, dynamic>>[],
},
parseDegraded: false,
```

**(c)** Extend `copyWith` with the three new optional params.

**Why mode-conditional initialization:** Audit mode keeps its existing flat-list flow. `currentLayer: ''` is the signal that funnel logic is off. Do not branch all over the codebase — the notifier reads `state.currentLayer.isEmpty` to decide which path to take.

---

### 3. `lib/features/interview/state/interview_notifier.dart` (most of the work lives here)

#### 3a. Replace `_interviewSystemPrompt` for Build mode only

Branch at the top of the function:

```dart
String _interviewSystemPrompt(InterviewState state, {String? ingestedContext}) {
  final isBuild = state.dimensions == buildDimensions;
  if (!isBuild) {
    return _auditInterviewSystemPrompt(state, ingestedContext: ingestedContext);
  }
  return _buildInterviewSystemPrompt(state, ingestedContext: ingestedContext);
}
```

Move the current prompt body into `_auditInterviewSystemPrompt` verbatim (it stays correct for Audit). Write the new `_buildInterviewSystemPrompt` using the body in `## Build Interview System Prompt` at the bottom of this brief.

#### 3b. Add a forge-state parser

Add a top-level helper:

```dart
typedef ForgeStateParse = ({
  Map<String, dynamic>? extracted,
  String? layer,
  bool layerComplete,
  List<ConflictItem> conflicts,
  String visibleText,        // LLM text with the fenced block stripped
  bool parseOk,
});

ForgeStateParse parseForgeState(String llmRaw) {
  // 1. Find the fenced block: ```forge-state ... ```
  //    Use a RegExp: r'```forge-state\s*\n([\s\S]*?)\n```'
  // 2. If not found → return ForgeStateParse(parseOk: false, visibleText: llmRaw, ...)
  // 3. Strip the block from llmRaw → visibleText
  // 4. jsonDecode the captured group; catch FormatException → parseOk: false
  // 5. Pull fields out; coerce missing arrays to [] and missing scalars to null
  // 6. Convert each conflicts entry to a ConflictItem with id = '${a}_${b}' (sanitized)
}
```

Use `package:convert` for `jsonDecode` — already transitively available via `package:flutter/services.dart`. If not, add `import 'dart:convert';` (built-in).

#### 3c. Rewrite `addUserMessage`

Sequence (Build mode):

1. Append user turn, set `isLoading: true` (unchanged).
2. Call `llmService.complete(...)` with the new Build prompt. Temperature: `0.1`. Role: `LlmRole.executor` (unchanged).
3. On exception: fall back to `stubInterviewStep` (current behavior). Set `llmUnavailable: true`. Do NOT attempt to parse forge-state.
4. On success: call `parseForgeState(llmRaw)`.
5. If `parseOk == false`: retry **once** with a corrective suffix appended to `userPrompt`:
   ```
   Your previous response did not include a ```forge-state block. Re-emit the SAME answer with the mandatory ```forge-state JSON block appended. The block is required on every turn.
   ```
6. If retry also fails: hold state (no layer advancement, no extracted update), set `parseDegraded: true`, render the visible text, return.
7. If parse succeeded: merge `extracted` into state; if `layerComplete: true` AND the new layer's required fields are populated (see "Layer Advancement Gates" below), advance `currentLayer`. Merge `conflicts` into `openConflicts`.
8. After L3 confirmation (i.e., `layer == 'L3'` AND `layerComplete == true`), write the v2 seed list to disk:
   ```dart
   await repo.writeIngestedFile(
     state.projectPath,
     '${state.projectName}_V2Seeds.md',
     _v2SeedsMarkdown(extracted['v2Seeds'] as List),
   );
   ```
   Use the existing `ProjectFileRepository` write path for the `ingested/` folder — match the signature for `writeIngestedSummary`. If a public helper does not exist with that exact name, use the closest existing public method that writes a named file under `{projectPath}/ingested/`. Inspect `lib/data/filesystem/project_file_repository.dart` to confirm.
9. Update the 8-id `confidenceMap` from `extracted`:
   - `corePurpose` → resolved if `extracted.outcome != null`
   - `primaryUser` → resolved if `extracted.primaryUser != null`
   - `identityModel` → resolved if `extracted.identityModel != null`
   - `inputModel` → resolved if `extracted.inputModel != null`
   - `outputModel` → resolved if `extracted.outputModel != null`
   - `platform` → resolved if `extracted.platform != null`
   - `scopeBoundary` → resolved if `extracted.v2Seeds` is non-empty AND `extracted.demoScript` is non-empty (closed-by-default scope)
   - `externalServices` → resolved if `extracted.externalServices` field present (empty list is a valid answer — "no external services")
10. `specGenEnabled` flips when `currentLayer == 'L4'` AND `layerComplete: true` AND `openConflicts` is empty AND all 8 `confidenceMap` entries are `DimensionState.resolved`.

#### 3d. Demote `stubInterviewStep`

- Keep the function. Rename internal comments to indicate it is the **LLM-unavailable fallback only**.
- Delete the scripted turn-3 conflict injection (`_stubConflictFor`). The stub now only progresses the cursor through dimensions; it no longer fabricates conflicts.
- Stub MUST NOT run when `llmUnavailable == false` and parse succeeded. Today's bug is the silent merge — eliminate it: when the real LLM path succeeds, `confidenceUpdates` come only from `extracted`, never from the stub.

#### 3e. Audit-mode path stays identical

Branch in `addUserMessage`:
```dart
if (state.dimensions == buildDimensions) {
  // ... new funnel flow
} else {
  // ... existing flow (stub + LLM text), unchanged
}
```

The existing `resolveConflict` and `reset` methods need no changes (conflicts now come from parsed state, but the resolution UI consumes the same `ConflictItem` shape).

---

### 4. `lib/features/spec_generation/spec_generator.dart`

Goal: when `state.currentLayer == 'L4'` (Build mode with the funnel complete), enrich the spec prompt with the demo script, capabilities, and v2 seeds. Audit mode and Build-mode-with-empty-extracted (LLM fallback path) keep today's behavior.

Modify `buildSpecPrompt` only. Add a single block **after** the existing `confidenceSummary` calculation, before the final return:

```dart
final extracted = state.extracted;
final hasFunnelData = isBuild &&
    state.currentLayer.isNotEmpty &&
    extracted['outcome'] != null;

final funnelBlock = hasFunnelData
    ? '''

FUNNEL OUTPUT (drive the spec from this — it is the user's confirmed V1 cut):

Outcome: ${extracted['outcome']}
Primary user: ${extracted['primaryUser']}
Capabilities (confirmed): ${(extracted['capabilities'] as List).join(', ')}
Chosen capability for V1: ${extracted['chosenCapability']}

Demo script (each step is a Completion Criterion row):
${(extracted['demoScript'] as List).asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

Architectural defaults (confirmed by the user — put these in Hard Constraints):
- Platform: ${extracted['platform']}
- Identity model: ${extracted['identityModel']}
- Input model: ${extracted['inputModel']}
- Output model: ${extracted['outputModel']}

External services (only services with core=true belong in V1):
${(extracted['externalServices'] as List).map((s) => '- ${s['name']} (core=${s['core']}, stripped=${s['stripped']})').join('\n')}

V2 seeds (put these in Explicit Out-of-Scope and v2 Architecture Notes — never V1):
${(extracted['v2Seeds'] as List).map((s) => '- $s').join('\n')}
'''
    : '';
```

Inject `$funnelBlock` into the final prompt string between the existing `CONFIDENCE MAP:` block and the `Generate a complete $modeLabel Locked Spec` line.

Add this rule to the existing inline rules in the prompt:
```
- Completion Criteria rows must mirror the demo script steps one-for-one.
- Hard Constraints come from the Architectural defaults block — do not invent.
- Anything in the V2 seeds list goes ONLY in Explicit Out-of-Scope (§7) and v2 Architecture Notes (§10). Never §3 Component Map or §5 Completion Criteria.
```

**No other changes** to `spec_generator.dart`. The audit path is untouched.

---

### 5. `DOCS/forge/workflow_template.md`

Rewrite **Stage 1A — Build Interview** (only that subsection) to describe the four layers. Reuse the language from `DOCS/forge/The_Forge_InterviewFunnel_Plan_v1.md` §3 (The Four Layers). The structure:

```
## Stage 1A — Build Interview

### Goal
Reach a locked V1 spec by deduction, not coverage. Four layers, each unlocks
the next. The interviewer does not advance until the layer's exit condition
is met.

### Rules
- Ask ONE question per turn (reconciled from previous "up to 3"). [Fix the
  long-standing inconsistency: standardize on one.]
- ... (rest unchanged from current text where compatible)

### The Four Layers
[Reproduce §3 of the Funnel Plan: L1 Outcome, L2 Decomposition, L3 PoC
Reduction + demo script + auto-deferral, L4 Critical Path with blocker scan.
Keep the exit conditions.]

### The 8 Invariants
[Reproduce §4 of the Funnel Plan: the mapping table from old dimension to
where it resolves now. State the invariant: all 8 must be present in the
locked spec; the funnel decides how each is resolved.]

### Conflict Detection
[Keep the existing format string — it is the prompt the LLM still uses.]

### Completion Criteria
- L1 sentence confirmed
- L2 capability list (3-5) confirmed
- L3 chosen capability + demo script (3-5 steps) confirmed
- L3 v2 seed list confirmed
- L4 architectural defaults confirmed or overridden
- L4 blocker scan complete
- All 8 invariants resolved
- All conflicts resolved
```

**Stage 1B (Audit Interview)** is unchanged. Do not edit any other Stage.

---

## JSON Contract — `forge-state` block

The LLM appends this fenced block to **every** Build-mode response. The Flutter side parses it, strips it from the visible chat text, and drives state.

```
```forge-state
{
  "layer": "L1",
  "layerComplete": false,
  "extracted": {
    "outcome": "string or null",
    "primaryUser": "string or null",
    "capabilities": ["string"],
    "chosenCapability": "string or null",
    "demoScript": ["string"],
    "v2Seeds": ["string"],
    "platform": "string or null",
    "identityModel": "string or null",
    "inputModel": "string or null",
    "outputModel": "string or null",
    "externalServices": [
      {"name": "string", "core": true, "stripped": false}
    ]
  },
  "conflicts": [
    {
      "a": "dimensionA label",
      "b": "dimensionB label",
      "description": "Your answers on a and b pull in opposite directions...",
      "recommendation": "Conservative reading for v1"
    }
  ]
}
```
```

Notes for the parser:
- The outer triple-backtick fence with tag `forge-state` is the delimiter — match it exactly.
- `extracted` is **cumulative across turns** — the LLM is instructed to emit the full known map each turn, not deltas.
- All array fields default to `[]`, all scalar fields default to `null` if missing.
- Layer advancement gates (see below) are evaluated by the Flutter side, not trusted blindly from `layerComplete`.

### Layer Advancement Gates (server-side guard)

`layerComplete: true` alone is not sufficient. Confirm the layer's required fields are populated before advancing `currentLayer`:

| Layer | Advance to next when |
|---|---|
| L1 | `outcome != null` AND `primaryUser != null` |
| L2 | `capabilities.length >= 3 && capabilities.length <= 5` |
| L3 | `chosenCapability != null` AND `demoScript.length >= 3 && demoScript.length <= 5` AND `v2Seeds` is a list (may be empty) |
| L4 | `platform != null` AND `identityModel != null` AND `inputModel != null` AND `outputModel != null` AND `externalServices` is a list |

If `layerComplete: true` but the gate fails: do NOT advance, do NOT set `parseDegraded`. The LLM was overeager; let the user's next answer fill the gap. The system prompt makes the gates explicit so the LLM knows them too.

---

## Build Interview System Prompt (drop into `_buildInterviewSystemPrompt`)

```dart
String _buildInterviewSystemPrompt(InterviewState state, {String? ingestedContext}) {
  final refBlock = ingestedContext != null
      ? '\n\nREFERENCE CONTEXT:\n'
          'The following was extracted from reference documents provided by the user. '
          'Use it to inform your questions but do not treat it as binding — '
          'surface any tensions between the reference material and the user\'s answers.\n\n'
          '$ingestedContext\n'
      : '';

  final extractedJson = const JsonEncoder.withIndent('  ').convert(state.extracted);

  return '''You are The Forge interviewer — a sharp, direct product architect
running a Build Interview for a project called "${state.projectName}". Your
job is to reach a locked V1 spec an autonomous executor can build in one
pass. You are the user's product manager: push back on scope, force the
proof-of-concept cut, keep every deferred idea on the record.
$refBlock
THE FUNNEL — you are currently at ${state.currentLayer}. Do not advance until
the exit condition is met. Never ask about a later layer early.

L1 OUTCOME: Establish the one thing this app does for its user that nothing
they use today does, and who that user is. Exit: you restate it as "For
[user], this app [outcome]" and the user confirms.

L2 DECOMPOSITION: Get the 3-5 capabilities required to deliver L1. Push back
on lists over 5 and on anything that doesn't trace to the outcome. Exit:
confirmed list.

L3 POC REDUCTION: Force the choice of ONE capability as proof, then get a
3-5 step demo script ("open the app, do X, see Y"). Every capability not
chosen and every feature mentioned but absent from the demo goes on the v2
seed list. Read the seed list back for confirmation. Exit: capability chosen,
demo confirmed, seeds confirmed.

L4 CRITICAL PATH: Do not ask open questions here. Deduce platform, identity,
input, output, and services from the demo script and propose conservative
defaults the user confirms or corrects. Identity defaults to none. Run the
blocker scan: ask what they already have set up, then propose stripping
every external service that is not itself the chosen capability (local
storage over cloud, mocks over live APIs, no auth over OAuth). Draft the 1-3
step sequence to a working demo and ask them to correct it. Exit: all
defaults confirmed or overridden, blocker scan done, sequence confirmed.

STATE SO FAR (cumulative `extracted` map — re-emit every field every turn):
$extractedJson

RULES
- Ask ONE question per turn. Acknowledge the answer first. Be concise.
- When answers conflict: "Your answers on [X] and [Y] pull in opposite
  directions. [X] implies [A]. [Y] implies [B]. I recommend [conservative
  option] for v1 because [reason]. Do you accept this scope?" Do not proceed
  past a conflict.
- Never accept "all of the above". Pressure-test it.
- When the user is uncertain, recommend the conservative default and move on.
- If the user pitches a new feature at any layer, acknowledge it, add it to
  the v2 seeds, and return to the current layer's question.
- L2 capabilities: hard cap at 5. Demo script: 3 to 5 steps. Hard limits.

After EVERY response, append a fenced forge-state block. The block is
MANDATORY on every turn, even when nothing changed. Emit the FULL extracted
map each turn (cumulative, not deltas):

```forge-state
{
  "layer": "${state.currentLayer}",
  "layerComplete": false,
  "extracted": { ... full map ... },
  "conflicts": []
}
```

Set `layerComplete: true` only when the current layer's exit condition is
met. Set `conflicts: []` unless you detected an actual contradiction.''';
}
```

`JsonEncoder` lives in `dart:convert`. Add the import at the top of `interview_notifier.dart` if not already there.

---

## Key Invariants (do not break)

- `dart analyze lib/` zero warnings before reporting done.
- Audit Interview path is **untouched** behavioral-equivalent: `state.dimensions == auditDimensions` means the new code paths are skipped.
- The 8-id `buildDimensions` constant survives — downstream code (`spec_generator.dart`, `interview_state.dart::confidenceMap` keys) depends on those exact id strings.
- The forge-state block must be stripped from `visibleText` before it is appended as an `InterviewTurn.content`. Users must not see the JSON in the chat.
- `parseDegraded` is the recovery signal — it is a state field, NOT an exception. Render the visible text, hold state, surface a small banner in a later UI pass (not in scope for this brief — leave a TODO comment on the field).
- LLM fallback path (`llmUnavailable: true`) must not call `parseForgeState` — the stub text has no block to parse.
- Layer advancement requires BOTH `layerComplete: true` AND the server-side gate condition. Trust nothing the LLM says blindly.
- The v2 seed file write at L3 confirmation is **idempotent overwrite** — not write-once. If the user re-resolves L3, the file is rewritten. Use the normal write path, not the locked-spec atomic temp+rename.
- Never write interview state to disk on every turn — only the v2 seed file at L3 confirmation (single-write, on confirmation, not on every L3 turn).
- No Firebase imports (`grep -ri firebase lib/` returns nothing).

---

## Out of Scope

- `lib/features/interview/ui/confidence_meter.dart` — the meter still reads the 8 ids; visual layer-grouping is a separate UI pass.
- `lib/features/interview/ui/interview_screen.dart` — no UI for the `parseDegraded` banner in this brief.
- Audit Interview funnel — Audit stays flat for now.
- v2 interview shortened funnel variant (Fable §11 Q4) — backlog.
- Handoff JSON schema changes — the new `extracted` map flows through `buildSpecPrompt` into the spec content; downstream handoff generation reads from the spec, not from `extracted`.
- Tests — none in scope. The repo currently has no unit tests for the interview engine; do not add a test framework as part of this work.

---

## File Read Order (recommended — read before editing)

1. `DOCS/forge/The_Forge_InterviewFunnel_Plan_v1.md` — Fable's full design rationale (read for context only)
2. `lib/features/interview/state/interview_dimension.dart` — current dimension defs
3. `lib/features/interview/state/interview_state.dart` — state shape
4. `lib/features/interview/state/interview_notifier.dart` — current flow
5. `lib/features/spec_generation/spec_generator.dart` — spec prompt
6. `lib/data/filesystem/project_file_repository.dart` — confirm the ingested-file write method name (used for V2Seeds.md)
7. `bugtracker/BUG_PREVENTION.md` — universal rules + Interview State + Flutter Navigation sections

---

## Verification Checklist (run before reporting done)

```bash
cd ../the-forge-interview-funnel
dart analyze lib/                                # zero issues required
grep -ri firebase lib/                           # zero matches required
grep -rn "ConfidenceDimension" lib/              # zero matches (legacy enum gone since §5)
grep -rn "_stubConflictFor" lib/                 # should appear ONLY in interview_notifier.dart and be unused
git diff --stat main..HEAD                        # confirm only the 5 listed files changed (+ pubspec.lock if any)
git status --short                               # must be empty before requesting merge
```

Then a runtime smoke (manual — overseer runs this):
1. Open the app, create a fresh Build-mode project "FunnelTest".
2. Open the interview. First interviewer message should ask the L1 outcome question.
3. Answer in three messages. By the third turn, the confidence meter should reflect L1 fields resolved.
4. Walk through L2 → L3 → L4. The demo script entered in L3 should appear in the generated spec's Completion Criteria.
5. Open a fresh Audit-mode project. Confirm the Audit interview still asks the 8 Audit dimensions in the original order. No regression.

---

## Self-Correction Checklist

DeepSeek: if any of these fire, stop and surface in your final report rather than guessing.

- The `ProjectFileRepository` method that writes a named file under `ingested/` is not obvious from a single read. State the method you chose and why.
- The JSON parser must not import `dart:io` — it should be pure Dart usable in any context. Use `dart:convert` only.
- If the existing system prompt references `state.dimensions.length` for "Resolved so far" — for Build mode, replace with the layer model. For Audit mode, leave as is.
- The `extracted` map's `dynamic` value type will trigger `prefer_typed_collection_literals` in some lint configs. If it does, use `<String, dynamic>{}` explicitly at every site. Do not change the typedef.

---

## Branch Hygiene

- One commit per logical sub-task is preferred but not required.
- Commit message convention: `feat(§IF1): <what>` — match the existing repo style (see recent `f90a959 feat(§W1): ...`).
- Do not commit `pubspec.lock` unless dependencies actually changed (they should not for this work).
- Do not run `flutter clean` — it forces a slow rebuild on the overseer side. If a stale build artifact gets in the way, `flutter pub get` alone usually fixes it.

---

*Plan written: 2026-06-11 · Ready for handoff to DeepSeek V4 Pro · Worktree: `wt/interview-funnel`*
*Source design: `DOCS/forge/The_Forge_InterviewFunnel_Plan_v1.md` (Fable)*
