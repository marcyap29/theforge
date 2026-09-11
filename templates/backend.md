<!-- TEMPLATE — replace {{PLACEHOLDERS}} and delete this line. Part of the Docs Templates system. -->
# {{PROJECT_NAME}} — Backend Reference

**Last Updated:** YYYY-MM-DD
**Version:** {{x.y.z}}

---

## Storage Model

{{One paragraph: where does data live? Is this local-first, cloud-first, or hybrid? What is the source of truth vs. cache/mirror? Example backends: {{BACKEND}} (e.g. Postgres, Firebase Firestore, S3, local filesystem).}}

**Primary storage:** {{where the source-of-truth data lives}}
**Local index / cache:** {{if any — what it is and whether it can be rebuilt}}
**Cloud sync:** {{if any — when and why it applies}}
**Server-side:** {{any server component, or "none"}}

---

## Data Schema

{{Describe the shape of the data. For a database, list the tables/collections and their key columns/fields. For a file-based store, show the directory/file layout. Keep it to the load-bearing fields.}}

```
{{Example: table/collection definitions, or a directory tree of stored files.}}
```

### Data Invariants

{{The rules that must always hold. Examples of the *kind* of thing to state:}}
- **{{Immutability rule}}** — {{e.g. records of type X are write-once; amendments create a new version.}}
- **{{Append-only rule}}** — {{e.g. the audit log is only ever appended, never truncated.}}
- **{{Atomicity rule}}** — {{e.g. writes go to a temp file then rename, so a crash can't leave a partial record.}}
- **{{Freshness rule}}** — {{e.g. which record is always kept current, and when.}}

### Key Record Formats

{{For each important record/document type, show its format or JSON schema. Replace with your real types.}}

```json
{
  "{{field}}": "{{type — string | number | bool | ISO date | array}}"
}
```

---

## Services / APIs Used

{{List every external or internal service the backend talks to. For each one, fill the block below. If you route through a provider abstraction/interface, describe the interface first, then each implementation.}}

### {{Service / Provider 1}}

- **API:** {{endpoint or base URL}}
- **Auth:** {{how this service is authenticated — see Auth Model / Secrets}}
- **Config:** {{models, versions, regions, or other tunables}}
- **Billing:** {{who pays and how, or "none" / "free"}}
- **Notes:** {{rate limits, requirements, gotchas}}

### {{Service / Provider 2}}

- **API:** {{endpoint or base URL}}
- **Auth:** {{...}}
- **Config:** {{...}}
- **Billing:** {{...}}
- **Notes:** {{...}}

---

## Endpoints

{{If this project exposes its own endpoints (HTTP routes, functions, RPC methods), list them here. Otherwise state "Consumer only — exposes no endpoints."}}

| Method | Path / Name | Purpose | Auth required |
|---|---|---|---|
| {{GET/POST/...}} | {{/path or fn name}} | {{what it does}} | {{yes/no}} |

---

## Auth Model

{{Describe how identity and access work end to end.}}
- **Who authenticates:** {{end user / service account / none}}
- **Mechanism:** {{e.g. API key, OAuth, session token, signed request}}
- **Where credentials are validated:** {{client / server / third party}}
- **Authorization:** {{roles, tiers, or scopes and what each can do}}

---

## Environment Variables & Secrets

{{List the configuration the backend needs and where each value lives. State the golden rule up front: secrets never go in source, logs, or committed files.}}

All secrets are stored in {{SECRET_STORE}} (e.g. OS keychain, a secrets manager, gitignored `.env`). Never write secrets to disk, source control, or log output.

| Key | Type | Stored in | Description |
|---|---|---|---|
| `{{ENV_VAR_NAME}}` | {{String/...}} | {{SECRET_STORE}} / env / config | {{what it configures}} |

{{List non-secret local preferences separately if they exist (e.g. UI settings), and be explicit that secrets are NOT stored alongside them.}}

---

## Deployment

{{How does the backend get built, released, and run?}}
- **Build:** {{build/packaging steps or commands}}
- **Environments:** {{dev / staging / prod and how they differ}}
- **Deploy process:** {{how a change reaches production}}
- **Runtime / hosting:** {{where it runs — e.g. serverless functions, container, edge, user's machine}}
- **Rollback:** {{how to revert a bad deploy}}

---

*Version {{x.y.z}} — {{one-line summary of what changed in this revision}}.*
