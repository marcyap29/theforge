---
id: BUG-INTERVIEW-002
area: INTERVIEW
status: Fixed
date_found: 2026-06-12
date_fixed: 2026-06-12
commit: 2a00350
---

# BUG-INTERVIEW-002 — Generate Spec button would never enable — specGenEnabled required layerComplete

## Symptom
Latent bug discovered during BUG-INTERVIEW-001 investigation. Even if the layer advancement bug were fixed, `specGenEnabled` would still never flip `true` because it also required `parse.layerComplete == true` — which the LLM never emits (see BUG-INTERVIEW-001).

## Root cause
`specGenEnabled` computation required both `allResolved` AND `parse.layerComplete`:

```dart
final specGenEnabled = newLayer == 'L4' &&
    parse.layerComplete &&          // ← LLM never emits true
    newConflicts.isEmpty &&
    allResolved;
```

This meant spec generation was gated on a model signal that was permanently `false` by design.

## Fix
Simplified `specGenEnabled` to depend only on Flutter-side state — the 8 confidence dimensions and open conflicts — both of which are derived from the `extracted` map, not from `layerComplete`:

```dart
final specGenEnabled = allResolved && newConflicts.isEmpty;
```

`allResolved` can only be true when L1 fields (outcome, primaryUser), L3 fields (demoScript, v2Seeds), and L4 fields (platform, identityModel, inputModel, outputModel) are all populated — equivalent in practice to the full funnel completing, without depending on any LLM boolean.

**File:** `lib/features/interview/state/interview_notifier.dart`

## Prevention rule
Same rule as BUG-INTERVIEW-001: never gate UI affordances on LLM-emitted booleans when that boolean appears as a hardcoded value in the system prompt template.
