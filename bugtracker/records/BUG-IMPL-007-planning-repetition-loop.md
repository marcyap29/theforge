# BUG-IMPL-007 — Build planning stuck in a repetition loop

**ID:** BUG-IMPL-007
**Area:** IMPL
**Severity:** High
**Status:** Fixed 2026-09-12

---

## Symptom

On a "Fix errors" / follow-up run for AR Mechanic, the build console filled with
the model reprinting the same ~1,500-char reasoning paragraph hundreds of times
("Internal thinking · 227 lines", doubled) and never produced a plan — burning
the whole token budget and effectively hanging the run.

## Root Cause

Two compounding problems:

1. **Contradictory prompt.** The plan system prompt asserted *"You already have
   all the files you are going to get (their CURRENT contents are provided
   below)."* But the plan user prompt only appends a `## Current file contents`
   section when the scout actually read files. When `readFiles` was empty, the
   model was told contents were below, saw none, and spiralled trying to
   reconcile the gap (the pasted reasoning literally repeats "it says contents
   are provided below… but they are not").
2. **No degeneration guard.** Nothing detected the runaway repetition, so the
   stream ran to the 16k-token cap producing garbage instead of failing fast.

## Fix

- **Accurate prompt** (`impl_agent.dart`): the system prompt no longer claims
  contents are always below — it says to work only with what's in the message,
  create missing files as NEW files or use commands, and explicitly "do NOT
  repeat yourself." When the scout reads nothing, the plan prompt adds a `## No
  existing file contents were included` note so there's no contradiction.
- **Loop guard** (`_stream` + `_looksLooping`): watches all emitted text
  (thinking + content); if the last ~500 chars already appear verbatim earlier
  within the last 12k chars (an exact long repeat normal generation never
  produces), it aborts the stream and throws a clear `ImplAgentException`
  ("The model got stuck repeating itself…"), which fails the run gracefully with
  a tip to use an instruction-following/coder model.

## Prevention Rule

See BUG_PREVENTION.md — "A prompt must never claim context that isn't actually
included; and any long-running model stream needs a degeneration/repetition
guard so a looping model fails fast instead of burning the whole budget."

## Commit

v0.4.14
