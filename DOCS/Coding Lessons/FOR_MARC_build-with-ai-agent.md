# FOR_MARC — Build with AI: putting a coding agent *inside* The Forge

We turned The Forge from a tool that *writes a spec and hands it off* into one that can *actually build a feature itself* — calling the LLM, proposing edits, running commands, and letting you watch it happen in an in-app console. Here's the whole story.

---

## Step 1 — Approach and reasoning

The core idea: pick a **feature** from the tracker (status `planned`), hit **Build with AI**, and The Forge becomes the builder. It reads your feature + spec, asks the LLM for a concrete plan (which files to change, which commands to run), shows you that plan, and — only after you approve — applies the edits and runs the commands, streaming everything into a live console.

Why this shape? Three reasons:
1. **Feature-driven, not spec-driven.** You said you think in features, and the tracker already stores them. So the *unit of work* is one feature; the Locked Spec and Handoff are just *context* we feed the model. Small, approvable, matches your mental model.
2. **Propose-and-approve, not autonomous.** For a non-technical builder, an agent that edits your code and runs commands with no brakes is terrifying. So nothing touches disk or runs without an explicit tap, and every applied edit is backed up for one-tap Undo.
3. **Reuse what exists.** The Forge already produces a machine-readable "Handoff verification checklist" (expected files, keywords). That became the agent's built-in "did it actually work?" test — for free.

## Step 2 — Roads not taken

- **Wrap an external CLI (Claude Code / a real terminal).** Fastest path to a literal terminal, but it fails the whole point: a vibecoder doesn't have a CLI installed or an API key to feed it. So The Forge had to *be* the agent, not shell out to one.
- **Have the model return unified diffs.** Diffs are compact, but *applying* a diff reliably in Dart is fiddly (context lines, fuzz, offsets). One malformed hunk and you corrupt a file. We chose the model returns the **full new file content**, and we compute the diff *locally* for display. More tokens, far fewer ways to break.
- **A first-class `Release` = just reuse `targetVersion`.** We could have derived releases on the fly from the free-text version field. But you explicitly wanted to *track* releases (dates, notes, tags), so a durable `Releases` table earns its keep.
- **Fail the run when the checklist fails.** We made verification *informational* instead. Early builds legitimately don't pass every check yet; blocking on it would make the tool feel broken.

## Step 3 — How the pieces connect

Think of it as **brains + hands + a stage**:
- **Brains** (`impl_agent.dart`): builds the prompt from the feature + spec, calls the LLM, parses back a JSON plan.
- **Hands** (`impl_workspace.dart`): the only thing that touches the filesystem — gathers the repo's file list, applies an edit (backing up first), runs the verification checklist.
- **The runner** (`command_runner.dart`): runs shell commands and *streams* their output.
- **The conductor** (`implementation_notifier.dart`): the state machine that walks a run through its phases — planning → awaiting approval → applying → running → verifying → done — logging each step to the console.
- **The stage** (`implementation_screen.dart`): the window you watch — console on the left, approval cards, step timeline on the right.

The tracker screen ties it together: "Build with AI" assembles the brief, flips the feature to `in_progress`, opens the window, and on ship flips it to `shipped` and ensures a `Release` row exists.

## Step 4 — Tools, methods, and frameworks

- **`Process.start` vs `Process.run`.** The app only ever used `Process.run` (run, wait, get all output at the end). The live "watch it work" feel *requires* `Process.start` — it hands you the output as a **Stream** you listen to line by line. That single choice is what makes the console feel alive.
- **Drift migration (`schemaVersion` 2→3).** Adding the `Releases` table is a *create-only* migration: `if (from < 3) await m.createTable(releases)`. Existing rows are never touched.
- **Riverpod `AutoDisposeFamilyNotifier`.** One run per feature, keyed by feature id, and it cleans up (kills any running process, drops the console) when the window closes.
- **LCS diff.** The diff view uses a Longest-Common-Subsequence table to line up unchanged lines so additions/deletions render like a real diff.

## Step 5 — Tradeoffs

- **Full-file content = reliability bought with tokens.** Big files cost more to send, but we never corrupt a file with a bad patch.
- **Approve-every-step = safety bought with friction.** More taps than a fully autonomous agent, but the right default for this audience. Autonomy can be a later toggle.
- **Deterministic release notes = robustness bought with polish.** We generate notes by *listing* shipped features, not by asking the LLM to write prose. Never fails, never hallucinates; less flowery. An LLM polish pass is an easy future add.

## Step 6 — Mistakes, dead ends, and wrong turns

- **A 7-digit color.** I wrote `Color(0xF0F0F10)` for a panel background. That's only 7 hex digits — Dart reads it as `0x0F0F0F10`, i.e. ~6% opacity, so the panel would've been nearly invisible. The analyzer says nothing (it's a valid `int`). Caught it by eye and fixed it to `0xFF0F0F10`. Lesson: color bugs hide from the linter.
- **Two missing imports.** `projectFileRepositoryProvider` and `dart:io` (`Directory`) weren't imported in the tracker screen. The analyzer caught both instantly — which is exactly why I run `dart analyze` after every wiring change instead of at the end.

## Step 7 — Pitfalls to watch for

- **The LLM is still blocking.** Every provider is hardcoded `stream: false`. So the *model's own reasoning* arrives in one chunk ("Planning…" then the plan appears) — it does **not** type out token by token. The live feel comes only from streamed **command** output. If you want the model prose to stream too, that's a real change to the provider layer (Phase 2).
- **We don't spawn a shell.** Commands are split into program + args and run directly (`runInShell: false`). So shell-only syntax (`&&`, pipes `|`, `$VAR`) won't work as written. That's deliberate — safer for this audience — but worth knowing.
- **Backups are per-run.** Undo restores from `.forge/impl_backups/<runId>/`. Close the window and that run's Undo history is what's on disk; we don't auto-clean it, so it's recoverable, but it's not a full version-control substitute.

## Step 8 — What an expert notices

The verification checklist was the quiet unlock. A junior builds a coding agent and then wonders "how do I know if it worked?" — and reaches for another LLM call to grade it (slow, non-deterministic). The Forge *already* emits a machine-readable checklist of expected files + keywords when it generates a Handoff. An expert spots that and wires a **deterministic** oracle: just check the files exist and contain the keywords. No extra tokens, repeatable, trustworthy. Reusing an artifact you already produce for a brand-new purpose is the senior move.

The other one: separating **brains / hands / conductor**. It's tempting to jam "call the LLM and write the files" into one class. Splitting the filesystem work (hands) from the LLM work (brains) from the state machine (conductor) means each is testable and swappable — e.g. we can unit-test release-notes generation without a database or an API key, which is exactly what `release_logic_test.dart` does.

## Step 9 — Transferable lessons

- **Make the machine's own output your test.** Any system that emits a structured description of "what done looks like" can verify itself deterministically. Applies to CI, data pipelines, form validation — anywhere.
- **Streaming is a data-shape decision, not a UI decision.** "Watch it work" isn't a widget; it's choosing an API that returns a *stream* instead of a *value*. Get the shape right at the bottom and the UI is easy.
- **Design the guardrails for your *worst-case* user, then relax them.** Propose-and-approve, Undo, no shell — these are for the nervous first-timer. You can always *add* autonomy behind a setting; you can't un-scare someone whose repo got mangled on day one.
- **Prefer boring reliability at the boundary.** Full file content over clever diffs; deterministic notes over generated prose. Save the cleverness for where a mistake is cheap.
