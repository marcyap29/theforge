<!-- TEMPLATE — replace {{PLACEHOLDERS}} and delete this line. Part of the Docs Templates system. -->
# Bugtracker — {{PROJECT_NAME}}

Entry point for bug discovery, triage, fix, and consolidation in this repo.

---

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file — orientation |
| `BUG_PREVENTION.md` | **Read before coding in risky areas.** Anti-patterns and known traps. |
| `BUGTRACKER_MASTER_INDEX.md` | Format spec, ID scheme, Open/Fixed index |
| `records/` | One markdown file per bug |
| `records/_TEMPLATE_BUG_RECORD.md` | Canonical template for a new bug record |

---

## When to use

| Situation | What to do |
|---|---|
| Starting work in a risky subsystem | Read `BUG_PREVENTION.md` first |
| Diagnosing a new bug | Gather facts before guessing; check the master index for similar symptoms |
| Bug is fixed | Copy `records/_TEMPLATE_BUG_RECORD.md` into a new record; add a row to `BUGTRACKER_MASTER_INDEX.md`; add the prevention rule to `BUG_PREVENTION.md` |

---

## Bug ID convention

`BUG-<AREA>-<NNN>` — e.g. `BUG-{{AREA}}-001`, `BUG-DATA-001`, `BUG-UI-002`.

`<AREA>` is an uppercase subsystem tag. `<NNN>` is a zero-padded sequence number, counted per area. Define the areas your project uses in `BUGTRACKER_MASTER_INDEX.md`.
