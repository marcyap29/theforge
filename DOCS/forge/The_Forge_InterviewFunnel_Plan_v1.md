# The Forge — Interview Funnel Redesign Plan v1

**Status:** IMPLEMENTED ✅ — Executor prompt in `DOCS/forge/interview_funnel_executor_plan_v1.md`. Code shipped 2026-06-11/12. See `tracking md files/planner.md §IF1`.
**Date:** 2026-06-11
**Scope:** Build Interview only. Audit Interview unchanged.
**Supersedes:** Nothing. The 8 confidence dimensions survive as spec invariants (see §4).

---

## 1. Problem Statement

Two defects in the current Build Interview, one in design and one in implementation.

### 1.1 Design: the flat list doesn't converge on a V1

`buildDimensions` in `lib/features/interview/state/interview_dimension.dart` is 8 independent questions. The system prompt dumps every unresolved dimension into "Still needed" each turn and lets the LLM pick. Consequences:

- Scope boundary sits at slot 7. The user commits to identity model, input model, output model, and platform before anyone asks what V1 actually is. That ordering invites feature accumulation, then asks the user to prune afterward.
- Answering one dimension never narrows another. "Core purpose" resolved doesn't change what gets asked about platform. There is no deduction, only coverage.
- Nothing in the flow forces the "if you could only ship one thing" decision. The interview can complete at 100% confidence with a V1 that is really a V3.

### 1.2 Implementation: the confidence map is turn-count theater

In `lib/features/interview/state/interview_notifier.dart`, the LLM generates only the chat text. State advancement comes from `stubInterviewStep`:

- Dimension N is marked resolved after N user turns, regardless of content.
- A scripted conflict between dimensions 0 and 2 is injected at user turn 3, every interview, regardless of what was said.
- `specGenEnabled` flips when the turn count runs out, not when the goal is actually understood.

A user who answers "I don't know" eight times reaches 100% confidence. Any funnel bolted onto this would still just count turns. The redesign must make resolution content-driven (§5) or it is cosmetic.

---

## 2. Design Goal

Get to a locked V1 spec the executor can one-shot, by deduction rather than coverage:

1. Establish the single outcome.
2. Decompose it into capabilities.
3. Force the proof-of-concept cut: one capability, expressed as a runnable demo.
4. Deduce the architecture from the cut, confirming defaults instead of asking blind.

Everything mentioned but not chosen is captured as a v2 seed, not lost and not built. The V1 critical path carries minimal blockers, with external services stripped unless one IS the key feature.

---

## 3. The Four Layers

Each layer unlocks the next. The interviewer does not advance until the current layer's exit condition is met.

### L1 — Outcome

**Question:** "What is the one thing this app does for its user that nothing they currently use does? Who is that user?"

Replaces `corePurpose` + `primaryUser`. One question, because purpose and user are inseparable in practice; an answer to one without the other is incomplete and the interviewer asks the follow-up.

**Exit condition:** Interviewer can restate the outcome in one sentence ("For [user], this app [outcome]") and the user confirms the restatement.

### L2 — Decomposition

**Question:** "What are the 3 to 5 capabilities the app needs to deliver that outcome? Not features you'd like. Capabilities it cannot deliver the outcome without."

New layer. Surfaces the component map at interview time instead of spec-generation time. The interviewer pushes back on lists longer than 5 ("which two of these are really one?") and on capabilities that don't trace to L1 ("how does this serve [outcome]?").

**Exit condition:** A confirmed list of 3 to 5 capabilities, each traceable to the L1 outcome.

### L3 — PoC Reduction (the demo script)

**Question A:** "If you could ship only ONE of those capabilities right now as proof this works, which one, and why that one?"

**Question B:** "Describe the demo that proves V1 works. 3 to 5 steps, in the form: open the app, do X, see Y."

Question B is the heart of the redesign. A capability pick alone still leaves surface area fuzzy ("search" can be a text box or a faceted engine). A demo script bounds it exactly, and it does double duty:

- Each demo step becomes a row in the Completion Criteria table (the gap identified in `TheForge_GoalIntegration_Prompt_v1.md`). The interview produces the /goal's verification surface natively instead of the spec generator inventing it later.
- The demo script is the definition of done for the executor loop. The judge agent checks the steps.

**Auto-deferral rule (default-closed scope):** every capability from L2 not chosen here, and every feature mentioned anywhere in the conversation but absent from the demo script, is written to the v2 seed list automatically. The interviewer reads the seed list back: "Captured for v2, not lost: [list]. Confirm nothing on this list is needed for the demo to run." This replaces the open-ended "what is out of scope?" question. Scope is closed by default; the user opts things in by putting them in the demo, never opts them out one by one.

**Exit condition:** One capability chosen, demo script confirmed, v2 seed list read back and confirmed.

### L4 — Critical Path

The four architectural dimensions stop being questions and become confirmations. The interviewer deduces each from the demo script and proposes the most conservative default that still runs the demo:

| Invariant | How L4 resolves it |
|---|---|
| Platform | Deduced from the demo ("you said 'open the app on your phone', so iOS first — confirm?"). If the demo doesn't imply one, propose the cheapest to ship. |
| Identity model | Default: none. Accounts enter V1 only if the demo cannot run without them. |
| Input model | Read directly off the demo steps ("do X"). |
| Output model | Read directly off the demo steps ("see Y"). |
| External services | Blocker scan, below. |

**Blocker scan:** "To run this demo, what do you already have set up? (API keys, accounts, paid services, devices.)" Then, for every external service the demo implies:

- If the service IS the chosen capability (the demo is meaningless without it), it stays in V1 and goes on the Setup Worksheet.
- Otherwise the interviewer proposes stripping it: local storage instead of cloud sync, mock data instead of a live API, no auth instead of OAuth. Strip unless core.

A V1 with zero new external services has a near-empty Setup Worksheet and can ship the same day the executor finishes. That is the minimal-blocker critical path.

**Question:** "What is the minimum sequence of steps (1 to 3) to get the demo working end to end with zero blockers?" The interviewer drafts this sequence itself from the confirmed defaults and asks the user to correct it, rather than asking blind.

**Exit condition:** All five invariants confirmed or consciously overridden, blocker scan complete, critical path sequence confirmed.

---

## 4. The 8 Dimensions Become Invariants

The dimensions are not deleted. They move from "questions asked in order" to "conditions the locked spec must satisfy." Mapping:

| Old dimension | Where it gets resolved now |
|---|---|
| Core purpose | L1 |
| Primary user | L1 |
| Identity model | L4 confirmation (default: none) |
| Input model | L4, read off demo steps |
| Output model | L4, read off demo steps |
| Platform | L4 confirmation |
| Scope boundary | L3 auto-deferral (default-closed) |
| External services | L4 blocker scan |

The spec generator keeps validating that all 8 are present before locking. Nothing downstream of the interview (spec structure, handoff JSON, /goal artifact) changes shape. The Completion Criteria section gains a guaranteed source: the L3 demo script.

If L3's cut leaves an invariant thin (a demo that never touches identity, say), the spec records the conservative default and the reasoning ("no accounts; demo runs without identity; revisit at v2 interview"), which is exactly what the Accepted Decisions table is for.

---

## 5. Content-Driven Resolution (the stub fix)

This is the work item that makes the funnel real.

### 5.1 Contract

Every interviewer turn, the LLM is instructed to end its response with a fenced state block:

```
```forge-state
{
  "layer": "L1" | "L2" | "L3" | "L4",
  "extracted": {
    "outcome": "string | null",
    "primaryUser": "string | null",
    "capabilities": ["string"],
    "chosenCapability": "string | null",
    "demoScript": ["string"],
    "v2Seeds": ["string"],
    "platform": "string | null",
    "identityModel": "string | null",
    "inputModel": "string | null",
    "outputModel": "string | null",
    "externalServices": [{"name": "string", "core": true, "stripped": false}]
  },
  "layerComplete": false,
  "conflicts": [
    {"a": "string", "b": "string", "description": "string", "recommendation": "string"}
  ]
}
```
```

The Flutter side strips the block before rendering the chat text, parses it, and drives state from it. Layer advancement requires `layerComplete: true` AND the layer's required `extracted` fields non-null. Belt and suspenders: the app validates, the model proposes.

### 5.2 State changes

`InterviewState` gains `currentLayer` and an `extracted` map mirroring the contract. The confidence map keys stay the 8 invariant ids (downstream consumers keep working), but each flips to resolved when its source field in `extracted` is populated and confirmed, never on turn count.

`stubInterviewStep` survives only as the LLM-unavailable fallback, clearly labeled, and stops feeding `confidenceUpdates` when the LLM succeeds. Today's silent merge of stub state with real LLM text is the bug; the fallback must be all-or-nothing per turn.

`specGenEnabled` flips when L4's exit condition is met and `conflicts` is empty.

### 5.3 Conflict detection

Unchanged in spirit, relocated in time. Conflicts now surface inside the layer where they arise (L2 capability contradicts L1 outcome; L4 default contradicts the demo). The scripted turn-3 conflict is deleted. The conflict resolution UI (`resolveConflict`) keeps working as is, fed by parsed `conflicts` instead of the stub.

### 5.4 Parse failure policy

If the state block is missing or malformed: retry once with a corrective suffix ("your last response omitted the forge-state block; re-emit it for the same answer"). On second failure, hold state (no advancement), render the text, set a `parseDegraded` flag the UI can surface. Never advance on unparsed turns.

---

## 6. Revised System Prompt (draft)

Replaces `_interviewSystemPrompt` body for Build mode. Audit mode keeps the current prompt.

```
You are The Forge interviewer, a sharp, direct product architect running a
Build Interview for "{projectName}". Your job is to reach a locked V1 spec
an autonomous executor can build in one pass. You are the user's product
manager: push back on scope, force the proof-of-concept cut, keep every
deferred idea on the record.

{REFERENCE CONTEXT block, when present — unchanged}

THE FUNNEL — you are currently at {currentLayer}. Do not advance until the
exit condition is met. Never ask about a later layer early.

L1 OUTCOME: Establish the one thing this app does for its user that nothing
they use today does, and who that user is. Exit: you restate it as "For
[user], this app [outcome]" and the user confirms.

L2 DECOMPOSITION: Get the 3-5 capabilities required to deliver L1. Push back
on lists over 5 and on anything that doesn't trace to the outcome. Exit:
confirmed list.

L3 POC REDUCTION: Force the choice of ONE capability as proof, then get a
3-5 step demo script ("open the app, do X, see Y"). Every capability not
chosen and every feature mentioned but absent from the demo goes on the v2
seed list. Read the seed list back for confirmation. Exit: capability
chosen, demo confirmed, seeds confirmed.

L4 CRITICAL PATH: Do not ask open questions here. Deduce platform, identity,
input, output, and services from the demo script and propose conservative
defaults the user confirms or corrects. Identity defaults to none. Run the
blocker scan: ask what they already have set up, then propose stripping
every external service that is not itself the chosen capability (local
storage over cloud, mocks over live APIs, no auth over OAuth). Draft the
1-3 step sequence to a working demo and ask them to correct it. Exit: all
defaults confirmed or overridden, blocker scan done, sequence confirmed.

STATE SO FAR:
{serialized extracted map — resolved fields and current layer}

RULES
- Ask ONE question per turn. Acknowledge the answer first. Be concise.
- When answers conflict: "Your answers on [X] and [Y] pull in opposite
  directions. [X] implies [A]. [Y] implies [B]. I recommend [conservative
  option] for v1 because [reason]. Do you accept this scope?" Do not
  proceed past a conflict.
- Never accept "all of the above". Pressure-test it.
- When the user is uncertain, recommend the conservative default and move on.
- If the user pitches a new feature at any layer, acknowledge it, add it to
  the v2 seeds, and return to the current layer's question.

After EVERY response, append a fenced forge-state block:
{contract from §5.1}
The block is mandatory even when nothing changed.
```

Note the last rule. The mid-interview feature pitch is the main drift vector; the prompt makes the parking-lot response reflexive.

---

## 7. What Flows Downstream

- **Spec generator:** input improves, format unchanged. Completion Criteria rows come straight from the demo script. Out-of-Scope list and v2 Architecture Notes come from the seed list. Component Map seeds from L2 capabilities with the L3 choice marked v1-active.
- **/goal artifact:** Outcome = L1 sentence. Completion Criteria = demo steps. Boundaries' off-limits list = seed list. No format change.
- **Setup Worksheet:** only services that survived the blocker scan. Often empty, which is the point.
- **Versioning loop:** unchanged mechanics, and the funnel repeats naturally. A v2 interview's L1 becomes "v1 shipped and does [outcome]; what is the next single capability?" with the v1 spec, bullet handoff, and seed list as reference context. L2 starts from the existing seed list instead of a blank page. One or two capabilities per version, every version shippable.
- **Workflow template:** Stage 1A rewritten to the four layers with the invariant table from §4. Also fix the standing inconsistency: the template says max 3 questions per turn, the system prompt says one. Standardize on one.

---

## 8. Confidence Meter (state model only — UI sketch deferred)

The meter's data source changes from 8 independent booleans to 4 layers that unlock in order, with the 8 invariants as sub-items resolving inside them. `DimensionState` (unresolved / partial / resolved) still fits. UI redesign is a separate task; nothing here blocks it or depends on it.

---

## 9. Files Affected (when this plan is executed)

| File | Change |
|---|---|
| `lib/features/interview/state/interview_dimension.dart` | Add layer definitions; keep dimension ids as invariants |
| `lib/features/interview/state/interview_state.dart` | Add `currentLayer`, `extracted`, `parseDegraded` |
| `lib/features/interview/state/interview_notifier.dart` | New system prompt; parse forge-state block; demote stub to labeled fallback; delete scripted conflict |
| `lib/features/spec_generation/spec_generator.dart` | Consume `extracted` (demo script → Completion Criteria, seeds → out-of-scope) |
| `lib/features/interview/ui/confidence_meter.dart` | Layered data source (UI pass separate) |
| `DOCS/forge/workflow_template.md` | Rewrite Stage 1A; reconcile question-per-turn rule |

Audit Interview, Firestore layer, project folder structure, handoff formats: untouched.

---

## 10. Tradeoffs Accepted

| Tradeoff | Accepted because |
|---|---|
| Spec may be thinner on identity/services when the demo never touches them | The conservative default plus reasoning is recorded in Accepted Decisions; v2 interview revisits. A thin true spec beats a thick speculative one. |
| Demo-script framing biases toward UI-demonstrable products | For APIs/CLIs the demo script is a command transcript ("run X, see Y output"). Same structure, same verification value. |
| Strip-unless-core means some v1 mocks get replaced in v2 | Replacing a mock behind an interface contract is cheap; a blocked Setup Worksheet stalls the whole executor loop. Shipping wins. |
| LLM-emitted state blocks can fail to parse | §5.4 policy: retry once, then hold state. Never advance unparsed. |

---

## 11. Open Questions for Marc

| # | Question | Recommended default |
|---|---|---|
| 1 | Should L2 hard-cap at 5 capabilities, or allow 6-7 with pushback? | Hard cap at 5. The pushback line is the feature. |
| 2 | Demo script length: fixed 3-5 steps, or allow up to 7 for genuinely multi-step products? | 3-5. If it needs 7 steps to prove, the L3 cut wasn't deep enough. |
| 3 | Should the seed list be written to disk mid-interview (survives a crash) or only at spec generation? | At L3 confirmation, to `/ingested/` alongside the project files. Cheap insurance. |
| 4 | Does the v2 interview reuse this exact funnel, or get a shortened variant (L1 reframe + L3 + L4 only)? | Shortened variant, designed when the first v1 ships. |

---

*The Forge · Interview Funnel Redesign Plan v1 · Orbital AI*
*Markup this document directly. Execution produces no code until approved.*
