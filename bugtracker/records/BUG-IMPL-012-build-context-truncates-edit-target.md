# BUG-IMPL-012 — Build-with-AI truncates large files, so the model edits code it can't see → unbalanced-bracket breaks + Fix-it loops

**ID:** BUG-IMPL-012
**Area:** IMPL
**Severity:** High (makes Build unusable on any non-trivial file; corrupts the target repo)
**Status:** Fixed 2026-10-02

---

## Symptom

Building a feature into AR Mechanic (`lib/main.dart`) failed **on every model**
(kimi-k2.6, kimi-k3, minimax-m2.7): the model's edit introduced a syntax error
(unbalanced `)`/`]`/`}`), the file stopped compiling, and the "Fix it" retry got
**stuck repeating itself** ("the model got stuck repeating itself and was
stopped"). minimax even wrote a Python format spec in Dart
(`'${sm.progress * 100:.0f}%'`) and said out loud: *"the file content shown is
truncated at that point."*

## Root Cause

**The Forge truncated each file it sent to the model to 24,000 characters**
(`impl_agent.dart`, Pass-2 read: `if (c.length > 24000) c = …(truncated)`).

- AR Mechanic `lib/main.dart` = **56,363 chars**.
- Char 24,000 lands at **line 735**.
- The method the model needed to edit, `_buildInstructionOverlay()`, is at
  **line 685**, and its body runs well past line 735.

So the model saw the method's *start* but its body was **cut off mid-method**
with `…(truncated)`. It could not construct a find/replace hunk that matches real
code, so it **guessed** — producing unbalanced delimiters. The broken code then
landed *past the cut too*, so every "Fix it" pass was equally blind and **looped**.
This is why every model failed identically: none of them could see the code they
were editing. Not a model problem — a context-truncation bug.

## Fix

Raised the Pass-2 read caps in `impl_agent.dart` so real-world files arrive whole:

- Per-file cap: **24,000 → 80,000** chars (named `perFileCap`).
- Total read budget: **90,000 → 150,000** chars.

The total budget remains the real guardrail against overflowing the model's
context window; the per-file cap just must not be smaller than a single important
file the budget can afford. An 80k cap covers the vast majority of source files
whole (AR Mechanic's 56k file now arrives complete).

## Prevention Rule

See `BUG_PREVENTION.md` — "Never send an AI code-editor a **truncated** copy of a
file it is expected to edit. A find/replace agent that can't see the target code
guesses and emits unbalanced delimiters; the broken output then sits past the cut
so the fix pass is equally blind and loops. Per-file content caps must be ≥ a
single important file within the total budget; the TOTAL budget (not a small
per-file cap) is the context-window guardrail. Prefer sending edit-target files
whole."

## Related

Compounded the model-choice issue ([[theforge-forge-model-choices]]): base kimi
loops on Build regardless, but even a capable model can't edit code it can't see.

## Commit

v0.5.7
