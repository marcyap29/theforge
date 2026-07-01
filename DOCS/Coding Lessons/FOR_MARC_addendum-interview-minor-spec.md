# FOR_MARC — Addendum Interview & Minor Spec System (v1.1 Pattern)

**Topic:** How we built the "Update vN → v1.1 spec" flow, and why it's structured the way it is.

---

## Step 1 — Approach and reasoning

The core idea: sometimes you don't want a full new version interview. You just want to add one feature, tighten a constraint, or fix a spec section. That's a minor spec — v1.1, v2.1, etc.

The existing interview system is heavy. It runs 4 layers of deductive questioning, resolves 8 confidence dimensions, and produces a full locked spec. That's perfect for v1→v2 jumps. But for "I want to add push notifications to v3" — overkill.

So we built a lighter path:
1. The user taps "Update v3" on the version panel.
2. A confirmation dialog asks if they want to start an addendum interview.
3. A focused chat screen opens — same dark theme, same style as the main interview.
4. The LLM asks 2-3 targeted questions based on what the user describes.
5. After ≥3 turns, a "Generate v3.1 Spec" button appears.
6. One LLM call synthesises the interview into an addendum spec document.
7. The spec lands at `specs/v3.1/ProjectName_LockedSpec_v3.1.md`.

That's the whole thing. Light, targeted, produces a real artifact on disk.

---

## Step 2 — Roads not taken

**Option A: Reuse the full interview system with a `isMinor: true` flag.**
Rejected. The full interview has 4 layers, tracks 8 confidence dimensions, writes forge-state JSON blocks after every turn, manages layer advancement gates. Adding a "minor mode" would mean either gutting half that logic or running all of it unnecessarily. Better to have a separate, simpler notifier that does exactly what minor specs need — nothing more.

**Option B: Just open a text editor and let the user write the addendum.**
Rejected. The whole point of The Forge is that the LLM does the synthesis work. A raw text editor doesn't help the user think through what they're actually adding. The interview forces specificity.

**Option C: Produce a diff/patch instead of a full addendum document.**
Considered. A diff is more precise — it shows exactly what changed. But it's harder for the executor agent to use (they'd need to apply a patch to the base spec). A self-contained addendum document that stands on its own is more useful as a handoff artifact.

---

## Step 3 — How the pieces connect

```
project_detail_screen.dart
  → _latestVersionOnDisk()             scans specs/ to find the latest version
  → _buildUpdateCta(context, version)  shown when selected version != latest
  → confirmation dialog
  → Navigator.push → AddendumInterviewScreen

AddendumInterviewScreen
  → watches addendumInterviewProvider(args)
  → calls notifier.addUserMessage(text)   ← sends each chat turn
  → calls notifier.generateMinorSpec()   ← when user is ready

AddendumInterviewNotifier
  → build():  reads base spec from disk via findSpecFile(); builds greeting
  → addUserMessage(): LLM call with full transcript as history
  → generateMinorSpec(): LLM synthesises transcript → addendum doc
                         writes via writeMinorLockedSpec()

ProjectFileRepository
  → findSpecFile(projectPath, version)   scans specs/v{version}/ for .md matching the locked spec suffix
  → writeMinorLockedSpec(...)            creates specs/v{minor}/ dir and writes the file
```

The screen is a pure UI shell. All the logic is in the notifier. The notifier is the only thing that touches the LLM and the filesystem.

---

## Step 4 — Tools, methods, and frameworks

**`FamilyAsyncNotifier<State, Args>`** — same pattern as the main interview notifier. The `args` struct (`AddendumInterviewArgs`) is the key: projectPath + projectName + baseVersion. Every unique set of args gets its own notifier instance.

One thing to know: `AddendumInterviewArgs` uses Dart's default object identity for `==` and `hashCode`. That's fine here because we never cache an args object — a new one is created each time the user navigates to the screen. If you ever tried to watch the same provider from two places with "the same" args, you'd get two different notifier instances and two separate LLM sessions. That would be a bug. For now, one screen = one notifier = correct.

**`AddendumInterviewState.copyWith`** — the standard immutable-state pattern. State never mutates. Every transition creates a new copy via `copyWith()`. This makes it safe to call `state = AsyncData(...)` from the notifier.

**The LLM system prompt** — tighter than the main interview prompt. No forge-state JSON blocks, no layer tracking. Just: "You are helping extend this spec. Ask one focused question per turn. After 2-3 turns, say exactly: 'I have what I need. Tap Generate {version} Spec when ready.'" That sentence is the exit signal — when the user sees it, the button is already visible (it appears after 3+ turns), so they can immediately act on it.

---

## Step 5 — Tradeoffs

**"Generate Spec" button after ≥3 turns vs. LLM-controlled exit:**
We gate the button on turn count (≥3 user turns), not on the LLM saying it's done. The LLM can say "I have what I need" earlier or later than 3 turns, but the button appearance is always our code's decision. Why? Because LLMs can miscount turns, decide they have enough after 1 vague answer, or get confused and never signal readiness. The count is a hard floor — you must have at least 3 exchanges before generating. After that, the user decides when they're ready, not the LLM.

**Full addendum document vs. section patches:**
The addendum is a self-contained document with its own header, summary, and sections. It doesn't reference the base spec by embedding diffs. The cost: there may be overlap between the base spec and the addendum. The gain: any agent reading the addendum gets a complete picture without needing to read and apply patches to the base spec.

**Separate feature vs. modifying the main interview:**
We built `addendum_interview/` as a completely separate feature folder, not an extension of `interview/`. The main interview is complex enough. Keeping addendum interview isolated means a change to one can't break the other.

---

## Step 6 — Mistakes, dead ends, and wrong turns

**DeepSeek's class-closing brace bug:**
When DeepSeek replaced the `build()` method in `_CoderPackageSectionState` to add `_buildUpdateCta` and `_latestVersionOnDisk`, it accidentally swallowed the class's closing `}` in the replacement. Result: `_PackBtn` (the next class down) ended up nested *inside* `_CoderPackageSectionState`, causing a cascade of "Classes can't be declared inside other classes" errors.

The fix was simple — add the missing `}` — but diagnosing it was the interesting part. We ran a Python script that counted `{` and `}` between two class markers in the file. The count came back unbalanced (+1 unclosed), which immediately told us: one `{` without a matching `}`. One-liner to fix; 5 minutes to diagnose without the script.

**Wrong import for `AddendumInterviewArgs`:**
The screen file originally imported only `addendum_interview_screen.dart` at the project detail screen level. But `AddendumInterviewArgs` is defined in `addendum_interview_notifier.dart`, not the screen file. The screen file imports the notifier file — so the class is transitively available if you import the screen. But the project detail screen needs to *construct* `AddendumInterviewArgs(...)`, which requires the notifier file to be directly imported. Two imports needed: notifier + screen.

**Minor-version regex missing from sidebar scan:**
The `_FilesSidebarState._scan()` method was using `RegExp(r'^v\d+$')` to identify version directories. That regex matches `v1`, `v2`, `v3` — but not `v1.1`, `v2.3`. So minor-version spec directories would have been invisible to the sidebar. Fixed to `^v(\d+(?:\.\d+)?)$` which matches both.

---

## Step 7 — Pitfalls to watch for

**`FamilyAsyncNotifier` and object identity:** If your `args` struct doesn't implement `==` and `hashCode`, two calls with "the same" values produce two different notifier instances. That's usually a bug. `AddendumInterviewArgs` skips this for now because navigation always creates a fresh args object. If you ever want to `ref.watch(addendumInterviewProvider(args))` from two widgets at the same time with semantically-equal args, you'll need `==` + `hashCode` on the args class.

**Reading state in `build()` vs. in a method:** The notifier's `build()` method runs once on first watch. If you read the base spec from disk there (like we do), it runs once and caches the result. If the spec file changes on disk after that, the notifier won't see it. For our use case, the spec never changes after locking, so this is fine. But if you ever wanted "live" disk reads, you'd need to move the read into each `addUserMessage()` call (or invalidate the provider on file changes).

**Class-closing brace in large file edits:** Whenever you ask an AI to replace a method that's the *last method in a class*, check that the replacement includes a `}` for the class closing. It's easy to drop. Run `grep -c '{' file` vs `grep -c '}' file` after any big edit — a difference of 1 means you have an unmatched brace.

**Minor-version spec filenames:** The `findSpecFile` method handles two naming conventions: `{Name}_LockedSpec_v{version}.md` and `{Name}_LockedSpec_{version}.md`. This matters because minor specs might be named either way depending on how the notifier generates them. The `writeMinorLockedSpec` method uses the second form (no leading `v` in the version suffix) — but `findSpecFile` handles both just in case.

---

## Step 8 — What an expert notices

The addendum interview notifier has one subtle architectural choice: the LLM receives the *full conversation history* as a single block of text (`FORGE: ... USER: ... FORGE: ... USER: ...`), not as a structured messages array. This is the same pattern as the main interview notifier. Why?

Because LLM APIs that take structured message arrays can be finicky about roles, ordering, and context windows. Sending a plain transcript as a single `userPrompt` with the conversation history embedded gives the model everything it needs, in a format that's identical to what it saw in training (which is full of conversation transcripts). It also makes debugging easier — you can `print()` the transcript and read it directly.

The tradeoff: the context grows linearly with the conversation. For short addendum interviews (3-5 turns), this is fine. For a 50-turn interview, you'd want to summarize earlier turns. But addendum interviews aren't 50 turns — they're brief by design.

Another thing an expert would notice: `generateMinorSpec()` reads the base spec from disk *inside the method*, not from `state`. That's intentional. The state doesn't hold the full spec text — only the turns. The spec is large (could be 2000+ tokens). Storing it in state would bloat every `copyWith()` call. Reading it from disk on demand is cheaper and the disk read is fast (local filesystem, sub-millisecond).

---

## Step 9 — Transferable lessons

**The "lighter parallel path" pattern.** When you have a complex feature with lots of state and logic, and you need a simpler version of the same thing — don't bolt the simpler thing onto the complex one. Build it separately. The complexity of the main feature is load-bearing; adding optional flags and conditionals to accommodate the simpler use case makes both harder to understand. New folder, new notifier, same visual style.

**Brace counting as a diagnostic tool.** Any time you get "Classes can't be declared inside other classes" or "unexpected token `class`" in Dart, your first thought should be "unmatched brace." A 5-line Python script counting `{` and `}` between two class-name markers will tell you exactly where the imbalance is. This is faster than reading the file with your eyes.

**LLM-triggered vs. code-gated UI transitions.** The "Generate Spec" button in the addendum interview is gated on turn count (≥3), not on the LLM saying it's ready. This is a general principle: any UI transition that the user can trigger should be controlled by code, not by LLM output. LLMs give hints ("I have what I need") — they don't control UI state. Your code does. This prevents the LLM from locking users out of a button because it decided it needed 10 more turns.

**Minor versions as first-class artifacts.** We made `specs/v1.1/` a real directory with a real locked spec file in it. The whole downstream system — sidebar scan, coder package detection, the "Update v{N}" button logic — treats minor versions exactly like major versions. No special cases. The regex just needed to match `1.1` as well as `1`. Small regex change, big conceptual unlock.
