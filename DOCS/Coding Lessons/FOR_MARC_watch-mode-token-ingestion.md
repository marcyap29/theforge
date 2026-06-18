# FOR_MARC: Watch Mode Token Ingestion Engine (§W1)

**Session:** 2026-06-17
**Task:** Build the abstract `UsageProvider` layer + 4 provider implementations + 4 demo profiles + engineer roster settings. Ship 9 new files. Zero analyzer issues. Zero Firebase.

---

## Step 1 — Approach and reasoning

The job was to build the data source for all of Watch Mode. Every signal in §W2–§W6 (git activity, CI correlation, failure signals, alerts, dashboards) eventually asks the same question: *how much is this engineer spending, and on what?* §W1 is the layer that answers that question once, so everything downstream can just read the answer.

The reasoning chain:

1. **Start with the output, not the input.** Before thinking about Anthropic's API or OpenAI's endpoint, decide what shape the rest of the app needs. That shape is `EngineerUsage` — one engineer, one provider, 30 days of daily breakdown, a 30-day total, a session count, and a list of alert flags. Everything else is plumbing to produce that.

2. **Hide every provider behind one interface.** The `UsageProvider` abstract class is the contract. Anthropic, OpenAI, Gemini, Ollama, and the demo data all implement the same interface. The `UsageService` resolves a handle to a provider, calls it, and returns the result. §W2–§W6 never import a provider class — they only know about `EngineerUsage`. This is the same pattern The Forge already uses for LLM calls (`LlmProvider` → `LlmService`), so it's not a new idea — it's the house style.

3. **Fail per-engineer, not per-batch.** If one engineer's API key is wrong, the other engineers still render. `fetchAllUsage()` catches each failure and returns an `EngineerUsage` with `alertFlags: ['fetch_error']` instead of throwing. The dashboard shows "error" for that engineer and "data" for everyone else. This is the right default for telemetry — you're ingesting, not serving a request-response.

4. **Ship with synthetic data so the app works before configuration.** Four demo profiles (the runaway spender, the ghost, the high performer, yourself) using `Random(42)` so the output is identical every run. The default roster auto-loads one demo entry on first launch — the app never shows an empty state.

---

## Step 2 — Roads not taken

**Road A — One big `fetchUsage()` that switches on providerType internally.**
Rejected. A single function with a giant switch means every provider change touches the same file, and there's no way to test one provider in isolation. The abstract-class approach lets each provider own its own file and HTTP logic. Same reason The Forge has `ClaudeProvider`, `OpenAiProvider`, etc. as separate classes instead of one `LlmService` with a switch.

**Road B — Store the roster in SQLite via drift (like the project list).**
Rejected. The roster is small (typically 1–10 engineers), changes rarely, and belongs with the rest of the settings. `forge_config.json` already exists for settings storage — adding a `watch_engineer_roster` key to it keeps all user-configurable state in one file. A new database table would split configuration across two stores for no benefit. The existing `SettingsNotifier` already proved this pattern works.

**Road C — Make `fetchAllUsage()` throw on first failure.**
Rejected hard. This is the most important decision in the whole task. If the function throws, one bad API key means the dashboard shows nothing — not "one engineer errored." Telemetry ingestion must be resilient to partial failure. The catch-and-return-error-entry pattern means the caller never has to wonder "did the whole batch fail or just one?" — each entry carries its own status in `alertFlags`.

**Road D — Use `Random()` without a seed for demo data.**
Rejected. A non-seeded `Random()` gives different demo data every run. That means screenshots change, regression tests can't assert against fixed values, and demos look flaky. `Random(42)` makes the demo deterministic — same 30 days, same costs, same alert flags, every time. The seed is part of the contract, not an implementation detail.

**Road E — Build the Gemini provider for real.**
Rejected (for now). Google has no reliable per-engineer usage API as of 2026. Rather than guess at an endpoint that might not exist, the Gemini provider returns a stub with `['api_unsupported']`. The code path is alive (the provider exists, the service routes to it) but doesn't pretend to have data. This is more honest than returning zeros — zeros look like "the engineer spent nothing," `api_unsupported` looks like "we can't tell."

---

## Step 3 — How the pieces connect

The flow is a three-layer cake, and the order matters:

```
EngineerRosterNotifier (settings)
    ↓ provides List<EngineerRosterEntry>
UsageService (service)
    ↓ resolves each entry → UsageProvider
    ↓ calls fetchUsage() per entry
UsageProvider (abstract)
    ↓ implemented by Anthropic / OpenAI / Gemini / Ollama / Demo
    ↓ returns EngineerUsage
```

**Why this order:** The roster is the source of truth for "who exists." The service is the orchestrator — it knows *how* to ask each provider but doesn't know the details. The providers know the details (HTTP endpoints, headers, response shapes) but don't know about each other.

The `usageServiceProvider` (Riverpod) wires it together: it watches the roster, and when the roster loads, it constructs a `UsageService` with it. If the roster is still loading, the provider returns `null` — consumers gate on that.

The key invariant: **§W2–§W6 import `EngineerUsage` and `UsageService`, never a provider.** If a future feature needs to know "is this the Anthropic provider?" it checks `usage.providerName == 'anthropic'`, not the runtime type. This keeps the surface area small and the coupling low.

---

## Step 4 — Tools, methods, and frameworks

- **Riverpod `AsyncNotifier`** for the roster — same pattern as `SettingsNotifier`. `build()` reads from disk, mutators write back and update state. The `AsyncNotifier` wrapper handles loading/error states for free.
- **`forge_config.json`** in `getApplicationSupportDirectory()` — the authoritative settings store. Same file `SettingsNotifier` uses; we just added a new key. `JsonEncoder.withIndent('  ')` for human-readable diffs.
- **`package:http`** for all HTTP calls — already in `pubspec.yaml`, no new deps. `http.get` with `Uri.parse` for query params, headers as a map. Same pattern as `ClaudeProvider`.
- **`Future.wait`** for the OpenAI provider's per-day parallelism — the OpenAI usage endpoint takes a single `date`, not a range, so we fire N requests in parallel instead of sequentially. This is a real API constraint, not a design choice.
- **`@immutable`** on `EngineerUsage` and `DailyUsage` — every field `final`, no mutators. Matches the codebase convention for data models (see `InterviewState`, `LlmSettings`).
- **`implements UsageProvider`** (not `extends`) — `UsageProvider` is an abstract class, not an interface, but `implements` is cleaner here because the providers don't share any inherited logic. Gemini and Ollama can be `const` constructors since they have no state.

---

## Step 5 — Tradeoffs

**Blended cost rate vs. per-model pricing.** The spec says use a single blended rate ($9/MTok for Anthropic, $5/MTok for OpenAI). The real APIs return per-model breakdowns (Sonnet vs. Haiku vs. Opus have wildly different prices). The blended rate is simpler and "close enough" for v1 — but it'll overcount cheap-model usage and undercount expensive-model usage. Trade: simplicity now, accuracy later. When §W4 dashboard ships and someone says "this number looks wrong," that's the signal to add per-model pricing.

**Per-day parallel HTTP vs. single ranged call (OpenAI).** Anthropic's API accepts `start_date` + `end_date` — one call for 30 days. OpenAI's API accepts one `date` — 30 calls for 30 days. We parallelize with `Future.wait`, but that's still 30 requests vs. 1. Trade: correctness (we have to use the API as it exists) vs. rate-limit risk (30 rapid-fire requests could hit a throttle). Mitigation: if rate limits become a problem, add a semaphore or switch to sequential. Not a problem yet.

**Stubs for Gemini and Ollama vs. half-built implementations.** We could have guessed at a Gemini endpoint and returned zeros. We could have built an Ollama sidecar. Instead, both return explicit "unsupported" flags. Trade: the dashboard shows "unsupported" for those providers instead of fake data or zeros. This is more honest and prevents users from trusting numbers that aren't real.

**Config-file storage for API keys vs. macOS Keychain.** The existing `SettingsNotifier` moved away from Keychain (because the `keychain-access-groups` entitlement broke sandbox builds). The roster stores API keys in `forge_config.json` too — same convention. Trade: keys are in a plain JSON file in Application Support instead of the Keychain. For a dev tool on a personal machine, this is acceptable. For a shared machine or production deployment, it would need to change. The bugtracker records this decision (BUG_PREVENTION.md, macOS Sandbox section).

---

## Step 6 — Mistakes, dead ends, and wrong turns

**The `copyWith` extension I wrote and then deleted.** The first draft of `anthropic_usage_provider.dart` had an `extension on EngineerUsage` for `copyWith` to override the handle in the error path. It was overkill — the `_errorUsage` helper can just construct an `EngineerUsage` directly with the handle passed in. Deleted the extension, simplified the helper. Lesson: don't add abstractions for one-use code. If you're constructing the same object twice with one field different, just construct it twice.

**Import path bug caught by the linter.** `demo_usage_provider.dart` is at `lib/services/watch/`, and I initially wrote `import '../usage_provider.dart'` — which would resolve to `lib/services/usage_provider.dart` (wrong). The analyzer caught it immediately (`uri_does_not_exist`). Fix: `import 'usage_provider.dart'` (same directory). Lesson: when a file is at the same level as its import target, the relative path is just the filename, not `../`. The linter is the safety net here — always run `dart analyze` after writing, not just before committing.

**Forgetting that `AsyncNotifier` requires `build()` to return a `Future`.** The roster notifier's `build()` reads a file from disk, which is async. No issue here, but the pattern matters: `build()` is `Future<List<EngineerRosterEntry>>`, not `List<EngineerRosterEntry>`. If you try to make it synchronous, Riverpod rejects it at the type level. The `SettingsNotifier` in the codebase is the reference — copy that shape exactly.

---

## Step 7 — Pitfalls to watch for

**Usage APIs change without warning.** The Anthropic response shape (`data[].aggregation_key.date`) is approximate. The OpenAI shape (`data[].aggregation_timestamp` as Unix epoch) is approximate. Both providers can rename fields, restructure responses, or add pagination at any time. The defensive parse (catch `FormatException` + `TypeError`, return `api_error`) is what prevents a silent API change from crashing the dashboard. **Never** write a parser that assumes the response shape is stable.

**`Random(seed)` is deterministic per-process, not per-anything-else.** `Random(42)` gives the same sequence every time you construct it — but only for the same Dart version and platform. If you ever change the demo provider's logic (add a day, change the variance formula), the output changes even with the same seed. The seed makes output reproducible across runs, not across code changes. If you snapshot demo data for a regression test, snapshot the *values*, not just the seed.

**Don't put API keys in SharedPreferences.** The roster's `apiKey` field goes into `forge_config.json` (a file in Application Support). SharedPreferences (NSUserDefaults) can be wiped by `flutter clean` during development. The config file is more durable. This is the same lesson `SettingsNotifier` already learned — copy it, don't relearn it.

**The default roster entry must be a `const`.** `const EngineerRosterEntry(handle: 'demo', ...)` lets you return `const [_defaultEntry]` from `build()` without allocating. If the default isn't `const`, every call to `build()` creates a new list. Small thing, but the pattern matters — defaults should be compile-time constants when possible.

**One bad API key shouldn't crash the batch.** This is worth repeating because it's the easiest mistake to make. If `fetchAllUsage()` throws on the first failure, the dashboard shows nothing. If it catches and returns `fetch_error`, the dashboard shows one error row and the rest of the data. The catch is not optional — it's the contract.

---

## Step 8 — What an expert notices

A junior engineer would write `fetchAllUsage()` with a `try/catch` around the whole loop — one failure kills the batch. An expert writes the `try/catch` *inside* the loop — each entry is independent, so each entry's failure is isolated. The difference is one line of code, but it's the difference between "the dashboard works when one engineer's key is wrong" and "the dashboard is blank when one engineer's key is wrong."

A junior would store the roster in SharedPreferences because "it's just settings, right?" An expert stores it in `forge_config.json` because SharedPreferences can be wiped by container resets during development, and because all the other settings already live there. Consistency of storage location matters more than the specific choice of store.

A junior would make the demo data use `Random()` (no seed) because "it's just demo data, who cares?" An expert uses `Random(42)` because deterministic demo data means screenshots, regression tests, and demos all stay stable. The seed is a contract with the future — anyone who changes the demo logic knows the output will shift, and that's a deliberate decision, not an accident.

A junior would build the Gemini provider by guessing at an endpoint and returning zeros. An expert returns `['api_unsupported']` because zeros lie (they say "no spend" when the truth is "we don't know") and flags tell the truth ("we can't get this data"). Honest absence is more valuable than fake presence.

---

## Step 9 — Transferable lessons

**The "abstract interface + per-impl file + one service that routes" pattern is The Forge's house style.** §4 (LLM providers) uses it. §W1 (usage providers) uses it. Any future pluggable subsystem in this codebase should use it. The rule: downstream consumers import the interface and the output model, never a concrete implementation. If you're tempted to `import 'anthropic_usage_provider.dart'` from a widget, stop — you're coupling the widget to a provider. Go through the service.

**Error isolation is the right default for ingestion, propagation is the right default for request-response.** A login form should throw on failure (the user needs to know). A telemetry ingestion batch should not (one failure shouldn't poison the rest). The question to ask: "if one item fails, should the caller see all the other items, or nothing?" If the answer is "the other items," catch per-item. If the answer is "nothing," let it throw.

**Defaults that auto-populate are better than empty states.** The default `demo` roster entry means the app has data to show before the user configures anything. This is the same principle as shipping the 4 synthetic profiles — the app should work out of the box. Empty states are a failure mode, not a feature. Whenever you build a settings-backed feature, ask: "what does the app show before the user opens Settings?" If the answer is "nothing," add a default.

**Deterministic synthetic data is a feature.** `Random(42)` isn't a hack — it's a deliberate choice that makes demo data reproducible. The same principle applies to any test fixtures, sample data, or seeded databases. A seed isn't an implementation detail; it's a contract. Document it, don't change it casually, and anyone who modifies the data-generation logic knows they're breaking the contract.

**Storage-location consistency beats storage-location optimization.** The roster could go in SQLite (it's structured data), in SharedPreferences (it's settings), or in `forge_config.json` (where the other settings live). The right answer is "where the other settings live" — because consistency means one read/write pattern, one migration path, one place to look when debugging. The fact that SQLite would be "more correct" for structured data doesn't matter if it splits settings across two stores.