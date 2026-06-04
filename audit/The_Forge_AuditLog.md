# The Forge — Audit Log

Append only. Newest entry at top. Do not modify existing entries.

---

## Entry 002 — Platform merge: Vigilint absorbed into The Forge as Watch Mode

**Date:** 2026-06-03
**Type:** Product decision / naming decision
**Filed by:** Claude Sonnet 4.6

**Decision:** The Forge and Vigilint are merged into a single platform. The Forge is the surviving brand. Vigilint-the-product name is retired. Vigilint's functionality (token spend visibility, git activity, CI correlation, spec compliance, SwarmSpace briefing, Monte Carlo decision simulation) becomes **Watch Mode** within The Forge platform. Plan Mode = former The Forge. Reverse Mode = new capability.

**Rationale:** Two products serving the same customer (engineering managers running agentic teams) with overlapping infrastructure (SwarmSpace MCP, locked spec format, Flutter desktop, flutter_secure_storage). The Forge is the stronger brand — implies construction and permanence. Vigilint implied surveillance. Combined platform has a flywheel: Plan specs become Watch benchmarks. Watch outcomes inform Amendment interviews. Reverse specs bring legacy repos into compliance.

**Platform note — open flag:** The SuperSpec Handoff Package originally stated `"platform": "Web (Watch/Reverse) + macOS app (Plan)"`. This conflicts with the existing Flutter macOS implementation of The Forge (§1–§5 complete, passing `dart analyze`). Recommended resolution: Flutter desktop for all three modes. This avoids a split stack and Electron-style web wrapper complexity. The Watch/Reverse data surfaces are management dashboards — they require the same screen real estate as Plan mode and lose nothing by being native macOS. **This flag must be resolved before Watch Mode build begins.**

**Affected files:**
- `DOCS/forge/The_Forge_SuperSpec_v1.md` — new; defines the merged platform
- `DOCS/forge/The_Forge_SuperSpec_Backlog_v1.md` — new; backlog items not in v1 scope
- `tracking md files/backlog.md` — Watch Mode and Reverse Mode phases added
- Vigilint repo: `audit/Vigilint_AuditLog.md` — entry 002 filed there as well

**What does NOT change:** The Forge §1–§5 codebase is unchanged. The existing Interview Engine, LLM Provider Layer, Settings, and Project screens are Plan Mode. §6 Spec Generation and §7 Artifact Viewers remain the next critical path items before Watch Mode work begins.

---

## Entry 001 — [Pre-merge: reserved for original Forge audit entries if any]

No prior audit entries — audit log created at merge event.

---

_Append new entries above this line. Do not modify entries already filed._
