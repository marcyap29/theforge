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
