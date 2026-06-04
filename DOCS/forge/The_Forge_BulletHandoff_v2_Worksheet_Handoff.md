# The Forge — Bullet Handoff v2 · §8 Setup Worksheet + §9 Handoff Package + /goal
**Prepared for:** External agent (DeepSeek Flash / any capable coding model)
**Date:** 2026-06-04
**Phase:** Plan Mode critical path — §8 Setup Worksheet Generation + §9 Handoff Package + /goal text
**Written by:** Claude Sonnet 4.6 (planning session)
**Primary repo:** `/Volumes/Marc Working Drive/Development/The Forge`
**GitHub remote:** `https://github.com/marcyap29/theforge.git`
**Branch:** `main`

---

## Context — Where the Codebase Stands

Pull `main` and read these files before touching anything:

| File | What it tells you |
|---|---|
| `lib/features/spec_generation/spec_notifier.dart` | The full spec generation pipeline — you will extend this |
| `lib/features/spec_generation/spec_generator.dart` | Prompt builders and handoff builder — you will add to this |
| `lib/features/spec_generation/spec_generation_screen.dart` | The done state you will modify to add "Generate Worksheet →" |
| `lib/data/filesystem/project_file_repository.dart` | `writeWorksheet()`, `writeHandoffPackage()`, `writeHandoff()` — exact signatures |
| `DOCS/forge/workflow_template.md` | Worksheet structure (Stage 3) and /goal format (Stage 4b) — ground truth |

**What is already built (do not touch):**
- `spec_notifier.dart:generate()` — full pipeline: LLM → SpecParser.clean → writeLockedSpec → writeHandoff (bullet) → appendAuditLog → updateReadme → DB update
- `spec_generator.dart:buildBulletHandoff()` — already writes the Interview→Spec bullet handoff
- `ProjectFileRepository.writeWorksheet(projectPath, filename, content)` — already exists, just call it
- `ProjectFileRepository.writeHandoffPackage(projectPath, version, Map data)` — already exists
- `ProjectFileRepository.writeHandoff(projectPath, filename, content)` — already exists

---

## Definition of Done

Complete when:
1. After spec generation, "Generate Setup Worksheet →" button navigates to `WorksheetGenerationScreen`
2. `WorksheetNotifier.generate()` reads the spec from disk, calls LLM, writes `worksheets/{ProjectName}_SetupWorksheet_v1.md`
3. README.md `**Setup worksheet:**` field flips from `Incomplete` to `Complete`
4. `handoff_package_v1.json` and `handoffs/{ProjectName}_goal_v1.md` are written to disk as part of the spec generation pipeline (no extra screen needed)
5. `dart analyze lib/` → No issues found
6. `grep -ri firebase lib/` → zero matches

---

## §9 — Handoff Package + /goal text (extend spec_notifier.dart — no new screen)

§9 outputs are derived from the interview state and spec content. No new LLM call. No new screen. Fold into the existing `spec_notifier.dart` pipeline immediately after `writeLockedSpec()`.

### Task 1: Add builders to `spec_generator.dart`

Add these two functions to the bottom of `spec_generator.dart`:

```dart
/// Builds the /goal text from interview state + locked spec content.
/// Writes to: handoffs/{ProjectName}_goal_v{N}.md
String buildGoalText(InterviewState state, String specVersion, String specContent) {
  final isBuild = state.dimensions == buildDimensions;
  final goalStatement = _extractSection(specContent, '## 1. Immutable Goal Statement') ??
      _extractSection(specContent, '## 1. Project Goal Statement') ??
      '(see locked spec)';
  final completionCriteria = isBuild
      ? (_extractSection(specContent, '## 5. Completion Criteria') ?? '(see locked spec)')
      : '(Audit mode — see locked spec for next phase seeds)';

  return '''# /goal — ${state.projectName} $specVersion

## Outcome
$goalStatement

## Completion Criteria
$completionCriteria

## Constraints
(see Hard Constraints table in the locked spec)

## Boundaries
- Component ownership: see Component Map in the locked spec
- Out-of-scope: see Explicit Out-of-Scope List in the locked spec

## Iteration Policy
Work at low temperature. Resolve ambiguity conservatively. When uncertain
between two valid approaches, choose the one with less surface area. Flag
decisions you are not confident in rather than guessing.

## Stop Conditions
Stop and surface a blocker if:
- A completion criterion cannot be met without a decision not in this spec
- A required external service is unavailable or misconfigured
- The Setup Worksheet variables are missing or invalid

Do not stop because the work is hard. Stop only when genuinely blocked.
''';
}

/// Builds the Handoff Package JSON map.
/// Writes to: {projectPath}/handoff_package_v{N}.json
Map<String, dynamic> buildHandoffPackage(
    InterviewState state, String specVersion, String specContent) {
  final isBuild = state.dimensions == buildDimensions;
  final goalStatement = _extractSection(specContent, '## 1. Immutable Goal Statement') ??
      _extractSection(specContent, '## 1. Project Goal Statement') ??
      '';
  final now = DateTime.now().toIso8601String().split('T').first;

  if (isBuild) {
    return {
      'interviewMode': 'build',
      'specVersion': specVersion,
      'appName': state.projectName,
      'lockedAt': now,
      'goalStatement': goalStatement.trim(),
      'openFlags': _countTableRows(specContent, '## 9. Open Flags'),
      'outOfScopeItems': _countListItems(specContent, '## 7. Explicit Out-of-Scope List'),
      'setupWorksheetComplete': false,
      'v2SeedItems': [],
    };
  } else {
    return {
      'interviewMode': 'audit',
      'specVersion': specVersion,
      'projectName': state.projectName,
      'auditDate': now,
      'goalStatement': goalStatement.trim(),
      'activeBlockers': _countTableRows(specContent, '## 4. Active Blocker Registry'),
      'decisionDebtItems': _countTableRows(specContent, '## 5. Decision Debt Log'),
      'technicalDebtItems': _countTableRows(specContent, '## 6. Technical Debt Log'),
      'documentationGaps': _countListItems(specContent, '## 8. Documentation Gaps'),
      'v2SeedItems': [],
    };
  }
}

// Extracts the body of a section headed by [header] until the next ## heading.
String? _extractSection(String content, String header) {
  final start = content.indexOf(header);
  if (start < 0) return null;
  final bodyStart = start + header.length;
  final nextHeader = content.indexOf('\n## ', bodyStart);
  final end = nextHeader < 0 ? content.length : nextHeader;
  return content.substring(bodyStart, end).trim();
}

// Counts data rows in a markdown table (skips header and divider rows).
int _countTableRows(String content, String sectionHeader) {
  final section = _extractSection(content, sectionHeader);
  if (section == null) return 0;
  return section
      .split('\n')
      .where((l) => l.startsWith('|') && !l.contains('---') && !l.contains('---|'))
      .length - 1; // subtract header row
}

// Counts non-empty list items (lines starting with - or *) in a section.
int _countListItems(String content, String sectionHeader) {
  final section = _extractSection(content, sectionHeader);
  if (section == null) return 0;
  return section.split('\n').where((l) => l.trimLeft().startsWith('- ') || l.trimLeft().startsWith('* ')).length;
}
```

### Task 2: Call them in `spec_notifier.dart`

In `spec_notifier.dart:generate()`, immediately after the `await repo.writeLockedSpec(...)` line, add:

```dart
// §9 — /goal text + Handoff Package (no LLM call — derived from spec)
final goalText = buildGoalText(interviewState, specVersion, specContent);
await repo.writeHandoff(
  projectPath,
  '${projectName}_goal_$specVersion.md',
  goalText,
);

final handoffPackage = buildHandoffPackage(interviewState, specVersion, specContent);
await repo.writeHandoffPackage(projectPath, specVersion, handoffPackage);
```

`spec_notifier.dart` already imports `spec_generator.dart`, so no new import needed.

### Task 3: Expose `specVersion` in `SpecGenState`

`SpecGenerationScreen` needs to pass `specVersion` to `WorksheetGenerationScreen`. `SpecGenState.specVersion` doesn't currently exist (only `specFilename`). Add it:

```dart
// In spec_notifier.dart — SpecGenState class:
class SpecGenState {
  final SpecGenStatus status;
  final String? specFilename;
  final String? specVersion;   // ADD THIS
  final String? errorMessage;
  const SpecGenState({
    this.status = SpecGenStatus.idle,
    this.specFilename,
    this.specVersion,          // ADD THIS
    this.errorMessage,
  });
}
```

In the `done` state assignment inside `generate()`, set it:
```dart
state = SpecGenState(
  status: SpecGenStatus.done,
  specFilename: specFilename,
  specVersion: specVersion,    // ADD THIS
);
```

---

## §8 — Setup Worksheet Generation (new screen + notifier)

### Task 4: Create `lib/features/spec_generation/worksheet_generator.dart`

```dart
import 'interview/state/interview_state.dart'; // adjust import path if needed

String buildWorksheetPrompt(String projectName, String specContent) {
  return '''You are The Forge setup worksheet writer.

PROJECT: $projectName

LOCKED SPEC:
$specContent

Generate a Setup Worksheet for every external service mentioned in this spec.
If the spec has no external services, output: "# $projectName — Setup Worksheet\n\nNo external services required. Proceed directly to executor."

Otherwise follow this exact structure:

# $projectName — Setup Worksheet

## Before You Start
[Time estimate. Prerequisites. What you will need before beginning.]

## [Service Name] (one section per external service)
### 1. Create account / project
[Step-by-step instructions]
### 2. Enable required features
[List any APIs, features, or plans to enable]
### 3. Generate credentials
[Where to find the API key / credentials — exact UI path]
### 4. Copy these values
[Table: Variable name | Where to find it | Notes]

## Local Project Configuration
[How to wire the credentials into the local project — .env.example reference, config file location]

## Environment Variables Table
| Variable | Required | Description |
|---|---|---|
| [VAR_NAME] | Yes / No | [what it controls] |

## Verification Checklist
- [ ] [Each service: account created, feature enabled, credentials copied]
- [ ] Local config updated with all variables
- [ ] App launches without credential errors

## What Happens Next
[The executor agent reads this worksheet and the locked spec. Setup must be complete before executor starts. setupWorksheetComplete must be true in the handoff package.]

## Free Tier Reference
| Service | Free tier limit | Upgrade trigger |
|---|---|---|
| [service] | [what's free] | [when you'd need to pay] |

Be specific and concrete. Real console UI paths. No placeholder instructions.
''';
}

String buildWorksheetAuditEntry(String projectName, String worksheetFilename) {
  final now = DateTime.now().toIso8601String();
  return '\n## $now — Setup Worksheet Generated\n'
      '- File: $worksheetFilename\n'
      '- Status: complete\n'
      '---\n';
}
```

**Import note:** This file is in `lib/features/spec_generation/` — it does not need to import `InterviewState`. The `specContent` string is passed in from the notifier which reads it from disk.

### Task 5: Create `lib/features/spec_generation/worksheet_notifier.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/filesystem/project_file_repository.dart';
import '../../features/projects/providers/providers.dart';
import '../../services/llm/llm_provider.dart';
import '../../services/llm/llm_service_provider.dart';
import 'worksheet_generator.dart';

enum WorksheetGenStatus { idle, generating, done, error }

class WorksheetGenState {
  final WorksheetGenStatus status;
  final String? worksheetFilename;
  final String? errorMessage;
  const WorksheetGenState({
    this.status = WorksheetGenStatus.idle,
    this.worksheetFilename,
    this.errorMessage,
  });
}

class WorksheetNotifier extends AutoDisposeNotifier<WorksheetGenState> {
  @override
  WorksheetGenState build() => const WorksheetGenState();

  Future<void> generate({
    required String projectPath,
    required String projectName,
    required String specVersion,
  }) async {
    if (state.status == WorksheetGenStatus.generating) return;
    state = const WorksheetGenState(status: WorksheetGenStatus.generating);

    final worksheetFilename = '${projectName}_SetupWorksheet_$specVersion.md';

    try {
      // Read the locked spec from disk — it was written in §6
      final repo = ref.read(projectFileRepositoryProvider);
      final specFile = await repo.readLockedSpec(projectPath, projectName, specVersion);

      final llmService = ref.read(llmServiceProvider);
      final rawWorksheet = await llmService.complete(
        systemPrompt: buildWorksheetPrompt(projectName, specFile),
        userPrompt: 'Generate the setup worksheet now.',
        temperature: 0.3,
        role: LlmRole.architect,
        maxTokens: 4096,
      );

      await repo.writeWorksheet(projectPath, worksheetFilename, rawWorksheet.trim());

      // Flip README setup worksheet field
      final currentReadme = await repo.readReadme(projectPath) ?? '';
      final updatedReadme = currentReadme.replaceFirst(
        '**Setup worksheet:** Incomplete',
        '**Setup worksheet:** Complete',
      );
      await repo.writeReadme(projectPath, updatedReadme);

      // Append to audit log
      await repo.appendAuditLog(
        projectPath,
        projectName,
        buildWorksheetAuditEntry(projectName, worksheetFilename),
      );

      state = WorksheetGenState(
        status: WorksheetGenStatus.done,
        worksheetFilename: worksheetFilename,
      );
    } catch (e) {
      state = WorksheetGenState(
        status: WorksheetGenStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}

final worksheetNotifierProvider =
    NotifierProvider.autoDispose<WorksheetNotifier, WorksheetGenState>(
        WorksheetNotifier.new);
```

### Task 6: Add `readLockedSpec()` to `ProjectFileRepository`

`WorksheetNotifier` needs to read the spec from disk. Add this method to `project_file_repository.dart`:

```dart
Future<String> readLockedSpec(
    String projectPath, String projectName, String specVersion) async {
  final specPath = p.join(
      projectPath, 'specs', '${projectName}_LockedSpec_$specVersion.md');
  return File(specPath).readAsString();
}
```

### Task 7: Create `lib/features/spec_generation/worksheet_generation_screen.dart`

Mirrors `SpecGenerationScreen` exactly — same idle/generating/done/error pattern, same amber theme.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'worksheet_notifier.dart';

class WorksheetGenerationScreen extends ConsumerStatefulWidget {
  const WorksheetGenerationScreen({
    super.key,
    required this.projectPath,
    required this.projectName,
    required this.specVersion,
  });

  final String projectPath;
  final String projectName;
  final String specVersion;

  @override
  ConsumerState<WorksheetGenerationScreen> createState() =>
      _WorksheetGenerationScreenState();
}

class _WorksheetGenerationScreenState
    extends ConsumerState<WorksheetGenerationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(worksheetNotifierProvider.notifier).generate(
            projectPath: widget.projectPath,
            projectName: widget.projectName,
            specVersion: widget.specVersion,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(worksheetNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Worksheet — ${widget.projectName}'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: switch (state.status) {
            WorksheetGenStatus.idle ||
            WorksheetGenStatus.generating =>
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFE8A04C)),
                  SizedBox(height: 24),
                  Text(
                    'Generating setup worksheet…\nThis takes 10–20 seconds.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            WorksheetGenStatus.done => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF22C55E), size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Worksheet ready — ${state.worksheetFilename}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE5E5E7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Complete the worksheet before starting the executor.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE8A04C),
                      foregroundColor: const Color(0xFF0F0F10),
                    ),
                    child: const Text('Back to Projects'),
                  ),
                ],
              ),
            WorksheetGenStatus.error => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFEF4444), size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Worksheet generation failed',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE5E5E7)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.errorMessage ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 11,
                      color: Color(0xFFEF4444),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => ref
                        .read(worksheetNotifierProvider.notifier)
                        .generate(
                          projectPath: widget.projectPath,
                          projectName: widget.projectName,
                          specVersion: widget.specVersion,
                        ),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }
}
```

### Task 8: Update `SpecGenerationScreen` done state

Replace the single "Back to Projects" `FilledButton` in the `SpecGenStatus.done` branch with:

```dart
SpecGenStatus.done => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 48),
      const SizedBox(height: 16),
      Text(
        'Spec locked — ${state.specFilename}',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE5E5E7),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Bullet Handoff, /goal text, and Handoff Package written.',
        style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
      ),
      const SizedBox(height: 32),
      // Primary action: generate worksheet
      SizedBox(
        width: 260,
        child: FilledButton(
          onPressed: () {
            final specVersion = state.specVersion ?? 'v1';
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WorksheetGenerationScreen(
                  projectPath: widget.interviewState.projectPath,
                  projectName: widget.interviewState.projectName,
                  specVersion: specVersion,
                ),
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE8A04C),
            foregroundColor: const Color(0xFF0F0F10),
          ),
          child: const Text('Generate Setup Worksheet →'),
        ),
      ),
      const SizedBox(height: 12),
      // Secondary action: skip for now
      TextButton(
        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        child: const Text(
          'Back to Projects',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      ),
    ],
  ),
```

You will need to import `worksheet_generation_screen.dart` at the top of `spec_generation_screen.dart`.

---

## Key Invariants — Do Not Violate

- **`dart analyze lib/` must return zero issues.** Run it. Fix everything before reporting done.
- **No Firebase.** `grep -ri firebase lib/` must return zero matches.
- **Read before editing.** Read every file before modifying it.
- **`writeWorksheet()` is a normal write (not write-once).** Worksheets can be regenerated. Only `writeLockedSpec()` is write-once.
- **LLM temperature for worksheet: 0.3.** Lower than spec generation — worksheets are procedural, not creative.
- **Do not touch §1–§7 code** beyond the specific modifications listed. Every changed line must trace to §8 or §9 requirements.
- **Do not add a `/goal` or `/worksheet` named route to `app.dart`.** Both screens use `MaterialPageRoute` directly — matches existing codebase pattern.

---

## File Summary

| File | Action | Section |
|---|---|---|
| `lib/features/spec_generation/spec_generator.dart` | Modify — add `buildGoalText()`, `buildHandoffPackage()`, helpers | §9 |
| `lib/features/spec_generation/spec_notifier.dart` | Modify — call /goal + handoff builders; add `specVersion` to `SpecGenState` | §9 |
| `lib/features/spec_generation/spec_generation_screen.dart` | Modify — done state gets "Generate Worksheet →" primary button | §8 |
| `lib/data/filesystem/project_file_repository.dart` | Modify — add `readLockedSpec()` | §8 |
| `lib/features/spec_generation/worksheet_generator.dart` | **New** — `buildWorksheetPrompt()`, `buildWorksheetAuditEntry()` | §8 |
| `lib/features/spec_generation/worksheet_notifier.dart` | **New** — `WorksheetNotifier`, `WorksheetGenState`, `worksheetNotifierProvider` | §8 |
| `lib/features/spec_generation/worksheet_generation_screen.dart` | **New** — `WorksheetGenerationScreen` | §8 |

---

## Session Close Checklist (mandatory before reporting done)

- [ ] `dart analyze lib/` → No issues found
- [ ] `grep -ri firebase lib/` → zero matches
- [ ] `handoffs/{ProjectName}_goal_v1.md` written during spec generation pipeline
- [ ] `handoff_package_v1.json` written during spec generation pipeline
- [ ] "Generate Worksheet →" button appears on spec done screen
- [ ] `WorksheetGenerationScreen` generates and writes the worksheet file
- [ ] README.md `**Setup worksheet:**` flips to `Complete` after worksheet generation
- [ ] Audit log appended after worksheet generation
- [ ] Append a session block to `tracking md files/context.md` (newest first)
- [ ] Cross off §8 and §9 in `tracking md files/planner.md`
- [ ] Mark §8 and §9 complete in `tracking md files/backlog.md` Completed section
- [ ] Append to `audit/The_Forge_AuditLog.md` — entry confirming §8+§9 complete
- [ ] Commit: `feat(§8+§9): setup worksheet generation + handoff package + /goal text`
- [ ] Push to `origin main`

---

## What NOT to Build

- §11 Audit Interview Mode spec structure — out of scope
- §12 Document Ingestion — out of scope
- §13 Workspace + Billing — out of scope
- §14 Monte Carlo multi-temperature spec generation — out of scope
- Watch Mode (§W1+) — gated on first end-to-end Plan Mode run, which this completes the prerequisites for
- Do not add error recovery for the spec-already-exists case in worksheet generation — that's not a real failure path

---

_The Forge · Orbital AI · June 2026_
_Primary format reference: `DOCS/forge/workflow_template.md` Stages 3 and 4._
