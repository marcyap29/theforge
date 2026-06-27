> **STATUS: COMPLETE ✅** — §6 Spec Generation + §7 Artifact Viewers implemented 2026-06-04. See `tracking md files/planner.md §6` and `§7` for implementation notes. This document is an archived executor handoff retained for format reference.

# The Forge — Bullet Handoff v1 · Platform Merge + §6 Spec Generation
**Prepared for:** External agent (DeepSeek Flash / any capable coding model)
**Date:** 2026-06-03
**Phase:** Plan Mode critical path — §6 Spec Generation + Artifact Writing
**Written by:** Claude Sonnet 4.6 (planning session)
**Primary repo:** `/Volumes/Marc Working Drive/Development/The Forge`
**GitHub remote:** `https://github.com/marcyap29/theforge.git`

---

## Context — What This Platform Is Now

**The Forge** is a three-mode platform for engineering managers running agentic teams:

- **Plan Mode** (what you are building now): Structured interview → locked spec → /goal artifact → executor handoff. The Forge defines what gets built.
- **Watch Mode** (future — gated on Plan Mode completion): Token spend + git activity + CI correlation. The Forge monitors whether it is being built correctly.
- **Reverse Mode** (future): Reads an existing codebase and generates a locked spec for it. The Forge reverse-engineers the spec from code that already exists.

The three modes share one artifact format: the locked spec. It is the universal language connecting everything.

**You are not building Watch Mode or Reverse Mode.** Your job is Plan Mode §6 and §7. Watch Mode begins only after a complete end-to-end Plan Mode run exists.

---

## Repo State When You Receive This

**Local path:** `/Volumes/Marc Working Drive/Development/The Forge`
**Branch:** `main` (working directly on main — this is standard for The Forge)
**Tech stack:** Flutter 3.38.7 · Dart 3.10.7 · Riverpod · drift SQLite · flutter_secure_storage · package:http · SharedPreferences

**What is complete (§1–§5, §10):**

| Section | Status | Key files |
|---|---|---|
| §1 Flutter Bootstrap + Local Data Layer | ✅ | `lib/data/local_db/forge_database.dart`, `lib/data/filesystem/project_file_repository.dart` |
| §2 Riverpod Project State Layer | ✅ | `lib/features/projects/providers/` |
| §3 Project Folder Browser | ✅ | `lib/features/projects/screens/projects_list_screen.dart`, `lib/core/app.dart`, `lib/core/theme/app_theme.dart` |
| §4 LLM Provider Layer | ✅ | `lib/services/llm/` (8 files — provider abstract, model config, service, 4 impls) |
| §5 Interview UI + State | ✅ | `lib/features/interview/` (6 files — state, notifier, providers, meter, screen, dimensions) |
| §5 Ext — Dual Mode (Build + Audit) | ✅ | `new_project_screen.dart`, `project_detail_screen.dart` extended |
| §10 Settings + BYOK Key Storage | ✅ | `lib/features/settings/` (3 files) |

**Do not modify any of the above.** `dart analyze lib/` must return zero issues after your changes.

---

## What You Are Building — §6 Spec Generation

### Definition of Done
Complete when: the "Generate Spec" button in `interview_screen.dart` triggers a real LLM call that writes a locked spec in standard v1.1 format to `{projectPath}/specs/{ProjectName}_LockedSpec_v1.md` via `ProjectFileRepository.writeLockedSpec()`, updates README.md, appends to the audit log, and `dart analyze lib/` returns zero issues.

### §6 Tasks — Execute in Order

**Task 1: Read before touching**

Read these files before writing any code:
- `lib/features/interview/state/interview_state.dart` — the `InterviewState` shape you'll consume
- `lib/features/interview/ui/interview_screen.dart` — the Generate Spec button (currently shows a SnackBar)
- `lib/data/filesystem/project_file_repository.dart` — `writeLockedSpec()` method (check its signature — it takes a path and content string)
- `DOCS/forge/workflow_template.md` — this is the ground truth for what the spec format looks like

**Task 2: Create `lib/features/spec_generation/` directory structure**

```
lib/features/spec_generation/
  spec_generation_service.dart   ← main service: takes InterviewState, calls LLM, returns spec string
  spec_prompt_builder.dart       ← builds the system prompt and user prompt from interview transcript
  spec_parser.dart               ← validates/cleans the spec string before writing (basic checks only)
```

**Task 3: `spec_prompt_builder.dart`**

Build the system prompt and user prompt for spec generation from the completed `InterviewState`.

```dart
class SpecPromptBuilder {
  static String buildSystemPrompt() {
    // The Forge spec generator system prompt.
    // Instructs the LLM to produce a locked spec in v1.1 format.
    // Reference: DOCS/forge/workflow_template.md Stage 2 — Spec Generation
    // The spec must include all 11 sections in order:
    // 1. Immutable Goal Statement
    // 2. Hard Constraints Table
    // 3. Component Map (single responsibility per component)
    // 4. Interface Contracts
    // 5. Completion Criteria (verifiable without human input)
    // 6. Static Content Specs (if applicable — omit section if not applicable)
    // 7. Explicit Out-of-Scope List
    // 8. Accepted Decisions (RFC format: chosen / alternatives / drawbacks / confidence)
    // 9. Open Flags (Flag / Component / Options / Recommended default)
    // 10. v2 Architecture Notes
    // 11. Handoff Package (JSON)
  }

  static String buildUserPrompt(InterviewState state) {
    // Format the full interview transcript into a user prompt.
    // Include: all turns (role + content), the final confidence map (dimension → resolved/partial),
    // any conflicts that were surfaced and how they were resolved.
    // End with: "Generate the locked spec for this project."
  }
}
```

**Task 4: `spec_generation_service.dart`**

```dart
class SpecGenerationService {
  final LlmService _llmService;

  SpecGenerationService(this._llmService);

  Future<String> generateSpec(InterviewState state) async {
    final systemPrompt = SpecPromptBuilder.buildSystemPrompt();
    final userPrompt = SpecPromptBuilder.buildUserPrompt(state);
    
    // Single call at t=0.6 for v1 (Monte Carlo at three temperatures is §14 — future)
    final rawSpec = await _llmService.complete(
      role: LlmRole.architect,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
    
    return SpecParser.clean(rawSpec);
  }
}
```

Note: `LlmService.complete()` signature — check `lib/services/llm/llm_service.dart` for the exact method signature before calling it. It may take `role:` as a named parameter.

**Task 5: `spec_parser.dart`**

Minimal validation only. The LLM output is a markdown string. Do not over-parse.

```dart
class SpecParser {
  static String clean(String raw) {
    // Strip any leading/trailing code fences if the LLM wrapped the spec in ```markdown
    // Trim whitespace
    // Return the cleaned string
    // Do NOT validate section content — the LLM is trusted to follow the system prompt
  }
}
```

**Task 6: Wire `SpecGenerationService` into Riverpod**

Create `lib/features/spec_generation/spec_generation_providers.dart`:

```dart
final specGenerationServiceProvider = Provider<SpecGenerationService>((ref) {
  final llmService = ref.watch(llmServiceProvider);
  return SpecGenerationService(llmService);
});
```

Check how `llmServiceProvider` is exposed in `lib/services/llm/llm_service_provider.dart` before writing this.

**Task 7: Update `interview_screen.dart` — wire the Generate Spec button**

The Generate Spec button is already rendered in `interview_screen.dart`. It currently shows a SnackBar. Replace the SnackBar handler with:

1. Show a loading state (disable button, show spinner)
2. Call `specGenerationService.generateSpec(state)`
3. Call `ProjectFileRepository.writeLockedSpec(projectPath, specContent)` — check the exact method signature
4. Update README.md via `ProjectFileRepository` to reflect new phase + spec version
5. Append to the audit log via `ProjectFileRepository.appendAuditLog(projectPath, entry)`
6. On success: navigate to `SpecViewerScreen` (stub it if §7 isn't built yet — just show a SnackBar "Spec generated: {path}" as a placeholder until §7)
7. On error: surface the error message in the chat bubble (same pattern as the existing LLM error handling)

**Task 8: `dart analyze lib/` — zero issues**

Run it. Fix every warning or error your changes introduced. Do not skip.

---

## §7 — Artifact Viewers (build only if §6 is clean)

Viewer screens are read-only markdown displays. Build them only after §6 is passing `dart analyze`.

```
lib/features/artifacts/
  spec_viewer_screen.dart        ← reads specs/{ProjectName}_LockedSpec_v{N}.md
  handoff_viewer_screen.dart     ← reads handoffs/{ProjectName}_BulletHandoff_*.md
  worksheet_viewer_screen.dart   ← reads worksheets/{ProjectName}_SetupWorksheet_v{N}.md
  audit_log_viewer_screen.dart   ← reads audit/{ProjectName}_AuditLog.md
```

Each viewer:
- Takes `projectPath` as constructor parameter
- Reads the file via `ProjectFileRepository` (do not read directly from disk — go through the existing repo layer)
- Renders as scrollable markdown using `flutter_markdown` (add to `pubspec.yaml` if not present — check first)
- Has a "Close" button that pops the route

Wire them from `project_detail_screen.dart` (the artifacts list already shows filenames — make them tappable).

Add routes to `lib/core/app.dart`:
```
'/spec-viewer'
'/handoff-viewer'
'/worksheet-viewer'
'/audit-viewer'
```

`dart analyze lib/` — zero issues before reporting done.

---

## Locked Spec Format Reference (v1.1)

Every spec The Forge generates must follow this structure exactly. Use `workflow_template.md` as the ground truth. Here is the summary:

1. **Immutable Goal Statement** — problem + solution, one paragraph, no bullet points
2. **Hard Constraints Table** — 2 columns: Constraint | Value | Reason
3. **Component Map** — each component: name, single responsibility, owns, does not own
4. **Interface Contracts** — input/output per component boundary (typed)
5. **Completion Criteria** — table: Criterion | Component | How to verify (verifiable by agent without human input)
6. **Static Content Specs** — only if applicable (omit section entirely if none)
7. **Explicit Out-of-Scope List** — table: Item | Note
8. **Accepted Decisions** — table: Decision | Chosen | Alternatives Considered | Drawbacks Accepted | Confidence
9. **Open Flags** — table: Flag | Component | Options | Recommended default
10. **v2 Architecture Notes** — bullet list of deferred items worth preserving
11. **Handoff Package** — JSON block: `specVersion`, `appName`, `platform`, `framework`, `lockedAt`, `goalStatement`, `components[]`, `infrastructure{}`, `openFlags`, `outOfScopeItems`, `v2SeedItems[]`

---

## Key Invariants — Do Not Violate

- **`dart analyze lib/` must return zero issues.** Do not report done if there are warnings.
- **No Firebase.** `grep -ri firebase lib/` must return zero matches.
- **No API keys in source code.** All secrets via `flutter_secure_storage`.
- **Read before editing.** Read every file before modifying it.
- **`writeLockedSpec()` is write-once at the repo layer.** Do not try to overwrite an existing spec — check the `ProjectFileRepository` implementation before calling it. Amendment logic (versioning) is a future phase.
- **Single LLM call for §6.** No parallelism. Monte Carlo (3 temperatures) is §14.
- **Do not touch §1–§5 code.** Every line you change must trace to §6 or §7 requirements.

---

## Session Close Checklist (mandatory before reporting done)

When §6 and §7 are complete:

- [ ] `dart analyze lib/` → No issues found
- [ ] `grep -ri firebase lib/` → zero matches
- [ ] Generate Spec button triggers real LLM call (not a stub)
- [ ] Spec written to `{projectPath}/specs/{ProjectName}_LockedSpec_v1.md`
- [ ] README.md updated: phase → "v1_spec_generated", spec version → "v1"
- [ ] Audit log appended with spec generation entry
- [ ] All four artifact viewers navigate and render without crashing
- [ ] Append a session block to `tracking md files/context.md` (newest first)
- [ ] Cross off §6 and §7 in `tracking md files/planner.md`
- [ ] Append §6 and §7 completion entries to `tracking md files/backlog.md` "Completed" section
- [ ] Commit with message: `feat(§6): spec generation + artifact writing — Plan Mode Stage 2 complete`
- [ ] Append to `audit/The_Forge_AuditLog.md`: brief entry confirming §6+§7 complete, any decisions made

---

## What NOT to Build

- Watch Mode — not yet. Gated on first end-to-end Plan Mode run.
- Reverse Mode — not yet.
- Monte Carlo (3-temperature parallel calls) — that is §14 (Low Priority).
- SwarmSpace billing — §13.
- Setup Worksheet generation — §8 (do §6+§7 first).
- Amendment / versioning logic for locked specs — future.
- Do not add features beyond what §6 and §7 require.

---

_The Forge · Orbital AI · June 2026_
_This handoff is self-contained. Primary reference for format questions: `DOCS/forge/workflow_template.md`._
