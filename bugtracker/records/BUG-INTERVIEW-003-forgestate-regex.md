---
id: BUG-INTERVIEW-003
area: INTERVIEW
status: Fixed
date_found: 2026-06-12
date_fixed: 2026-06-12
commit: 2a00350
---

# BUG-INTERVIEW-003 — forge-state block silently dropped on trailing whitespace before closing fence

## Symptom
When any LLM emits the `forge-state` JSON block with trailing whitespace or `\r\n` line endings before the closing triple-backtick fence, `parseForgeState` returns `parseOk: false`, sets `parseDegraded: true`, and neither extracted fields nor layer state are updated. The conversation continues (the visible LLM text renders normally) but all state advancement is silently suppressed.

Compounds BUG-INTERVIEW-001: even if the LLM correctly populates `extracted` fields, a trailing space on the closing fence line causes the entire block to be discarded.

## Root cause
The regex required an exact `\n` before the closing fence with no intervening whitespace:

```dart
final fencePattern = RegExp(r'```forge-state\s*\n([\s\S]*?)\n```');
//                                                            ^^^
//                              requires newline + ``` with nothing between
```

Any trailing space (`\n   ``` `), Windows line ending (`\r\n``` `), or blank line before the fence caused a non-match. Gemini and some OpenAI models routinely add trailing spaces or use `\r\n` in structured output.

## Fix
Made the pattern lenient on whitespace immediately before the closing fence:

```dart
final fencePattern = RegExp(r'```forge-state[^\n]*\n([\s\S]*?)\n\s*```');
//                                                              ^^^^
//                              \s* allows any whitespace (spaces, \r) before ```
```

Also tightened the opening fence pattern (`[^\n]*` instead of `\s*`) to avoid accidentally matching a fence that is on a different line.

**File:** `lib/features/interview/state/interview_notifier.dart`

## Prevention rule added to BUG_PREVENTION.md
> When writing RegExp patterns to match LLM-emitted code fences, always use `\n\s*` before the closing fence, not `\n` alone. LLMs from different providers vary on trailing whitespace and line ending style (`\n` vs `\r\n`). A strict closing-fence pattern silently drops the entire block rather than erroring visibly.
