# BUG-UI-004 — TextEditingController created inline in build() — memory leak + stale text

**ID:** BUG-UI-004
**Area:** UI
**Severity:** Medium
**Status:** Fixed 2026-10-14

---

## Symptom

In the Build Brief dialog, a `TextEditingController` was constructed inline inside
a `StatelessWidget.build()` method:

```dart
TextField(
  controller: TextEditingController(text: brief)
    ..selection = TextSelection.collapsed(offset: brief.length),
  ...
)
```

Every rebuild created a new controller and leaked the old one — `dispose()` was
never called. On a session where the user typed quickly or the parent state
changed often (e.g. Inspector verdict arriving), dozens of controllers could
accumulate. Additionally, because each controller was fresh, any programmatic
`setText` on the "old" controller had no effect on the visible field.

## Root Cause

`StatelessWidget` has no lifecycle — it cannot own resources that need disposal.
`TextEditingController`, `ScrollController`, `AnimationController`, and `FocusNode`
all implement `ChangeNotifier` and **must** be disposed when they go out of use.
Creating them in `build()` means they are never disposed.

Flutter's framework does not automatically dispose controllers attached to
widgets — it only manages the widget tree. A controller attached to a `TextField`
will be detached when the widget is rebuilt with a new controller, but the
original object is never garbage-collected until the GC sweeps it (it holds a
`ValueNotifier` subscription, preventing collection).

## Fix

`_BriefBlock` converted from `StatelessWidget` → `StatefulWidget`:

- `late final TextEditingController _controller` initialized in `initState()`
  with the initial text and cursor position.
- `didUpdateWidget()` syncs `_controller.text` (and re-positions the cursor)
  when the parent passes a new `brief` value — guards against updating when
  the new value already matches the field (avoids redundant cursor resets mid-type).
- `dispose()` calls `_controller.dispose()`.

Affected file: `lib/features/tracker/widgets/build_brief_dialog.dart`

## Grep to catch this class of bug

```bash
grep -rn "TextEditingController(\|ScrollController(\|AnimationController(\|FocusNode(" lib/ \
  | grep -v "//\|\.dispose\|State<\|_controller\s*=\|_focus\s*=\|late final\|final _"
```

A non-empty result means a controller is being constructed somewhere that isn't
a `State` field — investigate each hit.

## Prevention Rule

See BUG_PREVENTION.md — "Flutter Widget Lifecycle: disposable objects must be
owned by State, never constructed in build()."

## Commit

`d1fe77f`
