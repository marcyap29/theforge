# FOR MARC — The Interview Funnel Redesign (§IF1)

*Session: 2026-06-11/12 — From turn-counter theater to content-driven state*

---

## Step 1 — Approach and reasoning

The original interview had a fundamental design flaw: it counted turns, not understanding. After 8 user messages, every dimension was marked "resolved" regardless of what was said. A user who typed "I don't know" eight times reached 100% confidence. That's not a confidence meter — that's a timer.

The redesign replaced the flat 8-dimension list with a 4-layer deductive funnel:

- **L1 Outcome** — establish the one thing this app does and who uses it
- **L2 Decomposition** — get the 3-5 capabilities required to deliver it
- **L3 PoC Reduction** — force the "if you could ship only ONE thing right now" cut + 3-5 step demo script
- **L4 Critical Path** — deduce platform, identity, input, output, and services from the demo

Each layer exits when the LLM confirms it. No turn counter. No scripted conflicts. Real content, real advancement.

The mechanism: every LLM response ends with a fenced `forge-state` JSON block. Flutter strips the block before displaying the chat text, parses the JSON, and uses it to drive state. Layer advancement only happens when the extracted fields are populated AND the model says `"layerComplete": true`. Belt and suspenders: Flutter validates even when the model agrees.

The motivation for the demo script (L3) deserves its own explanation. A capability pick alone is fuzzy — "search" could be a text box or a faceted engine. A 3-5 step demo script bounds it exactly: "open the app → type a query → see ranked results with prices." That script does double duty: it becomes the Completion Criteria table in the locked spec, and it becomes the definition of done for the executor loop. The interview produces the /goal's verification surface natively instead of having the spec generator invent it later.

---

## Step 2 — Roads not taken

**Turn counter with content scoring on top.**
The tempting incremental approach: keep the timer, add NLP to score responses, advance only on "good" answers. Rejected because the problem isn't scoring — it's structure. Without a deductive funnel, the user can still nail all 8 dimensions in the wrong order (locking in platform before deciding scope) and produce an over-engineered V1. The funnel enforces the order; no amount of scoring fixes a flat list.

**Full trust in LLM state reporting.**
"Just let the LLM decide when a layer is done" — reject `layerComplete: false` from the JSON and advance anyway. Rejected because LLMs are optimistic. The model will often say "we've covered everything" when there are obvious gaps. Flutter validates the required extracted fields; if `outcome` is still null, L1 is not done regardless of what the model says.

**Multiple LLM calls per turn — one for chat, one for state extraction.**
Cleaner separation of concerns. Rejected for latency: doubling the LLM calls per turn doubles the wait time on every message, and the embedded forge-state block in the chat response is a well-established structured output pattern that works reliably when the system prompt is clear about the requirement.

**Keep the scripted turn-3 conflict.**
The old code injected a fake `corePurpose ↔ identityModel` conflict on user turn 3, every interview, regardless of what was said. Removed completely. Real conflicts emerge from real content when the LLM sees incompatible answers; scripted ones break trust if the user notices they always happen at the same point.

---

## Step 3 — How the pieces connect

Here's the data flow on every turn:

```
User message
    ↓
interview_notifier.dart: addUserMessage()
    ↓
Build system prompt (includes: funnel instructions, current layer, full conversation history, extracted state)
    ↓
LlmService.complete()
    ↓
Raw LLM response
    ↓
parseForgeState() — extracts + strips the ```forge-state block
    ├─→ Parsed extracted map → _confidenceFromExtracted() → updated confidenceMap
    ├─→ layerComplete flag + field validation → layer advancement check
    └─→ conflicts array → openConflicts
    ↓
InterviewState.copyWith() — single immutable state update
    ↓
Chat text (block stripped) → displayed to user
```

`InterviewState` gained two new fields for the redesign:
- `currentLayer: String` — which layer we're on ('L1'–'L4')
- `extracted: Map<String,dynamic>` — the accumulated extracted data

`_confidenceFromExtracted()` maps extracted fields back to the 8 dimension IDs. This kept all downstream consumers (spec generator, handoff package, confidence meter) unchanged — they still read the same `confidenceMap`, they just don't know the funnel changed how it's populated.

`layerBoundaries: Map<String,int>` was added in the UX session (2026-06-18) to enable layer rewind — it stores the turn index where each layer began, so you can truncate the turn history back to any layer start.

---

## Step 4 — Tools and patterns

**forge-state parsing:**
```dart
final pattern = RegExp(r'```forge-state\s*\n([\s\S]*?)\n```');
final match = pattern.firstMatch(raw);
final jsonStr = match?.group(1);
```
The regex is lenient about trailing whitespace before the closing fence — LLMs sometimes add it.

**Safe list cast — the most important pattern in this whole redesign:**
```dart
// WRONG — throws TypeError when LLM outputs "None" (a string, not a list)
'capabilities': (extractedRaw['capabilities'] as List<dynamic>?)?.cast<String>() ?? [],

// RIGHT — check first, then cast
'capabilities': extractedRaw['capabilities'] is List<dynamic>
    ? (extractedRaw['capabilities'] as List<dynamic>).cast<String>()
    : <String>[],
```
This pattern applies to every list field: `capabilities`, `demoScript`, `v2Seeds`, `externalServices`.

**Layer gate function:**
```dart
bool _layerGateMet(String layer, Map<String,dynamic> extracted) {
  return extracted['platform'] != null &&
      extracted['identityModel'] != null &&
      extracted['inputModel'] != null &&
      extracted['outputModel'] != null;
}
```
Used both at interview time (for layer advancement) and at restore time (to re-evaluate `specGenEnabled` from saved data).

**`specGenEnabled` gate:**
```dart
final l4GateMet = _layerGateMet('L4', mergedExtracted);
final specGenEnabled = (allResolved || l4GateMet) && newConflicts.isEmpty;
```
The original gate required ALL 8 confidence dimensions resolved. That was too strict — `externalServices` was always tricky (an empty list is still a list; the check `is List` was always true for the initial empty state). The relaxed gate fires when either all dimensions resolve OR the L4 funnel is complete (all four architectural fields populated).

---

## Step 5 — Tradeoffs

**More turns, not fewer.**
The old timer ended the interview in 8 turns guaranteed. The 4-layer funnel ends when the funnel is complete — which usually takes 10-20 turns for a real product. That's the right tradeoff: a 20-turn interview that produces a usable spec beats an 8-turn interview that produces garbage confidence scores.

**Demo script biases toward UI products.**
"Open the app, do X, see Y" assumes there's an app to open. For APIs and CLIs the demo is a command transcript: "run `forge interview --project myapp`; see Y output." Same structure, same verification value. The funnel works for both; it just sounds more natural for UI products.

**Funnel adds tokens per turn.**
The system prompt includes the current extracted state (serialized JSON of what's been resolved) so the LLM can reason about what's missing. That's maybe 300-500 extra tokens per turn. Small price for accuracy.

**Parse can fail.**
If the forge-state block is missing or malformed, the app holds state (no advancement), displays the text, and sets a `parseDegraded` flag. On the next turn, the system prompt includes a corrective note asking the model to re-emit the block. This is better than the alternative (advancing on any response, or crashing). See Step 7 for the dangerous pattern that made this important.

---

## Step 6 — Mistakes, dead ends, and wrong turns

**The outer try/catch was masking individual field failures.**
The original `parseForgeState()` was:
```dart
try {
  final extracted = json.decode(jsonStr);
  return {
    'capabilities': (extracted['capabilities'] as List<dynamic>?)?.cast<String>() ?? [],
    // ...
  };
} catch (e) {
  return null; // silent failure
}
```
When the LLM outputted `"capabilities": "None"` (a string, not a list), the `as List<dynamic>?` cast threw a `TypeError`. The outer catch caught it and returned `null` — discarding ALL extracted data for that turn, not just the one bad field. The interview could silently degrade over multiple turns, leaving dimensions permanently unknown. The fix: `is List` check per field so each field fails independently, and the `TypeError` never reaches the outer catch.

**`externalServices` confidence was permanently wrong.**
The original code resolved `externalServices` confidence with `is List` — always true for the initial empty `[]`. This meant `externalServices` was often "resolved" from the first turn onward, before any actual external services had been discussed. Fixed: resolve `externalServices` when the other L4 fields are present (platform + identityModel + inputModel + outputModel non-null), since services are established as part of L4.

**`specGenEnabled` was saved to disk and trusted on restore.**
If the user closed the app mid-interview, `specGenEnabled: false` was saved. On restore, the app loaded `false` from the saved state and kept the Generate Spec button hidden even when all L4 data was present. Fixed: `_restoreState` re-evaluates `specGenEnabled` using `_layerGateMet()` on the restored `extracted` map. Never trust a saved boolean for computed state — always re-derive from data.

---

## Step 7 — Pitfalls to watch for

**Never hard-cast LLM list output. Always `is List` first.**
This is the lesson from the `externalServices` TypeError. LLMs can and will output strings, nulls, numbers, or nested objects where you expect a list. The `as List<dynamic>?` cast throws; the enclosing try/catch silently degrades. Defense: check `is List<dynamic>` before every cast.

**Never save computed booleans to disk and trust them on restore.**
`specGenEnabled` is a function of `extracted` + `conflicts`. The function is cheap to run. The saved value is stale the moment the code that computes it changes. Re-derive on every load.

**Layer advancement must be Flutter-side, not LLM-side.**
The LLM proposes (`"layerComplete": true`). Flutter validates (required fields non-null). If Flutter delegates the gate entirely to the LLM, you get interviews that advance to L4 with `outcome: null`.

**Always send full conversation history to stateless LLMs.**
Every `LlmService.complete()` call in the interview sends the full conversation history as the user prompt. The LLM has no memory between calls — it's stateless. If you only send the last message, the LLM has no context and the forge-state block will be inconsistent.

**Model IDs in SharedPreferences outlive code changes.**
If you update the model catalog (rename `gemini-3.5-flash` → `gemini-2.5-flash`), the old string is still in the user's preferences. It will be sent to the API and fail. Validate model IDs on load against the current catalog and fall back to the first valid model if the stored ID isn't found.

---

## Step 8 — What an expert notices

The forge-state block is an instance of **structured output embedded in a conversational response** — a well-established pattern used by function calling, tool use, and chain-of-thought techniques. Embedding the state JSON in the chat text (rather than a separate API call) is clever because it keeps the model's reasoning and its state update causally linked. When the model writes "Great, I think we've established the outcome: For busy professionals, this app manages meeting notes" and then emits `"outcome": "manages meeting notes for busy professionals"` in the state block, the state is grounded in the reasoning that produced it.

The `is List<dynamic>` check pattern is the mature version of defensive programming for typed collections from dynamic sources. The naive version uses `as T?` everywhere and adds `?? []` for nulls. The mature version recognizes that "it could be null" and "it could be the wrong type entirely" are two different failure modes requiring different defenses.

The `_restoreState` insight — never trust saved computed state — is a principle you'll encounter in many forms: React's derived state warning, Redux's recommendation to normalize computed values, React Query's refetch-on-mount default. The underlying idea is always the same: persisted state gets stale; recompute it when you can.

---

## Step 9 — Transferable lessons

**"Content-driven vs. structure-driven validation"** applies everywhere you accept user input for a multi-step process. A wizard that advances pages based on which fields are filled is more honest than one that advances on "Next" clicks. The form might feel slower; the output will be better.

**The forge-state pattern** (embed structured output in a natural language response) is reusable for any situation where you need to drive app state from an LLM conversation. You can use it for extraction, classification, slot-filling — any case where you need both readable text and machine-readable data from the same LLM call.

**"Outer catch hides inner bugs"** is a general principle. Any time you have a broad try/catch around logic with multiple failure points, ask: which failure modes am I actually handling, and which am I accidentally swallowing? The goal is to catch expected failures (network timeout, parsing a valid but empty response) and let unexpected failures surface (TypeError from a wrong-type field). The fix: fine-grained error handling per field, not coarse catching per function.

**The funnel-as-interview-structure** is also a product design principle. Any time you're asking humans a set of questions to extract structured information, ordering matters: get the outcome before the platform, get the proof-of-concept before the architecture. Answering L4 questions (what platform?) before L1 (what does it do?) is how you end up over-engineering a V1.

---

*Session: §IF1 — Interview Funnel Redesign · 2026-06-11/12 · The Forge · Orbital AI*
