<!-- TEMPLATE — replace {{PLACEHOLDERS}} and delete this line. Part of the Docs Templates system. -->
# {{PROJECT_NAME}} — Feature Backlog

**Last Updated:** YYYY-MM-DD

Long-term feature pool. Active sprint work lives in `planner.md`.

---

## Critical Path

```
§1 <foundation item> ✅
  → §2 <next item> ✅
  → §3 <next item> (in progress)
       ↓
  → §N <later item> (not started)
```

_Use this fenced block to show the ordered dependency chain of the core build. Mark shipped links with ✅. Keep it to the spine of the project, not every item._

---

## How to use

- **Read first** when picking up new work — pull from High Priority before Medium before Low.
- **Add to** when the {{OWNER}} agrees a future feature should be done but is not the current focus.
- **Mark shipped items** with `✅` and the date; do not delete.
- **Do not remove items** without {{OWNER}} approval.
- Each item has a stable `§<TAG>`. Full items use the **What / Why / Architecture / Dependencies / Status** block; shipped items may collapse to a single `✅ Complete <date> — …` line.

---

## High Priority

### §EX — Example Feature   (example — replace or delete)
**What it is:** One or two sentences describing the feature concretely — what the user sees and does.

**Why it matters:** The reason this is worth building; the problem it removes or the value it adds.

**Architecture:** Where it lives in the codebase and how it reuses existing pieces — `path/to/module/**`, key classes, and which shared services it hooks into ({{STACK}}).

**Dependencies:** §<TAG> it needs first, or "None".

**Status:** Not started.  <!-- when shipped: ✅ Complete YYYY-MM-DD — see <reference doc / ARCHITECTURE section> -->

---

## Medium Priority

_(Items here follow the same block format. Move up to High Priority when prioritised.)_

---

## Low Priority

_(Same format. Ideas that are agreed-good but not near-term.)_

---

## Completed ✅

_(Shipped items collapse to a one-liner here, newest first. Do not delete — this is the shipped-feature history.)_

### §EX — Example Feature
✅ Complete YYYY-MM-DD — one-line summary of what landed and the files/classes involved; lint/test gate green.
