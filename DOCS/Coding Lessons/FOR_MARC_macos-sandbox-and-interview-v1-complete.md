# FOR MARC: macOS Sandbox Survival + Interview v1 Launch

*Session: 2026-06-05 | Topic: macOS entitlements, API key persistence, Flutter UX patterns*

---

## What We Were Trying to Do

Ship the first working end-to-end Plan Mode run: interview → spec → worksheet → all artifacts. We got there, but the path through the macOS sandbox was rougher than expected.

---

## The Sandbox Fight (and Why It Happened)

We added `keychain-access-groups` to the macOS entitlements so `flutter_secure_storage` could access the Keychain. That's the documented way to use it.

The problem: `keychain-access-groups` requires `$(AppIdentifierPrefix)` in the value — and that prefix is only resolved at build time if you have a **provisioning profile** from Apple. Without a paid developer account with a provisioning profile set up in Xcode, the build explodes:

```
"Runner" has entitlements that require signing with a development certificate
```

The fix: remove `keychain-access-groups` entirely, switch API key storage to `SharedPreferences` + a config file. Less "secure" in a technical sense (keys sit in a JSON file rather than the Keychain), but the file is inside the app's sandbox container — only your app can read it. Good enough for a local-first tool.

**The rule to burn in:** Never add `keychain-access-groups` unless you have a provisioning profile ready. Check `CODE_SIGN_STYLE` in `project.pbxproj` too — if it says `Manual`, you need a profile or it'll fail.

---

## API Key Persistence: Why Two Places

`NSUserDefaults` (what `SharedPreferences` uses on macOS) lives in the sandbox container at:
```
~/Library/Containers/ai.orbitalai.theForge/Data/Library/Preferences/ai.orbitalai.theForge.plist
```

During development, the container can get wiped — `flutter clean`, Xcode sandbox resets, or just bad luck. When that happens, `NSUserDefaults` goes with it.

The fix: dual-write to a JSON file in `getApplicationSupportDirectory()`:
```
~/Library/Containers/.../Application Support/forge_config.json
```

On every launch, the config file is checked first and wins. SharedPreferences is the fallback for anything that was saved before the file existed. If a key is found in prefs but not the file, it's migrated automatically.

The file looks like:
```json
{
  "api_keys": {
    "gemini": "AIza...",
    "claude": null
  }
}
```

---

## The Save Button Bug (Classic Flutter Trap)

The Settings Save button was always disabled. The condition was:
```dart
final canSave = _controller.text.trim().isNotEmpty;
```

`_controller.text` is evaluated when `build()` runs. The widget was built once, evaluated the empty text, and never rebuilt because **nothing triggered a `setState`**. The user could type a full API key and the button stayed gray.

Fix: add a listener in `initState`:
```dart
@override
void initState() {
  super.initState();
  _controller.addListener(() => setState(() {}));
}
```

Every keystroke now triggers a rebuild. The enabled state reflects reality. This is Flutter 101 but easy to miss in stateful forms — if your enable condition depends on a `TextEditingController`, always add this listener.

---

## RouteAware: The Sidebar Refresh Pattern

The file sidebar scanned the project folder once on first mount, but wouldn't refresh when you came back from the worksheet generation screen. The files were there on disk, but the widget didn't know.

The pattern:
1. Register a `RouteObserver<ModalRoute<dynamic>>` in `app.dart` (global singleton)
2. Add it to `MaterialApp.navigatorObservers`
3. In the widget that needs to refresh: mix in `RouteAware`, subscribe in `didChangeDependencies`, unsubscribe in `dispose`, and override `didPopNext()`

```dart
@override
void didPopNext() {
  // A child route was popped — rescan
  setState(() => _scanFuture = _scan());
}
```

`didPopNext` fires when a route pushed on top of the current route is popped back. Exactly what you want for "refresh when the user comes back."

---

## The Timeline Design Decision

Three steps (Interview → Worksheet → Ready) rather than four (Interview → Spec → Worksheet → Ready).

Why three: Spec generation is automatic after the interview — there's no moment where the user is "at Spec" waiting to proceed. It would just be a confusing blinking state that resolves itself immediately. The user-actionable moments are Interview (start the interview) and Worksheet (trigger worksheet generation). "Ready" is the terminal green state.

Each step:
- **Amber pulsing** = current, actionable — click it or use the CTA button
- **Green checkmark** = done — click to open the artifact it produced
- **Gray outline** = pending — not yet reachable

The CTA button at the bottom mirrors the current timeline step. Two affordances for the same action: the dot for quick taps, the button for first-time users.

---

## What Shipped

- 10 files created or significantly modified in this session
- First end-to-end Plan Mode run passing (Testapp)
- All 5 folders populated: forge/ specs/ handoffs/ worksheets/ audit/
- Timeline fully interactive; sidebar auto-refreshes; API key gate on New Project
- Tag: `v1.0-interview-complete`

## What's Next

Executor Timeline (§EX1): parse the spec's Component Map (§3) and generate an LLM-narrated build sequence — one milestone per component. Shown in ProjectDetailScreen when the project is Ready. Makes "Ready for executor" actually meaningful instead of just a green badge.
