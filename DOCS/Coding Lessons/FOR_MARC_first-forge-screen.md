# FOR MARC: How the First Forge Screen Came Together

*Session 6 · 2026-06-01 · §3 Project Folder Browser*

---

## Step 1 — Approach and reasoning

We had built the bones in §1 and §2 — a drift SQLite database, a filesystem repository with atomic writes, and two Riverpod notifiers that scan the project folder and read README files. None of that was visible. The Forge was a backend with no face.

§3 was about giving it a face. Four files, exactly: rewrite the auto-generated counter `main.dart` so the app actually starts, create an `app.dart` to host the `MaterialApp`, write a `theme.dart` so it doesn't look like a 2014 Bootstrap site, and finally build the first real screen — the project list. That's it. Tap a project, see its README. Tap +, see a stub that says "interview coming soon."

The interesting part isn't the screen itself. It's the *seam* where Riverpod meets Flutter. The whole screen is 200 lines and it does almost nothing on purpose. What it actually does is prove the wiring works end-to-end — providers fire, state propagates, the UI rebuilds when state changes, and a tap can reach into the provider layer to load a project. Everything that comes after §3 (interview, spec generation, settings) is the same pattern repeated with more state.

---

## Step 2 — Roads not taken

**A real router (go_router, auto_route, beamer).**

For an app with more than 3-4 routes, you want a router package. It handles deep links, browser back-button history, typed routes, modal vs push semantics — all the things a hand-rolled `Navigator.push` does badly. We didn't use one because §3 has exactly two routes: the project list (home) and the project detail. Adding a router for two routes is the kind of "preparing for scale at the cost of clarity" that bites you later. The 4-file scope was the discipline. We can swap in `go_router` when §5 (interview) lands and we have 5+ routes.

**A separate file for the detail screen.**

The natural urge is `project_detail_screen.dart` in the same folder, imported by the list screen. Symmetric, discoverable, follows the "one widget per file" convention. We rejected it because the detail screen in §3 is a *placeholder* — a Scaffold that shows whatever README is in `activeProjectProvider`. It will be replaced entirely in §7 (artifact viewers). Writing it in a separate file with imports and a barrel file commits to an API surface that exists for one day. Keeping it inline as `_ProjectDetailStub` in the same file means the next person to touch §3 sees both screens side by side and can delete the stub in five seconds.

**A custom widget kit (LUMARA design system, etc.).**

The Forge needs reusable components eventually — buttons, badges, list rows, modals. We didn't build any. The list row is a stock `ListTile`, the mode badge is a `Container` with a `BoxDecoration`, the error state is a `Column` with an `Icon` and a `Text`. Stock Flutter. The reason is the same as the router: a design system at the §3 stage is anticipatory abstraction. The 4 files become 12. The Forge doesn't have a product surface yet — it has a v1 of one screen. We build the kit when the third screen needs the same component. Two is coincidence.

---

## Step 3 — How the pieces connect

The data flow is the architecture. Read this from top to bottom and the whole app makes sense:

```
User taps a project row
    ↓
ListTile.onTap callback fires
    ↓
ref.read(activeProjectProvider.notifier).open(path, repo)   ← asks notifier to load
    ↓
Notifier: state = isLoading:true                              ← UI shows spinner
    ↓
Notifer: await repo.readReadme(path)                          ← I/O happens here, nowhere else
    ↓
Notifier: state = ActiveProjectState(readme: ..., loading:false)  ← state change published
    ↓
await Navigator.push(detailScreen)                            ← NOW navigate
    ↓
DetailScreen: ref.watch(activeProjectProvider)               ← reads state, renders
```

Every widget that needs to *do* something reads `ref.read(notifierProvider.notifier)`. Every widget that needs to *display* something reads `ref.watch(provider)`. The split is total. The list screen does `ref.watch(projectListProvider)` and `ref.read(activeProjectProvider.notifier)`. The detail screen does `ref.watch(activeProjectProvider)` and `ref.read(activeProjectProvider.notifier)`. Two patterns, used consistently, and Riverpod's reactivity does the rest.

The repo (`ProjectFileRepository`) is the only thing that touches the disk. Providers wrap repos. Screens wrap providers. Widgets wrap screens. Each layer has one job and one job only.

---

## Step 4 — Tools, methods, and frameworks

**`ConsumerWidget` over `StatelessWidget` for screens.**

A `ConsumerWidget` is a `StatelessWidget` with a `WidgetRef` injected into `build()`. That's the only difference, but it's everything. Without `WidgetRef`, you have no way to read providers — every screen would need to wrap its body in a `Consumer` widget, which is more nesting and more rebuilds. With `ConsumerWidget`, the entire screen is the watch boundary. Rebuilds are surgical and obvious.

**`AsyncValue<T>` for async state.**

Riverpod's `AsyncValue` is a sealed type with three variants: `loading`, `error`, `data`. The `.when(loading:, error:, data:)` API forces you to handle all three. You can't accidentally forget the loading state — if you don't pass the three callbacks, the analyzer complains. The pattern in the list screen is exactly that: a `CircularProgressIndicator` for loading, an error column with a Retry button for failure, a `ListView` (or empty-state message) for data. No booleans, no nullable state, no "is it loaded yet?" checks scattered through the widget tree.

**`ref.invalidate(provider)` for retry, `notifier.refresh()` for pull-to-refresh.**

Same effect, different intent. `invalidate` tells Riverpod "throw away this provider, rebuild it from scratch" — it's a state-management primitive. `notifier.refresh()` calls `ref.invalidateSelf()` inside the notifier, then `await future` — it returns a `Future<void>` that `RefreshIndicator` can await. They're not redundant. Invalidate is for the Retry button (no future to await, the rebuild is the work). `notifier.refresh()` is for the pull gesture and the AppBar refresh button (the indicator needs a future to know when to stop spinning).

**`MaterialPageRoute<void>` for now.**

`Navigator.push(MaterialPageRoute(builder: ...))` is the verbose way. `go_router`'s `context.go('/detail')` is the concise way. Verbose is fine when you have two routes and you want to see the destination widget right there in the call site. It's fine to be a little verbose when clarity wins.

---

## Step 5 — Tradeoffs

**Inline stubs vs separate stub files.** Inline keeps §3 to 4 files and shows the next agent what to delete. Separate files would be more "production-shaped" but commit to an API that exists for one day. We chose inline. Trade: the list screen file is 250 lines, which is long for a "list screen." Acceptable — most of those lines are the stubs, which won't be there in a week.

**Dark theme only, no light theme.** We set `themeMode: ThemeMode.dark` and pass the same theme to `theme` and `darkTheme`. The alternative is a full light + dark system. We chose dark-only because The Forge is a developer tool (terminal-adjacent product, monospace font, spec/code feel) and the spec calls for a dark aesthetic. Trade: macOS users with system-wide light mode will get dark The Forge. That's the product decision. We can add a light theme in a single-file change later if needed.

**AsyncNotifier for the project list, plain Notifier for the active project.** The project list has true async lifecycle (initial scan, can be refreshed, has a future to await). The active project is a synchronous state machine: "empty" → "loading" → "loaded" — the loading state is set *during* the async work, the notifier itself isn't async. Using `AsyncNotifier` for active project would have meant wrapping the README content in `AsyncValue<String>` even though the "loading" state already lives in the model. Trade: two notifier classes for two different shapes of state, instead of forcing one shape on both. Worth it — the code is more honest.

**Stock Flutter widgets (ListTile, Container) over a custom kit.** A `ForgeListTile` with Forge-styled dividers and padding would be more "branded." A `Container` with `BoxDecoration` is more explicit. We chose explicit. Trade: every list-like screen in the future will re-write this `Container` decoration or copy-paste it. We accept that until the third copy-paste.

---

## Step 6 — Mistakes, dead ends, and wrong turns

**The first build had two analyzer errors.**

I assumed `ActiveProjectState` had an `error` field. I wrote the detail screen to render an error branch with `active.error != null`. The analyzer said "getter 'error' isn't defined for the type 'ActiveProjectState'." The state class has four fields: `projectPath`, `projectName`, `readmeContent`, `isLoading`. No error.

Why did I assume? Because in §2 I sketched the state as "with loading, with error, with data" in my head. But I never wrote an `error` field because the spec for §2 said "open() reads README and populates state" — no error handling. The README read returns null (handled at the repo layer), and null becomes `(no README.md found)`. There's no error to carry.

Fix: deleted the error branch. The detail stub now has two states — loading and loaded. Loaded shows the readme or the placeholder. That's the actual state shape.

Lesson: don't read the model from your mental sketch — read it from the file. The shape in the file is the contract.

**First version of the AppBar had a centered title.**

`AppBar` defaults to centered on iOS-style apps and left-aligned on Android. macOS is neither — it follows Android by default (left). We overrode `centerTitle: false` explicitly. Centered title on a desktop app with text-only navigation looks wrong (it's a mobile pattern). Now it's explicit. If a future change to the parent theme re-enables centerTitle, this screen keeps the left-aligned look.

**Pulled in a refresh method that wasn't there yet.**

I called `notifier.refresh()` from the `IconButton.onPressed` and `RefreshIndicator.onRefresh` callbacks. The first pass assumed `refresh()` was sync. Then I remembered: `refresh()` is async (it does `await future`). The `IconButton.onPressed` is a `VoidCallback`, so I just passed the method reference directly (`onPressed: notifier.refresh`) — Dart treats it as a `Future<Null> Function()` and the analyzer is happy. The `RefreshIndicator` is the same — its `onRefresh` is a `Future<void> Function()` that gets awaited internally. No boilerplate, no anonymous async closures. Method references for the win.

---

## Step 7 — Pitfalls to watch for

**Don't capture `BuildContext` across an `await`.**

The list row's `onTap` does:
```dart
final navigator = Navigator.of(context);
await ref.read(activeProjectProvider.notifier).open(project.path, repo);
navigator.push(...);
```

I could have written `Navigator.of(context).push(...)` after the await. The analyzer would have warned `use_build_context_synchronously` — a real bug, not a stylistic warning. If the user navigates back during the `await`, the widget is unmounted, the `context` is dead, and `.push()` throws. The fix is to capture the Navigator *before* the await. The Navigator is stable for the lifetime of the route, so capturing it is safe.

Pattern: any time you're about to `await` something, ask "does anything in the next 5 lines need `context`?" If yes, capture what you need (Navigator, ScaffoldMessenger, Theme) to a local first.

**Don't make theme colors magic numbers in every widget.**

The first version of `_ModeBadge` hard-coded `Color(0x33E8A04C)` for the build-mode background. That's the primary at 20% alpha. If the primary ever changes, every badge, every FAB, every accent breaks silently. The fix is to read from `Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)`. The `withValues` method (new in Flutter 3.27) replaces the deprecated `withOpacity` and matches the rest of the framework.

In §3 we still have some literal hex codes in the theme file itself. That's fine — the theme *is* the source of truth for those values. Don't spread them into widgets.

**`ListTile.subtitle` with three dot-separated facts is fine, but don't nest formatting.**

`Text('${project.phase} · $modeLabel · $lastOpened')` is readable. The moment someone wants to bold the phase or color-code the mode, this string becomes a `Text.rich` with `TextSpan` children, and the inline interpolation gets awkward. The pattern is: when you need formatting, use a `Text.rich` with a `TextSpan` per fact. The interpolation is still there, but the spans are explicit.

**The `RefreshIndicator` only works inside a scrollable.**

If you wrap a `Column` or `Center` widget in `RefreshIndicator`, it does nothing. The indicator needs a scrollable child (ListView, SingleChildScrollView, etc.) to capture the pull gesture. The list screen uses `ListView.separated` for the data branch — that works. The empty-state branch uses `Center` (not scrollable) — so the empty state has no pull-to-refresh. The user can still tap the AppBar refresh icon. That's an acceptable degradation.

**Don't forget `const` on private widget constructors.**

`class _ProjectRow extends ConsumerWidget` with `const _ProjectRow({required this.project})` — that const constructor lets Dart reuse instances across rebuilds. Without it, every rebuild creates a new `_ProjectRow` object. Tiny perf hit, no correctness issue, but the analyzer will eventually warn if you use `prefer_const_constructors_in_immutables` (we don't, but other repos do).

---

## Step 8 — What an expert notices

**The list screen does not own the repo.**

`final repo = ref.read(projectFileRepositoryProvider);` is inside the `onTap` callback, not a member variable, not a constructor parameter, not a singleton. The screen has no constructor parameters at all. It reads the repo from Riverpod at the moment it needs it. This is the opposite of a typical Flutter app where you'd inject dependencies through constructors or use a service locator. The reason it works: Riverpod's `Provider` is a global dependency container with deterministic disposal. Reading a provider from a callback is safe because the provider is stable for the app's lifetime.

**The detail screen has no `initState`.**

It doesn't need one. The data it displays comes from `activeProjectProvider`, which is already populated by the time the screen is pushed. There's nothing to load, no controllers to initialize, no animations to start. The whole class is `build()` and nothing else. This is what it looks like when state management is done at the right layer — the screen is purely declarative.

**The FAB uses inverse colors.**

`backgroundColor: primary` and `foregroundColor: background` — the icon and the button background are the two ends of the color scheme. That's why the FAB pops: it's the only place in the app where the primary color is a *fill* (everywhere else it's a text accent or a 20%-alpha chip background). This is a one-line visual hierarchy decision. The most important action gets the loudest color. Everything else is monochromatic.

**`const Padding(padding: EdgeInsets.all(24), child: Text('...'))` instead of `Padding(EdgeInsets.all(24), child: Text('...'))`.**

The `const` lets Dart share the same `Padding` instance across every rebuild. The text inside is a string literal — the only thing that changes between rebuilds is which `Padding` parent is rendering it. With const, the Padding is a compile-time constant. Without it, every rebuild allocates a new Padding. Negligible perf, but the analyzer enforces it (`prefer_const_constructors`) and you get used to seeing the `const` as a signal that "this subtree is stable."

**The list is sorted by filesystem scan order, not by recency.**

The repo scans the root directory and returns paths in the order the filesystem returns them. On macOS APFS, that's not alphabetical — it's hash-bucket order, which is stable but unpredictable. We don't sort. The "right" sort is by `lastOpened` descending, but `lastOpened` is in the drift DB, not the filesystem. To sort properly we'd need to: scan paths → look up each in DB → sort → render. We didn't. It's §3 — the screen is a placeholder for the resumption flow, not a polished list view. When §3.1 (or whatever the next iteration is called) adds sorting, the change is in the notifier's `build()`, not the screen.

**The error state's Retry button uses `ref.invalidate`, not `notifier.refresh()`.**

`ref.invalidate(projectListProvider)` from a regular widget rebuilds the provider by re-running its `build()`. The widget doesn't need to await anything — Riverpod handles the rebuild and the screen will switch to `AsyncValue.loading()` then back to `AsyncValue.data()`. `notifier.refresh()` would also work, but it returns a `Future<void>` that we'd have to either await (and wrap the onPressed in an async closure) or fire-and-forget. Invalidate is the right tool for "user pressed retry, kick off the load again."

---

## Step 9 — Transferable lessons

**Two-pattern state management scales further than people think.**

Every screen in The Forge, from here on out, is a `ConsumerWidget` that does `ref.watch(someProvider)` for display and `ref.read(someProvider.notifier).someMethod()` for actions. The interview screen will add an `InterviewNotifier` for the question/answer flow. The spec screen will add a `SpecGeneratorNotifier` for the LLM call. The settings screen will add a `SettingsNotifier` for the user preferences. Every one of them is the same shape. The mental model is: "Riverpod owns state, widgets own rendering." Once you have that model, the rest is filling in notifiers.

**Inline stubs are a development speed tool, not just a discipline hack.**

When §7 lands and the artifact viewers replace the inline `_ProjectDetailStub`, the diff is one file (`projects_list_screen.dart` gets shorter, the new viewer screen file gets added). The state class (`ActiveProjectState`) doesn't change. The provider doesn't change. The list row's `onTap` doesn't change. The integration test for "tap a project, see the README" gets re-pointed at the new screen — the test contract is stable, only the screen swaps. This is what "infrastructure is the contract, screens are the implementation" looks like in practice.

**Theme as a single file pays for itself the second you want to rebrand.**

The Forge's brand is "developer tool with terminal feel — dark, monospace, amber accent, flat surfaces." If we change to a different accent color (say, cyan), the change is in `app_theme.dart` at the top, where `primary` is defined. Every FAB, every badge, every accent line follows. The Forge could become The Anvil with a 4-line change. Theme files are the cheapest design system you'll ever ship.

**Riverpod's `AsyncValue.when` is the missing piece most apps write by hand.**

The pattern of "loading state, error state with retry, data state" appears in every app that loads anything from anywhere. Most apps write it as three separate boolean flags or nullable fields. `AsyncValue` is a sealed type that enforces all three branches — the `.when(loading:, error:, data:)` API literally won't compile if you don't handle one. That's the value of types that model real states instead of representing them with primitives.

**The first screen of a new app is almost never the screen that matters.**

§3 is the project browser. It is not the core loop of The Forge — the core loop is the interview, which is §5. The browser is the home screen because every app needs a home, but the value of the product is in the screens that come after. The discipline of keeping §3 small (4 files, no abstractions, stubs for what's coming) is what lets §4 and §5 ship without §3 getting in the way. The browser is a launchpad, not a destination.
