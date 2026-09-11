<!-- TEMPLATE — replace {{PLACEHOLDERS}} and delete this line. Part of the Docs Templates system. -->
# Security Checklist — {{PROJECT_NAME}}

Read this before any security audit or when touching auth, access-control rules, or billing.

---

## Pre-Commit Checklist

- [ ] No hardcoded secrets — API keys and tokens live in {{SECRET_STORE — e.g. env vars / secret manager / OS keychain}} (gitignored)
- [ ] Service/config credential files are gitignored ({{list any generated credential files for your platform}})
- [ ] Every server endpoint / privileged function checks authentication before proceeding
- [ ] Access-control rules enforce owner-only access on all user-owned data paths
- [ ] Immutable records have no `update`/`delete` path in the access rules
- [ ] Append-only records enforce append semantics (no overwrite, delete rule denies)
- [ ] No user PII in debug logs
- [ ] Server-only secrets are never sent to the client

---

## Access-Control Rules Review

Before deploying any access-rule change:
1. Confirm owner-only read/write on user-owned resources
2. Confirm immutable resources are create-only (deny update/delete)
3. Confirm append-only logs cannot be truncated or replaced
4. Run access-rule tests (emulator / integration) against the new rules

---

## Known Risk Areas

<!-- Replace the example rows with this project's real risk areas. Keep the table shape. -->

| Area | Risk | Mitigation |
|---|---|---|
| {{Server function taking client input}} | Caller passes arbitrary/unvalidated payload | Validate schema server-side before acting on it |
| {{Write to an immutable resource}} | Client could overwrite a record meant to be immutable | Rule: create-only on that path |
| {{Billing / metered operation}} | Double-billing on retry | Idempotency key on the operation |
| {{Auth}} | Unauthenticated access to protected data | All rules require an authenticated caller |
