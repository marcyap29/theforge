# Security Checklist — The Forge

Read this before any security audit (STEP 3E) or when touching auth, Firestore rules, or billing.

---

## Pre-Commit Checklist

- [ ] No hardcoded secrets — Firebase config, API keys, SwarmSpace tokens are in `.env` (gitignored)
- [ ] `google-services.json` and `GoogleService-Info.plist` are gitignored
- [ ] Every Firebase Function checks `context.auth` before proceeding
- [ ] Firestore rules enforce owner-only access on all `forge-projects` paths
- [ ] Spec documents have no `update` or `delete` path in Firestore rules (immutable)
- [ ] Audit log enforces append-only (`arrayUnion` only; delete rule is `false`)
- [ ] No user PII in debug logs
- [ ] SwarmSpace API token is server-side only — never sent to Flutter client

---

## Firestore Rules Review

Before deploying any Firestore rule change:
1. Confirm owner-only read/write on `forge-projects/{projectId}`
2. Confirm specs are create-only (`allow update, delete: if false`)
3. Confirm audit/log is append-only (size check on entries array)
4. Run Firestore emulator tests against the new rules

---

## Known Risk Areas

| Area | Risk | Mitigation |
|---|---|---|
| Spec generation function | Caller passes arbitrary `interviewJson` | Validate schema server-side before LLM call |
| Firestore spec write | Client could attempt to overwrite a spec | Rule: create-only on specs subcollection |
| Credit billing | Double-billing on retry | Idempotency key on `generateSpec` function |
| Auth | Unauthenticated Firestore access | All rules require `request.auth != null` |
