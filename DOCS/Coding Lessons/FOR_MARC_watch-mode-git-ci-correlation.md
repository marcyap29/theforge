# FOR_MARC: Watch Mode Git + CI Correlation (§W2)

**Session:** 2026-06-17
**Task:** Build the Git Activity Engine (GitHub GraphQL — commits, PRs, agent-vs-human attribution) and CI Outcome Correlator (GitHub Actions REST — pass/fail/timeout per commit). Output is a per-engineer `EngineerCorrelation` shape that §W3 and §W4 consume. Ship 8 new files. Zero analyzer issues. Zero Firebase.

---

## Step 1 — Approach and reasoning

The job was to answer one question for every engineer on the team: *when they spend tokens, do the builds pass?* That's the core Watch Mode signal — it's what separates "high performer" (high spend + high pass rate) from "management decision" (high spend + low pass rate).

The reasoning chain:

1. **Two data sources, one join.** §W1 gave us token spend per engineer per day. §W2 adds two more: git commits (who committed what, when) and CI runs (did the build pass or fail). The correlation is the join: an engineer's commits trigger CI runs, and the CI run outcomes are matched back to that engineer's daily token spend. The commit SHA is the join key — it's the only field that appears in both the git data and the CI data.

2. **Abstract both data sources behind interfaces.** Same pattern as §W1: `GitActivityProvider` and `CIOutcomeProvider` are abstract classes. GitHub GraphQL and GitHub Actions REST are the implementations. §W3 and §W4 never import a provider — they consume `EngineerCorrelation`, the joined output. This keeps the surface area small and makes it trivial to add GitLab or Bitbucket later.

3. **Correlate at the day level, not the session level.** The Anthropic usage API returns daily aggregates, not sub-hour session timestamps. The SuperSpec wanted a 4-hour lookback window — that's not possible at v1 resolution. Instead, v1 correlates an engineer's daily token spend to CI runs triggered by their commits on the same calendar day. The limitation is documented in code; the upgrade path is written down. This is the honest answer: ship the day-level correlation now, note the time-window upgrade for when session data exists.

4. **Agent attribution is a heuristic, not a fact.** We can't know with certainty whether a commit was AI-assisted. But commit messages often *say* — "Co-Authored-By: Claude", "Generated with Claude Code", the 🤖 emoji, `[ai]` tags. A substring scan of the commit message is cheap, fast, and good enough for a v1 signal. It's explicitly a heuristic, not a source of truth.

---

## Step 2 — Roads not taken

**Road A — Use the GitHub REST API for commits instead of GraphQL.**
Rejected. The REST commits endpoint (`/repos/{org}/{repo}/commits`) returns commits but doesn't include `changedFilesIfAvailable` cleanly and requires more requests for pagination. GraphQL gives us the whole history block in one call per repo, with the fields we need. GraphQL also lets us fetch merged PR counts in the same round-trip shape. The cost is a more complex query string; the benefit is fewer requests and richer data.

**Road B — Store CI runs in SQLite and query them by SHA.**
Rejected. The CI runs are fetched fresh each time `fetchCorrelations()` is called — no persistence layer. Adding a database table would mean syncing, cache invalidation, and a new drift schema. For v1, where the dashboard is a one-shot fetch, the in-memory join is simpler. If §W4 needs historical trending (e.g. "pass rate over 90 days"), *then* we add a table. Don't build the database until the query pattern demands it.

**Road C — Attempt the 4-hour window correlation by guessing session times.**
Rejected hard. We don't have session timestamps. Guessing them (e.g. "assume tokens were spent 2 hours before the commit") would produce a number that looks precise but is fabricated. The day-level correlation is honest about what it is: "on the day the engineer spent $X, their commits triggered Y passes and Z fails." Anyone reading the dashboard knows the granularity. Fabricating finer-grained data would be worse than coarse real data.

**Road D — Count cancelled/skipped/neutral CI runs as fails.**
Rejected. A cancelled run isn't a failure — it's an interruption. Counting it as a fail would inflate the token-to-fail ratio and make repos with lots of cancelled runs (e.g. force-pushes, retriggers) look worse than they are. The mapping is explicit: `success`→pass, `failure`→fail, `timed_out`→timeout, everything else → skip. The skip is important — it's not "count as zero," it's "don't count at all."

**Road E — Build the PR count into the main fetch path.**
Rejected. PRs are supplementary data — nice for the dashboard, not load-bearing for §W3 failure signals. Fetching them in the main `Future.wait` would make every engineer wait for N extra GraphQL calls even if they don't care about PRs. Instead, the main fetch returns fast, then PRs are enriched per-engineer afterward with a default of 0 on failure. The dashboard can render without PRs; PRs are a bonus.

---

## Step 3 — How the pieces connect

The flow is two parallel fetches, one join, one enrichment:

```
GitActivityService.fetchCorrelations()
    │
    ├── Future.wait([
    │     GitActivityProvider.fetchCommits()    → List<GitCommit>
    │     CIOutcomeProvider.fetchRuns()          → List<CIRun>
    │   ])
    │
    ├── CICorrelator.correlate({
    │     tokenUsage:  §W1 EngineerUsage list
    │     commits:     GitCommit list
    │     ciRuns:      CIRun list
    │     mappings:    GitHubEngineerMapping list
    │   })
    │   → List<EngineerCorrelation>
    │
    └── per-engineer PR count enrichment (supplementary)
        → List<EngineerCorrelation> with prsMerged filled in
```

**Why this order:** Fetch first (parallel, fast), join second (CPU-only, no I/O), enrich last (supplementary, can fail without breaking the main path). The join is the expensive conceptual step but the cheap computational one — it's all in-memory map lookups.

The join key is the commit SHA. `CICorrelator` builds a `Map<String, List<CIRun>>` keyed by `triggeringCommitSha`, then for each engineer's commits on a given day, it looks up the CI runs for those SHAs. This is O(commits + CI runs), not O(commits × CI runs) — the map lookup is what makes it fast.

The `GitHubConfig` (org, repos, token, engineer mappings) is the single source of truth for "what GitHub data are we watching." `isConfigured` is the guard — if it's false, `fetchCorrelations()` returns an empty list immediately, no HTTP call.

---

## Step 4 — Tools, methods, and frameworks

- **GitHub GraphQL API** (`POST https://api.github.com/graphql`) — one endpoint, query + variables in the body. GraphQL gives us the commit history block with author, message, `changedFilesIfAvailable` in one call per repo. The query string is a multiline Dart string literal — `const` because it never changes at runtime.
- **GitHub Actions REST API** (`GET /repos/{org}/{repo}/actions/runs`) — paginated, `per_page=100`, `created>=` filter for the lookback window. REST here because the Actions API doesn't have a clean GraphQL equivalent for workflow runs with conclusion.
- **`Future.wait`** for parallel per-repo fetches — same pattern as §W1's OpenAI provider. N repos = N parallel HTTP calls, results flattened. One repo failing doesn't poison the rest (per-repo catch → empty list).
- **`@immutable`** on all models (`GitCommit`, `EngineerGitActivity`, `CIRun`, `DailyCorrelation`, `EngineerCorrelation`, `GitHubConfig`, `GitHubEngineerMapping`) — every field `final`. Matches the codebase convention.
- **`AsyncNotifier`** for `GitHubConfigNotifier` — same pattern as `EngineerRosterNotifier` and `SettingsNotifier`. `build()` reads from `forge_config.json`, mutators write back. The config file is the single persistence store.
- **Record types for engineer mappings** — `List<({String handle, String githubLogin})>` passed to `fetchCommits`. Dart 3 record types are perfect for "tuple of two strings I need to pass through an interface" without defining a whole class.

---

## Step 5 — Tradeoffs

**GraphQL complexity vs. REST simplicity.** GraphQL gives us richer data in fewer requests, but the query string is harder to read and debug. If GitHub deprecates a field (e.g. `changedFilesIfAvailable`), the query silently breaks. REST is more stable but requires more calls. We use GraphQL for git (where the nested history block is valuable) and REST for CI (where the flat run list is sufficient). This split is pragmatic, not principled — it reflects what each API actually offers.

**Commit-message heuristic vs. git-trailer parse.** `isAgentCommit()` scans the message for substrings. This catches "Co-Authored-By: Claude" and "Generated with Claude Code" but misses a commit that was AI-assisted without any marker. A proper git-trailer parse (`git log --format='%(trailers)'`) would be more accurate but requires a local clone — we're working with the API, not a local repo. The heuristic is the right v1 choice; the upgrade path is documented by the function's existence (anyone can see what it checks and add more patterns).

**Day-level correlation vs. time-window correlation.** Day-level is honest about its granularity. Time-window would be more precise but requires data we don't have. The trade: ship the coarse correlation now (it's still useful — "high spend + high fail rate on the same day" is a real signal) and upgrade when session-level data exists. Documenting the limitation in code means anyone reading it knows not to trust sub-day precision.

**Per-engineer PR enrichment vs. batch PR fetch.** Fetching PR counts one engineer at a time means N sequential GraphQL calls after the main fetch. A batch fetch (one query for all engineers' PRs) would be faster but more complex — GitHub GraphQL doesn't have a clean "count PRs by author for multiple authors" query. The per-engineer approach is simpler and fails gracefully (default 0). The trade: slower enrichment for simpler code. For v1 with ~5 engineers, this is fine; for 50 engineers, it would need batching.

---

## Step 6 — Mistakes, dead ends, and wrong turns

**Import path bug — three files imported `github_config_notifier.dart` as a same-directory relative path.** `ci_correlator.dart`, `git_activity_service.dart`, and `git_activity_service_provider.dart` all wrote `import 'github_config_notifier.dart'` — but that file lives in `lib/features/settings/`, not `lib/services/watch/`. The analyzer caught it immediately (`uri_does_not_exist`). Fix: `import '../../features/settings/github_config_notifier.dart'`. Lesson: when a file is in a different feature directory, the relative path must cross the `lib/` boundary. The linter is the safety net — always run `dart analyze` after writing, not just before committing. This is the same import-path mistake from §W1 (the `../usage_provider.dart` bug), repeating because the file layout has cross-directory dependencies. The fix is always the same: check the actual file path, not the path you assumed.

**`firstWhere` with `orElse: () => null as dynamic` — a type-system lie.** The first draft of the PR enrichment loop used `config.engineerMappings.firstWhere((m) => m.handle == c.engineerHandle, orElse: () => null as dynamic)` to find an engineer's mapping. This is broken — `null` isn't a `GitHubEngineerMapping`, and casting through `dynamic` defeats the type checker. Fix: use `.where((m) => ...).firstOrNull` instead — `firstOrNull` returns `null` safely when the list is empty, no cast needed. Lesson: never use `null as dynamic` to satisfy a type bound. If you need "find or null," use `firstOrNull` (Dart 3) or a manual `for` loop with a null check. The `firstWhere(orElse: () => null as dynamic)` pattern is always wrong.

**`const` vs `final` for string literals — analyzer info, not error.** The analyzer flagged `final query = '''...'''` as "use `const` for final variables initialized to a constant value." String literals are compile-time constants, so `const` is more precise than `final`. Fix: `const query = '''...'''`. Small thing, but the analyzer is right — `const` tells the reader "this never changes," `final` only says "this doesn't change after construction." The distinction matters for intent.

---

## Step 7 — Pitfalls to watch for

**GraphQL field names change without warning.** GitHub's GraphQL schema evolves. `changedFilesIfAvailable` could be renamed, deprecated, or moved. The defensive parse (catch `FormatException` + `TypeError`, return empty) is what prevents a schema change from crashing the dashboard. **Never** write a GraphQL parser that assumes the response shape is stable. Always access fields with `as String?` / `as num?` and default to empty/0 on null.

**`conclusion` can be null for in-progress runs.** A CI run that hasn't finished yet has `conclusion: null`. The `_mapOutcome` function returns `null` for any unrecognized conclusion, including null — so in-progress runs are skipped. This is correct (they're not done yet) but worth knowing: if you ever want to show "in progress" runs in the dashboard, you'll need a new `CIOutcome` value and a different mapping.

**The commit-timestamp proxy is a v1 limitation, not a design choice.** Anyone reading the `ci_correlator.dart` comment should understand: this is the best we can do with daily-granularity token data. When session-level data becomes available (via a proxy/sidecar or a richer API), the date-equality check in `_correlateDay()` should become a time-window query. Don't "fix" the proxy by guessing session times — that's fabrication. Fix it by getting real session data.

**`GitHubConfig.isConfigured` is the guard, not `token.isEmpty`.** If you find yourself writing `if (config.token.isEmpty) return ...` inline, stop. Use `if (!config.isConfigured) return ...`. The definition of "configured" might grow (e.g. requiring at least one engineer mapping) — if it's centralized in the getter, one change updates all guards. If it's inlined, you'll miss a call site.

**`Future.wait` fails fast on first error by default.** If one repo's HTTP call throws, `Future.wait` throws the first error and the other results are lost. That's why each provider's fetch method catches per-repo (returns empty list on failure, doesn't throw) — so `Future.wait` in the service always gets two successful lists, even if some repos failed. The catch is *inside* the provider, not around the `Future.wait`. This is the error-isolation pattern from §W1, applied consistently.

---

## Step 8 — What an expert notices

A junior would put the `try/catch` around the `Future.wait` in the service. An expert puts it inside each provider's fetch method. The difference: with the catch at the service level, one bad repo kills the whole batch. With the catch at the provider level, one bad repo returns an empty list for that repo, and the service gets a complete (if partial) result. The service's `Future.wait` never throws because the providers never throw. This is the "error isolation at the boundary" pattern — catch where you have the context to degrade gracefully, not where you have to abort.

A junior would correlate token spend to CI runs by time window (e.g. "tokens spent within 4h of the CI run"). An expert asks: "do I actually have session-level token timestamps?" If no, the time-window correlation is fabricated precision. The day-level correlation is honest about its granularity. Honest coarse data is more valuable than fake precise data — anyone reading the dashboard knows the day is the unit, and can reason about it correctly. Fabricated precision invites false confidence.

A junior would count cancelled CI runs as fails ("they didn't pass, so they're failures, right?"). An expert distinguishes "didn't pass" from "failed" — a cancelled run is an interruption, not a failure. Counting cancellations as fails would make high-cancellation workflows (force-pushes, retriggers, quota limits) look like quality problems. The skip is the right semantic: "this run didn't produce a signal, ignore it."

A junior would fetch PR counts in the main `Future.wait` because "it's data, we need it." An expert fetches them after correlation, as enrichment, because PRs aren't load-bearing for the §W3 failure signals. The main path returns fast; PRs are a bonus. If the PR fetch fails, the dashboard still works. This is the "separate critical from supplementary" pattern — fetch what you need first, enrich with what's nice-to-have second.

---

## Step 9 — Transferable lessons

**The join key is the most important field in a correlation system.** Here it's the commit SHA — it appears in both the git data (as `oid`) and the CI data (as `head_sha`). Without a reliable join key, correlation is guessing. When designing any system that joins two data sources, the first question is: "what field appears in both, and is it unique and stable?" If the answer is "nothing" or "it's not unique," you have a data model problem, not a code problem. Fix the data model first.

**Honest coarse data beats fabricated precise data.** The day-level correlation is less precise than a 4-hour window, but it's real. Fabricating session timestamps to enable a 4-hour window would produce numbers that look more precise but are made up. This applies everywhere: if you don't have the granularity a spec asks for, ship the granularity you do have and document the gap. The spec is a target, not a contract — the contract is "tell the truth about what you measured."

**Error isolation at the boundary, not at the caller.** The pattern is: each provider catches its own failures and returns an empty/zero result. The service's `Future.wait` then never throws. The caller (§W3, §W4) never has to handle "did the whole batch fail or just one?" — each item carries its own status. This applies to any batch-fetch system: catch where you have context to degrade, not where you have to abort.

**Centralize the "is this configured?" check in one getter.** `GitHubConfig.isConfigured` is used in the service, the provider, and anywhere else that gates on GitHub being wired up. If the definition changes (e.g. "configured" now requires at least one engineer mapping), one getter update fixes all call sites. If the check is inlined, you'll miss one. This applies to any feature-gate or config-presence check: one getter, many callers.

**Heuristics should be labeled as heuristics.** `isAgentCommit()` doesn't return "is this commit AI-authored?" — it returns "does the commit message contain AI markers?" The function name is honest about what it checks. Anyone consuming the `isAgentAuthored` flag knows it's a heuristic, not a fact. This applies to any probabilistic signal: name the function after what it *measures*, not what it *infers*. `"messageContainsAIMarker"` would be even more honest; `"isAgentCommit"` is the shorthand. The point is: don't name a heuristic as if it were a fact.