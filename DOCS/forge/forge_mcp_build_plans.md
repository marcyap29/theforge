# Forge MCP Server — Build Plans

**Author:** Claude Code (overseer)
**Date:** 2026-06-04
**Stack:** TypeScript · Node.js · @modelcontextprotocol/sdk
**Status:** Plans 1–6 complete. MCP server live. Next: §9.5 Flutter amendment.

---

## Repo Gap Analysis (reference)

**Current Flutter app output:**
```
~/Documents/The Forge Projects/{ProjectName}/
  README.md
  handoff_package_v1.json              ← missing: components, contextFiles
  specs/
    {ProjectName}_LockedSpec_v1.md     ← File 1 (in specs/, not forge/)
  handoffs/
    {ProjectName}_BulletHandoff_v1_Interview.md
    {ProjectName}_goal_v1.md
  worksheets/
    {ProjectName}_SetupWorksheet_v1.md
  audit/
    {ProjectName}_AuditLog.md
```

**Target state (after §9.5):**
```
~/Documents/The Forge Projects/{ProjectName}/
  {ProjectName}_HandoffPackage_v1.json     ← full schema with components + contextFiles
  forge/
    {ProjectName}_LockedSpec_v1.md         ← File 1
    {ProjectName}_DecisionContext_v1.md    ← File 2
    {ProjectName}_ActiveState_v1.md        ← File 3 (MCP-managed)
    {ProjectName}_HandoffTrail_v1.md       ← File 4 (MCP-managed)
    {ProjectName}_OpenFlags_v1.md          ← File 5
  worksheets/
    {ProjectName}_SetupWorksheet_v1.md
```

**MCP bridge rules (active in server until §9.5 ships):**
- File 1: check `forge/` → fallback `specs/`
- File 2, 5: check `forge/` → error if missing
- File 3, 4: MCP always writes to `forge/`
- HandoffPackage: try `{ProjectName}_HandoffPackage_v1.json` → `HandoffPackage.json` → `handoff_package_v1.json`
- `components` missing → parse from File 1 Component Map (`### ComponentName` headers)
- `contextFiles` missing → derive from standard naming convention
- `forge/` dir: created by `forge_session_start` if absent

---

## Plans 1–6 — Complete ✅

| Plan | Scope | Status |
|------|-------|--------|
| 1 — Server Foundation | Package setup, registry, server entry, types | ✅ Done |
| 2 — Spec Serving Tools | fileSystem.ts, forge_session_start/end/get_spec | ✅ Done |
| 3 — Scope and Decision Tools | forge_check_scope, forge_log_decision | ✅ Done |
| 4 — Deviation and Drift Tracking | telemetry.ts (drift + compression), forge_log_deviation | ✅ Done |
| 5 — Component Completion and Token Tracking | telemetry.ts (tokens), forge_complete_component | ✅ Done |
| 6 — Telemetry Query Tool and Final Wiring | queryApi.ts, forge_get_report, README.md | ✅ Done |

**Build state:** Clean. Zero TypeScript errors. Zero `any`. All 8 tools confirmed registered.

**Post-implementation fixes applied by Claude Code overseer:**
- `package.json` build script: added `NODE_OPTIONS=--max-old-space-size=4096` (OOM during tsc)
- `forge_check_scope`: added V2 seeds to blocked list (`[...outOfScope, ...v2Seeds]`)
- `queryApi.ts`: removed dead `sessionsByAgent` variable
- `queryApi.ts`: fixed `percentComplete` denominator to use `allComponents.length`
- `index.ts`: removed duplicate local `deriveContextFiles`, imported from fileSystem.ts

---

## §9.5 — Flutter App Amendment

**Goal:** Generate the full 5-file `forge/` structure from the Flutter app so the MCP bridge fallbacks are no longer needed.

**Files to modify:**
1. Project creation — create `forge/` subfolder
2. `spec_generator.dart` / `spec_notifier.dart` — after LockedSpec is written:
   - Extract "Accepted Decisions" section → write `{ProjectName}_DecisionContext_v1.md` to `forge/`
   - Extract "Open Flags" + "Explicit Out-of-Scope List" → write `{ProjectName}_OpenFlags_v1.md` to `forge/`
   - Write LockedSpec to `forge/` (in addition to or instead of `specs/`)
3. `buildHandoffPackage()` — add `components` (parse from spec Component Map) and `contextFiles` fields
4. `writeHandoffPackage()` — use filename `{ProjectName}_HandoffPackage_v1.json`

**Definition of done:** A fresh Plan Mode run produces a project folder where `forge_session_start` returns all 5 context files without hitting any fallback path and without error.

---

## Evaluation Criteria (for future plans)

| Criterion | Check |
|-----------|-------|
| TypeScript strict | `grep -r ": any" src/` → zero matches |
| Build clean | `npm run build` exits 0 |
| Scope discipline | Only files listed in the plan modified |
| Invariants | Append-only logs never truncated; errors include expected paths |
| MCP protocol | All returns use `{ content: [{ type: 'text', text: JSON.stringify(...) }] }` |
| Fallback handling | Missing files return errors or zero values, never silent |
| File 1 fallback | `readForgeFile` checks `forge/` then `specs/` |
| HandoffPackage | Reader tries all 3 filename patterns |

---

*The Forge — MCP Server Build Plans — Orbital AI — 2026-06-04*
