# FOR_MARC: Watch Mode Signal Engine (§W3)

**Session:** 2026-06-17
**Task:** Build the Failure Signal Engine (derives management-layer signals from §W1+§W2 data), Alert Engine (deduplicates signals into alert entries), Alert Log (persists to forge_config.json), Project Status Aggregator (workspace health), and WatchSignalService (orchestrates all three). Ship 6 new files. Zero analyzer issues. Zero Firebase. Zero HTTP — pure computation.

---

## Step 1 — Approach and reasoning

§W3 is the first Watch Mode subsystem that does no fetching. §W1 fetched token spend. §W2 fetched git commits and CI runs. §W3 takes all of that already-fetched data and derives meaning from it: "this engineer is burning tokens without producing passing builds," "this workspace has gone quiet while still spending," "this engineer keeps reverting their work."

The reasoning chain:

1. **Computation is a separate layer from fetching.** §W1 and §W2 are HTTP-bound — they talk to Anthropic, GitHub, OpenAI. §W3 is pure functions: data in, signals out. This separation matters because it means §W3 is always available. No API key? No GitHub token? §W3 still runs — it just gets empty inputs and returns empty outputs. The provider is non-nullable (`Provider<WatchSignalService>`, not `Provider<WatchSignalService?>`). This is the inverse of §W1/§W2 where the service was nullable because it depended on config.

2. **Six signals, one engine.** The spec defined six signal types: high token-to-fail ratio, loop detection, churn (reverts), spend threshold, runaway day, stalled workspace. Each has its own derivation rule and severity. The engine is one class with one `evaluate()` method that runs all six — the caller doesn't pick which signals to compute, they get all of them. §W4 (the dashboard) decides which to display.

3. **Deduplication is a separate concern from detection.** `FailureSignalEngine` detects signals. `AlertEngine` decides which signals become alert entries, deduplicated against the existing log. Separating these means the detection logic never has to know about the alert log state — it just reports what it sees. The dedup rule (same handle+signalType within 24h, dismissed alerts still dedup) lives entirely in `AlertEngine`.

4. **Workspace status is a third output, not a signal.** The dashboard needs a "workspace health" summary — commits last 7d vs prior 7d, velocity trend, stall detection, CI pass rate. This isn't a signal (it's not actionable per-engineer) and it's not an alert (it's not deduplicated). It's a status snapshot. `ProjectStatusAggregator` produces it as a separate output in `WatchSignalResult`.

---

## Step 2 — Roads not taken

**Road A — One big `evaluate()` function with all signal logic inline.**
Rejected. The engine would be 300 lines of nested if-statements. Instead, each signal type has its own private method (`_highTokenToFailRatio`, `_loopDetected`, etc.) and `evaluate()` calls them all and concatenates the results. Each method is independently testable and readable. The cost is six small methods instead of one big one; the benefit is that you can understand one signal without reading all six.

**Road B — Make the alert log a database table (drift).**
Rejected. The alert log is a flat list of entries with a 24h dedup window — it doesn't need querying by arbitrary fields, it needs "get all" and "update by id." `forge_config.json` already holds the roster and GitHub config; adding `watch_alert_log` to the same file keeps all Watch Mode state in one place. A database table would split state across two stores for no query benefit. If the log grows to thousands of entries, *then* migrate — but for v1 with ~5 engineers and a 24h dedup window, the list stays small.

**Road C — Emit both warning AND critical for the same condition.**
Rejected hard. For `highTokenToFailRatio` and `spendThreshold`, the spec said "emit critical OR warning, never both." If both were emitted, the alert log would have two entries for the same condition — one saying "warning: $X" and one saying "critical: $X" — and the dashboard would show double the alerts. The fix is to test the critical threshold first, then use else-if for warning. One condition → one alert → one severity.

**Road D — Emit one signal per runaway day (not one per engineer).**
Rejected. An engineer with five $100+ days would produce five `runawayDay` signals, flooding the alert log. The spec was explicit: "emit ONE signal (the worst day), not one per day — use the day with highest tokenSpend." The engine finds the peak day per engineer and emits one critical signal with the peak's date and spend in metadata. The dashboard shows "worst day was $X on Y" without flooding.

**Road E — Add a stub signal for bug introduction rate.**
Rejected. The spec was explicit: "Do not attempt to implement it. Do not add a stub signal for it either." A stub would suggest the signal exists when it doesn't — the dashboard would show a `bugIntroductionRate` signal type that always returns nothing, which reads as "no bugs introduced" when the truth is "we don't measure this." Honest absence beats fake presence. The signal type isn't even in the enum.

---

## Step 3 — How the pieces connect

The flow is three engines, one orchestrator, one result:

```
WatchSignalService.evaluate({
  correlations,    // from §W2
  tokenUsage,      // from §W1
  roster,          // from §W1 settings
  commits,         // from §W2
  ciRuns,          // from §W2
  existingLog,     // from AlertLogNotifier
})
    │
    ├── FailureSignalEngine.evaluate()   → List<FailureSignal>
    │     (6 signal types, severity escalation)
    │
    ├── AlertEngine.evaluate()           → List<AlertEntry>
    │     (dedup against existingLog, 24h window)
    │
    ├── ProjectStatusAggregator.aggregate() → WorkspaceStatus
    │     (velocity trend, stall detection, CI pass rate)
    │
    └── WatchSignalResult { signals, newAlerts, workspaceStatus }
```

**Why this order:** Signals are detected first (pure data derivation). Alerts are derived from signals (dedup against the log). Status is computed independently (it doesn't depend on signals or alerts). All three are bundled into `WatchSignalResult` — the single return type §W4 consumes.

The `WatchSignalService` is `const`-constructible. It has no state, no config, no dependencies. The provider is `Provider<WatchSignalService>((ref) => const WatchSignalService())` — every rebuild returns the same instance. This is the cleanest possible provider: pure function, no lifecycle.

---

## Step 4 — Tools, methods, and frameworks

- **`AsyncNotifier<List<AlertEntry>>`** for the alert log — same pattern as `EngineerRosterNotifier` and `GitHubConfigNotifier`. `build()` reads from `forge_config.json`, mutators write back. The config file is the single persistence store.
- **`SignalType` and `SignalSeverity` enums with `.name`** — used for JSON serialization (`signalType.name` → string, `SignalType.values.byName(string)` → enum). Dart's enum `.name` property is stable and readable — no manual string mapping needed.
- **`Map<String, dynamic>` for signal metadata** — each signal carries the raw numbers that produced it (ratio, threshold, peak spend, stalled days). §W4 can read metadata for drill-down without re-deriving the signal. The metadata is untyped (dynamic) because each signal type has different fields — a typed union would be overkill for a v1 dashboard.
- **`firstWhere` with `orElse` avoided** — used `.where((m) => ...).firstOrNull` instead in §W2, and here the loop detection uses a manual scan with a running counter. `firstWhere(orElse: () => null as dynamic)` is always wrong (see §W2 coding lesson).
- **`@immutable` on all models** — `FailureSignal`, `AlertEntry`, `WorkspaceStatus`, `WatchSignalResult`. Every field `final`. Matches the codebase convention.

---

## Step 5 — Tradeoffs

**24h dedup window vs. "ever" dedup.** The same handle+signalType within 24h is skipped. After 24h, the same condition can re-alert. Trade: a runaway spend that persists across days will surface again tomorrow, which is good (the user needs to know it's still happening) but could feel noisy. The alternative — "ever" dedup, where a condition alerts once and never again — is worse because it hides persistent problems. The 24h window is the compromise: re-alert if the problem persists, don't spam within a day.

**Dismissed alerts still dedup.** A dismissed alert prevents re-alerting within 24h, but after 24h the same condition can alert again (even if previously dismissed). Trade: the user sees "I dismissed this, why is it back?" The answer is: dismissal means "I saw this," not "this is resolved." If the condition persists, it should re-surface. The alternative — dismissed-forever — would hide problems the user dismissed once but that never got fixed.

**One signal per engineer for runaway day (worst day only).** An engineer with five $100+ days gets one alert, not five. Trade: the dashboard shows "worst day was $X" but not "you had five bad days." The metadata has the peak day's date and spend — if §W4 wants to show "5 days over $100, worst was $X on Y," it can derive that from the `DailyCorrelation` list directly. The signal is the summary; the detail is in the data.

**`stalledDays=999` for empty commit list.** An empty commit list means the workspace has never committed (or all commits are outside the lookback). `stalledDays=999` makes `isStalled=true` correct without special-casing. Trade: the dashboard shows "999 days stalled" which looks weird. The fix is in the UI layer (§W4): display "never" when `stalledDays >= 999`, not "999 days." The data layer reports a sentinel; the display layer interprets it.

**Severity escalation (critical OR warning, not both).** For `highTokenToFailRatio` and `spendThreshold`, the engine emits one severity. Trade: you lose the "it was a warning, now it's critical" progression in the alert log — the log has one entry at the current severity, not a history of severity changes. The alternative (emit both, let the dashboard filter) would double the alerts. The chosen trade: one alert at the current severity; if the user wants history, they look at the signal metadata over time.

---

## Step 6 — Mistakes, dead ends, and wrong turns

**Field access bug — `DailyUsage.tokenSpend` doesn't exist.** First draft of `_runawayDay` used a `DailyUsage? peak` temporary and accessed `.tokenSpend`. But `tokenSpend` is on `DailyCorrelation`, not `DailyUsage` — `DailyUsage` has `costUSD`. The analyzer caught it immediately (`undefined_getter`). Fix: iterate `DailyCorrelation` directly and store the peak as `DailyCorrelation?`. Lesson: when two models have similar fields (`DailyUsage.costUSD` vs `DailyCorrelation.tokenSpend`), the wrong type can slip in during refactoring. The analyzer is the safety net — always run it after writing, not just before committing. This is the third import/type bug caught by the analyzer in §W1/§W2/§W3 (the §W1 `../usage_provider.dart` path, the §W2 `github_config_notifier.dart` path, and now this). The pattern: the analyzer catches what the eye misses.

**Almost used `firstWhere(orElse: () => null as dynamic)` again.** Caught myself in `failure_signal_engine.dart` when looking up an engineer's threshold from the roster. Started writing `roster.firstWhere((e) => e.handle == handle, orElse: () => null as dynamic)` — remembered the §W2 lesson and switched to a `Map<String, double>` built from the roster (`thresholdByHandle`). Cleaner, no cast, O(1) lookup instead of O(n) scan per engineer. Lesson: the same anti-pattern tempts every time. The fix is to build a lookup map once, not to scan the list per item.

---

## Step 7 — Pitfalls to watch for

**Severity escalation must emit one, not both.** If you write `if (ratio > 100) emit critical; if (ratio > 30) emit warning;` you get both for a ratio of 150. The fix is `if (ratio > 100) emit critical; else if (ratio > 30) emit warning;`. This applies to any tiered threshold: test the highest tier first, use else-if for lower tiers. One condition → one alert.

**Loop detection counts the longest run, not the first run.** A naive implementation counts the first consecutive run and stops. The engine scans the whole list, tracking the longest run seen so far. An engineer with a 2-day loop, a 1-day break, then a 3-day loop should report 3 (the longest), not 2 (the first). The `current` counter resets on non-loop days; `longest` is only updated when `current > longest`.

**Runaway day emits one signal, not one per day.** If you write `for (final d in days) if (d.tokenSpend > 100) emit signal;` you get N signals for N bad days. The fix: track the peak day, emit one signal after the loop. The peak is the most actionable — "worst day was $X" is more useful than "you had 5 bad days" because it points to the specific day to investigate.

**Stalled workspace handle is `'workspace'`, not an engineer handle.** If you use an engineer handle, the stalled signal gets mixed into per-engineer alerts in the log. The literal `'workspace'` string distinguishes workspace-level signals. §W4 can filter by `handle == 'workspace'` to show workspace alerts separately from engineer alerts. This is a convention, not a type system guarantee — be consistent.

**`stalledDays=999` is a sentinel, not a real number.** The dashboard must interpret `>= 999` as "never," not display "999 days stalled." Document the sentinel in the model so the display layer knows to handle it. The data layer reports the sentinel; the display layer interprets it.

**Dismissed alerts still dedup.** If you skip dedup for dismissed alerts, a dismissed condition re-alerts immediately (within the 24h window), which is spammy. The dedup checks the existing log regardless of dismissed status — dismissed alerts still occupy their dedup slot for 24h. After 24h, the dismissed alert is outside the window and the condition can re-alert.

---

## Step 8 — What an expert notices

A junior would put all signal logic in one method. An expert splits each signal into its own method. The junior's code works but is unreadable — 300 lines of nested ifs, impossible to test one signal in isolation. The expert's code has six small methods, each independently testable. The cost is six method signatures instead of one; the benefit is that you can understand `_loopDetected` without reading `_churnDetected`.

A junior would emit both warning and critical for tiered thresholds. An expert tests critical first, else-if for warning. The junior's alert log has double entries; the expert's has one. The difference is one `else` keyword — but it's the difference between "the dashboard shows 12 alerts" and "the dashboard shows 6 alerts" for the same underlying conditions.

A junior would emit one signal per runaway day. An expert emits one per engineer (the worst day). The junior's dashboard floods; the expert's dashboard is readable. The difference is a loop that tracks the peak vs. a loop that emits per item — same data, different alert volume.

A junior would make `WatchSignalService` nullable "in case config isn't set." An expert makes it non-nullable because it does no fetching — it's pure computation. The junior's provider returns `null` when config is missing, forcing §W4 to handle null. The expert's provider always returns the service; empty inputs return empty outputs. The difference is whether the caller has to null-check the computation layer — and the answer should be no, because computation doesn't fail for lack of config.

A junior would add a stub signal for bug introduction rate "so the enum is complete." An expert omits the enum value entirely. The junior's dashboard shows a signal type that never fires, reading as "no bugs introduced" when the truth is "we don't measure this." The expert's dashboard doesn't show what isn't measured. Honest absence beats fake presence.

---

## Step 9 — Transferable lessons

**Fetching services are nullable, computation services are not.** §W1 (`UsageService?`) and §W2 (`GitActivityService?`) are config-gated — they return null when unconfigured because they can't fetch without credentials. §W3 (`WatchSignalService`) is always available because it does no fetching. The rule: if a service does I/O, it's nullable (the caller must handle "not ready"). If a service is pure computation, it's non-nullable (the caller always gets a result, possibly empty). This split keeps the caller's null-checks proportional to the actual failure modes.

**One condition → one alert → one severity.** Tiered thresholds (warning at X, critical at 2X) should emit one alert at the current severity, not two alerts at both severities. The implementation is: test the highest tier first, else-if for lower tiers. This applies to any tiered system — alerts, log levels, error categories. Doubling alerts for the same condition inflates the log and confuses the reader.

**Emit the summary, not the instances.** For runaway day, emit one signal (the worst day), not one per bad day. For loop detection, emit one signal (the longest run), not one per loop. The rule: if the same condition occurs N times, emit one signal with the most actionable instance, not N signals. The dashboard can derive "how many times" from the raw data if needed; the alert log shouldn't be the data store.

**Sentinels are fine, document them.** `stalledDays=999` for "never committed" is a sentinel value. Sentinels are a legitimate pattern when the alternative is a nullable field (`int? stalledDays`) that forces every caller to null-check. The contract: the data layer reports the sentinel, the display layer interprets it. Document the sentinel in the model so the display layer knows `>= 999` means "never," not "999 days."

**Honest absence beats fake presence.** Bug introduction rate isn't measured. A stub signal (always returns nothing) would suggest it is measured and finds nothing. Omitting the enum value entirely is honest: the signal type doesn't exist because the measurement doesn't exist. This applies to any unimplemented feature — don't add a placeholder that reads as "working but empty," add nothing and document the gap.

**The analyzer catches what the eye misses.** Three type/import bugs in three sessions (§W1, §W2, §W3), all caught by `dart analyze`. The pattern: when two models have similar fields, or when a file moves between directories, the wrong path/type slips in during writing. The eye sees "tokenSpend" and assumes it's right because the word looks right. The analyzer sees "DailyUsage doesn't have tokenSpend" and stops. Run the analyzer after every file, not just before commit — it's the cheapest bug-finder you have.