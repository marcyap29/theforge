# Bugtracker Master Index — The Forge

Bug IDs: `BUG-<AREA>-<NNN>`
Areas: `INTERVIEW` · `UI` · `SPECGEN` · `SETTINGS` · `AUTH` · `BILLING` · `DATA`

Records go in `bugtracker/records/` — one file per bug.

---

## Open

*(none)*

## Fixed

| ID | Area | Summary | Fixed |
|---|---|---|---|
| BUG-INTERVIEW-001 | INTERVIEW | Funnel stuck at L1 for 20+ turns — `layerComplete` gate driven by LLM boolean | 2026-06-12 |
| BUG-INTERVIEW-002 | INTERVIEW | Generate Spec button permanently disabled — `specGenEnabled` gated on `layerComplete` LLM output | 2026-06-12 |
| BUG-INTERVIEW-003 | INTERVIEW | forge-state block silently dropped — regex required `\n``` ` (no trailing space) | 2026-06-12 |
| BUG-UI-001 | UI | `InkWell` on macOS has no ink without immediate `Material` ancestor | 2026-06-09 |
| BUG-UI-002 | UI | Ingestion state race — `loadDocs` in `initState` raced with in-flight `addDoc` LLM calls | 2026-06-10 |
| BUG-INTERVIEW-004 | INTERVIEW | `externalServices as List<dynamic>?` hard cast threw `TypeError` → entire parse degraded each turn → dimension never resolved → Generate Spec button never appeared | 2026-06-19 |
| BUG-INTERVIEW-005 | INTERVIEW | Same `as List<dynamic>?` cast bug in `capabilities`, `demoScript`, `v2Seeds`; `specGenEnabled` required ALL 8 dimensions even when L4 funnel was complete | 2026-06-19 |
| BUG-SETTINGS-001 | SETTINGS | `gemini-3.5-flash` (retired) persisted in SharedPreferences caused Gemini API 404 on every LLM call; no validation on load | 2026-06-20 |
| BUG-SPECGEN-001 | SPECGEN | `HandoffPackage.json` always had `setupWorksheetComplete: false` and `v2SeedItems: []`; component names included `**` markdown bold | 2026-06-19 |
| BUG-SETTINGS-002 | SETTINGS | Changing a role's provider left `modelId` empty → every LLM call threw "No model selected"; provider dropdown now auto-selects first model | 2026-09-10 |
| BUG-UI-003 | UI | macOS folder picker silently did nothing — app-modal `getDirectoryPath` failed to present; added `lockParentWindow` + error snackbars | 2026-09-10 |
| BUG-DATA-001 | DATA | Deleting a project could rm-rf a real source repo — no guard that path was inside canonical root; fenced deletion + prune stale index rows | 2026-09-10 |
