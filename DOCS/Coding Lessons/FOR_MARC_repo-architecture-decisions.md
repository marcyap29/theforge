# FOR MARC: How We Designed The Forge's Architecture — and Why Every Decision Was a Choice

*Session 1 · 2026-05-31*

---

## Step 1 — What approach did we take, and why?

We started with a product that was fully specified on paper — positioning brief, workflow template, worked examples — but had zero backend or app code. Before writing a single line, we had three architectural questions to answer:

1. Where does state live during an interview?
2. Where does persistent data live between sessions?
3. Is this its own product or a feature of LUMARA/SwarmSpace?

The answer to the first question drove everything else.

**The state question.** An interview is a multi-turn conversation. At any given moment you're tracking 8 confidence dimensions, partial answers, detected conflicts, and the current question. That state needs to survive from one message to the next. There are two ways to hold it: server-side (a stateful session running on a server) or client-side (the app holds it in memory).

We chose client-side — specifically Flutter's Riverpod state management — because The Forge is a desktop app. Desktop apps are long-lived processes. The user opens it, does an interview over 20 minutes, and the Flutter process is running the whole time. There's no reason to pay the complexity cost of a server-side session when the client itself is available to hold the state. Riverpod is already the pattern in LUMARA, so this is a zero-learning-curve choice.

The server (Firestore) only gets written to on phase completion — when the interview finishes and a spec is about to be locked. That single event writes the spec, the handoff, and an audit log entry in one transaction.

**The standalone question.** The Forge is its own Flutter app, its own repo, using the same Firebase project (`arc-epi`) as LUMARA and SwarmSpace but not embedded in either. This matters because the product positioning is explicitly tool-agnostic — it sits *above* executor agents, not inside one. Shipping it inside LUMARA would make it look like a LUMARA feature. Shipping it inside SwarmSpace would make it look like a plugin. Neither is the right frame.

---

## Step 2 — Roads not taken

**Option A: Durable Objects for the interview session**

Cloudflare Durable Objects are stateful server-side primitives — you could have a DO hold the interview state between API calls. SwarmSpace already uses these for the News Briefing Durable Object.

We considered this and rejected it. DOs solve a problem that desktop apps don't have: *stateless clients*. A web browser sends an HTTP request and forgets everything. The server needs to remember where you are. A Flutter desktop app is running continuously — it's not stateless. Using a DO here would mean round-tripping state to a server on every message, adding latency and complexity to something the client can handle entirely on its own. It's the right tool for the wrong job.

The heuristic: DOs are for web/API clients. Flutter desktop apps hold their own state.

**Option B: Building inside LUMARA**

The Forge could have been a screen inside the LUMARA app. LUMARA is Flutter, it already has Firebase, it already has the SwarmSpace integration. The wiring would be straightforward.

We rejected it because of perception, not architecture. The Forge's value proposition is that it works *upstream of any executor* — Claude Code, Codex, Cursor, whatever comes next. If it lives inside a journaling app, the mental model breaks. Customers would ask "why is my project management tool inside a reflection app?" The positioning brief is clear: this is a standalone B2B PM tool targeting dev shops and technical founders. It needs its own front door.

**Option C: CHRONICLE as the project memory backend**

CHRONICLE is LUMARA's longitudinal record system — immutable, append-only, versioned. The Forge's project state (locked specs, audit logs, phase history) has the same structural properties. Could we just store Forge project data in CHRONICLE?

No, for two reasons. CHRONICLE is sacred personal biographical data. The separation between "what I built" and "who I am" is real and should be enforced in code, not just policy. Second, CHRONICLE lives in Hive on the local device and Firebase under a very specific path structure designed around user reflection. Bolt-on project management would corrupt that design.

What we *did* do is copy the *philosophy* of CHRONICLE into the Forge's Firestore schema: immutable spec writes, append-only audit log, versioned phases. Same principles, clean separation.

---

## Step 3 — How the pieces connect

Think of the Forge as a relay with three legs:

```
Leg 1: Flutter app (interview)
  → User answers questions across N turns
  → Riverpod holds all state during the session
  → When interview is complete, serialize to JSON

Leg 2: Firebase Function (spec generation)
  → Receives the complete interview JSON
  → Fires 3 parallel LLM calls (t=0.2, t=0.6, t=1.0)
  → Returns all three variants simultaneously

Leg 3: Firestore (persistence)
  → User selects variant
  → Flutter writes: locked spec (immutable), bullet handoff, audit log entry
  → All three in a single Firestore transaction
```

Each leg has a clean handoff point. Leg 1 to Leg 2 is a single POST call with the complete interview JSON. Leg 2 to Leg 3 is the user's variant selection triggering the write. Nothing is written until it's complete — there's no partial state in Firestore during an active interview.

The Firestore schema mirrors this structure. Every project has a `forge-projects/{projectId}` root document, and everything hangs off it as subcollections: `/specs/`, `/handoffs/`, `/worksheets/`, `/audit/log`. The audit log is a single document with an append-only array — you can never replace it, only add to it.

---

## Step 4 — Tools, methods, and frameworks

**Riverpod** for interview state. Riverpod is Flutter's modern dependency injection and state management layer — more type-safe and composable than Provider or BLoC for this kind of local session state. Since LUMARA already uses it, there's no new pattern to learn.

**Firestore** for persistence. A document database where the schema is enforced by Firestore Security Rules, not a rigid schema definition. This is important here because the spec content is Markdown text — it doesn't fit neatly into a relational table. A Firestore document that holds the full spec as a string is the right shape.

**Firebase Cloud Functions** for spec generation. The reason this lives server-side rather than in the Flutter app is credit billing. If the LLM calls happened in Flutter, you couldn't reliably bill per-run — the app could be modified to skip the billing call. Putting spec generation in a Firebase Function means the billing happens atomically with the generation. You can't get the variants without the credits being charged.

**Firebase Security Rules** for immutability enforcement. The rule `allow update, delete: if false` on the specs subcollection means the server enforces immutability — even if the Flutter client had a bug that tried to overwrite a spec, the server would reject it. This is a critical property. Locked means locked, not "locked unless something goes wrong."

---

## Step 5 — Tradeoffs

**Interview state in Flutter vs. server**

Client-side:
- Pro: zero latency, no server cost, simpler architecture
- Con: if the app crashes mid-interview, state is lost (mitigated by auto-save to local storage)

Server-side (DO or Firebase session):
- Pro: survives app crashes, could resume on a different device
- Con: latency on every message, more complexity, overkill for a single-user desktop session

We chose client-side. The crash scenario is real but manageable — auto-save the interview state to local storage as a draft every N turns. Server-side sessions solve a multi-device/multi-user problem The Forge doesn't have (yet).

**Single Firebase project vs. dedicated project**

Sharing `arc-epi` with LUMARA and SwarmSpace:
- Pro: no new infrastructure, same billing, same auth, same deploy pipeline
- Con: a Firestore rules error on one product could affect others; all products' data lives in one place

A dedicated Firebase project:
- Pro: complete isolation, separate billing, no blast radius
- Con: new accounts, new credentials, new deploy setup for something that doesn't need it yet

We shared the project. The Forge is early enough that the isolation cost isn't worth paying. When it's generating real revenue it can have its own project.

**Immutability enforced in rules vs. in code**

Rules-enforced: the server rejects any update attempt, regardless of what the client does. Foolproof.

Code-enforced: the Flutter app simply never calls `.update()` on a spec. Works until there's a bug.

Both are implemented. Rules enforcement is the safety net; code discipline is the first line. Defense in depth.

---

## Step 6 — Mistakes, dead ends, and wrong turns

**The CHRONICLE temptation was stronger than expected**

Early in the conversation, the instinct was to use CHRONICLE as the Forge's backend. The structural similarity is real — CHRONICLE is append-only, versioned, and longitudinal. The Forge needs the same properties. For about ten minutes it seemed like a sensible reuse of existing infrastructure.

The thing that killed it was a single word: *sacred*. CHRONICLE is personal data — the user's reflection history, emotional patterns, biographical memory. Forge project data is professional/technical artifacts. Mixing them would mean a bug in The Forge could corrupt personal data. More importantly, it would create a conceptual tangle that would get worse over time. The right call was to copy the *architecture philosophy* (immutability, append-only, versioned) but implement it independently in Firestore.

This is a common pattern: you see something that looks like a reuse opportunity, and it is, but you reuse the idea rather than the implementation.

**The Durable Objects detour**

Before the "this is a desktop app" realization clicked, there was genuine consideration of using DOs for the interview session. The SwarmSpace News Briefing uses a DO successfully, and the interview has the right shape — multi-turn, stateful, persistent.

The moment it clicked was: "wait, the app is running the whole time." A DO exists to give stateless clients somewhere to put state. A desktop app is not a stateless client. Once that framing landed, the right answer was obvious. Sometimes the fastest path to the right answer is eliminating the wrong problem statement.

---

## Step 7 — Pitfalls to watch for

**Don't write to Firestore mid-interview.**

The pattern is: Flutter holds all interview state in Riverpod until the phase is complete, then writes everything in a single transaction. If you start writing partial state to Firestore during an interview (e.g., saving answers as you go), you create a mess: partial specs, inconsistent state, audit log entries for interviews that didn't finish. The rule is clean — nothing hits the server until the phase is done.

**Firestore Security Rules are not optional.**

It's tempting to write the Flutter code first and "add rules later." Don't. The rules that make specs immutable and the audit log append-only are not a polish step — they're a correctness guarantee. If specs can be overwritten, the product's core promise (locked means locked) is a lie. Write the rules before writing the repository code.

**The Firebase Function must be idempotent.**

If a user's network drops after the Function completes but before the Flutter app receives the response, the user might retry — triggering a second spec generation and a double credit charge. The Function needs an idempotency key (pass a `runId` from Flutter; reject duplicate `runId` values). This is easy to forget and painful in production.

**Never trust the client to bill itself.**

If spec generation called the LLM directly from Flutter and billed separately, a motivated user could intercept and skip the billing call. All credit deduction happens inside the Firebase Function, atomically with the generation. The function doesn't return variants unless billing succeeds. No workarounds possible.

---

## Step 8 — What an expert notices

A junior developer would look at this architecture and say: "it's a Flutter app that talks to Firebase."

A senior developer would notice:

**The transaction boundary is the entire design.**

The single Firestore transaction that writes the spec + handoff + audit log entry is not a convenience — it's the correctness guarantee. If spec creation succeeds but the audit log entry fails, the project is in a state where a locked spec exists with no audit record. You'd never be able to reconstruct what happened. The transaction means all three succeed or none do. That's the difference between a system that's eventually consistent and one that's provably consistent.

**The app crash scenario is real and needs a draft system.**

Right now, if the Flutter app crashes mid-interview, the entire interview is lost. For a 20-minute PM interview with a technical founder, that's a bad experience. The fix is a local draft — serialize Riverpod state to `SharedPreferences` or a local SQLite/Hive box every N turns. The server never sees draft state. When the app reopens, it reads the draft and offers to resume. This isn't in the backlog yet, but it should be.

**The Monte Carlo architecture is not just aesthetics.**

Running three LLM calls at different temperatures isn't a gimmick. Temperature controls creativity vs. reliability. At t=0.2, the model produces the most conservative, highest-confidence output. At t=1.0, it explores more. Showing all three simultaneously lets the user see the design space — not just one answer, but the range of defensible answers. This is how good architects actually work: they generate options before evaluating, rather than converging prematurely on the first reasonable solution.

**Credit billing as the auth gate is elegant.**

The Firebase Function won't return variants unless credits are deducted. This means credit balance is effectively the authorization check for the spec generation feature. It's not a separate auth layer — it's baked into the transaction. Simple systems are more reliable than complex ones.

---

## Step 9 — Transferable lessons

**Copy philosophy, not implementation.**

We took CHRONICLE's append-only, immutable, versioned architecture and applied it to Firestore for The Forge. Not the code, not the data format — the design principle. This is a repeating pattern in good engineering: identify what makes a system *work* (the principle) and apply it in the new context. Copying the implementation without understanding the principle usually fails because the contexts are different. Copying the principle and re-implementing it for the new context usually works.

**The client is stateful by default — use it.**

Web developers spend a lot of time building server-side sessions because browsers are stateless. But desktop apps, mobile apps, and native clients are not stateless. A long-running process holds memory for its entire lifetime. Before reaching for a server-side session, ask: "can the client hold this?" In most native app contexts, the answer is yes, and it's cheaper and simpler when it is.

**Transactions are free — use them for correctness, not just performance.**

Firestore transactions are typically discussed in the context of preventing concurrent write conflicts. But they're equally valuable for ensuring that a set of writes either all succeed or all fail. Any time you have two or more writes that must be consistent with each other, wrap them in a transaction. The cost is negligible. The correctness guarantee is not.

**Design for the "what if this fails halfway through?" question.**

Before any multi-step operation — a Firebase Function, a multi-write sequence, a background task — ask: "what happens if this fails after step 2 of 5?" If the answer is "undefined bad state," that's a design problem, not just an edge case. The answer should always be: "the system is in a known, recoverable state." Transactions, idempotency keys, and draft saves are all tools for ensuring this property.

**Positioning drives architecture.**

The decision to make The Forge a standalone app — not a LUMARA feature, not a SwarmSpace plugin — was a product positioning decision, not a technical one. But it had direct architectural consequences: separate repo, separate Flutter project, separate entry point. This is a case where business strategy and software architecture are the same decision expressed in different terms. When you understand why the product needs to stand alone, you automatically understand why the codebase does too.
