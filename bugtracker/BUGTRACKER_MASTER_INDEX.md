# Bugtracker Master Index — The Forge

Bug IDs: `BUG-<AREA>-<NNN>`
Areas: `INTERVIEW` · `UI` · `SPECGEN` · `SETTINGS` · `AUTH` · `BILLING` · `DATA` · `LLM` · `IMPL`

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
| BUG-LLM-001 | LLM | Reasoning models (glm-5.3, gpt-oss:120b) stream chain-of-thought in `message.thinking` with empty `content`; console sat on "Planning…" — now surface typed content+thinking deltas + wait-heartbeat | 2026-09-10 |
| BUG-IMPL-001 | IMPL | Stop during planning + "Try again" crashed build window — uncancellable stream's stale continuation raced restarted run; added generation counter `_gen` + empty-console guard | 2026-09-10 |
| BUG-IMPL-002 | IMPL | "Apply & Run" quit the whole app — unbounded console growth, no command denylist/timeout, unguarded `applyAndRun`; capped 5000 lines + denylist + 3-min timeout + wrap | 2026-09-10 |
| BUG-IMPL-003 | IMPL | "Build with AI" full-file rewrite dropped ~345 lines / gutted code so it wouldn't compile — full-file edits can omit code; two-pass read-then-edit + preserve instruction + Undo (Mitigated) | 2026-09-10 |
| BUG-IMPL-004 | IMPL | Build with AI "Planning failed: did not return valid JSON" — reasoning model spent the turn thinking; unmanaged Ollama generation; forced JSON-only + num_predict + bigger budget + auto-retry | 2026-09-10 |
