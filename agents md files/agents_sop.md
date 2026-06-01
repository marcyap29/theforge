# SOP — Standard Operating Procedures — The Forge

Universal prompts for planning, error diagnosis, and task structure.

**Linter:** `dart analyze lib/`

---

## SOP-PLAN — Task Planning Protocol

Use this before starting any non-trivial implementation task.

### Steps

1. **Read before writing** — read every file you plan to modify before touching it
2. **State the definition of done** — one sentence: what does "complete" look like?
3. **List files to modify** — exact paths; if unsure, grep for the class/method first
4. **Break into sub-tasks** — ordered list; mark dependencies explicitly
5. **Identify risks** — check `bugtracker/BUG_PREVENTION.md` before coding; skim `bugtracker/bug_tracker.md`
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
3. **Narrow the blast radius** — which layer? (UI / interview state / Firestore / spec gen / auth)
4. **Form one hypothesis at a time** — test it; do not stack multiple changes
5. **Check the bugtracker** — grep `bugtracker/bug_tracker.md` and `bugtracker/records/`
6. **Document the fix** — add a record to `bugtracker/records/`

**Escalation:** If 2 hypotheses are ruled out and cause is unknown — stop. Document in `planner.md` under `## Pending Review`. Do not loop silently.

---

## SOP-REVIEW — Pre-Commit Checklist

- [ ] `dart analyze lib/` — zero new errors in modified files
- [ ] No changes outside the files listed in the plan
- [ ] No debug logging left in production paths
- [ ] `bugtracker/BUG_PREVENTION.md` consulted — no known anti-patterns reintroduced
- [ ] `tracking md files/context.md` updated with session block
- [ ] `tracking md files/planner.md` tasks crossed off
- [ ] Commit message follows `<type>: <short description>` convention

---

## SOP-AGENT — Multi-Agent Task Structure

1. **Overseer defines work** — writes a spec doc with definition of done, exact file paths, constraints
2. **Overseer assigns** — each sub-agent gets a single spec; no agent works on the same file as another
3. **Sub-agent works** — reads spec, reads actual files, implements, runs linter, commits to branch
4. **Sub-agent reports** — pushes branch; does NOT merge
5. **Overseer reviews** — reads diff, checks linter, confirms definition of done met
6. **Overseer merges or requests changes** — one round max before escalating to user

---

## SOP-SECURITY — Security Audit

| Step | Action |
|------|--------|
| 1 | Read `agents md files/SECURITY_CHECKLIST.md` |
| 2 | Secrets scan — check all changed files for hardcoded keys/tokens |
| 3 | Auth/authz — every new Firestore path or Function must check auth |
| 4 | Input validation — all user inputs validated; no injection vectors |
| 5 | Document findings with date and commit ref |

---

## SOP-WORKTREE — Branch Isolation Protocol

**Use a worktree when:** multi-session work, risky/shared paths (Firestore schema, spec gen function), external agent doing the work, experimental change.

**Stay on main for:** single-file fixes, doc-only, < 30 minutes, trivially reversible.

**Lifecycle:**
1. Plan (SOP-PLAN)
2. `git worktree add ../the-forge-<id> -b wt/<id>`
3. Implement; commit to `wt/<id>` only
4. User review: `git -C ../the-forge-<id> diff main..HEAD`
5. User approval (explicit)
6. `git checkout main && git merge --no-ff wt/<id> && git push origin main`
7. Verify clean: `git -C ../the-forge-<id> status --short` — must be empty
8. `git worktree remove ../the-forge-<id> && git branch -d wt/<id>`

**Never** `--force` remove a dirty worktree. **Never** `-D` to skip merged-check without user confirmation.

---

*The Forge — v1.0.0*
