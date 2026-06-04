# The Forge — SuperSpec Backlog Appendation v1

**Appended to:** The_Forge___SuperSpec_v1.md
**Date:** 2026-06-03
**Status:** Backlog — not in scope for v1 or current v2 seeds
**Amendment policy:** Append only. Items move to a versioned spec when promoted to active scope.

---

## Backlog Item 001 — First-Party Decision Simulation Engine

**Current state:** The Decision Simulation Engine is a SwarmSpace MCP call. 50 iterations run via SwarmSpace's infrastructure. This works for v1 because SwarmSpace is live and the integration is days not weeks.

**The problem with keeping it that way:** The simulation engine's accuracy is a function of the data it runs against. Right now it runs against whatever context the manager provides in the decision frame. As Watch mode accumulates proprietary engineering telemetry — token-to-failure ratios, drift scores, engineer behavioral profiles, CI outcome patterns — that data is sitting in The Forge's data layer but the simulation engine is borrowed from SwarmSpace. The two are not connected at the model level.

**What first-party ownership unlocks:**

A simulation engine that runs against The Forge's own accumulated telemetry, not just a general-purpose reasoning call. Specifically:

- Baseline calibration from real engineering team data across workspaces. "An engineer with this token-to-failure ratio and this commit velocity, at this stage of a build, when reassigned, improved output in 67% of observed cases." That is a meaningfully different confidence score than one derived from first principles.
- Feedback loop. When a manager runs a simulation, makes a decision, and the outcome is observable in Watch mode data 30 days later, that outcome feeds back into the simulation's calibration. The engine gets more accurate with every decision made and observed.
- Separation from SwarmSpace dependency. If SwarmSpace pricing, availability, or architecture changes, the simulation engine is not affected.
- Proprietary signal that cannot be replicated externally. Neither GitHub nor Anthropic has cross-workspace engineering outcome data at the management decision layer. This is the data moat that survives the Sam Altman test permanently.

**What this requires:**

- A simulation data store: structured outcome records keyed to decision type, engineer profile snapshot, team context, and observed 30/90-day outcome.
- A feedback ingestion loop: Watch mode writes outcome observations back to the simulation data store when a sufficient time window has elapsed.
- A first-party simulation runtime: replaces the SwarmSpace call with an internal engine that uses the calibrated data store as context alongside the manager's decision input.
- Privacy architecture: outcome data is aggregated and anonymized before being used for cross-workspace calibration. No individual workspace's raw data is exposed to the model serving another workspace.

**Migration path from SwarmSpace:** The interface contract for the Decision Simulation Engine is already defined in the SuperSpec. The input and output schemas do not change. The underlying call switches from SwarmSpace MCP to the first-party runtime. Watch mode and the Dashboard UI Shell are unaffected.

**Promotion criteria:** Promote to active scope when two conditions are met:

1. Watch mode has been live long enough across enough workspaces to produce meaningful calibration data (estimated: 6 months post-launch, 10+ active workspaces).
2. SwarmSpace simulation accuracy has been benchmarked against observable outcomes and a calibration gap is confirmed.

**Priority:** High — this is the long-term moat. Not urgent for v1 or early v2, but the data collection infrastructure (outcome recording in Watch mode) should be designed with this migration in mind from day one. Do not design Watch mode in a way that makes outcome data hard to capture later.

**Design constraint for current build:** The Watch mode data model must include an `observedOutcomes` table from day one, even if it is empty. Structure: `{ decisionId, decidedAt, decisionType, engineerProfiles[], contextSnapshot, observedAt, outcomeSignals[] }`. Populate it later. Schema migration is more expensive than an empty table.

---

## Backlog Item 002 — Monte Carlo Naming Disambiguation

**Current state:** The SuperSpec uses "Monte Carlo" to describe two distinct capabilities: the Plan mode architecture variant generator (three variants at t=0.2/0.6/1.0) and the Watch mode decision simulation (50 iterations, confidence score, regret risk). Both are Monte Carlo by method but serve entirely different purposes.

**The problem:** As the platform matures and both capabilities are live simultaneously, "run the Monte Carlo" is ambiguous. Documentation, UI copy, and customer communication will create confusion.

**Proposed resolution when this is actively built:**

- Plan mode variant generator: **Variant Engine** or **Architecture Variants**
- Watch mode decision simulation: **Decision Simulation** (already named this in the SuperSpec — keep it)

No code changes required. This is a naming and copy decision. Promote when both capabilities are in the same product surface and customer confusion is observed.

**Priority:** Low — cosmetic until both are live and in the same UI.

---

_The Forge · SuperSpec Backlog Appendation v1 · Orbital AI · June 2026_
_Append new items below this line. Do not modify existing items._
