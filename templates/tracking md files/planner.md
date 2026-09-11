<!-- TEMPLATE — replace {{PLACEHOLDERS}} and delete this line. Part of the Docs Templates system. -->
# {{PROJECT_NAME}} — Active Planner

Active sprint tasks only. Wipe clean when a feature ships. Preserve partial work between sessions.

> **How to use this file**
> - Holds **only the current sprint / in-flight work** — the long-term feature pool lives in `backlog.md`.
> - Each sprint gets a `## §<TAG> — <name>` section with a checklist of `- [ ]` / `- [x]` items. Each item names the concrete files it touches.
> - When a sprint fully ships, mark the header `— COMPLETE ✅` and add a `**Completed:** YYYY-MM-DD` line. Completed blocks may be kept here for recent history or moved out once stale.
> - Preserve partial work between sessions — leave unchecked items and short `### Notes` so the next session can resume mid-task.
> - `§<TAG>` is just a short stable workstream label; use whatever scheme suits the project.

---

## §EX — Example Sprint — COMPLETE ✅   (example — replace or delete)

**Completed:** YYYY-MM-DD

- [x] §EX1 <task summary> — what shipped and where; `path/to/file_a`, `path/to/file_b`
- [x] §EX2 <task summary> — `path/to/file_c` (NEW)
- [x] <toolchain / lint gate, e.g. build + tests green with zero new warnings>
- [ ] §EX3 <partial task still in progress> — carried into next session; see notes below

### Notes
- A design decision or invariant established during this sprint that later work depends on.
- Any deliberate deferral (what was skipped and why).

---
