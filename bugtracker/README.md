# Bugtracker — The Forge

Entry point for bug discovery, triage, fix, and consolidation in this repo.

---

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file — orientation |
| `BUG_PREVENTION.md` | **Read before coding in risky areas.** Anti-patterns and known traps. |
| `BUGTRACKER_MASTER_INDEX.md` | Format spec, tags, resolution patterns, maintenance procedures |
| `bug_tracker.md` | Index of all bug records |
| `records/` | One markdown file per bug |

---

## When to use

| Situation | What to do |
|---|---|
| Starting work in Firestore schema, spec generation, or auth | Read `BUG_PREVENTION.md` first |
| Diagnosing a new bug | Apply SOP-ERROR; check `bug_tracker.md` for similar symptoms |
| Bug is fixed | Add a record to `records/`; add index entry to `bug_tracker.md` |

---

## Bug ID convention

`BUG-<AREA>-<NNN>` — e.g. `BUG-FIRESTORE-001`, `BUG-SPECGEN-001`, `BUG-INTERVIEW-001`.

Areas: `FIRESTORE`, `SPECGEN`, `INTERVIEW`, `AUTH`, `UI`, `BILLING`
