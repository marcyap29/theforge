# FOR_MARC — Cross-Cutting Invariant Extraction (§CCI)

**Topic:** How we built the system that automatically extracts architectural rules from an ingested codebase and threads them through the Pull Mode pipeline.

---

## Step 1 — The problem we were solving

After Pull Mode runs its ingestion engine, you have a list of components, dependencies, and infrastructure patterns. But there's a category of knowledge that isn't in any single file: rules that apply *across* multiple components. Things like "all writes go through the audit subcollection" or "no executor starts without a complete project folder." These are the rules that, when violated, break the whole system — and they're invisible to a per-file extraction pass.

That's the gap §CCI fills. After ingestion, we run a second LLM pass over the whole ingestion summary and ask it: "What rules apply across multiple components, and what breaks if they're violated?" The result is a list of `ExtractedInvariant` objects, stored in the `IngestionSummary`, surfaced in the as-built spec, and used to prime the pull interview when confidence is low.

---

## Step 2 — Roads not taken

**Option A: Extract invariants per-file during the component extraction pass.**
Rejected. Per-file extraction sees one component at a time. Cross-cutting rules require seeing multiple components together — you can't identify "all writes go through the repo layer" by reading one file. The invariant extraction pass needs the aggregated ingestion summary as its context.

**Option B: Hard-code a list of "standard" invariants for all projects.**
Rejected. Every project has different rules. A hard-coded list would be mostly wrong and would train engineers to ignore the section.

**Option C: Extract invariants during the pull interview (ask the engineer).**
Partially adopted. High- and medium-confidence invariants are extracted automatically from code. Low-confidence invariants surface in the pull interview as targeted questions — because the LLM isn't sure, so the engineer should confirm. The hybrid approach is more honest about what the LLM actually knows.

---

## Step 3 — How the pieces connect

```
startIngestion()
  scanning → processing → aggregating → done
                              ↑
                     InvariantExtractor.extract(
                       referenceContext: summary.toMarkdown(),
                       components: allComponents,
                     )
                              ↓
                   summary.copyWith(invariants: invariants)
                              ↓
                   writeIngestionSummary() — single write

IngestionSummary
  → invariants: List<ExtractedInvariant>    stored in JSON
  → toMarkdown()                            §CCI section
  → lowConfidenceInvariants getter          filtered list for interview

PullIngestionSummaryScreen
  → _buildSummaryCard()        count row ("N cross-cutting rules")
  → _buildInvariantsSection()  confidence badge + full details per rule

AsBuiltSpecGenerator
  → §2a Cross-Cutting Invariants in the spec template
  → summary.toMarkdown() includes §CCI automatically

PullInterviewNotifier
  → _buildGreeting()       mentions low-confidence count
  → _buildSystemPrompt()   LOW-CONFIDENCE INVARIANTS block with rule + source
```

The key architectural choice: invariants live on `IngestionSummary`. They're not a separate file, a separate provider, or a separate database table. The summary is already the canonical output of Pull Mode — extending it keeps the data flow simple.

---

## Step 4 — The LLM call design

The `InvariantExtractor` uses these two roles:

**System prompt (constant):**
> You are a senior software architect. Extract cross-cutting invariants — rules that apply across multiple components and would cause bugs or system failures if broken. Output a JSON array only. No prose, no code fences. Maximum 10 invariants. Only include rules that span 2+ components.

**User prompt (built from data):**
> INGESTION SUMMARY: {summary.toMarkdown()}
> COMPONENT LIST: {name: responsibilities, ...}
> Extract cross-cutting invariants from this codebase.

Temperature 0.2, maxTokens 4096. Low temperature because this is a structured extraction task, not creative synthesis.

The response is a JSON array — not an object with an `invariants` key. The parser strips fences, then checks `decoded is List<dynamic>` before iterating. If anything goes wrong (malformed JSON, fences, empty response), `_parseInvariants()` returns `const []` and the ingestion completes cleanly with zero invariants.

---

## Step 5 — The safe JSON parse pattern

This is a pattern worth remembering. Any time you're asking an LLM to return structured data:

```dart
List<ExtractedInvariant> _parseInvariants(String raw) {
  try {
    // 1. Strip fences — LLMs add these even when you tell them not to
    final cleaned = raw
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    
    // 2. Decode
    final decoded = jsonDecode(cleaned);
    
    // 3. Check the type BEFORE casting — never assume
    if (decoded is! List<dynamic>) return const [];
    
    // 4. Iterate safely — check each item
    final result = <ExtractedInvariant>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        result.add(ExtractedInvariant.fromJson(item));
      }
    }
    return result;
  } catch (_) {
    // 5. Catch everything — LLM output is not guaranteed
    return const [];
  }
}
```

And in `fromJson()`, every string field is `as String? ?? ''`, never `as String`. Because the LLM can return null for a field you told it was required. It does this. Plan for it.

---

## Step 6 — The mistakes DeepSeek made (and what we fixed)

**Mistake 1: System/user prompt swapped.**
DeepSeek put the data context (ingestion summary + component list) as the `systemPrompt` and the instruction string ("List all cross-cutting invariants") as the `userPrompt`. This is backwards — system prompt is for instructions, user prompt is for data. The call would have worked (LLMs are flexible about this) but it's wrong by convention and makes the intent harder to read.

**Mistake 2: Wrong expected JSON shape.**
DeepSeek's parse did `jsonDecode(response) as Map<String, dynamic>` then `json['invariants'] as List<dynamic>`. But the system prompt says to return a plain array, not `{"invariants": [...]}`. The LLM would return `[...]` and the cast would throw. Parse and prompt must be written together — verify that what you ask the LLM to return matches what you try to decode.

**Mistake 3: Double write.**
DeepSeek wrote the summary to disk once before extraction (with `invariants: const []`) and then again after extraction. The first write produces a stale file that gets immediately overwritten. The correct pattern is a single write after extraction. The `aggregating` state transition signals to the UI that extraction is happening between processing and done.

**Mistake 4: Didn't use `copyWith`.**
We added `copyWith()` to `IngestionSummary` specifically so the notifier could do `summary.copyWith(invariants: invariants)`. DeepSeek instead manually reconstructed the whole `IngestionSummary` with every field spelled out. Not a bug, but if you add `copyWith()` for a reason, use it — it's shorter and it won't miss a field if the model grows.

**Mistake 5: Missing `fromJson()` parse.**
DeepSeek added the `invariants` field to `toJson()` (so it writes to disk) but forgot to add the corresponding parse in `fromJson()`. Result: invariants would be written to disk on the first run, but when you read the summary back, they'd be gone (falling back to `const []`). Always update both directions together.

---

## Step 7 — Backward compatibility for model changes

When you add a field to a model that gets serialized to disk (JSON), old files on disk won't have that key. The safe pattern for `fromJson()`:

```dart
invariants: json['invariants'] is List<dynamic>
    ? (json['invariants'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(ExtractedInvariant.fromJson)
        .toList()
    : const [],
```

The `is List<dynamic>` check handles three cases:
1. Key doesn't exist → `json['invariants']` returns null → `null is List<dynamic>` is false → `const []`
2. Key exists with correct type → proceeds to parse
3. Key exists with wrong type (shouldn't happen, but) → `const []`

This is the correct pattern any time you add a field to an existing serialized model. Never use a required constructor param for a new field if old data might not have it — use `this.field = defaultValue` and a safe parse.

---

## Step 8 — What an expert notices

The `InvariantExtractor` is a plain class, not a Riverpod notifier. It has no state. You construct it, call `extract()`, get a list, throw the extractor away. This is intentional.

Riverpod notifiers are for state that the UI watches. `InvariantExtractor` has no state the UI cares about — it's a pure function from `(LlmService, referenceContext, components)` to `List<ExtractedInvariant>`. Making it a notifier would add lifecycle boilerplate for no benefit. The notifier that *uses* it (`PullIngestionNotifier`) handles the state management.

The pattern: "LLM wrapper classes are plain classes; the state machines that orchestrate them are notifiers." Keep them separate.

Also: the `lowConfidenceInvariants` getter on `IngestionSummary` is computed on every call — no caching. That's fine because:
1. `List.where().toList()` on a ≤10 element list is microseconds
2. `IngestionSummary` is `@immutable` (conceptually — Dart doesn't enforce this here), so the result is stable
3. If you cached it, you'd need to invalidate the cache on `copyWith`, which adds complexity for zero benefit

Three similar computed properties in one class would be a candidate for `lazy final`. One is fine as a getter.

---

## Step 9 — Transferable lessons

**Prompt and parse must be designed together.** If your system prompt says "return a JSON array," your parser must expect a `List<dynamic>`, not a `Map`. Write them side by side. Read both before you commit.

**One write, not two.** If you're generating data and then writing it to disk, do one write with the complete data. Two writes means the first write is stale the moment the second write happens. The only valid reason for two writes is if you want an intermediate checkpoint in case the second operation fails — and in that case, the checkpoint should be to a different file (e.g., a `.tmp` file).

**Add `copyWith()` to models when downstream code needs to update one field.** `IngestionSummary` didn't have `copyWith()` before §CCI. We added it so the notifier could do `summary.copyWith(invariants: invariants)` instead of reconstructing the full object. This saves 10 lines and eliminates the risk of missing a field in the reconstruction.

**`is List<dynamic>` before every LLM-returned list cast.** LLMs can return null, a string, an empty string, a JSON object instead of an array, or malformed JSON. None of these are `List<dynamic>`. The `is` check catches all of them without a try/catch per field.

**Low-confidence information should ask, not assert.** Invariants the LLM isn't sure about don't get silently included in the as-built spec — they surface as interview questions. The engineer confirms or rejects them. This is the right trust boundary: use the LLM for pattern detection, use the human for confirmation. Don't trust LLM output enough to assert facts it's uncertain about.
