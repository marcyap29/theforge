# The Forge — Changelog

---

## v0.3.0 — 2026-09-10

- Portfolio Tracker — new home dashboard plus per-project feature board with status tracking (idea/planned/in_progress/blocked/shipped/archived)
- Auto-scan + virtual-PM check-ins — `FeatureScanner` proposes features from `.forge` docs and/or a linked repo; `CheckinService` diffs git since last review into status changes, new features, and flags
- Import → Spec + existing-repo onboarding — paste a description/doc/transcript or analyze a repo (Quick docs+structure / Deep code-reading), with a compressed CONFIRM/gap form, into the existing spec pipeline
- Doc-based feature scan — features distilled directly from a project's own `.forge` documents
- `.forge` deliverable layout — all generated artifacts moved under a hidden `.forge/` folder with a fixed canonical projects root; "Export docs…" copies deliverables to `<chosen>/forge-docs/`
- Project deletion (safe) — double-confirm, index+folder cascade, guarded to the canonical root
- Provider layer — Ollama Cloud (`gpt-oss:120b-cloud`) is the default; Gemini removed entirely
- Dictation input via the `theforge://paste` URL scheme
- Cross-platform app icon
- Deploy scripts (`tool/deploy_{macos,ios,android}.sh`) + macOS unsandboxed, direct Developer ID distribution
- Fixed BUG-SETTINGS-002, BUG-UI-003, BUG-DATA-001

## v0.2.0 — 2026-06-01

- Backlog rewritten from 11 items to 16 items, grounded in Obsidian product docs (Workflow Template v3.0, Positioning Brief v4.0, ForkIt worked examples)
- Stale Firestore/Firebase Function references removed from §2–§9
- Critical path corrected: project folder browser now precedes interview
- New backlog items: §2 Riverpod state layer, §4 LLM provider layer, §9 Handoff Package, §10 Settings + BYOK, §14 Monte Carlo spec generation
- DeepSeek v4 Pro registered in agent registry as Rank 1 Executor (4.6/5)
- §1 Flutter Bootstrap + Local Data Layer — complete ✅

## v0.1.0 — 2026-05-31

- Initial repo bootstrap from Starter Repo
- Architecture defined, backlog seeded, docs scaffolded
- No Flutter code yet — docs and config only
