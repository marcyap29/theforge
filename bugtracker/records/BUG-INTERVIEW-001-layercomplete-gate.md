---
id: BUG-INTERVIEW-001
area: INTERVIEW
status: Fixed
date_found: 2026-06-12
date_fixed: 2026-06-12
commit: 2a00350
---

# BUG-INTERVIEW-001 — Interview funnel stuck at L1 — layerComplete gate never satisfied

## Symptom
Build Interview loops on L1 questions indefinitely. User receives the same "what does this app do?" / "who is the user?" questions on every turn regardless of answers given. Layer never advances to L2. Reported after 20+ turns with no progress.

## Root cause
`_buildFlow` in `interview_notifier.dart` gated layer advancement on `parse.layerComplete == true`:

```dart
if (parse.layerComplete && parse.layer != null) {
  if (_layerGateMet(parse.layer!, mergedExtracted)) {
    newLayer = _nextLayer(parse.layer!);
  }
}
```

The `forge-state` JSON template in `_buildInterviewSystemPrompt` showed `"layerComplete": false` hardcoded as the example value. LLMs copy example values from the template literally — the model never emitted `true`, so the Flutter side never advanced the layer regardless of what fields the model populated in `extracted`.

## Fix
Removed `parse.layerComplete` as a gate. Flutter side is now authoritative: advance the layer when `_layerGateMet()` passes on the current `extracted` map, independent of any LLM signal.

```dart
// Before
if (parse.layerComplete && parse.layer != null) {
  if (_layerGateMet(parse.layer!, mergedExtracted)) {
    newLayer = _nextLayer(parse.layer!);
  }
}

// After
if (_layerGateMet(withUser.currentLayer, mergedExtracted)) {
  newLayer = _nextLayer(withUser.currentLayer);
}
```

**File:** `lib/features/interview/state/interview_notifier.dart`

## Prevention rule added to BUG_PREVENTION.md
> Never gate Flutter state transitions on a boolean the LLM emits when that same boolean appears as `false` in the system prompt template. The LLM copies the example value literally. Make the app authoritative for state advancement; use LLM output only for data extraction.
