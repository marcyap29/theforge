# Executor Plan — §VF1/§VC1/§QOL Documentation Closeout
## Versioned Folder Structure + Verification Checklist + QOL Session

**Agent:** Qwen3 Code  
**Task type:** Documentation only — no Dart files to write  
**Date assigned:** 2026-06-27  
**Difficulty:** Low — two markdown files, exact formats provided  

---

## What Was Built (Session Summary)

A Claude Code session produced the following uncommitted changes. Your job is to document them — write a `context.md` session block and `planner.md` entries. Do NOT touch any `.dart` files.

### Feature 1 — §VF1: Versioned Folder Structure (`project_file_repository.dart` +274 lines)

All artifact writes now go into version subfolders instead of flat directories:
- **Before:** `specs/ProjectName_LockedSpec_v1.md`
- **After:** `specs/v1/ProjectName_LockedSpec_v1.md`
- Same change applies to `handoffs/`, `forge/`, `worksheets/`

New methods added to `ProjectFileRepository`:
- `getSavedRootPath()` [STATIC] — reads root path from SharedPreferences
- `saveRootPath(String path)` [STATIC] — persists root path to SharedPreferences
- `_defaultRootDir()` — now checks saved root path first, falls back to `~/Documents/The Forge Projects/`
- `_extractVersion(String filename)` [STATIC] — regex extracts `v1`, `v2`, etc. from filename
- `hasFlatVersionedFiles(String projectPath)` — detects old flat-structure files needing migration
- `migrateToVersionFolders(String projectPath)` — moves flat versioned files into version subfolders; returns count of files moved

Backward compatibility: all reads check versioned path first, fall back to flat for existing projects. `writeHandoffPackage` now writes to `handoffs/v1/`.

### Feature 2 — §VC1: Verification Checklist (`spec_generator.dart`, `spec_notifier.dart`)

After spec generation, a second LLM call generates a machine-readable verification checklist and stores it in the handoff package JSON under `verificationChecklist`.

New functions in `spec_generator.dart`:
- `buildVerificationChecklistPrompt(String specContent, String projectName)` — builds the LLM prompt
- `parseVerificationChecklist(String llmOutput)` — parses JSON output, returns `List<Map<String, dynamic>>`

Changes in `spec_notifier.dart`:
- `maxTokens` raised from 4096 → 8192
- Truncation guard added: if the spec doesn't contain `## 9.` and `## 10.`, throws an error ("Spec generation was truncated — sections 9/10 are missing")
- After `writeLockedSpec()`, calls checklist generation; failure is non-fatal (spec is already locked)
- `buildSpecPrompt()` now accepts `specVersion` param so the spec title includes the version number

### Feature 3 — §CI1: Compliance-Informed Feature Interview (`interview_providers.dart`, `interview_notifier.dart`)

Feature interview (V2+) can now receive a `complianceContext` block — the verification checklist results from V1 showing which items passed/failed. Items marked ❌ or ⚠️ are surfaced to the user during scoping.

Changes:
- `InterviewArgs` gains `complianceContext: String?` field
- `_featureInterviewSystemPrompt()` injects the compliance block when present
- `InterviewArgs` `==` and `hashCode` updated to include `complianceContext`

### Feature 4 — QOL improvements

**New project screen — first-time root path picker** (`new_project_screen.dart`):
- On first project creation, prompts user to choose where to store Forge Projects via `FilePicker.platform.getDirectoryPath()`
- Saves the chosen path via `ProjectFileRepository.saveRootPath()`
- Falls back to default and saves it if the user dismisses

**Escape hatch fallback** (`interview_notifier.dart`):
- Original trigger: L3/L4 after ≥6 user turns
- New fallback: ANY layer after ≥10 user turns (catches cases where LLM wraps up interview at L1/L2 without emitting forge-state JSON blocks, leaving the app stuck)

**`project_detail_screen.dart` — major rewrite** (+1135 lines):
- `_buildVersionPanel()` / `_buildVersionEntry()` — multi-version accordion display; latest version expanded, prior versions collapsed to "V1 ✓" pills
- `_buildTimelineRow()` — redesigned phase timeline
- `_RepoPathRow` widget — displays linked repo path, "Show in Finder" button
- `_CopyWorksheetButton` — copies worksheet content to clipboard
- `_FixStructureBanner` widget — detects flat versioned files via `hasFlatVersionedFiles()`, shows amber banner with "Fix Structure" button that calls `migrateToVersionFolders()`; disappears after migration
- `_BacklogSection` widget — reads V2 seeds from ingested files, shows as expandable list
- `_scan()` — scans versioned folder structure (`specs/v1/`, `handoffs/v1/`, etc.) and returns hierarchy `Map<String folder, Map<String version, List<String> filenames>>`

**`executor_timeline_notifier.dart`**:
- Updated to scan versioned handoffs subfolders for `*_BuildSequence_*` files (was flat-only)

**`llm_model_config.dart`**:
- Gemini default changed to `gemini-3.5-flash` (reverted from `gemini-2.5-flash`)

**`settings_notifier.dart`**:
- Ollama health check `maxTokens` bumped from 10 → 100 (too small to get a valid response)

---

## Your Tasks

### Task 1 — Write a session block in `tracking md files/context.md`

**IMPORTANT:** Prepend the block — insert it AFTER line 5 (`---`) and BEFORE the existing first session block. Do NOT delete or modify any existing content.

Use this exact structure (copy the structure, fill in the content):

```
## Session: 2026-06-27 — Claude Code [§VF1/§VC1/§CI1/§QOL — Versioned FS + Verification Checklist + QOL]

**Branch:** main

### Done

**§VF1 — Versioned Folder Structure (all committed):**
[bullet list of what was done — one bullet per sub-feature]

**§VC1 — Verification Checklist (all committed):**
[bullet list]

**§CI1 — Compliance-Informed Feature Interview (all committed):**
[bullet list]

**QOL improvements (all committed):**
[bullet list]

**Commits this session:**
- [list any commits — if unknown, write "uncommitted — pending commit"]

### Key Technical Findings
[3–5 findings. Each is one sentence naming the pattern + the reason it matters. Use the same voice as existing entries — factual, past-tense, developer tone. See existing blocks for examples.]

### Next
- §W5 — Watch Mode: SwarmSpace Briefing + Decision Simulation (next on critical path; requires §W4 ✅)

### Modified (key files)
- `lib/data/filesystem/project_file_repository.dart` — versioned folder writes + root path persistence + migration helpers
- `lib/features/projects/screens/project_detail_screen.dart` — multi-version panel, _FixStructureBanner, _BacklogSection, _RepoPathRow, _CopyWorksheetButton
- `lib/features/spec_generation/spec_generator.dart` — buildVerificationChecklistPrompt, parseVerificationChecklist, specVersion param
- `lib/features/spec_generation/spec_notifier.dart` — maxTokens 8192, truncation guard, checklist generation
- `lib/features/interview/providers/interview_providers.dart` — complianceContext on InterviewArgs
- `lib/features/interview/state/interview_notifier.dart` — compliance block injection, escape hatch fallback
- `lib/features/projects/screens/new_project_screen.dart` — first-time root path picker
- `lib/services/llm/llm_model_config.dart` — Gemini default gemini-3.5-flash
- `lib/features/settings/settings_notifier.dart` — Ollama maxTokens 10 → 100
- `lib/features/spec_generation/executor_timeline_notifier.dart` — versioned handoffs scan
```

**Reference — look at existing session blocks for exact tone and formatting.** Read lines 6–80 of `tracking md files/context.md` to see the established pattern.

---

### Task 2 — Add entries to `tracking md files/planner.md`

Add the following three new sections before the `## Next Up — §W5` block at the bottom of the file. Each section follows the existing `## §ID — Name` pattern.

**Section to add:**

```
## §VF1 — Versioned Folder Structure — COMPLETE ✅

**Completed:** 2026-06-27

- [x] `lib/data/filesystem/project_file_repository.dart` — versioned subfolder writes (specs/v1/, handoffs/v1/, forge/v1/, worksheets/v1/); backward-compatible reads (versioned path first, flat fallback); `_extractVersion()` regex helper; `hasFlatVersionedFiles()` + `migrateToVersionFolders()` migration helpers; `getSavedRootPath()` + `saveRootPath()` configurable root path via SharedPreferences
- [x] `lib/features/projects/screens/project_detail_screen.dart` — `_FixStructureBanner` widget (detects flat files, runs migration on tap); versioned artifact browser (`_scan()` returns folder → version → filename hierarchy); multi-version accordion panel (`_buildVersionPanel` / `_buildVersionEntry`); `_BacklogSection` widget (V2 seeds); `_RepoPathRow` (repo path + Finder button); `_CopyWorksheetButton`
- [x] `lib/features/projects/screens/new_project_screen.dart` — first-time root path picker via `FilePicker.platform.getDirectoryPath()`; saves chosen path; falls back to default if dismissed
- [x] `lib/features/spec_generation/executor_timeline_notifier.dart` — scans versioned handoffs subfolders for build sequence files
- [x] `dart analyze lib/` — zero issues

### Notes
- Backward compatibility is the critical invariant: reads always check versioned path first, then fall back to flat. Existing projects open without migration required.
- `_FixStructureBanner` detects and offers one-click migration — appears only when flat versioned files exist; auto-hides after migration.
- Root path is stored under SharedPreferences key `forge_root_path`; `_defaultRootDir()` reads it on every launch.

---

## §VC1 — Verification Checklist — COMPLETE ✅

**Completed:** 2026-06-27

- [x] `lib/features/spec_generation/spec_generator.dart` — `buildVerificationChecklistPrompt(specContent, projectName)` generates LLM prompt; `parseVerificationChecklist(llmOutput)` parses JSON output to `List<Map<String, dynamic>>`; `buildSpecPrompt()` gains `specVersion` param so spec title includes version number; `externalServices` safe-null parse fix
- [x] `lib/features/spec_generation/spec_notifier.dart` — `maxTokens` raised 4096 → 8192; truncation guard (throws if §9 or §10 absent); post-lock checklist generation call (non-fatal on failure); checklist stored in handoff package under `verificationChecklist`
- [x] `dart analyze lib/` — zero issues

### Notes
- Checklist generation is a second LLM call after `writeLockedSpec()`. Its failure is explicitly non-fatal — the spec is already immutably locked at that point.
- Truncation guard fires when the model hits its context ceiling mid-generation; the user sees a "try again" error rather than a silently-truncated spec.
- `maxTokens` raised because §6 specs were sometimes truncated at 4096 tokens (10+ section format is long).

---

## §CI1 — Compliance-Informed Feature Interview — COMPLETE ✅

**Completed:** 2026-06-27

- [x] `lib/features/interview/providers/interview_providers.dart` — `complianceContext: String?` field on `InterviewArgs`; `==` and `hashCode` updated
- [x] `lib/features/interview/state/interview_notifier.dart` — `_featureInterviewSystemPrompt()` injects compliance block when `complianceContext` is non-null; escape hatch fallback (fires at any layer after ≥10 user turns, not just L3/L4 after 6)
- [x] `dart analyze lib/` — zero issues

### Notes
- `complianceContext` is the text of V1 verification checklist results — items marked ❌ or ⚠️ surface to the user during V2 scoping so they are addressed or explicitly deferred.
- Escape hatch fallback (10 turns, any layer) catches the case where the LLM wraps up the interview at L1/L2 without emitting forge-state JSON blocks, which previously left the app stuck with no way to proceed.

---
```

---

## Verification Checklist (run after writing)

- [ ] `context.md` — new session block is prepended ABOVE the 2026-06-18/19 block
- [ ] `context.md` — existing content from line 6 onward is unchanged
- [ ] `planner.md` — three new `## §VF1`, `## §VC1`, `## §CI1` sections added before `## Next Up — §W5`
- [ ] `planner.md` — existing content is unchanged
- [ ] No `.dart` files were modified
- [ ] Formatting: section headers use `##`, bullet items use `- [x]`, notes use `### Notes`

---

## Failure Mode Reminders (Qwen3 Code — documentation tasks)

1. **Do NOT edit `.dart` files.** This is a documentation-only task. Every file you touch must end in `.md`.
2. **Prepend, do not replace.** `context.md` is an append-only log. The new block goes at the top, after the `---` divider on line 5. Never delete existing session blocks.
3. **Preserve exact formatting.** Use the exact markdown structure shown above. The heading level, checkbox format `- [x]`, and `### Notes` subsection are load-bearing — Claude Code reads these files.
4. **Do not compress or summarize existing content.** If a line was there before your edit, it must still be there after.
