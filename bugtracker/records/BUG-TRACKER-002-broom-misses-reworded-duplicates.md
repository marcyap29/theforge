# BUG-TRACKER-002 — "Remove duplicates" silently misses reworded duplicates

**ID:** BUG-TRACKER-002
**Area:** TRACKER
**Severity:** High
**Status:** Fixed 2026-09-16

---

## Symptom

The **Remove duplicates** (broom) tool reported no/too-few duplicates and left
obvious reworded pairs on the board — e.g. "Camera Permission & Live Feed" vs
"Camera Permission Request", "Camera Retry Mechanism" vs "Camera Retry Logic",
"Text Instruction Overlay" vs "Text Instruction Overlays". The exact-title pass
can't catch these, and the semantic (LLM) pass appeared to do nothing.

## Root Cause

Two compounding flaws in `FeatureDeduplicator`:

1. **Silent swallow.** The semantic pass was wrapped in `try { … } catch (_) {}`,
   so any failure (the Architect model returning non-JSON — glm-5.3 ignores JSON
   mode on Ollama Cloud) was discarded and the broom fell back to exact-only,
   then reported "No duplicates found." The user had no idea the AI pass failed.
2. **Brittle parse.** `_llmGroups` only accepted `{"groups":[[…]]}` and, for any
   other valid shape, returned an **empty list with no error** — so even a
   JSON-clean model that answered with a bare array `[[1,4],…]` produced zero
   groups silently. No retry, no tolerance for fences/prose.

## Fix

- `_extractGroups`: tolerant parse — handles code fences, surrounding prose, an
  object `{"groups":[…]}`, OR a bare `[[…]]` array; returns int-lists.
- `_llmGroups`: retries once with a firm JSON-only reminder; **throws** with the
  raw snippet if still unusable (no more silent empty).
- `findDuplicates` returns a `DedupResult { groups, semanticOk, error }`; the
  semantic failure is logged to `diag.log` (`DiagLog.error('dedup.semantic', …)`)
  and, when nothing was found because the AI pass couldn't run, the broom shows a
  clear dialog telling the user to switch the Architect model to a JSON-clean one
  (qwen3.5:cloud) — instead of the misleading "No duplicates found."

## Prevention Rule

See BUG_PREVENTION.md — "Never `catch (_) {}` a best-effort AI pass into silence:
log it and report whether it ran, or the feature lies about its results. And
tolerant-parse model JSON (object OR bare array OR fenced) — don't require one
exact shape."

## Commit

v0.4.33
