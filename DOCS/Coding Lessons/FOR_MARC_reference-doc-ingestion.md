# FOR_MARC: Reference Doc Ingestion Engine (§DOC)

**Topic:** How we built the doc ingestion pipeline — file picker → LLM extraction → disk cache → interview + spec injection  
**Sessions:** 2026-06-09 (build), 2026-06-10 (post-merge fixes)

---

## Step 1 — Approach and reasoning

The goal: let users drop `.md` or `.txt` reference files into a project before the interview, and have the extracted content automatically flow into every interview turn and the final spec generation — without them doing anything extra.

The insight that drove every decision: **the interview notifier is AutoDispose**. It gets destroyed whenever you navigate away. Any context held in Riverpod memory disappears when the user backs out to change a setting or check their project list. So "hold the doc context in Riverpod state" is a dead end from the start.

The architecture we landed on: **extract once, write to disk, read on demand.**

Three layers:
1. `ingestion_engine.dart` — takes raw doc text, calls the LLM with an extraction prompt, returns structured facts as markdown
2. `ingestion_notifier.dart` — manages add/remove lifecycle; writes per-doc `.facts.md` files; rebuilds the aggregated `reference_context.md` on every change
3. `interview_notifier.dart` + `spec_notifier.dart` — independently read `reference_context.md` from disk each time they need it

The fact that both consumers read from disk independently is a feature, not a flaw. They don't know about each other, they don't share state — they both just read the same file. Simple and solid.

---

## Step 2 — Roads not taken

**In-memory context (Riverpod state).** Natural first instinct. Store the extracted facts in a `IngestionNotifier` and expose them to the interview notifier. The problem: `InterviewNotifier` is `AutoDisposeNotifier`. When you navigate away, it's destroyed. When you come back, it rebuilds fresh — but the `IngestionNotifier` (a vanilla `Notifier`, not AutoDispose) is still alive. Threading the docs from one provider to the other on every rebuild gets messy fast. Disk is simpler: both providers just read the same file.

**Re-running the LLM every interview turn.** Every time a new message is sent, re-parse the reference docs through the LLM and inject fresh context. Technically clean, practically expensive — this would burn an extra architect-role call every single turn, for content that hasn't changed. Cache invalidation only matters when a doc is added or removed. Extract once.

**Injecting context as a chat message.** Add a hidden message to the conversation history: "SYSTEM CONTEXT: [facts here]". Keeps things in one place. The downside: it shows up in the turn history and messes with the UI, and it gets re-injected every turn as conversation grows anyway. System prompt injection is invisible and persistent.

**Single aggregated file written directly on add.** Skip the per-doc `.facts.md` step and write straight to `reference_context.md`. The problem: removing a doc becomes expensive — you'd need to parse the aggregated file to find and excise the right section. With per-doc facts files, removal is just: delete the file, rebuild from remaining files. Clean.

---

## Step 3 — How the pieces connect

The flow, in order:

```
User taps "Add Document"
  → file_picker NSOpenPanel opens (allowMultiple: true)
  → Each selected file: copyReferenceDoc() copies it to {project}/ingested/
  → ingestion_engine.buildIngestionPrompt() builds the extraction prompt
  → LLM call: architect role, t=0.2
  → parseIngestedFacts() parses response → writes {doc}.facts.md
  → _rebuildContext() scans all .facts.md in ingested/ → writes reference_context.md

Every interview turn (addUserMessage):
  → repo.readIngestedSummary(projectPath) reads reference_context.md
  → _interviewSystemPrompt(state, ingestedContext: ...) injects it as REFERENCE CONTEXT block
  → LLM call with enriched system prompt

Spec generation:
  → repo.readIngestedSummary(projectPath) reads same reference_context.md
  → buildSpecPrompt(state, ingestedContext: ...) injects it as REFERENCE CONTEXT block
  → LLM generates spec with full document context
```

The path between "doc added" and "context injected" never goes through live Riverpod state — it's always disk → read → inject.

---

## Step 4 — Tools, methods, and frameworks

**`file_picker` 8.3.7** — picked over 11.x because Flutter 3.38.7 has a Dart analyzer version ceiling. Version 11.x requires a newer analyzer than the project supports. Staying on 8.x is not a compromise — it works fine for macOS file dialogs.

**`LlmRole.architect` at t=0.2** — the architect role maps to precision use cases in the codebase. Temperature 0.2 minimizes variance: you want the same extraction result every time you run the prompt on the same document. Verbatim quoting is the goal — no interpretation, no paraphrase, no inference.

**`NotifierProvider` (global, not AutoDispose, not family)** — docs need to outlive navigation. AutoDispose would destroy them when the screen is popped. A family-by-project notifier was considered but rejected for v1 — a global notifier with an explicit `loadDocs()` call on project open is simpler and works fine for single-project workflows.

**Per-doc `.facts.md` files** — the extraction outputs a facts file per document, not a combined output. This makes the rebuild step trivial: `_rebuildContext()` just scans for all `.facts.md` files and concatenates them. Removing a doc = delete its facts file + rebuild.

---

## Step 5 — Tradeoffs

**Text-only vs binary.** We support `.md` and `.txt` only. No PDF, no DOCX. This means users with specs or architecture diagrams in PDF format can't add them yet. The upside: zero new dependencies, no PDF parsing library, no binary extraction complexity. Binary support is the obvious §DOC v2.

**Global notifier vs per-project family.** The notifier is a singleton, not scoped to a project. If you open a different project, the notifier still holds the old project's docs until `loadDocs()` is explicitly called. For single-project workflows this is invisible. For multi-project jumping it could show stale data briefly. The alternative (AutoDispose family by project path) would require a more careful wiring in the interview notifier. Acceptable v1 tradeoff.

**Verbatim extraction vs synthesis.** The extraction prompt instructs "no inference, verbatim quoting only." The resulting context block can be dense and raw — it's not a cleaned summary. The LLM interviewer or spec writer has to process it. The upside is faithfulness — no data is lost through LLM interpretation of LLM output. Synthesis lives at the injection site, not the extraction site.

---

## Step 6 — Mistakes, dead ends, and wrong turns

**Forgot `allowMultiple: true`.** First version of the file picker called `pickFiles()` without the flag. Result: only one file picked per tap, even when the user selected multiple. Fixed by adding `allowMultiple: true` and changing the single-file path to loop over `result.files`. Caught in post-merge testing.

**InkWell without Material on macOS desktop.** The "Manage →" button in `_ReferenceDocsRow` on the project detail screen was completely unresponsive. No error, no crash — just silently did nothing. Root cause: Flutter macOS desktop requires an immediate `Material` widget in the widget's subtree for `InkWell` ink gesture recognition to work. A `Scaffold` or `Material` higher up in the tree doesn't count — the ink system looks for a *nearby* ancestor. Fixed with `Material(color: Colors.transparent)` wrapping the row. One line of code, two hours of confusion before we found it.

**`loadDocs()` race in `interview_screen.dart` initState.** Originally wired `ingestionNotifierProvider.notifier.loadDocs(path)` in the interview screen's `initState`. The problem: when you tap "Add" on the reference docs screen, `addDoc()` runs an LLM call and updates state. If you go into the interview screen while that LLM call is still in flight, the interview screen's `initState` fires a *second* `loadDocs()` concurrently. Two async writers on the same `IngestionState` produce interleaved state updates — the doc list flickers and loses the in-flight doc. Fixed by removing `loadDocs` from the interview screen entirely. The interview screen watches the notifier passively via `_DocCountChip` — it doesn't need to trigger loads.

---

## Step 7 — Pitfalls to watch for

**`NSOpenPanel` is silently blocked without the entitlement.** If you add `file_picker` to a macOS Flutter app and the file dialog appears to open but nothing happens when you pick a file — check your `.entitlements` files. You need `com.apple.security.files.user-selected.read-only` in *both* `DebugProfile.entitlements` and `Release.entitlements`. Miss one and the debug build works but release doesn't (or vice versa). No error log, no crash, just silent failure.

**`InkWell` on macOS needs a local `Material`.** This is different from iOS/Android behavior. On mobile, the `Scaffold`'s Material is sufficient for ink effects. On macOS desktop it isn't. Any time you add an interactive row or button using `InkWell` or `InkResponse` on macOS, wrap it with `Material(color: Colors.transparent)`. Make it a habit.

**Global `Notifier` + multiple `initState` callers = state race.** Never call state-writing methods (`loadDocs`, `addDoc`, anything that mutates state) from multiple widgets' `initState` callbacks simultaneously. If two screens can both fire initState while the notifier is in a writing state, you'll get interleaved updates. Watch passively; load explicitly from a single place (e.g., when the user opens a project).

**`file_picker` version ceiling.** Flutter 3.38.7 needs `file_picker: ^8.0.0`. Don't try to upgrade to 11.x without upgrading Flutter first — it will fail at `pub get` with an analyzer version mismatch.

---

## Step 8 — What an expert notices

**The per-doc facts file pattern is a proper incremental pipeline.** Intermediate artifacts (`.facts.md` per doc) are the right design for anything where individual items can be added or removed. Compare to a naive implementation that writes a single growing file and has to parse it for removal. The rebuild step (`_rebuildContext`) is O(n) in the number of docs, which is fine for a handful of reference files.

**Disk-as-cache beats Riverpod state when AutoDispose is involved.** A common mistake is trying to share state between providers when one of them is AutoDispose. The lifecycle mismatch means you're fighting the framework. Disk is a zero-ceremony shared memory store that survives any provider lifecycle. Both the interview notifier and spec notifier read it independently — no coupling, no inter-provider dependency.

**`LlmRole.architect` at t=0.2 for extraction is a meaningful choice.** Using the architect role signals precision intent — not just any LLM call, but one configured for careful, accurate output. The t=0.2 temperature floor makes outputs repeatable. If you run the ingestion prompt twice on the same document, you'll get nearly identical results. That's what you want for a cache that's meant to be written once and trusted.

---

## Step 9 — Transferable lessons

**"Extract once, cache to disk, read on demand"** is the right pattern for any pipeline where: (a) source data changes infrequently, (b) consumers are AutoDispose or otherwise ephemeral, and (c) multiple independent consumers need the same processed data. Think: tag extraction, metadata indexing, configuration parsing, embedding generation.

**Per-item intermediate files are more robust than a single combined file** for any collection where items can be added and removed. Write one `.processed.json` per item, aggregate on demand. Removal is `File.delete()` + re-aggregate. No parsing needed.

**On macOS Flutter desktop, treat `Material(color: Colors.transparent)` as mandatory for interactive widgets.** Not optional, not "should add" — just add it as a rule. InkWell, InkResponse, ListTile — wrap them all. It's invisible and free.

**Multiple concurrent async writers on a single shared state object = state race.** The fix isn't a lock — it's architecture. One writer at a time. Passive observers watch; they don't write.

---

*Written 2026-06-11 · Sessions: §DOC 2026-06-09, post-merge fixes 2026-06-10*
