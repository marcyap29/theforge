<!-- TEMPLATE — replace {{PLACEHOLDERS}} and delete this line. Part of the Docs Templates system. -->
# SOP — Standard Operating Procedures — {{PROJECT_NAME}}

Universal prompts for planning, error diagnosis, and task structure.

**Linter:** `{{LINT_COMMAND}}`   <!-- e.g. `dart analyze lib/` -->

---

## SOP-PLAN — Task Planning Protocol

Use this before starting any non-trivial implementation task.

### Steps

1. **Read before writing** — read every file you plan to modify before touching it
2. **State the definition of done** — one sentence: what does "complete" look like?
3. **List files to modify** — exact paths; if unsure, grep for the class/method first
4. **Break into sub-tasks** — ordered list; mark dependencies explicitly
5. **Identify risks** — check the project's bug-prevention notes before coding; skim the bug tracker
6. **State what NOT to change** — boundaries prevent scope creep

### Template

```
## Plan: [Feature Name]

**Definition of done:** [one sentence]

**Files to modify:**
- `path/to/file` — [what changes]

**Sub-tasks:**
1. [ ] [Task 1]
2. [ ] [Task 2 — depends on Task 1]

**Risks:**
- [Risk 1 — mitigation]

**Out of scope:**
- [Thing not being changed]
```

---

## SOP-ERROR — Error Diagnosis Protocol

1. **State the symptom exactly** — what happens vs. what was expected; error message verbatim
2. **Identify the last known good state** — last commit that worked; what changed since
3. **Narrow the blast radius** — which layer? ({{list the app's layers — e.g. UI / state / data / API / auth}})
4. **Form one hypothesis at a time** — test it; do not stack multiple changes
5. **Check the bug tracker** — grep prior bug records for the same symptom
6. **Document the fix** — add a record to the bug tracker

**Escalation:** If 2 hypotheses are ruled out and cause is unknown — stop. Document under `## Pending Review` in the planner. Do not loop silently.

---

## SOP-REVIEW — Pre-Commit Checklist

- [ ] `{{LINT_COMMAND}}` — zero new errors in modified files
- [ ] No changes outside the files listed in the plan
- [ ] No debug logging left in production paths
- [ ] Bug-prevention notes consulted — no known anti-patterns reintroduced
- [ ] Session log updated with a session block
- [ ] Planner tasks crossed off
- [ ] Commit message follows `<type>: <short description>` convention

---

## SOP-AGENT — Multi-Agent Task Structure

1. **Overseer defines work** — writes a spec doc with definition of done, exact file paths, constraints
2. **Overseer assigns** — each sub-agent gets a single spec; no agent works on the same file as another
3. **Sub-agent works** — reads spec, reads actual files, implements, runs linter, commits to branch
4. **Sub-agent reports** — pushes branch; does NOT merge
5. **Overseer reviews** — reads diff, checks linter, confirms definition of done met
6. **Overseer merges or requests changes** — one round max before escalating to {{OWNER}}

---

## SOP-SECURITY — Security Audit

| Step | Action |
|------|--------|
| 1 | Read `SECURITY_CHECKLIST.md` |
| 2 | Secrets scan — check all changed files for hardcoded keys/tokens |
| 3 | Auth/authz — every new data path or server endpoint must check auth |
| 4 | Input validation — all user inputs validated; no injection vectors |
| 5 | Document findings with date and commit ref |

---

## SOP-WORKTREE — Branch Isolation Protocol

**Use a worktree when:** multi-session work, risky/shared paths ({{list high-risk paths — e.g. schema, generation logic}}), external agent doing the work, experimental change.

**Stay on main for:** single-file fixes, doc-only, < 30 minutes, trivially reversible.

**Lifecycle:**
1. Plan (SOP-PLAN)
2. `git worktree add ../{{PROJECT_SLUG}}-<id> -b wt/<id>`
3. Implement; commit to `wt/<id>` only
4. {{OWNER}} review: `git -C ../{{PROJECT_SLUG}}-<id> diff main..HEAD`
5. {{OWNER}} approval (explicit)
6. `git checkout main && git merge --no-ff wt/<id> && git push origin main`
7. Verify clean: `git -C ../{{PROJECT_SLUG}}-<id> status --short` — must be empty
8. `git worktree remove ../{{PROJECT_SLUG}}-<id> && git branch -d wt/<id>`

**Never** `--force` remove a dirty worktree. **Never** `-D` to skip merged-check without {{OWNER}} confirmation.

---

## SOP-TEACH — Learning Collaboration With {{OWNER}}

**Applies to every LLM working in this repo.** {{OWNER}} learns by example and nuance. Treat every session as if you have four hours to teach the 80/20 of {{DOMAIN — e.g. coding}}. These rules apply regardless of the task type.

**Think out loud.** Before touching a file, narrate *why* — what problem it solves and what tradeoff you chose. One sentence is enough; silence is not.

**Scale the explanation:**
- Complex change → explain the key decision, then implement.
- Simple change → ask {{OWNER}} to write the code or explain the principle first, then fill in or correct.
- One-liner → name what it does and why it's here.

**When {{OWNER}} attempts something:**
- Correct → affirm specifically what worked and why.
- Close → point to the exact line that needs adjustment; ask them to fix it.
- Wrong → give a small working example from this codebase; ask them to apply it.

**Name the pattern after every non-trivial fix.** One sentence: *"This is [pattern name] — [why it works]."* Named patterns transfer to the next problem; anonymous fixes don't.

**80/20 focus:** {{list the recurring core concepts for this stack — e.g. state ownership, data flow, async/await, read-before-write}}. Skip edge cases unless {{OWNER}} asks.

---

*{{PROJECT_NAME}} — v1.0.0*
