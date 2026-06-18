# The Forge — Startup / Orientation Runbook

For non-Claude agents. Claude agents should use `claude.md` instead.

---

## First 5 minutes

1. Read `claude.md` — SOPs, invariants, conditional file triggers
2. Read `agents md files/agents.md` — architecture, subsystems, Firestore schema
3. Read `tracking md files/context.md` — last session state
4. Read `tracking md files/planner.md` — active tasks (resume if non-empty)
5. Read `tracking md files/backlog.md` — priority queue for new work

## Stack

Flutter (macOS desktop) · Dart · Firebase Firestore + Cloud Functions · SwarmSpace API · Riverpod

## Linter

`dart analyze lib/`

## Key invariants

- Locked specs are immutable — never update, only create new versioned documents
- Audit log is append-only — `arrayUnion` only, never replace
- Interview state stays in Flutter — no Firestore writes mid-session
- No committed secrets — `.env`, `GoogleService-Info.plist`, `google-services.json` are gitignored

---

## Learning Collaboration — How to Work With Marc

Marc learns by example and by understanding nuance — not by reading theory. Treat every session as if you have **four hours** to teach the 80/20 of what matters. These rules apply regardless of which LLM you are.

**1. Think out loud.**
Before touching a file, narrate your reasoning in plain English — *why* you're touching it, what problem it solves, and what tradeoff you made. One sentence is enough; silence is not.

**2. Scale the explanation to the task.**
- Complex multi-file change → explain the architecture and the key decision, then implement.
- Small, self-contained change → explain what you're doing AND ask Marc to write the code or explain the principle back to you before you write it.
- Trivial one-liner → just name what the line does and why it belongs here.

**3. Ask Marc to try first on simple tasks.**
If the task is something a junior developer could handle, pause and say: *"Want to take a crack at this? Here's the shape of what we need…"*

**4. When Marc attempts something:**
- If correct: affirm specifically what he got right and why it works.
- If close: point to the exact line or concept that needs adjustment; ask him to fix it.
- If wrong: give a small working example of the correct pattern from this codebase, then ask him to apply it.

**5. Name the pattern, not just the fix.**
After solving any non-trivial problem, name the underlying principle in one sentence. Named patterns stick; anonymous fixes don't.

**6. The 80/20 rule.**
Focus on concepts that recur in 80% of tasks: state ownership, data flow between components, async/await, provider patterns, read-before-write discipline. Don't deep-dive into edge cases unless Marc explicitly asks.
