<!-- TEMPLATE — replace {{PLACEHOLDERS}} and delete this line. Part of the Docs Templates system. -->
# {{PROJECT_NAME}} — Architecture

**Version:** {{VERSION}}
**Last Updated:** YYYY-MM-DD

> **How to use this file**
> - The single source of truth for **how the system is built** — stack, layout, subsystems, and invariants.
> - Bump **Version** and **Last Updated** on any structural change (new subsystem, moved module, changed data flow).
> - Keep it descriptive of the *current* state, not history — history lives in `CHANGELOG.md` and `context.md`.
> - Add a `## <Subsystem>` section per major subsystem as the system grows. Delete the example subsystem below.

---

## What It Is

One paragraph: what {{PROJECT_NAME}} is, who it is for, and the one artifact/output that ties the system together.

| Mode / Surface | Purpose | Status |
|---|---|---|
| <name> | <what it does> | ✅ / 🔲 / in progress |

---

## Design Principles

**<Principle>.** One or two sentences on a load-bearing design rule (e.g. local-first, provider-agnostic, offline-capable).

**<Principle>.** Another cross-cutting rule the whole codebase obeys.

---

## Stack

| Layer | Technology |
|---|---|
| App / UI | {{STACK}} |
| State management | <lib> |
| Storage | <where data lives> |
| External services | <APIs / integrations, or "none"> |
| Linter / quality gate | <command that must pass clean> |

---

## Repository Layout

```
{{PROJECT_NAME}}/
├── <top-level dir>/
│   ├── <subdir>/
│   │   └── <file>          — one-line purpose
│   └── <file>              — one-line purpose
└── <config / entry point>  — one-line purpose
```

---

## Local / Project File Structure

_Describe the on-disk or per-project artifact layout the app reads and writes, if any._

---

## <Subsystem>   (example — replace or delete)

_One section per major subsystem. Describe its responsibility, the key classes/files, the data flow in and out, and how it reuses shared services. Add diagrams or small tables where they clarify the flow._

---

## Key Invariants

- **<Invariant>.** A rule that must always hold, ideally with the check that verifies it (e.g. a grep, a lint command, a write-once guarantee).
- **<Invariant>.** Another non-negotiable constraint future changes must respect.

---

_{{PROJECT_NAME}} — Architecture v{{VERSION}}_
