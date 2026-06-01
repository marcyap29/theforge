# FOR MARC: Reviewing Agent Output, Diagnosing AOT Failures, and Writing a Backlog from Docs

*Session 2 · 2026-06-01 · Agent Review + Build Tooling + Backlog*

---

## Step 1 — Approach and reasoning

Three things happened in this session. They feel unrelated but they have a common thread: **the gap between what you think you're seeing and what's actually there**. That gap showed up in the agent review, in the build failure diagnosis, and in the backlog that needed rewriting.

**Reviewing DeepSeek's §1 output**

DeepSeek v4 Pro was given the §1 task: bootstrap the Flutter app, wire up Riverpod, drift, and path_provider, create `ForgeDatabase` and `ProjectFileRepository`. The review used a 5-dimension scoring rubric from `agent_scoping.md`:

1. **Spec Compliance** — did it do exactly what was asked?
2. **Integration Accuracy** — are the contracts with other code correct?
3. **Self-Correction Speed** — did it catch its own mistakes during the task?
4. **Scope Discipline** — did it stay within the brief or go rogue?
5. **Prompt Dependency** — how much pre-loaded context did it need before it could start?

Each dimension gets scored 1–5. The aggregate tells you where to rank the agent in your registry (T1 to T4).

**Running the code**

After the §1 files landed on disk, the standard next step is `dart run build_runner build` — this generates the drift database code (`forge_database.g.dart`) from the annotated schema. It failed immediately with a cryptic AOT compilation error. Diagnosing that took a few tool calls and eventually revealed a known Dart 3.10+ incompatibility that has a clean one-flag fix.

**Rewriting the backlog**

The existing backlog had 11 items. After reading the actual product documentation — the Agent Workflow Template, the Positioning Brief, and the worked examples (ForkIt spec, worksheet, bullet handoff) — it was clear the backlog was missing whole layers, had stale Firebase references scattered through it, and had the critical path in the wrong order. It got rewritten from scratch to 16 items against the real architecture.

---

## Step 2 — Roads not taken

**Scoring agent output from memory instead of checking disk**

The first instinct when reviewing agent diffs is to trust the diff display. The UI shows you what changed — why verify against disk? The answer is that some agent UIs (DeepSeek's in particular) display the *before* state in the edit marker, not the after state. If you score from the UI display without checking what actually landed, you can penalize an agent for an error it didn't make. More on this in Step 6.

**Diagnosing the AOT failure as a version mismatch**

First hypothesis when `build_runner` fails to compile: you're on the wrong Dart SDK or a package version conflict. This is usually the right first guess and it's quick to check. In this case it was wrong — the SDK and all packages were on their expected versions. The real cause was structural (native asset hook in a transitive dependency), not a version bump. The wrong guess would have sent you down a pubspec rabbit hole for an hour.

**Rewriting the backlog from existing §1 code**

You could look at what was already built and extrapolate the backlog forward from there — "§1 is done, so §2 should be the state layer, then §3 should be..." This produces a technically valid sequence but it misses everything the product documentation already decided. The worked examples (ForkIt spec, ForkIt worksheet, ForkIt bullet handoff) are ground truth for exactly what each stage should produce. Ignoring them and improvising means you'll write a spec output format that doesn't match what's in the template, and you'll discover that in §5 when it's expensive to fix.

---

## Step 3 — How the pieces connect

The three things in this session feed each other.

Agent review is only useful if the baseline is the actual codebase, not the agent UI. Once the §1 code was verified on disk, running `build_runner` was the obvious next step — that's how you know drift generated correctly and the code compiles. The AOT failure interrupted that verification, so fixing it was part of completing the review.

The backlog rewrite is downstream of both. You can't correctly scope §2–§9 if you don't know what §1 actually produced. And you can't write an accurate backlog without reading what the product expects each section to output — which is exactly what the worked examples document.

The dependency chain in order:

1. Verify §1 code on disk (not from agent UI)
2. Run `build_runner` to confirm generated code is valid → fix the AOT issue
3. `dart analyze lib/` → zero issues confirms §1 is actually done
4. Now rewrite the backlog knowing the real starting point and the real product requirements

---

## Step 4 — Tools, methods, and frameworks

**The 5-dimension scoring rubric**

The rubric from `agent_scoping.md` matters because it forces you to score orthogonally. "Spec Compliance" and "Scope Discipline" sound similar but they're not. Spec Compliance asks "did you do everything asked?" Scope Discipline asks "did you add anything not asked?" An agent can score high on one and low on the other. That separation matters for deciding where to use the agent next.

**`dart compile kernel` as an isolation test**

When `build_runner`'s AOT compilation fails, the question is: is the build script itself broken, or is the AOT compiler broken? Running `dart compile kernel path/to/build_runner_script.dart` compiles to bytecode (JIT path) without invoking native asset handling. If that succeeds, the script is fine and the issue is in the AOT step specifically. This is the correct isolation tool.

**`--force-jit` flag on build_runner**

`dart run build_runner build --force-jit` tells build_runner to skip its AOT bootstrap and use JIT kernel compilation instead. You lose a few seconds of startup time on very large projects (AOT is faster to start). You gain compatibility with the current macOS toolchain when any transitive dependency has a native build hook. On The Forge's codebase, JIT ran in 8 seconds. Not a meaningful difference.

**Product docs as backlog source**

The right input for a backlog is not a general understanding of the architecture — it's the specific output format that each stage must produce. For The Forge that means:
- `The Forge — Agent Workflow Template v3.0.md` for the 5 stages and their sub-steps
- The ForkIt worked examples for what correct outputs actually look like

If the backlog item says "generate a spec" but the worked example shows the spec has a specific structure (priorities, risk flags, scope brackets, variant sections), the backlog item needs to reference that structure. Otherwise the implementer (or future agent) will guess.

---

## Step 5 — Tradeoffs

**Trusting agent UI diffs vs. verifying on disk**

Trusting the diff display:
- Pro: faster review, no extra tool calls
- Con: some UIs show the old content in the edit marker; you can misevaluate the agent's work

Verifying on disk:
- Pro: score is accurate; you don't penalize correct work
- Con: a few extra reads during review

For a scoring system where you're building a registry of ranked agents, accuracy matters. A mistaken downgrade affects which tasks you assign the agent to in the future. Always verify.

**AOT vs. JIT for build_runner**

AOT bootstrap:
- Pro: slightly faster startup on very large projects
- Con: breaks when any transitive dependency has a native build hook (e.g. `objective_c` via `path_provider` on macOS)

JIT (`--force-jit`):
- Pro: works regardless of native asset hooks in the dep graph
- Con: marginally slower startup; you're bypassing an optimization

For a local developer tool that runs build_runner occasionally, JIT is the right call until the build_runner/native-assets incompatibility is resolved upstream. Don't let a speed optimization block your tooling.

**Backlog written from architecture knowledge vs. from product docs**

Architecture-only:
- Pro: faster to write, you can do it without reading all the docs
- Con: misses output format requirements, misses the critical path constraints, generates wrong descriptions for each stage

From product docs + worked examples:
- Pro: each backlog item maps to a real output format; you can reference worked examples as acceptance criteria
- Con: takes longer; you have to read several documents

The worked examples are worth the read time. They're not just examples — they're the contract for what "done" means at each stage.

---

## Step 6 — Mistakes, dead ends, and wrong turns

**The flutter_lints false positive**

During the agent review, the initial score docked DeepSeek on Spec Compliance because it appeared to have left `flutter_lints` as a dead dependency in `pubspec.yaml`. The spec said to remove dev dependencies that weren't needed.

The actual file on disk did not have `flutter_lints`. DeepSeek had correctly removed it.

What happened: DeepSeek's UI shows edits with an `← Edit /path/file` marker that displays the **old content** being replaced. The reviewer read the old content as the new content — the exact opposite of what was true. DeepSeek was being penalized for something it did correctly.

After reading the actual `pubspec.yaml` on disk, the score was corrected upward and DeepSeek landed at 4.6/5 — Rank 1 Executor.

The lesson is concrete: agent UI diff displays are not all the same. Some show the before, some show the after, some show both with +/- markers. When a score depends on what's in the file, read the file.

**The version mismatch dead end**

First hypothesis for the build_runner AOT failure was a Dart SDK or package version mismatch. Spent a few minutes checking `dart --version`, comparing dependency versions, looking for known conflicts. Nothing wrong. The issue wasn't in the versions at all — it was in what the dependency graph contained (a package with a native build hook).

The diagnostic pivot that cracked it: `dart compile aot-snapshot` returned a different error message that mentioned build hooks explicitly. That message pointed directly at `objective_c 9.4.1` and the `dart build` workaround. The version mismatch frame was the wrong frame; the right frame was "what kind of dependency causes AOT to fail on Dart 3.10+?"

**The backlog that described Firebase Functions for a local-first app**

The original backlog had items like "§3 — Spec Generation Firebase Function" and references to Firestore writes in the local interview flow. This was a straight copy from an earlier architecture that was subsequently replaced. Nobody updated the backlog when the architecture changed.

This is a common failure mode: the code moves forward, the backlog doesn't. After a few sessions, the backlog describes a system that doesn't exist. The fix is to re-anchor the backlog to the current architecture by reading the actual product documentation, not by editing the stale descriptions line-by-line.

---

## Step 7 — Pitfalls to watch for

**Don't score an agent from its UI output — verify on disk.**

Whatever display format the agent tool uses for edits and file writes, the only thing that matters for scoring is what landed on disk. Read the affected files. Takes 30 seconds. Prevents the kind of scoring error that happened here.

**`dart run build_runner build` will silently fail on macOS if you have `path_provider` in your dep graph and haven't used `--force-jit`.**

The failure message says "failed to compile build script" but doesn't tell you why. If you see this error on macOS after adding any package that pulls in `objective_c` transitively (which `path_provider` does), add `--force-jit`. The Dart native assets system and build_runner's AOT bootstrap are incompatible on Dart 3.7+. This is a known upstream issue, not something you broke.

**The backlog is not a living document by default — it becomes stale unless you actively re-anchor it.**

Every time a significant architectural decision changes, at least one backlog item is now describing something that doesn't exist. After any architecture revision, read the backlog top to bottom and compare each item against the current architecture docs. Stale backlog items are technical debt that shows up as confusion when an executor agent reads the brief.

**Critical path order matters. Don't assume the order is right just because the items are right.**

The original backlog had the Project Browser after the Interview Engine. That's backwards — the browser is the shell the interview launches from. You can't test the interview in context until the browser exists. When ordering backlog items, ask: "what does this task assume already exists?" That dependency determines the order.

**Worked examples are acceptance criteria, not illustrations.**

The ForkIt spec, worksheet, and bullet handoff aren't there to show you what the product feels like. They define exactly what a correct output looks like — the sections, the format, the level of detail. When you write a backlog item for "generate a locked spec," the acceptance criteria is "output matches the structure and depth of ForkIt_LockedSpec_v1." Without that anchor, "generate a locked spec" can mean 50 different things.

---

## Step 8 — What an expert notices

**Scoring rubrics that separate correlated-sounding dimensions are useful precisely because they're separate.**

A less careful review would merge "Spec Compliance" and "Scope Discipline" into one "did you follow instructions" score. But they pull in opposite directions: Compliance asks for completeness (did you do everything?), Discipline asks for restraint (did you do *only* what was asked?). An agent can pad its output with extras and still complete everything required — that's high Compliance, low Discipline. Keeping them separate forces you to notice that distinction and update your priors about which tasks to give the agent.

**Build failures that mention build hooks are telling you about the dep graph, not the code.**

When you see "does not support build hooks" in a Dart compile error, the question isn't "what's wrong with my code?" — the question is "which package in my transitive dependency tree has a `hook/build.dart`?" Native asset hooks are the new thing in Dart 3.x and most tutorials don't mention them. An expert reads the error message as pointing outward (at the dep graph) rather than inward (at the source code).

**The backlog is a contract, not a plan.**

A plan is a sequence of things you intend to do. A contract is a specific commitment: this input, this output, this definition of done. When a backlog item says "§3 — Generate Spec," that's a plan. When it says "§3 — Interview Engine calls active `SpecGenerationProvider`, fires 3 parallel LLM calls at temperatures [0.2, 0.6, 1.0], returns `List<SpecVariant>` that maps to the output structure in ForkIt_LockedSpec_v1" — that's a contract. Agents work from contracts, not plans.

**An agent that scores 4.6/5 and removed a dependency it was supposed to remove is, in the relevant ways, reliable.**

The instinct is to distrust agent output. That's healthy. But when verification confirms the agent did the right thing — accurately, without being told twice — update the registry score upward. The agent registry is only useful if the scores reflect reality. Keeping scores artificially low because "agents are usually flaky" defeats the purpose of having a registry.

---

## Step 9 — Transferable lessons

**"Read the file" is the base rate for any verification task.**

This applies everywhere: reviewing agent output, debugging unexpected behavior, checking whether a config change took effect, confirming a migration ran. The diff display, the log output, the terminal message — those are representations of reality, and representations can be wrong. The file is reality. Reading the actual file takes seconds and is always the most reliable check. Build the habit of going to the file when accuracy matters.

**Diagnostic isolation: find the smallest experiment that distinguishes two hypotheses.**

When the AOT failure happened, there were two competing explanations: the code is broken, or the AOT compiler is rejecting something structural. The smallest experiment that distinguishes them is `dart compile kernel` (bypasses AOT). When that succeeded, one hypothesis was eliminated. Then the second error message (`dart compile aot-snapshot` mentioning build hooks) pointed directly at the structural explanation. Each experiment was two lines. The diagnostic took maybe five minutes. The key is asking "what's the smallest thing I can run that tells me which of these two explanations is true?" — not "how do I fix it?" The fix comes after you know what's wrong.

**When a backlog goes stale, the fix is to re-read the source documents, not to edit the stale items.**

Editing stale items in place feels faster but it inherits whatever wrong assumptions are baked into the existing structure. If the architecture changed significantly, the backlog order might be wrong too, not just the descriptions. Re-reading the product docs from scratch and rewriting the backlog — as happened here — takes maybe an hour but produces a document where every item is grounded in actual requirements. The hour pays back the first time an agent reads the brief and doesn't ask a clarifying question that the worked example would have answered.

**Worked examples are the cheapest form of acceptance criteria.**

Writing acceptance criteria from scratch requires articulating every requirement at the right level of abstraction. That's hard. But if you already have a worked example of a correct output, you can just say "output should match the structure and completeness of [example]." The example does the articulation work for you. This generalizes: any time you're writing acceptance criteria for something that produces a document, ask if an example of a correct output exists somewhere. If it does, reference it.

**Agent registries are only worth maintaining if scores reflect reality.**

The scoring rubric and registry exist so you can pick the right agent for the right task. If you undercount agent failures (because you didn't verify on disk) or overcorrect for generic skepticism of agents, the registry drifts from reality. Then you assign T2 tasks to T3 agents or vice versa, and the quality varies unpredictably. The discipline of verifying before scoring — going to the file, checking the actual output — is what keeps the registry honest. An honest registry is a multiplier on every future task you delegate.
