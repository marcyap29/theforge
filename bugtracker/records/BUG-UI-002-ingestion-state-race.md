---
id: BUG-UI-002
area: UI
status: Fixed
date_found: 2026-06-10
date_fixed: 2026-06-10
---

# BUG-UI-002 — IngestionNotifier state race from concurrent initState callers

## Symptom
After adding a reference doc via `ReferenceDocsScreen`, the doc list on the interview screen flickered and the in-flight document disappeared from the list. Returning to the docs screen showed the state had reverted.

## Root cause
`interview_screen.dart` called `ingestionNotifierProvider.notifier.loadDocs(path)` from its `initState`. When the user navigated to the interview screen while `addDoc()` was still completing an LLM call on `ReferenceDocsScreen`, two async writers ran concurrently on the same `IngestionState` — producing interleaved state updates that overwrote the in-flight doc.

`IngestionNotifier` is a global non-AutoDispose `Notifier`. Two widgets both writing to it from `initState` is a race.

## Fix
Removed the `loadDocs()` call from `interview_screen.dart`'s `initState` entirely. The interview screen only watches the notifier passively via `_DocCountChip` — it does not need to trigger a load.

**File:** `lib/features/interview/ui/interview_screen.dart`

## Prevention rule
See `bugtracker/BUG_PREVENTION.md` — Common Anti-Patterns:
> Multiple `initState` callers on a global Notifier — secondary screens should watch passively; only the screen that owns the interaction should trigger explicit loads.
