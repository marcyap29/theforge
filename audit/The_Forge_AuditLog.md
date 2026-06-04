# The Forge — Audit Log

Append only. Newest entry at top. Do not modify existing entries.

---

## Entry 003 — §6+§7 complete: SpecParser + Artifact Viewers

**Date:** 2026-06-04
**Type:** Feature completion
**Filed by:** DeepSeek V4 Pro (implementing)

**What was done:** §6 SpecParser (`spec_parser.dart`) strips code fences from LLM output before `writeLockedSpec()`. §7 Artifact Viewers — single reusable `artifact_viewer_screen.dart` with `ArtifactViewMode` enum; artifact rows in `project_detail_screen.dart` made tappable; `flutter_markdown` added to pubspec.yaml.

**Verification:** `dart analyze lib/` — zero issues. `grep -ri firebase lib/` — zero matches.

**Affected files:**
- `lib/features/spec_generation/spec_parser.dart` — NEW
- `lib/features/spec_generation/spec_notifier.dart` — wired SpecParser.clean()
- `lib/features/artifacts/artifact_viewer_screen.dart` — NEW
- `lib/features/projects/screens/project_detail_screen.dart` — artifact rows tappable
- `pubspec.yaml` — added flutter_markdown

**Next:** §8 Setup Worksheet Generation → §9 Handoff Package + /goal → first end-to-end Plan Mode run → Watch Mode gate

---

## Entry 002 — Platform merge: Vigilint absorbed into The Forge as Watch Mode

**Date:** 2026-06-03
**Type:** Product decision / naming decision
**Filed by:** Claude Sonnet 4.6

**Decision:** The Forge and Vigilint are merged into a single platform. The Forge is the surviving brand. Vigilint-the-product name is retired. Vigilint's functionality (token spend visibility, git activity, CI correlation, spec compliance, SwarmSpace briefing, Monte Carlo decision simulation) becomes **Watch Mode** within The Forge platform. Plan Mode = former The Forge. Reverse Mode = new capability.

**Rationale:** Two products serving the same customer (engineering managers running agentic teams) with overlapping infrastructure (SwarmSpace MCP, locked spec format, Flutter desktop, flutter_secure_storage). The Forge is the stronger brand — implies construction and permanence. Vigilint implied surveillance. Combined platform has a flywheel: Plan specs become Watch benchmarks. Watch outcomes inform Amendment interviews. Reverse specs bring legacy repos into compliance.

**Platform — RESOLVED (2026-06-04):** Flutter desktop macOS for all three modes (Plan, Watch, Reverse). Confirmed by user. The SuperSpec draft's "Web (Watch/Reverse)" language is superseded. No split stack. Watch and Reverse mode screens are native macOS, same infrastructure as Plan Mode.

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
