# Bug Prevention Checklist — The Forge

**When to read:** Before coding in any subsystem listed below.
**When to update:** Every time a bug is fixed — add the rule that would have prevented it.

---

## Universal Rules

- **Read before editing** — read every file in full before modifying it. Never edit blind.
- **Linter clean before reporting done** — zero new warnings or errors (`dart analyze lib/`).
- **No committed secrets** — Firebase config, API keys, SwarmSpace tokens are gitignored. Never hardcode.
- **No silent error swallowing** — failed operations must throw or return a typed error. Never discard.
- **No debug logs leaking PII** — user IDs, emails, project content must not appear in print/debugPrint in production paths.

---

## Local File — Immutability Rules

**Rules:**
- **Never write to a spec path directly.** Write to `_LockedSpec_v1.md.tmp`, verify, then rename. Rename is atomic on macOS. Direct writes can leave a partial file that passes the existence check.
- **Check existence before writing a spec.** `ProjectFileRepository` must call `file.exists()` before any spec write. If it exists, throw `SpecAlreadyExistsException` — do not overwrite.
- **Audit log must be opened in append mode only.** Use `FileMode.append`. `File.writeAsString()` without mode truncates the file first. If the audit log is truncated, the entire history is gone.
- **All phase-completion writes use temp+rename where possible.** Write to `.tmp`, then rename to final path. This prevents a crash from leaving a corrupt partial file.
- **Phase gate checks are mandatory.** Verify `setupWorksheetComplete == true` before spec write in Build mode. Verify all 8 confidence dimensions are resolved before calling spec generation.

**Past bugs:** *(none yet — initial setup)*

---

## Spec Generation — Concurrency Rules

**Rules:**
- **All 3 variants must complete before any are revealed.** Use `Future.wait([...])` — never present a partial result.
- **Credit deduction happens server-side only (SwarmSpace routing).** The Flutter app never writes credit values directly. The SwarmSpace API handles billing; the provider records the cost in the audit log.
- **Timeout on LLM calls.** Each parallel LLM call must have a timeout. If one variant times out, return an error — do not return the two that completed.

**Past bugs:** *(none yet)*

---

## Interview State — Flutter Rules

**Rules:**
- **Interview state IS written to disk mid-session.** `writeInterviewProgress` is called in `_buildFlow` and `_auditFlow` after every successful LLM response. It writes the full turn history, confidenceMap, extracted data, specGenEnabled, and layerBoundaries to `audit/{Name}_InterviewState.json`. `build()` reads this file on app relaunch to restore the session. Do NOT assume interview state is memory-only.
- **Conflict detection blocks progression.** A detected conflict must be surfaced and explicitly resolved by the user before the interview advances. Never auto-resolve silently.
- **`specGenEnabled` fires when the L4 funnel gate is met — not just when all 8 dimensions resolve.** Gate condition: `allResolved || _layerGateMet('L4', mergedExtracted)`. Individual dimension resolution can silently fail due to LLM parse errors (see BUG-INTERVIEW-004/005). The L4 gate (platform + identityModel + inputModel + outputModel all non-null) is the reliable signal.
- **All LLM JSON list fields must use `is List<dynamic>` check, NOT `as List<dynamic>?` hard cast.** Hard cast throws `TypeError` when the LLM emits a string ("None", "TBD") for a list field. The outer try/catch degrades the ENTIRE `parseForgeState` result — ALL extracted data for that turn is discarded. Pattern: `extractedRaw['field'] is List<dynamic> ? (extractedRaw['field'] as List<dynamic>).cast<T>() : <T>[]`. See BUG-INTERVIEW-004.
- **`_restoreState` must re-evaluate computed booleans from data, not trust saved values.** `specGenEnabled` saved by old code may be `false` even when L4 is complete. On restore, call `_layerGateMet('L4', restoredExtracted) || savedSpecGen`.
- **Never gate Flutter state transitions on a boolean the LLM emits when that boolean appears as a hardcoded value in the system prompt template.** LLMs copy example values from the template literally — a template showing `"layerComplete": false` means the model will always emit `false`. Make the Flutter app authoritative for state advancement; use LLM output for data extraction only, never for flow control signals.
- **Never gate UI affordances (button enabled/disabled) on LLM-emitted booleans.** Same reason as above. Derive enabled state from Flutter-side conditions (field presence, confidence map, conflicts) that the app controls directly.
- **When writing RegExp to match LLM-emitted code fences, use `\n\s*` before the closing fence, not `\n` alone.** LLMs from different providers vary on trailing whitespace and line endings (`\n` vs `\r\n`). A strict `\n\`\`\`` pattern silently drops the entire block rather than erroring visibly.

**Past bugs:** BUG-INTERVIEW-001 (2026-06-12) — funnel stuck at L1 for 20+ turns; BUG-INTERVIEW-002 (2026-06-12) — Generate Spec button permanently disabled; BUG-INTERVIEW-003 (2026-06-12) — forge-state block silently dropped on trailing whitespace; BUG-INTERVIEW-004 (2026-06-19) — `externalServices as List<dynamic>?` hard cast threw TypeError, degraded entire parse; BUG-INTERVIEW-005 (2026-06-19) — same issue for `capabilities`, `demoScript`, `v2Seeds`; `specGenEnabled` required all 8 dimensions even when funnel complete.

---

## macOS Sandbox + Code Signing Rules

**Rules:**
- **Never add `keychain-access-groups` entitlement without a provisioning profile.** Requires `$(AppIdentifierPrefix)` which only resolves with a paid Apple Developer provisioning profile. Adding it to either `.entitlements` file breaks all builds with a signing error.
- **`flutter_secure_storage` requires `keychain-access-groups` on macOS sandbox.** If that entitlement is removed, every read/write throws `-34018 errSecMissingEntitlement`. Replace with SharedPreferences + config file dual-write.
- **`CODE_SIGN_STYLE = Manual` without a provisioning profile breaks the build.** Use `Automatic` for development unless you have a provisioning profile configured.
- **`NSUserDefaults` can be cleared by container resets during development.** Dual-write sensitive settings to a config file in `getApplicationSupportDirectory()` as the authoritative source on next launch.
- **`file_picker` requires `com.apple.security.files.user-selected.read-only` in both `.entitlements` files.** Without it, `NSOpenPanel` is silently blocked by the macOS sandbox — no error, no dialog, nothing. Add to both `DebugProfile.entitlements` and `Release.entitlements`.

**Past bugs:** June 2026 — `keychain-access-groups` broke macOS build; `flutter_secure_storage` broke API key storage after entitlement removal. Fixed by removing entitlement and switching to SharedPreferences + `forge_config.json`. June 2026 — `file_picker` NSOpenPanel silently blocked until `user-selected.read-only` entitlement added.

---

## Settings UI Rules

**Rules:**
- **`TextEditingController` changes do not trigger `setState` automatically.** If a button's enabled state depends on `controller.text`, add `_controller.addListener(() => setState(() {}))` in `initState`. Evaluating `controller.text` in `build()` without a listener gives a stale value.
- **Validate stored model IDs against the current catalog on settings load.** SharedPreferences persists across app versions. If the model catalog changes (retired models, new names), old IDs silently remain and cause API 404 errors on the next LLM call. In `SettingsNotifier.build()`, check `modelsFor(providerType).map((m) => m.id).contains(savedModelId)` and fall back to the first valid model if the check fails. See BUG-SETTINGS-001.
- **Never list retired model IDs in the catalog.** `gpt-4-turbo`, `gemini-3.5-flash`, `gemini-1.5-pro-preview` are retired. Current catalog as of 2026-06: Claude (`claude-opus-4-7`, `claude-sonnet-4-6`, `claude-haiku-4-5-20251001`), OpenAI (`gpt-4.1`, `gpt-4o`, `gpt-4o-mini`), Gemini (`gemini-2.5-flash`, `gemini-2.5-pro`, `gemini-2.0-flash`).

**Past bugs:** June 2026 — Settings Save button permanently disabled because text was evaluated at build time without a controller listener. June 2026 — BUG-SETTINGS-001: `gemini-3.5-flash` persisted in SharedPreferences from old code, caused Gemini API 404 on every LLM call; fixed by adding validation + fallback on load.

---

## Flutter Navigation / State Rules

**Rules:**
- **`AutoDisposeNotifier` state is lost on pop.** Interview state is `AutoDisposeNotifier` — if the user navigates away (e.g., back from spec gen error), all state is gone. Persist to disk before any navigation that could result in a pop back to the project list.
- **`FutureBuilder(future: _scan())` in a `StatefulWidget` only refreshes on `build()`.** Popping a route does not automatically trigger `build()` on the widget beneath. Use `RouteAware.didPopNext()` to call `setState` and create a new future when the parent route becomes visible again.
- **Never use `vv1` double-prefix.** If a version string already contains `v` (e.g., `'v1'`), don't prepend another: use `${version}` not `v${version}` in filenames.
- **`InkWell` on macOS Flutter desktop requires an immediate `Material` ancestor.** A `Scaffold` or any other `Material` widget higher in the tree is NOT sufficient — Flutter's ink system requires a local `Material` in the subtree. Wrap with `Material(color: Colors.transparent)` around the `InkWell`. Match the `_FileRow` pattern in `project_detail_screen.dart`.

**Past bugs:** June 2026 — HandoffPackage named `_vv1` due to `v$version` where `version = 'v1'`. June 2026 — `_ReferenceDocsRow` Manage button unresponsive on macOS until wrapped with `Material(color: Colors.transparent)`.

---

## Common Anti-Patterns

- **Catching too broadly** — catch specific types or let it bubble.
- **Race conditions on user input** — disable UI triggers while async work is in flight.
- **Optimistic state without rollback** — if spec write fails, do not update the project state in Flutter.
- **Stale references after refactor** — grep the full repo for old names before declaring a rename done.
- **Multiple `initState` callers on a global Notifier** — do NOT call state-writing methods (e.g., `loadDocs`) from `initState` in more than one widget when sharing a global non-AutoDispose `Notifier`. Two concurrent async writers produce interleaved state updates. Secondary screens should watch the provider passively; only the screen that owns the interaction should trigger explicit loads.

---

## Development Process Rules

- **Create git worktrees from a committed HEAD only.** If uncommitted changes exist on main, commit them first. A worktree branches from the last commit — any uncommitted changes on main are invisible to the worktree and reappear as conflicts at merge time. The sign: merge conflicts on files you didn't touch in the worktree branch.
- **Run `flutter pub get` after any merge that adds a new dependency.** If a `pubspec.yaml` change lands via merge, the app won't build until `pub get` runs. Use `flutter clean && flutter pub get` when a module import fails at compile time.

---

*This file grows over time. Update after every bug fix.*
