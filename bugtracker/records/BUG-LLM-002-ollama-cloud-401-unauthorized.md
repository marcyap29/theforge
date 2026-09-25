# BUG-LLM-002 — Ollama Cloud 401 "Unauthorized" on builds (bad/expired API key — NOT a Forge defect)

**ID:** BUG-LLM-002
**Area:** LLM
**Severity:** Low (operational, not a code defect) — but high time-cost to diagnose
**Status:** Resolved 2026-09-25 (user regenerated the key) — Forge-side UX improvements backlogged

---

## Symptom

Every Build-with-AI run on AR Mechanic failed at planning with:

```
Planning failed: Exception: Ollama error 401: {"error":"Unauthorized"}
```

(Occasionally a transient `ClientException: Connection reset by peer, uri=https://ollama.com/api/chat` on retry.) Model was `ollama · kimi-k2.6`. Re-entering the key — even a freshly generated one — did not fix it at first.

## Root Cause

**The API key itself, not The Forge.** The stored Ollama Cloud key was invalid (a formatting/validity problem in the copied value; the first regenerated key was also bad). The Forge was reading and sending the key correctly the whole time; `ollama.com` rejected it. Regenerating the key **again** (a clean one) resolved it immediately.

The investigation was long only because of two traps that produced misleading evidence:

1. **`https://ollama.com/api/tags` is PUBLIC** — it returns `HTTP 200` even with an empty/absent `Authorization` header. An early "does the key work?" test against `/api/tags` returned 200 and falsely suggested the key was valid. The endpoint that actually authenticates (and that Build-with-AI calls) is **`/api/chat`**.
2. **zsh vs bash in the test command** — `read -s -p "…" K` is a *bash*-ism; Marc's shell is **zsh**, where it fails with `read: -p: no coprocess` and leaves `K` empty. So the "test with your key" curl silently ran with **no key**, and `/api/chat` returned 401 (correct for an empty key) — looking like the key was rejected when it was never sent. zsh form: `read -rs "K?prompt"`.

Contributing red herring earlier in the session: the **keychain-vs-code-signature gotcha** (below), which *can* cause a real 401 but was not the cause this time.

## What was ruled out (evidence)

- **Not this session's changes.** `git log` on `lib/features/settings/settings_notifier.dart` + `lib/services/llm/` showed the auth path last changed in v0.4.48/v0.4.53 — before the base-view/guard work. Nothing recent touches it.
- **Key was stored correctly.** The login-keychain item `forge_api_key_ollama` (service `flutter_secure_storage_service`) had a fresh `mdat` right after Save, and `setApiKey` trims whitespace — so the app persisted the pasted key. Write success implies read access (same ACL) → the app was sending the key.
- **Auth wiring is correct.** `OllamaProvider` sends `Authorization: Bearer <key>` to `<baseUrl>/api/chat`; `LlmService` passes `settings.apiKeys[LlmProviderType.ollama]`. Faithful.

## Resolution

User generated a **new** key at ollama.com and pasted it into Settings → builds work. No code change.

## Forge-side improvements (backlogged, not built)

The raw `Ollama error 401: {"error":"Unauthorized"}` gave the user nothing to act on. Backlogged (`§LLMKEY`): a **clear message** ("Ollama rejected your key (401) — regenerate it or check your Cloud plan at ollama.com") and a **"Test key" button** in Settings that runs the exact `/api/chat` auth check, so this self-diagnoses in one click instead of a multi-round debugging session.

## Prevention Rule

See `BUG_PREVENTION.md` — "An Ollama Cloud 401 in The Forge is almost always the key, not the app: regenerate it. Never validate an Ollama key against `/api/tags` (public, 200 with no auth) — use `/api/chat`. And keys saved by an ad-hoc-signed local build aren't readable by the Developer ID–signed release (and vice-versa)."

## Related

- Keychain storage: BUG record for the Keychain migration (v0.4.48).
- Keychain-vs-signature gotcha: deploy local builds with `FORGE_SIGN_IDENTITY="Developer ID Application: Orbital AI, LLC (87W73WQSPF)"` so ad-hoc and release builds share one keychain entry.

## Commit

Docs-only (no code change). 2026-09-25.
