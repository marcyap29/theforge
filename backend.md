# The Forge — Backend Reference

**Last Updated:** 2026-05-31

---

## Firebase Project

**Project ID:** `arc-epi` (shared with LUMARA and SwarmSpace — no separate Firebase project needed)

**Services used:**
- Firestore — project state, locked specs, handoffs, worksheets, audit trail
- Firebase Auth — user authentication (email/password + Google OAuth)
- Cloud Functions — spec generation (TypeScript, Node 20)

---

## Firestore Schema

### Collection: `forge-projects`

```
forge-projects/{projectId}
  name: string
  mode: "build" | "audit"
  currentPhase: string          — "v1_interview" | "v1_build" | "v2_interview" | ...
  specVersion: string           — "v1", "v2", etc.
  setupWorksheetComplete: bool
  createdAt: timestamp
  updatedAt: timestamp
  ownerId: string               — Firebase Auth uid
  workspaceId: string           — billing workspace (SwarmSpace)
  interviewMode: "build" | "audit"
```

### Subcollection: `specs`

```
forge-projects/{projectId}/specs/{specVersion}
  content: string               — full spec in Markdown
  handoffPackage: map           — JSON handoff (see schema below)
  lockedAt: timestamp
  interviewMode: "build" | "audit"
  goalStatement: string
  openFlagsCount: number
  outOfScopeCount: number
  v2SeedItems: string[]
```

**Invariant: specs are immutable.** No update operation is permitted on a spec document after creation.

### Subcollection: `handoffs`

```
forge-projects/{projectId}/handoffs/{id}
  phase: string                 — "interview_to_spec" | "spec_to_executor" | "agent_N_to_agent_N+1" | "v1_to_v2"
  content: string               — bullet handoff Markdown
  createdAt: timestamp
  specVersion: string
```

### Subcollection: `worksheets`

```
forge-projects/{projectId}/worksheets/{version}
  content: string               — setup worksheet Markdown
  complete: bool
  createdAt: timestamp
```

### Document: `audit/log`

```
forge-projects/{projectId}/audit/log
  entries: [                    — array, append-only, never modified
    {
      phase: string
      interviewMode: string
      date: timestamp
      runId: string
      creditCost: number
      durationMinutes: number
      decisions: [{ decision: string, chosen: string, confidence: string }]
      conflictsSurfaced: string[]
      scopeChanges: string[]
    }
  ]
```

**Invariant: audit/log is append-only.** Use `arrayUnion` for all writes. Never use `set` or `update` to replace the entries array.

---

## Handoff Package JSON Schema

### Build Mode

```json
{
  "interviewMode": "build",
  "specVersion": "string",
  "appName": "string",
  "platform": "string",
  "framework": "string",
  "lockedAt": "ISO date",
  "goalStatement": "string",
  "components": ["string"],
  "infrastructure": { "service": "implementation" },
  "stateManagement": "string",
  "navigation": "string",
  "openFlags": "number",
  "outOfScopeItems": "number",
  "setupWorksheetComplete": "bool",
  "v2SeedItems": ["string"]
}
```

### Audit Mode

```json
{
  "interviewMode": "audit",
  "specVersion": "string",
  "projectName": "string",
  "auditDate": "ISO date",
  "goalStatement": "string",
  "buildState": {
    "shipped": ["string"],
    "inProgress": ["string"],
    "notStarted": ["string"]
  },
  "activeBlockers": "number",
  "engineersAffectedByBlockers": ["string"],
  "decisionDebtItems": "number",
  "technicalDebtItems": "number",
  "documentationGaps": "number",
  "confidenceMap": {
    "projectGoal": "Established | Partial | Unknown",
    "buildState": "Established | Partial | Unknown",
    "featureOwnership": "Established | Partial | Unknown",
    "activeBlockers": "Established | Partial | Unknown",
    "blockerBlastRadius": "Established | Partial | Unknown",
    "decisionDebt": "Established | Partial | Unknown",
    "technicalDebt": "Established | Partial | Unknown",
    "aiTokenUsage": "Established | Partial | Unknown"
  },
  "docConflictsSurfaced": "number",
  "v2SeedItems": ["string"]
}
```

---

## Firebase Cloud Functions

### `generateSpec`

**Trigger:** HTTPS callable (called from Flutter via Firebase Functions SDK)

**Input:**
```json
{
  "projectId": "string",
  "interviewJson": { ... },     — complete serialized interview state
  "mode": "build" | "audit"
}
```

**What it does:**
1. Validates auth (only project owner can call)
2. Fires 3 parallel LLM calls via SwarmSpace API (t=0.2, 0.6, 1.0)
3. Waits for all three to complete
4. Returns all three variants — no partial reveals
5. Deducts credits via SwarmSpace billing

**Output:**
```json
{
  "variants": [
    { "label": "conservative", "temperature": 0.2, "content": "string" },
    { "label": "balanced",     "temperature": 0.6, "content": "string" },
    { "label": "experimental", "temperature": 1.0, "content": "string" }
  ],
  "creditCost": "number"
}
```

**Does NOT write to Firestore.** The Flutter app writes the selected spec after user selection.

---

## SwarmSpace API

The Forge calls SwarmSpace for:
- LLM routing (spec generation)
- Credit billing

**Base URL:** `https://swarmspace.app/api/` (production) — confirm current endpoint in SwarmSpace repo

**Auth:** SwarmSpace API token (stored in `.env`, never hardcoded)

**Credit costs (estimated):**
| Action | Credits |
|---|---|
| Full Forge run (interview through locked spec) | 20–35 |
| Single variant generation | 4–6 |
| Executor agent run (per agent) | 8–15 |

---

## Firestore Security Rules (to implement)

```javascript
// forge-projects: owner-only read/write
match /forge-projects/{projectId} {
  allow read, write: if request.auth != null
    && request.auth.uid == resource.data.ownerId;

  // specs: create only (no update/delete)
  match /specs/{specVersion} {
    allow create: if request.auth != null
      && request.auth.uid == get(/databases/$(database)/documents/forge-projects/$(projectId)).data.ownerId;
    allow read: if request.auth != null
      && request.auth.uid == get(/databases/$(database)/documents/forge-projects/$(projectId)).data.ownerId;
    allow update, delete: if false;    // immutable
  }

  // audit/log: read + append only (no replace)
  match /audit/log {
    allow read: if request.auth != null
      && request.auth.uid == get(/databases/$(database)/documents/forge-projects/$(projectId)).data.ownerId;
    allow update: if request.auth != null
      && request.auth.uid == get(/databases/$(database)/documents/forge-projects/$(projectId)).data.ownerId
      && request.resource.data.entries.size() > resource.data.entries.size(); // append only
    allow delete: if false;
  }
}
```

---

*Update this file when schema or function signatures change.*
