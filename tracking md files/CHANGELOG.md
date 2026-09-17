# The Forge — Changelog

---

## v0.4.39 — 2026-09-17

- **"How to build this" — scale-aware build advice per feature.** Each feature's ⋮ menu has a new **How to build this** action: the Architect LLM reads the current repo + docs and returns concrete guidance for that feature — **Scope** (is this really a single feature, or an *epic* that should be split?), **Feasibility** (Buildable now / Hybrid / Needs human effort — i.e. can Build-with-AI actually code-generate it, or does it need a human, a dataset, or model training?), **Recommended approach** with named packages/APIs, **Effort**, **Risks & gotchas**, a **Suggested breakdown** into sub-features, and a sharper **descriptor**. Point it at something like on-device "Local AI Image Recognition" and it correctly flags it as an epic needing an ML model + dataset (not a one-shot code-gen), rather than letting a deceptively short description hide the real lift. On-demand with Regenerate + Copy. `FeatureScanner.adviseBuild` + `BuildAdviceScreen`.

---

## v0.4.38 — 2026-09-17

- **"What this app can do" — a live capability overview per project.** A new ✨ toolbar action on the feature board has the Architect LLM read the project's **current** repo (key `lib/` source + README + `.forge` docs) and the tracked features, then write a plain-language markdown overview of what the app can actually do right now — grouped capabilities, an honest "Not yet functional / in progress" section for stubbed/planned bits, and a one-line summary. It's **on-demand + cached**: the summary is saved to `.forge/capability_summary.json` (stamped with the git commit it describes) so it shows instantly next time, and a **"repo has changed"** banner offers a one-tap Refresh when new commits have landed since. Grounded in code (not just file names), so it reflects reality rather than aspirations. `FeatureScanner.describeCapabilities` + `CapabilitySummaryScreen`.

---

## v0.4.37 — 2026-09-17

- **Run & Preview now boots simulators for you (one-click).** The device picker previously only listed *booted* simulators — so if none was running, you only saw your physical device. Now it also lists **available (shut-down) iOS Simulators** (`xcrun simctl`) and **Android emulators / AVDs** (`flutter emulators`), tagged "(tap to boot)". Pick one and Run: The Forge **boots it automatically**, waits for it to come up, then runs and mirrors it — no more manually launching a simulator first. (Physical-device deploys from inside The Forge can still hit an Xcode-automation permission wall — use a simulator/emulator for the in-app preview.)
- **New apps are scaffolded at iOS 15.0 — no more Xcode-27 build wall.** Every app The Forge scaffolds (`flutter create`, via New Project *and* "Make runnable") now has its iOS deployment target raised to 15.0 in `project.pbxproj` and the `Podfile` (platform line + a `post_install` that forces every pod to 15.0). Xcode 27 rejects anything below 15.0, which used to break `flutter run` on brand-new apps. As a safety net, Run & Preview also re-applies this to iOS targets right before running (covers Podfiles generated after scaffolding). New `lib/data/filesystem/ios_deployment.dart` (pure, tested transforms).

---

## v0.4.36 — 2026-09-16

- **Run & Preview — watch your app run inside The Forge.** A new **play** action on the feature board opens a Run & Preview window that runs the app on a simulator/emulator and shows it live, so you can see how it looks when tested without leaving The Forge. It detects devices (`flutter devices`), runs `flutter run -d <device>` in the linked repo with a live **console** (build progress + errors), and gives **Hot reload**, **Hot restart**, and **Stop**. Because macOS can't embed Apple's Simulator window, the preview is a **live screenshot mirror** of the running app — captured from the iOS Simulator (`xcrun simctl`) or Android emulator (`adb`) and auto-refreshed after each reload (pinch/scroll to zoom). This is the native-fidelity path on purpose: camera/AR features (e.g. AR Mechanic) actually work in the real simulator/emulator, unlike a web preview. macOS/web targets run and stream their console here while opening in their own window/browser. New `lib/features/run/` (`RunController`, `RunPreviewScreen`). *Requires the relevant toolchain installed (Xcode for iOS, Android SDK for Android); note the iOS Simulator has no camera — use an Android emulator with a mapped webcam or a real device to eyeball camera apps.*

---

## v0.4.35 — 2026-09-16

- **Board can now group by build order, not just status.** A new **Group by: Status / Build order** toggle sits above the feature board. In **Build order** mode the not-yet-built features (Idea / Planned / Blocked / In Progress) are grouped by their **target version** — versions ascending, so the one to build next is at the top and tagged **NEXT UP** — and priority-ordered within each version. This is the sequence to feed features into Build-with-AI, answering "what do I build next, and in what order?" at a glance. It reads the `targetVersion` + `priority` that **Plan build order** assigns, so the flow is: run Plan build order → flip to Build order → work top-down. Features with no version yet collect in a trailing **Unversioned** group with a nudge to run Plan build order (there's also a shortcut button in the toggle bar). Status mode (the columns) is unchanged and still the default.

---

## v0.4.34 — 2026-09-16

- **Fixed the real reason the broom (and Scan/Recommend/Plan) returned empty (BUG-TRACKER-002, part 2).** After v0.4.33 the "Remove duplicates" pass *still* failed, and diag.log showed the smoking gun: the model returned **empty content** (`Raw:` was blank). Root cause: `qwen3.5`/`glm` are **reasoning models**, and with **thinking ON plus a small token budget**, the model spends the entire budget in its *thinking* channel and returns nothing in `content`. Fix: the JSON-only architect passes (Scan, Recommend, Plan build order, Remove duplicates) now force **thinking OFF** — a new `think` override on `LlmService.complete` — so the whole budget goes to the answer. Dedup's budget was also bumped 1500 → 2000 tokens. This is the fix that makes semantic dedup actually run on reasoning models.

---

## v0.4.33 — 2026-09-16

- **"Remove duplicates" now actually catches reworded duplicates (BUG-TRACKER-002).** The broom was missing obvious semantic dupes (e.g. "Camera Permission & Live Feed" vs "Camera Permission Request") for two reasons: the AI clustering pass was wrapped in a silent `catch` (so any model/JSON hiccup was discarded and it fell back to exact-title only), and its parser only accepted one JSON shape — a JSON-clean model answering with a bare array produced **zero groups with no error**. Now: tolerant parse (object *or* bare array *or* fenced), one retry, and failures are **logged to diag.log and reported** — if the semantic pass can't run, you get a dialog telling you to switch the Architect model to `qwen3.5:cloud`, instead of a misleading "No duplicates found."

---

## v0.4.32 — 2026-09-16

- **Errors are now captured and stay on screen.** Two diagnosability wins: (1) a persistent **`diag.log`** in the app-support dir (`~/Library/Application Support/ai.orbitalai.theForge/diag.log`) records failures — including uncaught Flutter errors and the **raw model output** a scan/recommend/roadmap choked on — so problems can be inspected even when the app is launched from Finder and after a toast vanishes (modeled on Sabihin's DiagLog). (2) Scan / Recommend / Plan-build-order / Remove-duplicates / Check-in failures now show a **dismissible dialog** (with Copy) that stays until you close it, instead of an auto-vanishing toast.

---

## v0.4.31 — 2026-09-16

- **Actionable error when the Architect model won't return JSON.** If scan/recommend/plan-build-order still can't parse after the retry, the error now says exactly what to do — "Switch the Architect model to a JSON-clean one like `qwen3.5:cloud` in Settings" — instead of a cryptic parse message. (Some models like `glm-5.3` don't support JSON output on Ollama Cloud, which no amount of parsing can fix.)

---

## v0.4.30 — 2026-09-15

- **Scan / Recommend / Plan build order are resilient to flaky JSON.** These architect-model passes could fail with "Could not parse scan result as JSON" when the model (e.g. `glm-5.3:cloud`, which doesn't honor JSON mode on Ollama Cloud) returned prose or wrapped the array in an object. Now the parser tolerates code fences, surrounding prose, and object-wrapped arrays (`{"features":[…]}`), and each pass **retries once** with a firm JSON-only reminder before failing. Tip: for these features, a JSON-clean architect model like `qwen3.5:cloud` avoids the retry entirely.

---

## v0.4.29 — 2026-09-15

- **Plan build order (phased roadmap).** A new **route** action on the feature board sequences your not-yet-shipped features into a dependency-aware, phased roadmap — Foundation → Core → Enhancements → Later — with a target version per phase and a one-line reason per feature (foundational-first, then value). Review it, and **Apply to board** writes each phase's target version + a running priority to the features, so the board sorts in build order and the Releases view groups by phase. Answers "what do we build, in what order, and what depends on what?" `FeatureScanner.planRoadmap` (architect model, JSON mode).

---

## v0.4.28 — 2026-09-15

- **Recommend new features (virtual-PM).** A new **lightbulb** action on the feature board analyzes what you've *already* built and tracked — plus the app's docs and codebase — and recommends **new features, enhancements, and improvements to build next**, prioritized with a one-line rationale each. Recommendations exclude what's already tracked, are deduped against the board, and you review/accept them into the tracker just like a scan (imported with source `recommend`). `FeatureScanner.recommend` (architect model, JSON mode).

---

## v0.4.27 — 2026-09-15

- **No more duplicate changelog/doc entries on re-ship.** The ship-docs step now skips prepending an entry that's already present, so re-shipping a feature (or shipping the same run twice) no longer repeats an identical block in the app's `CHANGELOG.md` / dev log. (AR Mechanic's existing doubled entry was cleaned up too.)

---

## v0.4.26 — 2026-09-15

- **Pick target platforms when creating an app — it's scaffolded runnable automatically.** "Create a new code folder" now asks which platforms the app is for (iOS, Android, macOS, Windows, Linux, Web; mobile pre-selected) and scaffolds a real, runnable Flutter app for exactly those with `flutter create --platforms=…`. So a new app runs on a device from the start — no separate **Make runnable** step needed. The chosen platforms are saved to the project config. ("Make runnable" stays as a fallback for existing/linked repos that weren't scaffolded; it greys to "Runnable ✓" once they are.)

---

## v0.4.25 — 2026-09-15

- **"Mark shipped" now shows it's working.** Shipping does real work — saving build memory, writing docs, and committing + pushing — which takes a few seconds before the window returns to the board. Instead of a silent delay that looked like a hang, the bar now shows a spinner + "Shipping… saving docs, committing & pushing. This can take a few seconds — the window will close when it's done."

---

## v0.4.24 — 2026-09-15

- **"Make runnable" greys out once the app is scaffolded.** It's a one-time, per-project setup, so once the platform folders exist the button now shows **"Runnable ✓"** and is disabled across every feature's build window — no more inviting you to re-run it on each feature.

---

## v0.4.23 — 2026-09-15

- **"Make runnable" now works on a freshly-opened feature.** It previously did nothing unless you'd already started a build in that window (it relied on internal run state that's only set once a build starts). It now uses the window's linked repo directly, so you can click it right after opening the feature — no need to build first. (If `flutter` can't be found or the command fails, it now says so in the console instead of sitting silent.)

---

## v0.4.22 — 2026-09-15

- **Fixed "Make runnable" (and "Commit & push") being greyed out (BUG-IMPL-009).** Reopening a feature that already had a run passed an empty repo path to the Build window, which disabled the repo-dependent actions — so you couldn't see/use **Make runnable** on the shipped Camera feature. The re-attach path now carries the project's linked repo, so those actions stay enabled when you reopen a feature.

---

## v0.4.21 — 2026-09-15

- **Make a generated app runnable in one click.** A new **Make runnable** action in the Build window runs `flutter create .` to generate the platform folders (android/ios) that Build-with-AI doesn't scaffold on its own — the gap that kept generated Flutter apps from running on a device. It backs up and restores your `Info.plist` / `AndroidManifest.xml` so permission edits (e.g. camera) survive the regeneration. Detects a Flutter repo, skips if already set up.
- **Shipping a feature now documents, commits, and pushes.** When you **Mark shipped**, The Forge updates the *app repo's* docs — prepends a `CHANGELOG.md` entry (what happened), appends a detailed `docs/DEVELOPMENT_LOG.md` entry (what/why/files/commands), and refreshes `docs/ARCHITECTURE.md` via the architect model — then `git add -A`, commits (`feat: <feature> + docs`), and pushes. The same "docs ship with code" discipline The Forge holds itself to, now applied to the apps it builds. All best-effort: a docs or git hiccup never blocks the ship.

---

## v0.4.20 — 2026-09-15

- **Builds auto-tidy the code they write.** After applying edits (and before the analyze gate), The Forge now runs `dart fix --apply` (safe automated lint fixes — remove unused imports, add `const`, …) and `dart format` on the edited files. So the cosmetic debris AI edits tend to leave — unused imports, unformatted code, the little warnings you'd otherwise chase — is cleaned automatically every build. Best-effort: unavailable tooling or a non-zero exit is just logged, never fails the run. Dart/Flutter repos only.

---

## v0.4.19 — 2026-09-15

- **Plans are now generated in enforced JSON mode — the model can't "answer" with prose.** A model (esp. with thinking off) could reason out loud in its answer — musing about package versions with code fences — instead of returning the plan object, failing with "did not return valid JSON." The scout/plan passes (and the feature scan + dedup) now use Ollama's **`format: "json"`**, which constrains the output to valid JSON, so a model literally can't return prose where JSON is required. This is the structural fix that complements the 32k ceiling, truncation-aware retry, loop guard, and the Thinking toggle.

---

## v0.4.18 — 2026-09-15

- **Thinking on/off toggle per model (Settings → each role).** Reasoning models (glm-5.3, deepseek, etc.) spend part of their output budget on chain-of-thought — which for big Build plans could eat the whole budget and truncate the JSON. Each role's model card now has a **Thinking (chain-of-thought)** switch: leave it **on** for the architect (better reasoning on interviews/specs), turn it **off** for the executor so the full output budget goes to the answer (more reliable plans, no thinking-driven truncation/loops). Sent to Ollama as `think:false` only when you turn it off, so non-thinking models are unaffected. The choice persists per role.

---

## v0.4.17 — 2026-09-14

- **Fixed "Planning failed: did not return valid JSON" caused by truncation.** On a large multi-file plan (several code hunks), the model could run past the output-token budget and get **cut off mid-JSON**, so it wouldn't parse. Two fixes: (1) the plan pass token ceiling is raised (16k → **32k**) so big plans fit; (2) the retry now **detects truncation** (JSON started but never closed) and asks for a *smaller, focused* plan instead of the generic "output valid JSON" nudge — which just truncated again. Genuinely malformed (non-truncated) output still gets the JSON-only retry.

---

## v0.4.16 — 2026-09-12

- **Fixed the app hard-quitting (SIGABRT) during builds (BUG-IMPL-008).** The local index ran on a background isolate (via `drift_flutter`); on close, `sqlite3`'s FFI-callback destructors tripped a Dart runtime assertion on that worker and aborted the whole app. The index now opens on the **main isolate** against the same database file (`~/Documents/forge_index.sqlite`) — same data, no migration — which removes the cross-isolate FFI teardown and that crash class. The index is tiny, so there's no noticeable cost.

---

## v0.4.15 — 2026-09-12

- **Builds now verify the code compiles before calling it done.** After applying edits, The Forge runs the project's analyzer (`flutter analyze` / `dart analyze`) automatically. If an edit doesn't compile — e.g. a find/replace hunk lands a stray brace or drops a symbol (the BUG-IMPL-003 class) — the errors are shown in the console and the run is marked fixable, so **Fix it** feeds them straight back to the AI instead of a broken edit silently landing. Warning/info-level lints don't block; an unavailable analyzer is skipped, not treated as failure. This catches exactly the kind of syntax break a model produced on AR Mechanic (a stray `}` that closed the class early).

---

## v0.4.14 — 2026-09-12

- **Build planning no longer hangs in a repetition loop (BUG-IMPL-007).** A run could get stuck with the model reprinting the same reasoning paragraph hundreds of times and never producing a plan. Three fixes: (1) the planning prompt no longer claims "the file contents are provided below" when the scout read none — it now says so explicitly and tells the model to create new files or use commands, removing the contradiction that sent the model spiralling; (2) a new **repetition guard** watches the stream and, if a long passage repeats verbatim, stops it and fails fast with a clear message (tip: use an instruction-following/coder model) instead of burning the whole token budget; (3) Ollama calls now send a stronger `repeat_penalty` (1.3) so weaker models are less likely to loop in the first place. Note: a small/fast model can still be too weak for a hard fix — switch the Build model to a coder/instruction-following one when it struggles.

---

## v0.4.13 — 2026-09-12

- **Every build action is now a standalone entry point.** You can click **Run checks**, **Fix errors**, **Suggest improvements**, or **Commit & push** directly, without pressing **Build this feature** first. Previously those did nothing until a build had run (they needed the run's brief); now each starts its own run from idle.
- **The action you clicked is highlighted.** The active action lights up in the ember accent with a spinner while it runs (the same visual weight as "Build this feature"), so it's obvious your click registered and which action is in progress — clearing when the run settles.

---

## v0.4.12 — 2026-09-12

- **Follow up on a build before you ship it.** When a run finishes, the "Run complete" bar now has a **Follow up** button next to Mark shipped, and the right-side actions have **Suggest improvements**. Either one asks the AI to review the code it just wrote and propose concrete follow-up fixes — missing error/permission handling, lifecycle and edge cases, platform/config completeness (scaffolding, manifests, min SDK), and tests — then implement them through the normal approve/apply loop. So you can keep hardening a feature in rounds and be thorough about what the code actually does, instead of shipping after one pass.

---

## v0.4.11 — 2026-09-12

- **Set / move a project's code location, front and centre.** The feature board now has an always-visible **Code:** bar at the top showing where the project's code lives, with **Set code location** (when none is linked) or **Change** + **Scan** (when it is). This is the entry point for pointing a project at a repo — so you can immediately scan an existing codebase or set where new source gets generated. The same **Change code location** action is also in the Build-with-AI window's toolbar and the project detail screen's repo row.
- **Relocate moves the code for you.** Creating a fresh folder under `~/Development` or picking an existing one **moves the existing code across** and repoints the project. The Forge deliverables (`.forge/` and the project-state `README.md`) stay in the workspace.
- **Guard: a Forge project workspace can no longer be used as a code repo.** Linking/relocating now rejects any folder inside `~/Documents/The Forge Projects/`. Root fix for **BUG-IMPL-006**: AR Mechanic's `repoPath` had been pointed at its own Forge workspace, so Build-with-AI wrote `lib/`, `pubspec.yaml`, `android/`, `ios/` in among the specs/handoffs — and a separate agent looking under `~/Development/ar_mechanic` couldn't find the generated code. (AR Mechanic's code has been moved to `~/Development/ar_mechanic` and its config repointed.)
- New repository helpers: `relocateRepo` (safe move, never touches `.forge`), `createEmptyCodeFolder`, and `isInsideProjectsRoot`.
- **Re-scanning no longer doubles features (BUG-TRACKER-001).** A scan (and check-in) now dedups proposed features against what's already tracked — matched on a normalized title (case-/punctuation-insensitive) — so running the scan repeatedly can't re-add the same planned/idea items. The import toast now reports how many were skipped as already tracked. (AR Mechanic's existing duplicates — 34 rows down to 19 — were cleaned up, keeping the most-recently-updated copy of each so manual status changes survived.)
- **Remove duplicates (clean-up tool).** A new broom icon in the feature-board toolbar finds duplicates already on the board — exact-title matches **and** the same feature worded differently across re-scans (e.g. "V2: Multi‑Part Highlighting" vs "Highlighting of Parts & Motion") using a conservative LLM pass — and lets you review each group (keeps the most-progressed / most-recently-updated copy) before deleting the extras. `FeatureDeduplicator` + `showDedupReviewSheet`.

---

## v0.4.10 — 2026-09-12

- **The build AI can now pull the right docs on demand.** As a project accumulates reference documents and prior-build records, they can outgrow what fits in every prompt. The build agent's "scout" pass now sees a compact **manifest** of the whole document pool and requests, by name, the specific reference doc or prior feature it needs for the task — the same way it already picks which code files to read. Retrieved material is fed into the plan and de-duplicated against what's already shown.
- **Small projects are unchanged.** This only kicks in when a pool is too large to show in full; below that, everything is already always-on, so nothing changes. The console now names any reference docs it pulled (`… · N reference doc(s): …`).

---

## v0.4.9 — 2026-09-11

- **Builds now remember what you built before.** When you **ship** a feature, The Forge saves a durable record — what was built, why, and which files changed — into a per-project **build-memory** pool (`.forge/build_memory/`). Every later build reads that pool back, so the AI follows the patterns and file layout it already established instead of starting cold. This is the "context that's gained and remains" — the same way a human (or Claude Code) carries forward what it learned earlier in a project.
- **Re-shipping updates, never duplicates.** Each feature keeps one record (overwritten on re-build), so the memory stays clean as you iterate.
- **Visible in the console.** A build now logs `Loaded build memory (N prior features)` when planning, and `Saved to build memory…` when you ship — so you can see context accumulating.

---

## v0.4.8 — 2026-09-11

- **Builds now start with your reference docs, not just code.** The Build-with-AI agent reads the project's **ingested reference context** — the same document pool the interview and spec stages already use — on every planning round. Previously the builder only saw the locked spec (silently cut at 6k chars), a fixed doc whitelist, and the code file list; the intake docs never reached it. Add docs on the project and they now ground every feature build.
- **You can see the context load.** The build console prints `Loaded reference context (~N words)` (or a nudge to add docs if the pool is empty), so it's no longer a mystery whether the app had your context.
- **No more silent truncation.** Over-budget spec/reference context is now marked with a visible `…(trimmed — N chars dropped)` note instead of being cut without warning, and the spec cap was raised from 6k to 12k chars.

---

## v0.4.7 — 2026-09-11

- **Build with AI no longer auto-runs.** Opening the window now shows a **compose screen** with on-screen hints — nothing is sent to the AI until you choose. Type what you want done in the prompt box (pre-filled with the feature's description) and press ↑, or use the new right-side **action buttons**.
- **Right-side action buttons** for the things you do over and over: **Build this feature**, **Run checks** (analyze + tests), **Fix errors**, and **Commit & push** (stages/commits the linked repo and pushes to origin — deterministic git, no AI). Buttons + the manual prompt box share one input.

---

## v0.4.6 — 2026-09-11

- Fixed "Mark shipped" doing nothing in the build window (BUG-IMPL-005) — when a run was re-attached (the common case for a finished run), the shipped result was discarded, so you had to exit and ship from the board. Shipping is now applied from the persistent run state on both the fresh and re-attach paths.

---

## v0.4.5 — 2026-09-11

- **Copy from the build console** — the console is now selectable (`SelectionArea`: drag-select + ⌘C) and there's a **Copy-all** button in the header, so you can grab an error/output and paste it back for a fix.
- **See why planning failed** — on a "did not return valid JSON" failure the console now prints the model's **raw output** (selectable/copyable) instead of just a generic error, so the actual cause is visible. Plan token ceiling raised to 16000 so heavy reasoning can't starve the answer.

---

## v0.4.4 — 2026-09-11

- **Vibecode in the app** — the Build window now has a **persistent prompt box** at the bottom (like Claude Code): type an instruction any time the agent is idle (awaiting approval, or after a run finished/failed) and it re-plans with your message. Replaces the phase-limited "Revise" box.
- **Esc to interrupt** — pressing Escape stops the running task, like Ctrl-C in a terminal.
- **Re-edit shipped features** — "Build with AI" is now available on shipped features too (labelled "Re-build / edit with AI"), so a finished feature can be re-opened and edited/extended instead of being locked.

---

## v0.4.3 — 2026-09-10

- **Build with AI now edits via targeted find/replace hunks, not full-file rewrites.** The model returns small `{find, replace}` hunks (exact snippets) for existing files and only returns full `content` for brand-new files. This fixes at the root both the truncation-driven "did not return valid JSON" failures (BUG-IMPL-004 — the model was asked to reproduce a whole file it only saw the first 6k chars of) and the full-file-rewrite corruption that dropped code (BUG-IMPL-003). Files are now read at a much larger cap (24k/file, 90k total) so hunks match reliably. Unlocatable hunks are skipped with a note instead of failing the run.
- The build STEPS timeline no longer shows every step green when a run actually failed.

---

## v0.4.2 — 2026-09-10

- Fixed Build with AI "Planning failed: did not return valid JSON" (BUG-IMPL-004) on heavy reasoning models — the model spent its turn thinking and never emitted JSON. Ollama now sends `num_predict` (generous ceiling so thinking can't starve the answer), the plan pass budget is larger (8000; scout 4000), the prompt forbids "asking for more files" and forces JSON-only output, and the agent auto-retries once before failing. Tip: prefer an instruction-following/coder model for Build with AI.

---

## v0.4.1 — 2026-09-10

- Create a code folder from inside The Forge — the "Link Repo" row and the Build-with-AI "no repo" prompt now offer **"Create a new code folder"**, which makes `~/Development/<name>`, `git init`s it, and links it automatically (or **"Link an existing folder"**). Closes the onboarding gap where a non-technical user had no repo for Build with AI to write into. New helpers `ProjectFileRepository.createCodeRepo` / `defaultCodeRoot`.
- Hardening — the sandbox guard for agent writes (`ImplWorkspace.isPathSafe`) rejects absolute/`..` paths so a model-supplied edit can never escape the linked repo; folder pickers now pass `lockParentWindow` (BUG-UI-003).

---

## v0.4.0 — 2026-09-10

- Build with AI (§BWAI, Pro) — from a tracked feature, The Forge itself calls the LLM to implement it: a propose-&-approve loop that applies approved edits with per-step Undo (`.forge/impl_backups/<runId>/`), runs approved commands with live streamed output (`Process.start`), and verifies against the Handoff checklist; new `lib/features/implementation/` module
- Two-pass read-then-edit loop — scout picks files → The Forge reads them → the agent plans edits grounded in real code (plus repo docs: README/ARCHITECTURE/CLAUDE.md/agents.md)
- Real token streaming across all LLM providers — `LlmDelta{text,thinking}` + `completeStream`; reasoning models (glm-5.3, gpt-oss:120b) stream their chain-of-thought live (Ollama `message.thinking`)
- Build console — visible scrollbar + smart stick-to-bottom, reasoning as real scrollable lines, internal thinking (dim) vs external presentation (green), collapsible inline "thinking" block, guaranteed green Summary, active-model chip + wait-heartbeat + elapsed timer
- Modify / Revise / Fix — hand-edit a proposed file's content or a command; **Revise** (steer the AI → re-plan); **Fix-on-failure** (feed command failures + failed checklist items back to the agent for a corrective plan)
- Runs survive navigation (keepAlive) and re-attach on reopen; per-feature board status dots; tap an in-progress feature to open its run
- Release tracking — new `Releases` drift table (schemaVersion 2→3), a per-version Releases view, and "Cut release" → deterministic notes → CHANGELOG.md + optional git tag
- New Project reduced to two vibecoder choices (§NP2) — "Describe a new app" (Import→Spec, Paste/Guided sub-toggle) and "Bring in existing code" (onboarding); audit-interview retired from the picker
- Forge design kit (§UIK) — new `ForgeTheme` (navy + ember/brass metals), the Hearth Dial mark (`lib/core/widgets/hearth_dial.dart`), a launch splash driven by real boot steps, a first-run onboarding screen, a portfolio digest ("what changed since you last looked"), and `ForgeAppHeader`; design language v2: `rust (#7A3826)` marks blocked/stuck

### Fixed

- BUG-LLM-001 — reasoning models showed nothing while streaming (only `content` was read; now reads the thinking channel too)
- BUG-IMPL-001 — Stop → Try again crashed (stale-stream race; fixed with a generation counter)
- BUG-IMPL-002 — app quit on Apply & Run (unbounded console + unsafe/hung command; fixed with a console cap + command denylist + 3-min timeout + guarded run)
- BUG-IMPL-003 — a Build-with-AI run on The Forge corrupted `app.dart` + `settings_notifier.dart` via a full-file rewrite that dropped code; caught in review and reverted (never shipped); real fix (diff-based edits) tracked as a follow-up

## v0.3.0 — 2026-09-10

- Portfolio Tracker — new home dashboard plus per-project feature board with status tracking (idea/planned/in_progress/blocked/shipped/archived)
- Auto-scan + virtual-PM check-ins — `FeatureScanner` proposes features from `.forge` docs and/or a linked repo; `CheckinService` diffs git since last review into status changes, new features, and flags
- Import → Spec + existing-repo onboarding — paste a description/doc/transcript or analyze a repo (Quick docs+structure / Deep code-reading), with a compressed CONFIRM/gap form, into the existing spec pipeline
- Doc-based feature scan — features distilled directly from a project's own `.forge` documents
- `.forge` deliverable layout — all generated artifacts moved under a hidden `.forge/` folder with a fixed canonical projects root; "Export docs…" copies deliverables to `<chosen>/forge-docs/`
- Project deletion (safe) — double-confirm, index+folder cascade, guarded to the canonical root
- Provider layer — Ollama Cloud (`gpt-oss:120b-cloud`) is the default; Gemini removed entirely
- Dictation input via the `theforge://paste` URL scheme
- Cross-platform app icon
- Deploy scripts (`tool/deploy_{macos,ios,android}.sh`) + macOS unsandboxed, direct Developer ID distribution
- Fixed BUG-SETTINGS-002, BUG-UI-003, BUG-DATA-001

## v0.2.0 — 2026-06-01

- Backlog rewritten from 11 items to 16 items, grounded in Obsidian product docs (Workflow Template v3.0, Positioning Brief v4.0, ForkIt worked examples)
- Stale Firestore/Firebase Function references removed from §2–§9
- Critical path corrected: project folder browser now precedes interview
- New backlog items: §2 Riverpod state layer, §4 LLM provider layer, §9 Handoff Package, §10 Settings + BYOK, §14 Monte Carlo spec generation
- DeepSeek v4 Pro registered in agent registry as Rank 1 Executor (4.6/5)
- §1 Flutter Bootstrap + Local Data Layer — complete ✅

## v0.1.0 — 2026-05-31

- Initial repo bootstrap from Starter Repo
- Architecture defined, backlog seeded, docs scaffolded
- No Flutter code yet — docs and config only
