# The Forge — UI/UX Patterns

**Last Updated:** 2026-05-31

Read this before touching any UI code.

---

## Design Principles

- **Desktop-first.** macOS primary. Wide layouts, sidebar navigation, keyboard shortcuts matter.
- **PM tone, not chatbot tone.** The interview feels like talking to a senior PM who will push back — not an assistant eager to please. The UI should reinforce this: structured, purposeful, no fluff.
- **Immutability is visible.** Locked specs look locked. A "LOCKED" badge, a timestamp, a read-only treatment. Users should never wonder if they can edit a locked artifact.
- **Confidence is visible.** The confidence meter is always present during an interview. Users can see progress toward 100%.
- **Conflicts stop the flow.** Conflict detection is not a warning banner — it pauses the interview and requires explicit resolution before proceeding.

---

## Core Screens

| Screen | Purpose |
|---|---|
| Project browser | List + resume projects. Entry point after auth. |
| New project | Mode selection (Build / Audit) + project name. |
| Interview | Main conversational screen. Confidence meter. Question/answer flow. Conflict resolution. |
| Variant selection | Show 3 spec variants side-by-side. User selects or nominates hybrid. |
| Locked spec viewer | Read-only. LOCKED badge + timestamp. Full spec content. |
| Bullet handoff viewer | Read-only. Phase transition summary. |
| Setup worksheet | Read-only checklist. Checkbox state tracked locally (not persisted to Firestore). |
| Audit log | Read-only. Timestamped append-only run history. |

---

## Patterns to Follow

*(Add patterns here as they are established during development)*

---

## Open UX Questions

- What does the confidence meter look like when a conflict is detected mid-interview?
- How are the 3 spec variants presented — tabs, columns, or sequential reveal?
- How does the variant selection screen handle a "nominate hybrid" path?
