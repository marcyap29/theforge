# FOR_MARC: Watch Mode Dashboard UI (§W4)

**Session:** 2026-06-17
**Task:** Build the Watch Mode dashboard — 5 new screens + 3 modifications. Engineer cards with spend + CI pass rate, fl_chart spend chart, workspace health, alert log with dismiss. Read-only except alert dismissal. Ship with empty/demo data path working.

---

## Step 1 — Approach and reasoning

§W4 is the first Watch Mode screen layer. §W1-§W3 built the data pipeline (fetch tokens, fetch git/CI, derive signals, dedupe alerts). §W4 renders that data. The reasoning chain:

1. **One orchestrating provider, many screens.** `WatchDataNotifier` is the only provider the watch screens watch. It fetches §W1+§W2, runs §W3, auto-appends alerts, and returns a `WatchData` bundle. The screens never import `usageServiceProvider` or `gitActivityServiceProvider` directly. This keeps the UI decoupled from the fetch pipeline — if the pipeline changes (caching, polling, error handling), only `WatchDataNotifier` changes; the screens don't.

2. **Color encodes quality, not just severity.** The fl_chart spend bars are colored per-day by that day's CI pass rate — green >70%, amber 30–70%, red <30%. A tall red bar is "high spend, low pass rate" (the worst case); a tall green bar is "high spend, high pass rate" (the best case). Single-color bars would show spend but hide quality. The color is the signal; the height is the magnitude.

3. **Alert log separates active from dismissed.** Active entries are full-opacity with a Dismiss button. Dismissed entries are 0.4 opacity with strikethrough and no button. The "— N dismissed —" divider only shows when dismissed entries exist. This makes the log scannable: active first (what needs attention), dismissed second (what was handled).

4. **Read-only except dismiss.** Every screen displays data. The only mutation is alert dismissal. No forms, no editing, no "add engineer" UI (that's a future settings screen). The dashboard is for watching, not configuring.

---

## Step 2 — Roads not taken

**Road A — Each screen watches its own providers directly.**
Rejected. If `WatchDashboardScreen` watched `usageServiceProvider` + `gitActivityServiceProvider` + `watchSignalServiceProvider` + `alertLogProvider` separately, it would have to orchestrate the fetch+evaluate+append logic itself. Then `EngineerDetailScreen` would need the same logic. The orchestration would be duplicated across screens, and any change to the pipeline would touch every screen. The single-provider approach centralizes the orchestration in `WatchDataNotifier`; the screens just read the result.

**Road B — Single-color spend bars.**
Rejected. A green bar chart of spend shows magnitude but not quality. A red bar chart shows magnitude but not quality either. Per-day coloring by pass rate makes the chart a "spend + quality" view — the color answers "was this spend productive?" The cost is a slightly busier chart; the benefit is that the worst case (tall red bar) is immediately visible.

**Road C — Show all alerts in one list, no active/dismissed separation.**
Rejected. A flat list mixes "needs attention" with "already handled." The user has to scan past dismissed alerts to find active ones. Separating active first, dismissed second (with a divider) makes the log scannable — active alerts are the top, dismissed are the bottom. The divider only appears when dismissed exist, so an all-active log is clean.

**Road D — Build the settings UI for GitHub config in §W4.**
Rejected. §W4 is display-only. The spec was explicit: "Settings UI for GitHub config or engineer roster (no forms in §W4)." Adding forms would mix concerns — the dashboard is for watching, not configuring. The settings screen is a separate task (future §W4b or §W5).

---

## Step 3 — How the pieces connect

The flow is one provider, four screens:

```
WatchDataNotifier._fetch()
    │
    ├── usageServiceProvider.fetchAllUsage()         → List<EngineerUsage>
    ├── gitActivityServiceProvider.fetchCorrelations() → List<EngineerCorrelation>
    ├── engineerRosterProvider.future                → List<EngineerRosterEntry>
    ├── alertLogProvider.future                      → List<AlertEntry>
    │
    ├── watchSignalServiceProvider.evaluate()         → WatchSignalResult
    │     (signals + newAlerts + workspaceStatus)
    │
    ├── alertLogProvider.notifier.appendAlerts(newAlerts)
    │
    └── WatchData { usage, correlations, signalResult, hasGitHubConfig }
          │
          ├── WatchDashboardScreen (reads WatchData + alertLogProvider)
          ├── EngineerDetailScreen (reads WatchData, filters by handle)
          ├── WorkspaceHealthScreen (takes status + workspaceSignals as constructor args)
          └── AlertLogScreen (reads alertLogProvider directly)
```

`WatchDashboardScreen` and `EngineerDetailScreen` watch `watchDataProvider` (the AsyncNotifier). `WorkspaceHealthScreen` takes `WorkspaceStatus` and `List<FailureSignal>` as constructor args (it's a display screen, no async). `AlertLogScreen` watches `alertLogProvider` directly (it needs the live log for dismiss updates).

The dashboard reads `alertLogProvider` in addition to `watchDataProvider` because the alert count needs to update immediately when an alert is dismissed — if it only read `watchData`, the count would be stale until the next full refresh.

---

## Step 4 — Tools, methods, and frameworks

- **`fl_chart` 0.70.0** — `BarChart` with `BarChartData` + `BarChartGroupData` + `BarChartRodData`. The chart is wrapped in a `SizedBox(height: 180)` inside a `Container` with the card decoration. `FlTitlesData` configures bottom (date) and left ($) axes; top/right are hidden. `FlGridData` shows horizontal grid lines only. `FlBorderData(show: false)` removes the chart border.
- **`AsyncNotifier<WatchData>`** for the orchestrating provider — same pattern as `EngineerRosterNotifier` and `GitHubConfigNotifier`. `build()` does the fetch, `refresh()` sets loading then guards.
- **`ref.watch` for data, `ref.read` for mutations** — the dashboard watches `watchDataProvider` and `alertLogProvider` for display; it reads `watchDataProvider.notifier` for refresh and `alertLogProvider.notifier` for dismiss. Watching a notifier would cause rebuilds on every state change; reading it is a one-shot call.
- **`switch` expressions for enum → color/label mapping** — `VelocityTrend.improving => 'IMPROVING'`, etc. Dart 3 switch expressions are cleaner than if-else chains for enum dispatch.
- **`firstOrNull` (Dart 3)** for safe list lookup — `data.correlations.where((c) => c.engineerHandle == handle).firstOrNull`. Returns null if empty, no cast needed.

---

## Step 5 — Tradeoffs

**Orchestrating provider vs. per-screen providers.** The single `WatchDataNotifier` centralizes the fetch+evaluate+append logic. The trade: every screen that watches it triggers the same fetch (Riverpod caches, so it's one fetch per rebuild cycle, not per screen). If the fetch is expensive, this is fine — it's one fetch. If the fetch is cheap and screens need different data slices, per-screen providers would be more granular. For §W4, the fetch is one network round-trip + one signal evaluation, and all screens need the same bundle, so the orchestrator is the right choice.

**fl_chart vs. custom CustomPainter chart.** fl_chart is a dependency, but it handles axes, grid, tooltips, and animations for free. A custom chart would be ~200 lines of `CustomPainter` code and would need to reinvent axis labeling. The trade: a dependency vs. code. fl_chart is well-maintained, ~1MB, and the bar chart is exactly what's needed. Worth the dependency.

**Auto-append alerts on fetch vs. manual append.** `WatchDataNotifier._fetch()` auto-appends new alerts to the log after signal evaluation. The trade: opening the dashboard has a side effect (writes to `forge_config.json`). The alternative — a separate "Process alerts" button — would require the user to click before alerts appear, which defeats the "passive monitoring" purpose. Auto-append is the right default for a dashboard; the side effect is the feature.

**Constructor args for WorkspaceHealthScreen vs. watching a provider.** `WorkspaceHealthScreen` takes `WorkspaceStatus` and `List<FailureSignal>` as constructor args, passed from the dashboard. The trade: the screen isn't "live" (it won't update if the data changes while it's open). The alternative — making it watch `watchDataProvider` — would mean another fetch when navigating to it. Since the dashboard already has the data, passing it as constructor args is cheaper and simpler. If the user refreshes the dashboard, they pop back and re-navigate, which gets fresh data.

---

## Step 6 — Mistakes, dead ends, and wrong turns

**`.length()` vs. `.length` — List.length is a getter, not a method.** First dashboard draft used `activeAlerts.where(...).length()` — the analyzer caught `invocation_of_non_function_expression`. In Python, `len()` is a function; in Dart, `.length` is a property. Fix: `.length` (no parens). Lesson: when switching between languages, property-vs-method is a common trap. The analyzer catches it immediately — run it after every file.

**`firstWhere(orElse: () => null as dynamic)` tempted a third time.** First dashboard draft had `_passRateFor` using the broken cast. Caught it during review, replaced with `.where(...).firstOrNull`. This is the third time this anti-pattern has tempted (§W1, §W2, §W4). The pattern is now muscle memory: never use `firstWhere(orElse: () => null as dynamic)`. Always use `.firstOrNull`.

**Unused imports from over-eager importing.** First draft imported `project_status_aggregator.dart` and `watch_signal_service.dart` in the dashboard, but the dashboard only uses `WatchData` (which already contains the `WorkspaceStatus` and signals). The analyzer flagged `unused_import`. Fix: remove the imports. Lesson: import what you use, not what you might use. The analyzer is the safety net for import hygiene.

**Import ordering matters to the linter.** `directives_ordering` info fires when imports aren't alphabetically sorted within their section. The fix is mechanical (sort the lines), but it's worth knowing: the analyzer treats `package:` imports and relative imports as separate sections, and within each section, alphabetical order is required. A quick sort before analyzing saves a round-trip.

---

## Step 7 — Pitfalls to watch for

**`ref.watch` for data, `ref.read` for mutations.** If you `ref.watch(alertLogProvider.notifier)`, the widget rebuilds on every notifier state change — including the one you just triggered by calling `dismissAlert`. This can cause infinite loops or jank. Always `ref.read` the notifier when you're calling a method; only `ref.watch` the state (the `List<AlertEntry>`).

**fl_chart needs a bounded height.** `BarChart` inside an unbounded-height parent (like a `ListView` without a `SizedBox`) throws a layout error. Always wrap `BarChart` in a `SizedBox(height: ...)` or give its parent a bounded height. The chart won't size itself.

**`AsyncValue.guard` for refresh, not raw try/catch.** `refresh()` sets `state = const AsyncLoading()` then `state = await AsyncValue.guard(_fetch)`. `AsyncValue.guard` catches errors and wraps them in `AsyncError`, so the `.when(error: ...)` branch handles them. If you use raw try/catch, you have to manually wrap in `AsyncError` — more code, more places to miss.

**The orchestrating provider has a side effect.** `WatchDataNotifier._fetch()` writes to `forge_config.json` (via `alertLogProvider.notifier.appendAlerts`). This means reading the provider causes a write. This is intentional (the dashboard auto-populates the alert log), but it's worth knowing: if you ever need a "read-only" mode (e.g. for testing), you'd need to skip the append. The current code doesn't guard against this because the dashboard is always "live."

**Dismissed entries still take up space in the log.** `clearDismissed()` removes them, but until then they're in the list at 0.4 opacity. If the log grows large (hundreds of dismissed alerts), the list gets long. The 24h dedup window in `AlertEngine` limits growth (alerts older than 24h can be re-emitted, but the same condition won't duplicate within 24h), but a busy workspace could still accumulate. A future "auto-prune dismissed after 7d" would help; for v1, manual `clearDismissed` is the release valve.

---

## Step 8 — What an expert notices

A junior would have each screen watch its own providers and orchestrate the fetch. An expert centralizes the orchestration in one provider and has the screens read the result. The junior's code duplicates the fetch logic; the expert's code has one fetch, many readers. The difference: if the fetch changes, the junior updates N screens; the expert updates one notifier.

A junior would color the spend bars a single color (e.g. all amber). An expert colors them per-day by pass rate. The junior's chart shows "how much was spent"; the expert's chart shows "was the spend productive." The color is the signal; the height is the magnitude. A tall red bar is the most actionable data point on the screen.

A junior would put all alerts in one flat list. An expert separates active from dismissed with a divider. The junior's log requires scanning past dismissed alerts to find active ones; the expert's log puts active first. The divider only appears when dismissed exist, so an all-active log is clean.

A junior would `ref.watch(alertLogProvider.notifier)` for the dismiss action. An expert `ref.read`s the notifier. The junior's widget rebuilds when the notifier state changes (including the change the dismiss just caused); the expert's widget only rebuilds when the data it displays changes. The difference is one keyword (`watch` vs `read`), but it's the difference between smooth dismiss and janky rebuild.

---

## Step 9 — Transferable lessons

**One orchestrating provider, many reader screens.** When multiple screens need the same data bundle, centralize the fetch in one provider. The screens watch the provider, not the underlying sources. This keeps the UI decoupled from the fetch pipeline. If the pipeline changes (caching, polling, error handling), only the orchestrator changes. This applies to any dashboard or multi-screen feature: one provider for the data, many screens for the views.

**Color encodes the secondary signal.** A chart that shows magnitude (bar height) can also show quality (bar color) without adding a second chart. The color is free — it doesn't take screen space. This applies to any chart where each data point has a "good/bad" axis in addition to magnitude. Use color for the quality, height for the quantity.

**`ref.watch` for data, `ref.read` for mutations.** Watching a provider causes rebuilds when its state changes. Reading a provider is a one-shot call. For data display, watch (so the UI updates when data changes). For mutations (calling a method on a notifier), read (so the call doesn't cause a rebuild). Mixing these up causes jank or infinite loops.

**Auto-side-effects are a feature, not a bug — when documented.** `WatchDataNotifier._fetch()` writes to the alert log as a side effect of reading. This is intentional: the dashboard auto-populates the log. But it's a side effect, and side effects should be documented. The rule: if reading a provider causes a write, say so in the provider's docstring or comments. Future readers need to know that `ref.watch(watchDataProvider)` isn't pure.

**Constructor args for display-only screens.** `WorkspaceHealthScreen` takes `WorkspaceStatus` and `List<FailureSignal>` as constructor args. It's a display screen, not a live-updating screen. This is cheaper than having it watch a provider (no second fetch, no second rebuild cycle). The trade: the screen isn't "live" — if the data changes while it's open, it won't update. For a dashboard drill-down that the user opens, reads, and closes, that's the right trade.