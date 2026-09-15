# BUG-IMPL-004 — Build with AI "Planning failed: did not return valid JSON"

**ID:** BUG-IMPL-004
**Area:** IMPL
**Severity:** High
**Status:** Fixed 2026-09-10

---

## Symptom

On "Build with AI", the scout pass succeeded ("Read 9 files…") but the plan
pass ended with **"Planning failed: The agent did not return valid JSON."** The
console showed the model (glm-5.3, a heavy reasoning model) thinking at length —
it even wanted to open another file (`forge_database.dart`) to see the data
model — and never emitted a parseable JSON plan.

## Root Cause

Two compounding issues with reasoning models:
1. The model spent its whole turn in the `thinking` channel (reasoning, and
   trying to "request" more files, which the fixed two-pass loop can't grant)
   and produced no valid JSON object in the `content` channel that `_parse`
   reads.
2. Token budget: the plan pass allowed only `maxTokens: 4000`, and — more
   importantly — the Ollama provider never sent `num_predict`, so generation
   length was unmanaged; a long reasoning phase could starve the answer.

## Fix

- Ollama `complete`/`completeStream` now pass `num_predict = maxTokens` so the
  model has a generous, explicit ceiling for thinking + answer.
- Plan-pass budget raised to 8000 (scout to 4000) so the cap is a safety
  ceiling, not a starvation limit for a model that thinks a lot.
- Stronger plan prompt: "You already have all the files you'll get — do NOT ask
  to open more files, do NOT stop to explain; your entire final answer MUST be
  the JSON object." Scout prompt now asks it to include data-model/schema files.
- **Auto-retry once** on a parse failure: if the plan pass doesn't yield valid
  JSON, the agent asks once more, firmly, for JSON only before failing.

## Follow-up (v0.4.17) — truncation cause of the same symptom

The same "did not return valid JSON" message later recurred with a *strong* model
(glm-5.3:cloud) for a different reason: a large multi-file plan (several code
hunks) **overran the output-token budget and was cut off mid-JSON**, so it
couldn't parse. The raw-output tail (surfaced since v0.4.5) ended inside
`"hunks": [ {` with no closing braces — the tell-tale of truncation, not
malformed output.

Fix: raised the plan-pass ceiling 16k → 32k (`_planTokens`), and made the retry
**truncation-aware** — `_looksTruncated` (JSON started but never closed) switches
the retry to ask for a *smaller, focused* plan (fewest/smallest hunks) instead of
the generic "output valid JSON" nudge, which just truncated again.

## Prevention Rule

See BUG_PREVENTION.md — "Reasoning models may spend a turn thinking and never
emit the answer: give a generous token ceiling (`num_predict`), forbid
'asking for more files', force JSON-only output, and auto-retry once before
failing." Prefer an instruction-following/coder model for Build with AI.

## Commit

`0497ac6`+ (follow-up v0.4.2)
