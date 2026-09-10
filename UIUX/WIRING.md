# Cold start: what to paste where

Five files. Nothing here adds a package, a table, or an API call. The digest
runs on `Projects.lastOpened` and `Features.updatedAt`, both of which already
exist and are already populated.

## 1. File placement

| File | Goes to |
|---|---|
| `forge_theme.dart` | `lib/core/theme/forge_theme.dart` |
| `hearth_dial.dart` | `lib/core/widgets/hearth_dial.dart` |
| `launch_screen.dart` | `lib/features/launch/launch_screen.dart` |
| `first_run_screen.dart` | `lib/features/onboarding/first_run_screen.dart` |
| `portfolio_digest.dart` | `lib/features/tracker/widgets/portfolio_digest.dart` |

`hearth_dial.dart` imports `../theme/forge_theme.dart`. If you put the theme
somewhere else, that's the one import to fix.

## 2. `lib/core/app.dart`

Three edits.

```dart
// add
import '../features/launch/launch_screen.dart';
import '../features/tracker/screens/portfolio_dashboard_screen.dart'; // already there
import 'theme/forge_theme.dart';

// swap the theme
theme: ForgeTheme.dark,
darkTheme: ForgeTheme.dark,

// swap the entry route, and give the dashboard its own name
routes: {
  '/':     (context) => const LaunchScreen(),
  '/home': (context) => const PortfolioDashboardScreen(),
  // ...everything else unchanged
},
```

Then in `launch_screen.dart`, delete the `_HomeRoute` placeholder at the bottom
and return `const PortfolioDashboardScreen()` from `_go`.

## 3. `portfolio_dashboard_screen.dart`

Two insertions in `build`. Keep everything else, including the multi-select and
double-confirm delete.

```dart
// at the top of the body, above the existing grid
const ForgeAppHeader(trailing: [ActiveModelChip()]),
Padding(
  padding: const EdgeInsets.fromLTRB(26, 26, 26, 0),
  child: PortfolioDigestPanel(
    onCatchUp: _runCheckinAcrossPortfolio,   // wire to checkin_service
    onOpenProject: _openTracker,
  ),
),
```

The existing `AppBar` can go: `ForgeAppHeader` replaces it, and losing the
Material app bar is what lets the digest be the first thing on the screen.

## 4. One decision you need to make

`markPortfolioSeen(ref)` stamps `lastOpened = now` on every project, which is
what clears the digest. Right now it only fires when the user presses **Catch
me up** or **Not now**. That means quitting without acting leaves the digest
waiting next launch, like unread mail.

The alternative is stamping it on home-screen mount, which is tidier but means
a user who opens the app and immediately gets distracted never sees what
changed. I'd keep the current behaviour. It's a one-line change if you disagree.

## 5. Fonts

The theme falls back to the system sans and Menlo. The design language calls
for **Unbounded** (display), **Fraunces** (body) and **IBM Plex Mono**
(counters, timestamps). To get the real thing:

```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: Unbounded
      fonts:
        - asset: assets/fonts/Unbounded-Medium.ttf
          weight: 500
        - asset: assets/fonts/Unbounded-SemiBold.ttf
          weight: 600
    - family: IBMPlexMono
      fonts:
        - asset: assets/fonts/IBMPlexMono-Regular.ttf
```

Then set `fontFamily: 'Unbounded'` on `headlineSmall` / `titleMedium` and
`fontFamily: 'IBMPlexMono'` on `labelSmall` / `labelMedium` in `forge_theme.dart`.
Do this after the layout is settled — the metrics shift and you'll want to
re-check spacing once.

## 6. What is genuinely new work

Everything above is a re-arrangement of data the app already holds. The one
thing the mockup implies that the code does not do yet:

**Git activity in the digest.** The mockup's "12 updates" reads like commits.
`portfolioDigestProvider` counts feature changes instead, which is honest and
needs no repo, no key, and no LLM — the right v1 for the vibecoder audience.
Folding real commit counts in later is additive: add a `gitUpdates` field to
`ProjectDelta`, populate it from the existing check-in git plumbing for
projects that have a folder linked, and take the larger of the two numbers for
the headline.

## 7. Design language v2

`rust (#7A3826)` is now doing semantic work: it marks blocked and stuck. v1 of
the design language had no colour for trouble, so this was invented here rather
than inherited. Write it into the doc before it gets improvised differently
somewhere else in the app.
