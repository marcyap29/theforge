# FOR MARC — Interview UX, State Persistence, Layer Rewind, and the Parse Bug

*Session: 2026-06-18/19 — The Forge interview UX overhaul*

---

## 1. What we built

Five distinct improvements to the interview experience, plus three critical bug fixes that were silently breaking spec generation. Let's go through each one.

---

## 2. Keyboard handling: Enter sends, Shift+Enter adds a line

**The pattern: `FocusNode.onKeyEvent`**

Flutter `TextField` has two options for handling Enter:
- `onSubmitted` — fires when Enter is pressed (but only works well with `textInputAction: TextInputAction.send`)
- `FocusNode.onKeyEvent` — intercepts raw keyboard events before the field processes them

We use `onKeyEvent` because it lets us distinguish plain Enter (send) from Shift+Enter (newline):

```dart
_composerFocus = FocusNode(onKeyEvent: (node, event) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  if (event.logicalKey != LogicalKeyboardKey.enter) return KeyEventResult.ignored;
  if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored; // let newline through
  if (!_isLoading) _send();
  return KeyEventResult.handled; // consume the event, don't insert newline
});
```

**The named pattern:** "keyboard event pre-emption" — intercept → check modifier keys → either handle it yourself (return `handled`) or pass it through (return `ignored`).

The field also needs `keyboardType: TextInputType.multiline` so Shift+Enter actually inserts a newline when we let it through.

---

## 3. Auto-scroll on AI response

**The problem:** `_scrollToBottom()` was only called after the user sent a message. The AI response came in later (async) and didn't trigger a scroll.

**The fix:** `ref.listen` in `build()`:

```dart
ref.listen(interviewProvider(args), (prev, next) {
  final prevLen = prev?.valueOrNull?.turns.length ?? 0;
  final nextLen = next.valueOrNull?.turns.length ?? 0;
  if (nextLen > prevLen) _scrollToBottom();
});
```

`ref.listen` fires on every state change. When the turn count goes up (either the user's turn or the AI's response), we scroll. This works for BOTH directions.

**The named pattern:** "reactive side effects" — use `ref.listen` (not `ref.watch`) when you need to trigger an action (scroll, focus, play sound) in response to state changes, without rebuilding the widget tree.

---

## 4. Interview state persistence (survive app close)

**The problem:** `InterviewNotifier` is a `FamilyAsyncNotifier`. When the app closes, ALL Riverpod state is gone. The user would lose their entire interview.

**The fix:** Write to disk after every LLM response.

```dart
// In _buildFlow, after updating state:
await repo.writeInterviewProgress(
  withUser.projectPath,
  withUser.projectName,
  _progressPayload(state.requireValue),
);
```

`_progressPayload` serialises turns, confidenceMap, extracted data, specGenEnabled, layerBoundaries, and currentLayer to JSON. On next launch, `build()` reads it:

```dart
final saved = await repo.readInterviewProgress(args.path, args.name);
if (saved != null && (saved['turns'] as List?)?.isNotEmpty == true) {
  return _restoreState(empty, saved);
}
return _withOpener(empty, args);
```

**One subtlety:** when restoring, don't blindly trust `specGenEnabled` from the saved file. It might have been `false` because of a bug in the old code. Re-evaluate it:

```dart
final specGenEnabled = savedSpecGen || _layerGateMet('L4', restoredExtracted);
```

**The named pattern:** "checkpoint-based persistence" — write the full state after every atomic unit of work (LLM response) so you can restore exactly where you left off. Don't try to save only on exit — that's unreliable (crash, force quit, battery death).

---

## 5. Turn rewind and layer rewind

**Turn rewind** (tap "edit" on a user bubble): truncate the turns list to before that turn, put the text back in the composer. The notifier's `rewindTo(i)` method:

```dart
void rewindTo(int turnIndex) {
  state = AsyncData(current.copyWith(
    turns: current.turns.sublist(0, turnIndex),
    isLoading: false,
    openConflicts: const [],
    specGenEnabled: false,
    currentLayer: current.currentLayer.isNotEmpty ? 'L1' : '',
  ));
}
```

**Layer rewind** (tap a completed L1/L2/L3 dot): more complex because we need to know WHERE in the turns list each layer started. We track this with `layerBoundaries`:

```dart
// When L2 starts (during L1→L2 transition):
newBoundaries['L2'] = withUser.turns.length + 1;
// (+1 because we're about to add the transition AI response)
```

Then `rewindToLayer('L2')`:
1. Truncate turns to `layerBoundaries['L2']`
2. Clear L2+ extracted data (capabilities, chosenCapability, demoScript, v2Seeds, platform, etc.)
3. Re-derive confidence map from the remaining extracted data
4. Set `currentLayer = 'L2'`

**The key insight:** the boundary is stored AFTER the transition AI response. So when you rewind to L2, you still see the AI's "great, now let's explore capabilities" message — the natural re-entry point.

---

## 6. The parse TypeError bug (BUG-INTERVIEW-004)

**This was the most subtle and painful bug.**

```dart
// WRONG — throws TypeError if LLM outputs "None" (a string)
'externalServices':
    (extractedRaw['externalServices'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        <Map<String, dynamic>>[],
```

What happens:
1. LLM outputs `"externalServices": "None"` (a string, not a list)
2. `as List<dynamic>?` throws `TypeError`
3. The outer `try/catch` in `parseForgeState` catches it → returns `degradedResult()` with `extracted: null`
4. `_buildFlow` sees `parse.extracted == null` → doesn't merge anything
5. `externalServices` in `mergedExtracted` keeps the initial `[]` value... but it had already been overwritten by a string from an EARLIER degraded turn
6. `_confidenceFromExtracted` sees a string → `externalServices is List` = false → dimension stays Unknown
7. `allResolved = false` → `specGenEnabled = false` → button never appears

**The fix:**
```dart
// CORRECT — normalise non-list to empty list
'externalServices': extractedRaw['externalServices'] is List<dynamic>
    ? (extractedRaw['externalServices'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList()
    : <Map<String, dynamic>>[],
```

Same fix applied to `capabilities`, `demoScript`, `v2Seeds`.

**The named pattern:** "defensive JSON parsing" — when parsing LLM output, never use hard casts (`as Type`). Always use `is Type` check first. LLMs are creative — they'll output strings where you expect lists, numbers where you expect strings, objects where you expect strings. Any hard cast is a potential parse bomb.

---

## 7. The specGenEnabled gate was too strict

Even after fixing the parse bug, there's a deeper problem: `specGenEnabled = allResolved` requires ALL 8 dimensions to be resolved. If any one dimension fails to resolve (for any reason), the user is permanently stuck.

The fix: relax the gate to also fire when the L4 funnel is complete:

```dart
final l4GateMet = _layerGateMet('L4', mergedExtracted);
final specGenEnabled = (allResolved || l4GateMet) && newConflicts.isEmpty;
```

`_layerGateMet('L4', ...)` checks that platform, identityModel, inputModel, and outputModel are all non-null. That's the real signal that the interview is done — the user has answered all the structural questions. Individual confidence dimension tracking is a derivative signal that can silently fail.

**The principle:** design your gates around **data presence** (did the LLM actually extract this value?), not **derived state** (did our code correctly credit it to the confidence map?). Data presence is observable; derived state can fail silently.

---

## 8. Model ID validation

**The problem:** SharedPreferences persists across app updates. When we updated `llm_model_config.dart` to remove `gemini-3.5-flash` (which never existed), users who had it stored got API 404 errors every time they tried to use Gemini.

**The fix:** validate on load:

```dart
final validIds = modelsFor(providerType).map((m) => m.id).toSet();
final modelId = validIds.contains(savedModelId)
    ? savedModelId
    : modelsFor(providerType).firstOrNull?.id ?? 'gemini-2.5-flash';
```

**The principle:** anything that persists across code versions needs a migration strategy. For model IDs, the strategy is: if the ID isn't in the current catalog, fall back to the first valid model. The user might be mildly surprised, but they won't be stuck.

---

## Summary table

| Feature | Pattern | Key file |
|---|---|---|
| Enter = send, Shift+Enter = newline | `FocusNode.onKeyEvent` | `interview_screen.dart` |
| Auto-scroll on AI response | `ref.listen` reactive side effect | `interview_screen.dart` |
| State survives app close | Checkpoint persistence after every LLM response | `interview_notifier.dart` |
| Layer rewind | Boundary tracking + extracted data rollback | `interview_notifier.dart` |
| Turn rewind | Turns list truncation | `interview_notifier.dart` |
| Parse bug fix | Defensive `is List` check, never hard cast | `interview_notifier.dart` |
| Gate relaxation | `allResolved || l4GateMet` | `interview_notifier.dart` |
| Model ID validation | Validate stored IDs on settings load | `settings_notifier.dart` |
