# BUG-LLM-001 — Reasoning models stream nothing (console sits on "Planning…")

**ID:** BUG-LLM-001
**Area:** LLM
**Severity:** High
**Status:** Fixed 2026-09-10

---

## Symptom

On "Build with AI" the console sat on "Planning…" for minutes with no output —
it looked stuck or broken. Import/Scan (which are non-streaming) worked fine.

## Root Cause

Reasoning models (glm-5.3, gpt-oss:120b) stream their chain-of-thought in
Ollama's `message.thinking` field with an **empty** `message.content` until
reasoning finishes. The streaming code only read `content`, so it yielded
nothing during the (long) thinking phase — leaving the UI with no signal that
the model was working.

## Fix

- `LlmProvider.completeStream` now yields a typed `LlmDelta{text, thinking}`.
- Ollama surfaces `thinking` deltas (Claude handles `thinking_delta`).
- The agent buffers only `content` for parsing, while the UI shows the reasoning
  live as real, scrollable lines (dim) — visually distinct from the green
  external "Summary".
- Added a wait-heartbeat while awaiting the first token so the UI never looks
  frozen.

## Prevention Rule

See BUG_PREVENTION.md — "When streaming an LLM, surface BOTH content and
reasoning/thinking deltas; a model that emits empty content during a long
thinking phase must not look stuck. Add a wait-heartbeat while awaiting the
first token."

## Commit

`38e92be`, `21813f8`, `7654ab7`
