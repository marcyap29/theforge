# The Forge — Feature Catalog

**Last Updated:** 2026-05-31

---

## Core Features

| Feature | Status | Notes |
|---|---|---|
| Build Interview (8-dimension confidence model) | Planned | §2 in backlog |
| Audit Interview (current state spec) | Planned | §6 in backlog |
| Monte Carlo spec generation (3 parallel variants) | Planned | §3 in backlog |
| Locked spec (immutable, versioned) | Planned | Part of §3 |
| Bullet handoff (phase transition summary) | Planned | Part of §3 |
| Setup worksheet (external services checklist) | Planned | §9 in backlog |
| Handoff package (JSON, for executor agents) | Planned | Part of §3 |
| Project folder browser (list + resume) | Planned | §4 in backlog |
| Artifact viewers (spec, handoff, worksheet, audit) | Planned | §5 in backlog |
| Document ingestion (PDF, Word, Markdown) | Planned | §7 in backlog |
| Workspace + billing ($150/workspace/month) | Planned | §8 in backlog |
| Audit trail export (versioned, client deliverable) | Future | §11 in backlog |
| Open source executor path (tool-agnostic JSON spec) | Future | §10 in backlog |

---

## Interview Modes

| Mode | Use case | Output |
|---|---|---|
| Build Interview | Greenfield — nothing exists yet | Locked Spec |
| Audit Interview | Existing team or codebase | Current State Spec |

---

## Outputs Per Run

| Output | Description | For |
|---|---|---|
| Locked Spec | Immutable architecture document | Executor agents |
| Bullet Handoff | Human-scannable phase transition summary | The Forge on resume + user |
| Setup Worksheet | Step-by-step human-action checklist for external services | User |
| Handoff Package | JSON summary of the run | Next agent or session |
