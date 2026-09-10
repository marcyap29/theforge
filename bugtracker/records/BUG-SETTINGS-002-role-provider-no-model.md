# BUG-SETTINGS-002 — Role with a provider but no model breaks every LLM call

**ID:** BUG-SETTINGS-002
**Area:** SETTINGS
**Severity:** High
**Status:** Fixed 2026-09-10

---

## Symptom

Scan, Import, and Check-in all failed — sometimes with a red "No model selected
for architect role" error, sometimes appearing to do nothing. The provider and
API key were configured correctly, yet every LLM-backed feature errored.

## Root Cause

Changing a role's **provider** in Settings cleared its model and did not
reselect one — the provider dropdown's `onChanged` created
`ModelAssignment(providerType: p, modelId: '')`. `LlmService.complete` then
threw `Exception('No model selected for <role> role')` because `modelId` was
empty. The load-time fallback only applied on a fresh read from prefs, so an
in-session provider change left the role with a blank model that persisted.

## Fix

- Settings: the provider dropdown now auto-selects the provider's first model on
  change — `modelsFor(p).firstOrNull?.id` — so a role can never be left with a
  provider but no model. (`lib/features/settings/settings_screen.dart`)
- Defensive: `LlmService.complete` falls back to the provider's first model when
  the assignment's `modelId` is empty, instead of throwing.
  (`lib/services/llm/llm_service.dart`)

## Prevention Rule

See BUG_PREVENTION.md — "A role provider selection must always carry a valid
model; never persist a role with an empty modelId."

## Commit

`6f677c0`
