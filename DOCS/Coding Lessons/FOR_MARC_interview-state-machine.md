# FOR MARC: How the Interview State Machine Came Together

*Session 7 · 2026-06-01 · §5 Build Interview UI + State*

---

## Step 1 — Approach and reasoning

§3 gave The Forge a face. §5 gave it a brain. The project list in §3 was a viewport into the filesystem — it showed projects, opened READMEs, did nothing else. The interview is the *core product loop*. Everything else (spec generation, worksheets, handoffs, executor agents) is downstream of what the interview produces. The interview is where the human's intent meets The Forge's understanding, and the output of that meeting is the locked spec.

We had three jobs: model the state, drive the conversation, render the conversation. The state model is 8 confidence dimensions (the Workflow Template lists them), a chat history, a list of open conflicts, and a "can we generate the spec yet?" flag. The driver is a `FamilyAsyncNotifier` that takes user input, calls a stub LLM, applies the result. The renderer is a screen with a meter at the top, a conflict area, a chat history in the middle, and a composer at the bottom.

The interesting design decision was the stub. We can't build the real LLM call yet — that's §4. But we need the interview to be testable end-to-end so the rest of the UI work can proceed. The stub is a top-level function that takes the current state + the user's message and returns a structured response (interviewer text + confidence updates + new conflicts). It's deterministic and turn-counter driven. Nine user messages covers all 8 dimensions and surfaces one conflict. When §4 lands, we replace *one function call* in the notifier with `await llmProvider.complete(...)` and parse the JSON result. That's the swap.

The other design decision was family-by-project. Each project gets its own interview state. If you close the project and reopen it later, the interview is still there. If you start a new project, that's a separate state. Riverpod's `AsyncNotifierProvider.family<NotifierT, T, ArgT>` does this for free — the family argument is `InterviewArgs(path, name)` and Riverpod keys state on it.

---

## Step 2 — Roads not taken

**Single non-family provider with project path in the state.**

The simplest version: one `interviewProvider` that holds an `InterviewState` for whatever project is currently open. The screen reads `activeProjectProvider` to know which project to display, and uses a `ref.watch(interviewProvider)` to get the state. When the user opens a different project, the notifier resets.

We rejected this because the reset is invisible. If the user is mid-interview on Project A and clicks Project B, then clicks back to A, the interview is gone. With a family, Project A's interview is still there — Riverpod caches by family arg. The user can context-switch without losing work. The cost is a tiny bit more boilerplate (the `InterviewArgs` class with `==`/`hashCode`), and we get resumption for free.

**A `Map<Dimension, DimensionState>` exposed directly as state (no `InterviewState` wrapper).**

Riverpod 2.6 lets you expose any object as state. Why wrap the dimension map in `InterviewState`? Because the state has multiple related fields (turns, conflicts, loading, specGenEnabled) that all change together. Wrapping them in one class means *one* rebuild per transition. Exposing the map directly means the screen would have to watch five separate providers, and the order of state updates would matter (turns update before conflicts, then loading, then... it's a mess).

The wrapper is one type that the notifier updates atomically. The screen watches one thing. The flow is `state = AsyncData(newState)` and the UI rebuilds. No partial states, no race conditions, no "did the turns update but not the loading flag yet?" weirdness.

**A "real" LLM stub that parses keywords from the user's message.**

The natural stub for a "smart" system is to fake the smart part — look for keywords in the user's message and decide which dimension to advance. "Account" → identity model. "Mobile" → platform. Etc.

We rejected this because keyword parsing is *more* code than turn-counting and *less* honest. The stub isn't trying to look smart. It's trying to walk through the 8 dimensions in a predictable order so we can test the UI mechanics. A turn counter (count user messages, pick the next dimension) is 9 lines of code and dead-obvious. Keyword parsing is 50 lines and pretends to be something it isn't. The state machine UI works the same way regardless. We build the real one in §4; the stub is a placeholder, not a prototype.

**A separate `ConflictItem` model vs inlining the conflict into the state.**

A conflict has: two dimension references, a description, a recommendation, a resolved flag. We could have modeled it as a plain tuple or a `Map<String, dynamic>`. We didn't. `ConflictItem` is a class with a const constructor, and `InterviewState.openConflicts` is `List<ConflictItem>`. The reason: the conflict is data, and data deserves a type. The screen renders a list of `ConflictItem`s with a known shape. The notifier adds and removes them by ID. The pattern is the same as `InterviewTurn` — typed data, not maps.

---

## Step 3 — How the pieces connect

The data flow for a single interview turn:

```
User types in TextField
    ↓
Composer.onSubmitted(text) fires
    ↓
notifier.addUserMessage(text) called
    ↓
Notifer: state = withUserTurn + isLoading:true   ← UI shows spinner
    ↓
await Future.delayed(400ms)                       ← simulate LLM latency
    ↓
stubInterviewStep(state, text)                    ← THE single call site
    ↓
stub returns: {interviewerText, confidenceUpdates, newConflicts}
    ↓
Notifer: state = withInterviewerTurn + updates + isLoading:false
    ↓
InterviewScreen rebuilds (AsyncValue.data changed)
    ↓
ConfidenceMeter rebuilds with new map
TurnBubble list grows by 1 (interviewer)
_scrollToBottom() runs in post-frame
```

Three layers, clean seams. The screen doesn't call the stub. The stub doesn't call the notifier. The notifier doesn't know about widgets. The state doesn't know about the screen.

The `FamilyAsyncNotifier<InterviewState, InterviewArgs>` is the seam. `InterviewArgs(path, name)` is the family key. The notifier is created per-family-arg by Riverpod. The screen constructs an `InterviewArgs` from its constructor params and passes it to `ref.watch(interviewProvider(args))`. Riverpod hashes the args, finds the right notifier, returns the state. Two screens watching the same args share the same notifier. A screen watching different args gets a different notifier. This is how state isolation works in Riverpod, and it's why the family arg has to implement `==` and `hashCode`.

---

## Step 4 — Tools, methods, and frameworks

**`FamilyAsyncNotifier<T, Arg>` for the state machine.**

This is Riverpod's async-state-with-arg pattern. The build method is `Future<T> build(Arg arg)`. You can do async work in build (e.g., load from disk), but for a pure in-memory state machine, you can return synchronously:

```dart
@override
Future<InterviewState> build(InterviewArgs args) async {
  return InterviewState.empty(args.path, args.name);
}
```

The `async` keyword wraps the return in a Future. The body is a one-liner. Riverpod treats it as if it were a sync notifier with a future-typed initial state.

**`AsyncNotifierProvider.family<NotifierT, T, ArgT>(NotifierT.new)`.**

This is the family constructor for async notifiers. The signature is:
- `NotifierT` — the notifier class
- `T` — the state type
- `ArgT` — the family argument type

Calling `interviewProvider(args)` returns `AsyncValue<InterviewState>`. Calling `interviewProvider(args).notifier` returns the notifier instance. Both lookups go through the family — Riverpod keys on `args`.

**Records for the stub return type.**

The stub returns `({String interviewerText, Map<ConfidenceDimension, DimensionState> confidenceUpdates, List<ConflictItem> newConflicts})`. That's a Dart 3 record. Records give you typed, named-field tuples without defining a class. The notifier destructures it: `final stub = stubInterviewStep(state, text);` then uses `stub.interviewerText`, `stub.confidenceUpdates`, etc.

We could have used a class (`_StubResponse`), but records are more lightweight for an internal contract that's used in exactly one place. A class is for data that crosses boundaries. A record is for "this is the shape of the thing I return to my one caller."

**`copyWith` for state transitions.**

Every state change goes through `state.copyWith(...)`. The method takes optional named params and uses `?? this.field` to preserve unchanged values. This is the standard pattern for immutable state in Dart. The cost is a slightly verbose call site; the benefit is that every transition is explicit and the new state is a new object (so Riverpod's identity check triggers a rebuild).

**`LinearProgressIndicator` for the meter bars.**

The confidence meter is 8 horizontal bars. Each bar's fill level reflects the dimension's state: 0% unknown, 50% partial, 100% resolved. `LinearProgressIndicator` does exactly this — it takes a `value: 0.0..1.0` and a `valueColor`. The track is the empty state; the fill is the state color. Wrap in `ClipRRect` for rounded corners. Add a label column on the right. Done.

**`WidgetsBinding.instance.addPostFrameCallback` for auto-scroll.**

When a new turn is added, the chat history grows. The user expects the view to scroll to the bottom. But the scroll position update has to happen *after* the layout pass — otherwise the new turn's height isn't in the layout yet, and `maxScrollExtent` returns the old value. The fix is to schedule the scroll in a post-frame callback:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!_scrollController.hasClients) return;
  _scrollController.animateTo(
    _scrollController.position.maxScrollExtent,
    ...
  );
});
```

The `hasClients` check guards against the controller being detached (e.g., during widget teardown).

---

## Step 5 — Tradeoffs

**Family provider vs single provider.** Family gives per-project state isolation for free. Single provider is one less file (`InterviewArgs` not needed) and one less `==`/`hashCode` to maintain. We chose family because resumption across project switches is a real product feature, not a hypothetical. Trade: more boilerplate now, less code to rewrite when resumption becomes a requirement.

**Stored `specGenEnabled` field vs computed getter.** The field is a `bool` on `InterviewState`, updated on every transition. A getter would compute it from `confidenceMap.values.every((s) => resolved) && openConflicts.isEmpty`. The field is more explicit; the getter is more robust. We chose the field because the notifier is the single source of truth for state transitions — if the field ever drifts from the truth, that's a bug in the notifier, not in the screen. The getter would silently paper over that bug. Trade: the notifier has to remember to update the field on every transition. We do — there are three call sites (`addUserMessage`, `resolveConflict`, `reset`) and they all set it.

**400ms stub latency.** The stub is synchronous — it could return instantly. We added a 400ms `await Future.delayed` to simulate LLM latency. This makes the spinner visible (otherwise the user wouldn't see it). Trade: the UI is slower than it needs to be during dev. We accept this because the UX is what we're testing — if the spinner is invisible, we can't verify it works. When §4 lands, the real LLM call will have its own latency, and the 400ms goes away.

**Deterministic stub vs simulated randomness.** The stub cycles through dimensions in a fixed order based on turn count. It could randomize. We didn't because deterministic is testable. A test can send 9 messages and assert the final state has 8 resolved + 0 conflicts. A random stub would require probability assertions or seeded RNG. Trade: the stub feels artificial (the interviewer asks the same question to every user on turn 1). Acceptable for a stub; the real LLM will be organic.

**Inline `ConfidenceMeter` rendering vs extracted into its own file.** The plan said "create `confidence_meter.dart`". We did. The file has the `ConfidenceMeter` widget (the public one) and `_DimensionBar` (the private one). Both are 100% stateless — they take a `Map<ConfidenceDimension, DimensionState>` and render. The benefit of the separate file is that the screen is 250 lines shorter, and the meter is reusable for the future "spec quality" view (§7). Trade: extra file in the directory tree. Acceptable — it's a clear single-responsibility module.

**SafeArea on the composer.** The composer is a `Container` with `SafeArea(top: false)` inside. SafeArea adds bottom padding on iOS for the home indicator. On macOS, SafeArea is a no-op (no safe area insets). We use it because Flutter's eventual mobile story (§11 Audit mode, or iOS port) will need it. The cost on macOS is zero. The cost on iOS later is one line of code.

---

## Step 6 — Mistakes, dead ends, and wrong turns

**The first build had three analyzer errors.**

I forgot two imports and one class reference. Specifically:
- `interview_notifier.dart` uses `InterviewArgs` (as the family arg type) but I defined `InterviewArgs` in `interview_providers.dart`. The notifier needs to import it.
- `interview_screen.dart` uses `ConfidenceMeter` (the widget) but I defined it in `confidence_meter.dart`. The screen needs to import it.

The analyzer caught all three on the first `dart analyze lib/` after writing the files. Three for three on the same import mistake. The fix was two `import` statements. I had defined the files in the right place; I just forgot to wire the dependencies.

Lesson: when you split a feature into multiple files, *draw the dependency graph first*, then write the imports. The graph for §5 was: state ← notifier ← providers → screen. The notifier needs `state` and `providers` (for `InterviewArgs`). The screen needs `state` (for the data classes), `providers` (for `InterviewArgs` and the provider), and `confidence_meter` (for the widget). I had `state ← notifier` and `state, providers ← screen` in my head, but I missed `providers ← notifier` and `confidence_meter ← screen`.

**First stub design was content-driven.**

My first stub was a function that took the user's message and tried to figure out which dimension it was about. "Account" → identity. "Mobile" → platform. "Login" → identity. Etc.

This was a mistake. The stub is supposed to be a placeholder for the LLM, not a prototype of the LLM. Turn-counting is 9 lines; keyword matching is 50+ and gets the stub in the awkward position of pretending to be smart. Worse, it would be the kind of stub that ships by accident — somebody sees the keyword matcher, thinks "good enough," and skips §4. We avoided that by making the stub *obviously* a stub: it counts turns and asks the next question in a fixed sequence. The intent is "this is a stand-in" not "this is a working version."

**First version of the conflict text was generic.**

I started with "There's a conflict between these two answers." That was wrong. The Workflow Template specifies an exact pattern that surfaces the trade-off and recommends the conservative option:

> "Your answers on [X] and [Y] pull in opposite directions. [X] implies [consequence]. [Y] implies [different consequence]. I recommend [conservative option] for v1 because [reason]. Do you accept this scope?"

The pattern is *prescriptive* — it doesn't just flag the conflict, it tells the user what to do about it. The Accept button is the user's "yes I accept your recommendation." The button label is literally "Accept: [recommendation]." This makes the workflow a single click after the user reads the explanation.

The generic version would have left the user staring at a flagged conflict with no guidance. The prescriptive version is what the Workflow Template author tested and refined.

**First version of the Composer had a plain `TextField` with no styling.**

The default TextField on a dark background looks like a 2010 form input — black on black with no visible border. I had to add `filled: true`, `fillColor`, and three `border` variants (default, enabled, focused) with explicit colors. The focused state uses the primary amber to make it obvious which field has focus.

The 9 lines of decoration code are the difference between "looks like a developer tool" and "looks like a placeholder."

---

## Step 7 — Pitfalls to watch for

**Don't call `setState` inside a ConsumerWidget.**

ConsumerWidget doesn't have a `setState` method — it has `ref.watch` and `ref.read`. The state lives in the notifier, not the widget. If you need to trigger a rebuild, the notifier publishes a new state and Riverpod rebuilds the watching widget. If you find yourself wanting `setState` in a ConsumerWidget, you've put state in the wrong place.

**Don't forget `==` and `hashCode` on family arg types.**

Without them, Riverpod creates a new notifier instance for every `InterviewArgs` you pass — even if two args are "the same." This leaks notifiers and breaks resumption. The fix is one method and one getter:

```dart
@override
bool operator ==(Object other) =>
    identical(this, other) ||
    (other is InterviewArgs && other.path == path && other.name == name);

@override
int get hashCode => Object.hash(path, name);
```

The `identical` short-circuit catches the "same instance" case (cheap). The structural check is the real work.

**Don't use `state.value` directly.**

`state.value` throws if the state is loading or error. `state.valueOrNull` returns null. For notifier methods, always use `valueOrNull` and guard:

```dart
final current = state.valueOrNull;
if (current == null) return;
```

This handles the brief window where the notifier is in its initial loading state. Without the guard, the method crashes on the first call.

**Don't put `await` before reading the notifier state in a callback.**

The notifier's `addUserMessage` reads `state.valueOrNull` at the *start* of the method, then awaits 400ms, then continues. If you re-read `state.valueOrNull` after the await, you get a potentially-different state (the user might have clicked Accept on a conflict during the 400ms). For the stub, this doesn't matter. For a real LLM call, the user might do many things during the latency. The correct pattern is: read state, do async work, re-read state, then publish the result. We didn't do that in the stub because the stub is fast and the race is small. When §4 lands, the re-read pattern is required.

**Don't render `LinearProgressIndicator` with no width constraint.**

`LinearProgressIndicator` inside a `Column` or `Row` without an `Expanded` wrapper has unbounded width. It throws a layout error. The fix is to wrap it in `Expanded` (for flex-based layouts) or `SizedBox(width: ...)` (for fixed widths). Our meter uses `Expanded` inside a `Row`, which constrains the bar to the available space.

**Don't disable the conflict Accept button based on `isLoading` only.**

We disabled the Accept button when `isLoading` is true. But we should also disable it when the user is mid-input. We didn't, because the visual state (the conflict surface disappears when there are no open conflicts) makes it impossible to click. The `isLoading` guard is the safety net. The visual state is the primary protection.

**Don't put `const` on a list literal that contains non-const elements.**

In a const constructor, the Dart compiler infers const for literals — `[_stubConflict]` in a const context becomes `const [_stubConflict]`. But if the list has non-const elements, the inference fails. The fix is to mark it `const` explicitly: `const [_stubConflict]`. Or don't use a const constructor for the class that has the list. Our `_StubResponse` is a private class with a const constructor, and all elements in its defaults are const, so the inference works. If we ever add a non-const element, we have to remove the const constructor or break the list out.

---

## Step 8 — What an expert notices

**The `ConfidenceMeter` reads the map directly — no `Provider` for it.**

You could wrap the meter in a `Provider<ConfidenceMeterViewModel>` that takes the state and returns a view-model. We didn't. The meter is a pure function of the map. The screen rebuilds when the state changes; the meter is a child of the screen; the meter rebuilds with new data. Wrapping it in a provider is an extra layer for no benefit. Pure widgets that take data are fine.

**The Composer is a stateless `StatelessWidget`, not a `ConsumerWidget`.**

The composer takes the controller, the loading flag, and a `Future<void> Function(String)` callback. It doesn't watch any provider. The state is owned by the parent (which watches the provider) and passed down. This is the right pattern: the parent owns the state, the child is a pure view. The composer can be reused for any input scenario in the app (composer for a future "spec review" screen, etc.).

**The `_StubResponse` defaults are `const {}` and `const []`.**

```dart
const _StubResponse({
  required this.interviewerText,
  this.confidenceUpdates = const {},
  this.newConflicts = const [],
});
```

These defaults are const-evaluable, which means a `_StubResponse` that doesn't pass them is itself a const expression. Used in a `switch` case:

```dart
case 1:
  return const _StubResponse(
    interviewerText: 'Got it.',
    confidenceUpdates: {ConfidenceDimension.corePurpose: DimensionState.resolved},
  );
```

The whole expression is a const. Dart allocates no heap. The case body returns a compile-time constant. Tiny optimization, but it tells you the engineer thought about lifetimes.

**The chat bubbles use `Align` + `Container` + `Column` instead of `Row` or `Wrap`.**

The natural way to do right-aligned vs left-aligned chat is `Row(mainAxisAlignment: ...)`. But Row tries to fill the width. We want the bubble to be only as wide as the text, with alignment. `Align(alignment: Alignment.centerRight, child: Container(...))` gives you a tight bubble that hugs its content and aligns to the side. The `maxWidth: 640` constraint prevents absurdly wide bubbles on huge screens.

**The `state.isLoading` guard is the reason no race condition exists.**

When the user clicks "Send," the notifier sets `isLoading: true` synchronously (before the await). The screen rebuilds. The text field is disabled. The send button shows a spinner. The conflict Accept button is disabled. The user *cannot* do anything that would mutate state during the 400ms stub latency. When the stub returns, `isLoading: false` is set, and the user can interact again.

Without the guard, the user could click Accept on a conflict, then the stub would add a duplicate conflict, then Accept would resolve only one of them, and `specGenEnabled` would never become true. The guard prevents this.

**The Send button uses `FilledButton` (not `IconButton.filled`).**

`IconButton.filled` exists but has padding baked in. `FilledButton` with `padding: EdgeInsets.zero` and a fixed `width`/`height` gives a square button that we control exactly. The result is a 44x44 amber square with a send icon — minimal, focused, matches the macOS dark aesthetic. An `IconButton` would have been 48x48 with a tinted background, which is the Material 3 default and looks mobile-y on desktop.

**The `_EmptyChat` widget is honest about the state.**

When the user first opens the interview, the chat is empty. We don't show a "Loading…" or a blank area. We show explicit instructions: "Type a greeting to start the interview. You will be walked through 8 confidence dimensions. Conflicts between answers will be surfaced before spec generation." This is a tiny widget (15 lines) that does a big job: it tells the user what's about to happen and what the constraints are. No "click here to start" CTA — the composer is right there, and the placeholder text "Type your answer…" is the instruction.

**The `withValues(alpha: ...)` API is used instead of `withOpacity`.**

`Color.withOpacity(0.18)` is deprecated in Flutter 3.27+. The replacement is `Color.withValues(alpha: 0.18)`. The analyzer warns on `withOpacity` if you have the right lints. We use the new API everywhere there's a translucent overlay. The new API also fixes precision issues that the old one had (e.g., `withOpacity(0.5)` of `#000000` should be `#7F7F7F` but historically wasn't, in some color spaces).

---

## Step 9 — Transferable lessons

**A stub LLM is a development speed tool, not just a placeholder.**

A naive stub returns hardcoded text: `return 'Hello, user';`. A useful stub returns a *structured* response that the notifier can apply: `return {interviewerText, confidenceUpdates, newConflicts};`. The structured form lets you develop the state machine end-to-end without an LLM. The state machine code (transitions, validation, side effects) is exercised on every interaction. The LLM swap is a one-line change at a well-defined call site.

The pattern generalizes: any time a system depends on a "smart" service, define a structured contract for the response, build a deterministic stub that returns well-formed data, develop the consumer end-to-end against the stub, then swap the stub for the real service. The consumer code is identical; only the call site changes.

**Family providers are the right tool for "one state per X".**

If the state has a 1:1 relationship with some domain object (one interview per project, one cart per user, one draft per document), use a family. The alternative — single provider with a "current X" selector — always has a bug: state isolation. The user switches to Project B, then back to A, and the state is gone. Family providers cache per-arg. The user gets resumption for free.

The boilerplate is the `==`/`hashCode` on the arg type, which is 6 lines. The payoff is correctness for a class of bugs you don't even know to look for. Default to family when in doubt.

**Type the data, not the containers.**

We have `InterviewTurn`, `ConflictItem`, `InterviewState` — three classes for data. We could have used `Map<String, dynamic>` and saved ~30 lines of class definition. We didn't, because:
- The data is the contract. The notifier's transitions are type-checked. The screen's render is type-checked.
- A `Map` is opaque to the analyzer. A class is not. The analyzer tells you when you typo a field name, when you forget to set a field in copyWith, when you pass the wrong type to a method.
- Refactoring a `Map` requires a search-and-replace. Refactoring a class requires changing the class definition; every caller is updated by the analyzer.

The rule: if a piece of data is read in more than one place, give it a type. The cost is class definition + copyWith + equality (if needed). The benefit is compile-time guarantees on the entire flow.

**Race conditions are easier to prevent than to debug.**

The 400ms stub latency creates a window where the user could click Accept on a conflict before the stub returns. The stub would then re-add the conflict, and the user would have to click Accept again. Frustrating UX, but more importantly, a class of bug that gets *worse* with real LLM latency (3-10 seconds).

The fix is structural: `isLoading` is part of the state, and the Accept button is disabled when `isLoading` is true. The user physically cannot click it during the window. No race possible.

The general principle: any time you have async work that mutates state, ask "what can the user do during the work?" If the answer is "nothing relevant," you can skip the guard. If the answer is "click a button that mutates the same state," you need the guard. The guard is a property of the state machine, not a special case in the handler.

**A button that does nothing useful is still a button.**

The "Generate Spec" button is gated on `specGenEnabled` and, when clicked, shows a SnackBar saying "Spec generation — coming in §6." This is the right pattern for an out-of-scope action. The button is *visible* (so the user can see the gate working), *enabled at the right time* (so the user gets feedback when the conditions are met), and *honest about its limitations* (the SnackBar tells them what's coming).

The alternative is to not render the button at all, but then the user has no way to know the gate is working. The stub-unlock moment (when `specGenEnabled` flips to true and the button appears) is the *test* that the state machine is correct. If the button never appears, the state machine is broken. If the button appears too early, the gate logic is wrong. The button is the test surface.

**Workflow Template patterns are specifications, not suggestions.**

The conflict text pattern in the Workflow Template is exact: "Your answers on [X] and [Y] pull in opposite directions..." — that's a *literal* template the Forge fills in. We copied it verbatim. Same for the 8 confidence dimensions — they have specific question text that the Workflow Template author tested. We copied those too.

The general lesson: when a workflow document specifies a format, follow it. Don't paraphrase, don't "improve" it, don't make it more "user-friendly." The format was tested with real users and refined. The text is what the user expects to see. If the spec says "I recommend [conservative option] for v1," the Forge says "I recommend [conservative option] for v1." Predictability is the product.
