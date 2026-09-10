# The Portfolio Tracker Era — A Development Story

**Version:** 1.0
**Date:** 2026-09-10
**Author:** Claude (Opus 4.8) with Marc

---

This is the story of one intense week of work on The Forge, roughly September 4th
through September 10th, 2026. It is not a changelog — it's a narrative you can read
start to finish to understand what The Forge became, why each decision was made, and
where the whole thing stands today. If you're a new engineer joining the project, or
if you're Marc coming back to this in six months, this is the document to read first.

Internally we tagged this arc **§PT — the "Portfolio Tracker era"** — because the
feature that kicked it off ended up reshaping the entire product.

## Where we started

Before this week, The Forge was a **spec-generation tool**. You'd sit down with it,
it would interview you about an app idea, and at the end you'd walk away with a set of
polished deliverables: a Locked Spec (immutable once written), a build worksheet, and
a bullet handoff for an executor agent to pick up. There was also **Watch Mode**, which
kept an eye on a repository via the GitHub API. It was a good tool for turning a fuzzy
idea into a buildable plan. But it was a *one-shot* tool — it helped you at the very
beginning of a project and then had nothing more to say.

Marc's actual problem was different. He has real apps in flight and a head full of
future projects, and what he wanted was a **virtual project manager**: something that
could sit above all of it and tell him, at a glance, *what features exist, what state
each one is in, and what deserves attention next.* The Forge already knew how to
*reason* about software projects — it just didn't know how to *track* them over time.
That gap is what this week set out to close.

## §PT1 — The Portfolio Tracker is born

The first move was to give The Forge a memory of features and their status.

We added two new drift tables — **`Features`** and **`ProjectTracking`** — and bumped
the database `schemaVersion` from 1 to 2. The migration is deliberately
**create-only**: it adds the two new tables and touches nothing that already existed,
so no one's data was at risk. Alongside the local database, each project's tracker
state is **mirrored to a per-project `tracker/*.json`** file, so the truth isn't
trapped inside an opaque SQLite blob — it lives, human-readable, next to the project.

The home screen changed identity. The **Portfolio dashboard became the new front door
(`/`)**, showing every tracked project as a card; the old project list was moved aside
to **`/projects`**. Open any project and you land on its **feature board**, where
features are grouped by lifecycle status: `idea → planned → in_progress → blocked →
shipped → archived`. You can add, edit, and delete features, and nudge them between
statuses with a quick move — the everyday motions of a project manager, now built in.

One small but important piece of hygiene: the old boilerplate "starter widget" test —
the one Flutter generates and nobody ever deletes — was finally **replaced with real
tracker tests** that actually exercise the new behavior.

## §PT2 — Teaching it to look, and to check in

A tracker you have to fill in by hand is a chore. So the next step was to let The Forge
**populate itself** and then **keep itself honest.**

The first half is an **auto-scan**: point it at a repo and the LLM proposes a feature
list from what it finds. You don't accept blindly — the proposal comes up in a review
sheet where you can accept, edit, or discard each suggestion.

The second half is the genuinely "virtual PM" part: **check-ins.** Each project has a
review cadence, and when a project goes stale relative to that cadence, an **on-open
banner** gently nudges you. Run a check-in and The Forge **diffs the git history since
your last review**, then proposes concrete changes — status moves, brand-new features
it noticed, and flags worth your attention — all in an accept-or-edit flow. This is the
moment The Forge stopped being a one-shot tool and started behaving like something that
watches your projects *with* you over time.

## §PT3 — Deploy tooling, and a fork in the road on sandboxing

With real features to ship, The Forge needed a real way to get onto devices. We
**ported the deploy scripts from Sabihin** (its sibling app) for macOS, iOS, and
Android — minus the Sabihin-specific machinery it didn't need (no bundled llama-server,
no TCC resets, no bundle-id migration). The Forge uses cloud LLMs with your own keys and
has no accessibility needs, so those steps simply fell away.

Then we hit a real architectural fork. The git-based features — Watch Mode, the repo
scan, the check-in diffs — all **shell out to the system `git` binary and read
arbitrary local repositories.** The macOS App Sandbox flatly forbids both. You cannot
have the features *and* the sandbox. We chose the features: **macOS ships unsandboxed**,
distributed directly with Developer ID and notarization rather than through the Mac App
Store.

Crucially, we didn't just make that call and forget it — we **wrote it down as a parked
decision** in `DOCS/deploy/APP_STORE_SANDBOX_PLAN.md`. That document maps the exact
surface that blocks the sandbox (four `git` call sites in two files, plus two
reveal-in-Finder subprocesses) and sketches the path back: an in-process git engine
behind a `GitReader` seam, security-scoped bookmarks for file access, and App Store
packaging. It's a decision we can revisit deliberately, not one we'll have to
rediscover in a panic.

## §PT4 — Ollama Cloud in, Gemini out

This one was triggered by a real failure. Mid-scan, **Gemini returned a 503** and the
whole flow fell over. That was the nudge to reconsider the LLM backend.

We added **Bearer-token auth for `https://ollama.com`** so The Forge can talk to
**Ollama Cloud**, and made it the **default** with `gpt-oss:120b-cloud`. And we
**removed Gemini entirely** — the provider, its usage tracking, all of it. Fewer
providers, one solid default, and no more single-vendor outage taking down a core
workflow.

## §PT5 — Deleting projects, carefully

A portfolio manager needs to be able to *remove* things too. We added **project
deletion from both the dashboard and the list**, gated behind a **double
confirmation** — you confirm once, then confirm again on a final dialog — and a
**cascade** that cleans up everything the project owns (features, tracking rows, and
the on-disk workspace). The double-confirm is not paranoia for its own sake; §PT-bug
below explains exactly why deletion turned out to be the most dangerous corner of the
whole app.

## §PT6 — Dictation via a URL scheme

Marc dictates. Sabihin, his other app, does dictation by putting text on the clipboard
and firing a synthetic ⌘V. The trouble is that **Flutter text fields on macOS don't
reliably receive CGEvent-based keystrokes**, so that synthetic paste silently dropped
into the void inside The Forge.

The fix mirrors exactly what Sabihin already does for its Correspondence feature: we
registered a **`theforge://paste` URL scheme.** Sabihin puts the transcript on the
clipboard and opens that URL; the native side forwards it to a method channel, and
The Forge inserts the text at the caret by invoking Flutter's own `PasteTextIntent` —
the very action ⌘V maps to inside the app, just triggered programmatically so it works
no matter how the keystroke was (or wasn't) delivered.

## §PT7 — A real app icon

Small but it matters for a product you're proud of: we **replaced the default Flutter
icon with The Forge's own icon across every platform** — macOS, iOS, Android, and the
rest. It stops looking like a demo the moment it has its own face.

## §PT8 — The `.forge` deliverables folder

By now projects were accumulating generated artifacts, and they were cluttering the
project root. We moved **all generated deliverables into a hidden `.forge/` folder**
per project. The two things a human actually opens by hand — the `README` and their
`user_notes` — **stay at the root** where they belong; everything The Forge produces
lives tidily out of the way.

This reorganization also flushed out some strays. Un-sandboxing (§PT3) meant we could
finally reach into the old sandbox container, and there we **recovered two stranded
projects — AR Mechanic and Forkit** — that had been marooned inside the sandbox. We
also **deleted a stale 130MB legacy container** that was doing nothing but taking up
space.

## §PT9 — A fixed home, and a way to export

Here's where a quiet but consequential safety decision got made. The projects root
became a **fixed, canonical home: `~/Documents/The Forge Projects`** — and it **can
never again be pointed at a code repository.** (The reason that guardrail exists in the
first place is the bug story below; this is us building the fence *after* seeing the
cliff.)

Because the deliverables now live in a fixed, hidden place, we also needed a clean way
to get them *out*. So we added **"Export docs…"**, which copies a project's
deliverables into `<a location you choose>/forge-docs/`. The canonical home keeps the
data safe and organized; export gives you an easy door out when you want to share or
archive.

## §PT10 — Import → Spec: a second door into generation

Up to now there was exactly one way to produce a spec: sit through the interview. That's
great when you're starting from nothing, but a lot of the time Marc already *had* the
idea written down somewhere.

So we built **Import → Spec**, a one-shot path. You paste a description, import a
`.md`/`.txt`, or drop in a transcript, and the LLM **fills the interview's structured
state for you.** You get a **compressed confirm screen** to review what it inferred, and
then — this is the elegant part — the **exact same spec generator** runs and produces
**identical deliverables.** No parallel code path, no second-class output. It's the same
engine, reached through a different door.

## §PT11 — Onboarding a repo that already exists

The third door is for projects that are already real. **"Analyze a repo…"** ingests a
project's existing docs and file structure, **auto-fills everything it reasonably can**,
and — importantly — **leaves genuine unknowns blank** rather than hallucinating answers.
Those blanks become a list of **open questions** presented as a **guided gap form**, so
you're only ever answering the things The Forge honestly couldn't determine.

For projects where the docs aren't enough, there's **"Dig deeper" / Deep scan**, which
runs the **real component analyzer** — the same engine Watch Mode's Pull mode uses. We
deliberately reused that machinery rather than writing a shallow parallel scanner; it's
the same rigor, just aimed at onboarding.

## §PT12 — Scanning documents, not just code

The feature scanner had one blind spot: it only understood repositories with git
history. But a project like **AR Mechanic** was *docs-only* — it had a spec and a goal
but no code yet. To that scanner, it looked empty.

So we taught the scanner to **read a project's own `.forge` documents** — its spec,
handoff, goal, and seed files. Now a docs-only project yields real features:
things that are **spec'd-but-not-yet-built become "planned."** The button was renamed
from "Suggest features" to **"Scan Repo and Documents"** to reflect that it now looks at
both. A project no longer has to have code before The Forge can help you track it.

## The pivot: who is this actually for?

Somewhere in the middle of all this, a bigger question surfaced. We decided The Forge
should target **"vibecoders"** — non-technical builders who want to ship apps without
being engineers.

And that decision immediately collided with what we'd built. The headline AI features —
the scans, the check-ins — **require an LLM key or backend, and quietly assume git
literacy.** That's precisely the opposite of what a non-technical builder has. The
product we'd been building and the customer we'd just named were pulling in different
directions.

The resolution is a **freemium model.** The **manual feature board is free** — anyone
can track projects and move features around by hand, no key, no git, no friction. The
**AI features become paid**, delivered through an **Orbital-run metered gateway over
Ollama Cloud**, so the customer never has to hold a key or understand a token. Orbital
runs the backend, meters usage, and bills for it.

Two strategy documents were written to capture this — a **Monetization Plan** and a
**Managed Backend Architecture** — and they live on Marc's Desktop (in
`Desktop/CLAUDE OUTPUTS/The Forge/`). Be clear about their status: **this is an open
business decision, not built code.** It's the direction, written down so we can argue
with it and commit to it deliberately.

## The dangerous bug we caught in time

This is the part of the week worth reading twice.

At some earlier point, the projects root had been pointed at an actual **code
repository.** The tracker's index dutifully recorded rows for what it found there — and
what it found were real source folders: `lib`, `macos`, `.git`, and the rest. Those rows
sat quietly in the database. Then we shipped project deletion (§PT5), and the two facts
collided into a genuine landmine: **deleting one of those "projects" would have
`rm -rf`'d actual source code.**

We caught it and hardened it in layers:

1. **A hard guard:** `deleteProjectCascade` now deletes an on-disk folder **only when it
   lives inside the canonical Forge root.** Anything outside that root gets its index
   rows purged but **never has its directory removed.** Deleting a project can no longer
   touch your code, full stop.
2. **Index pruning:** the stale rows pointing at real source folders get cleaned out, so
   the bad state can't linger and mislead.
3. **Honest dialogs:** the delete confirmations now **show the exact path** that's about
   to be removed, so nothing destructive happens behind an abstraction.

And §PT9's "the root can never be a code repo again" rule is the upstream fence that
stops this class of bug from ever forming in the first place.

Two smaller footguns got defused in the same stretch:

- **An empty-model settings bug:** a role configured with a provider but *no model* was
  breaking **every** LLM call. Now a missing model degrades gracefully instead of
  poisoning the whole pipeline.
- **A silent folder picker:** on macOS the folder picker would sometimes just... do
  nothing. The fix was `lockParentWindow` — the picker now presents reliably every time.

## Where it stands now

At the end of this week, The Forge is a **working virtual project manager** with:

- **Three doors into spec generation** that all converge on the same generator — the
  **interview**, **Import → Spec**, and **repo onboarding**.
- A **feature tracker** with a manual board, LLM-assisted scans (of both code *and*
  docs), and virtual-PM check-ins.
- **Safe project deletion**, guarded so it can never touch source code.
- A **fixed, canonical doc home** with a clean **export** path out.
- **Ollama Cloud** as the LLM backend, with Gemini fully removed.
- A clear, **written-down (but not yet built) monetization path** toward freemium with a
  managed metered gateway.

The repository was also **consolidated down to a single `main` branch** — no stray
worktrees or forks left over from the week's churn.

## What's next

A few threads are teed up but not started:

- **The managed-backend gateway spike** — prove out the Orbital-run metered gateway over
  Ollama Cloud that the monetization plan depends on. This is the load-bearing unknown
  for the whole freemium pivot.
- **Batch mode for Deep scan** — the component analyzer is powerful but currently
  one-at-a-time; batching it would make onboarding larger portfolios far less tedious.
- **Possibly the App-Store sandbox rework** — the parked plan in
  `DOCS/deploy/APP_STORE_SANDBOX_PLAN.md`, if and when Mac App Store distribution earns
  its place on the roadmap.

None of these are urgent, and that's the point: The Forge went from a one-shot spec tool
to a real, safe, daily-useful project manager this week, and the next moves are choices
we get to make deliberately rather than fires we have to fight.
