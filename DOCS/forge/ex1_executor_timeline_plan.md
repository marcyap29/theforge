# §EX1 — Executor Timeline
## Scoped Executor Prompt for Gemma

**Feature:** When a project reaches `phase == v1_worksheet_complete`, show a "BUILD SEQUENCE" section in `ProjectDetailScreen`. The user can generate a one-time LLM-narrated build sequence from the locked spec's Component Map. Result is persisted to disk and displayed on every subsequent open.

**Definition of done:** A BUILD SEQUENCE section appears in ProjectDetailScreen for projects with `phase == v1_worksheet_complete`. Tapping "Generate Build Sequence" calls the LLM and writes the result to `handoffs/`. On subsequent opens, the content loads from disk. `dart analyze lib/` — zero issues.

---

## Project Context

- **Stack:** Flutter 3.38.7 / Dart 3.10.7 / Riverpod / local filesystem (no Firebase)
- **Repo root:** `/Volumes/Marc Working Drive/Development/The Forge/`
- **State management:** Riverpod — `AsyncNotifier`, `Notifier`, `ConsumerWidget`
- **Linter:** `dart analyze lib/` — zero warnings required before done

### Existing patterns to match

| Pattern | Where to find it |
|---|---|
| AutoDispose family notifier | `lib/features/interview/state/interview_notifier.dart` — `FamilyAsyncNotifier` |
| Idle/generating/done/error state model | `lib/features/spec_generation/spec_notifier.dart` |
| LLM call via `llmServiceProvider` | `lib/features/spec_generation/spec_notifier.dart:40-49` |
| Reading locked spec from disk | `lib/features/spec_generation/spec_notifier.dart` (see how spec notifier reads files) |
| `parseComponentNames()` | `lib/features/spec_generation/spec_generator.dart:217` |
| `_extractSection()` helper | `lib/features/spec_generation/spec_generator.dart:304` |
| Writing a handoff file | `lib/features/spec_generation/spec_notifier.dart:66-76` — `repo.writeHandoff(path, filename, content)` |
| Project detail screen layout | `lib/features/projects/screens/project_detail_screen.dart` — left column has `_PhaseTimeline` followed by `_ReferenceDocsRow` |

---

## Files to Create

### 1. `lib/features/spec_generation/executor_timeline_notifier.dart` — NEW

**State model:**

```dart
enum ExecutorTimelineStatus { notGenerated, generating, done, error }

class ExecutorTimelineState {
  final ExecutorTimelineStatus status;
  final String? content;   // markdown content when done
  final String? error;
  const ExecutorTimelineState({required this.status, this.content, this.error});
}
```

**Notifier — family arg is `String projectPath`:**

```dart
class ExecutorTimelineNotifier
    extends FamilyAsyncNotifier<ExecutorTimelineState, String> {

  @override
  Future<ExecutorTimelineState> build(String projectPath) async {
    // Scan {projectPath}/handoffs/ for a file matching *_BuildSequence_*.md
    // Use Directory(p.join(projectPath, 'handoffs')).listSync()
    // If found, read and return ExecutorTimelineState(status: done, content: ...)
    // If not found or directory empty, return ExecutorTimelineState(status: notGenerated)
    // Catch any filesystem error → return notGenerated (don't crash)
  }

  Future<void> generate(String projectName, String specVersion) async {
    // Guard: if already generating, return
    state = const AsyncData(ExecutorTimelineState(status: ExecutorTimelineStatus.generating));

    try {
      final repo = ref.read(projectFileRepositoryProvider);
      final llmService = ref.read(llmServiceProvider);
      final projectPath = arg;  // family arg

      // 1. Read locked spec from disk
      //    Path: {projectPath}/specs/{projectName}_LockedSpec_{specVersion}.md
      //    Use File(path).readAsString() — consistent with ingestion_notifier.dart pattern
      //    (or use repo.readLockedSpec() if its signature supports this — check the method first)

      // 2. Build prompt
      final prompt = buildExecutorTimelinePrompt(projectName, specContent);

      // 3. Call LLM
      //    role: LlmRole.architect
      //    temperature: 0.3 (procedural — consistent with worksheet at 0.3)
      //    maxTokens: 2048
      final result = await llmService.complete(
        systemPrompt: prompt,
        userPrompt: 'Generate the build sequence now.',
        temperature: 0.3,
        role: LlmRole.architect,
        maxTokens: 2048,
      );

      // 4. Write to disk
      final filename = '${projectName}_BuildSequence_$specVersion.md';
      await repo.writeHandoff(projectPath, filename, result);

      state = AsyncData(ExecutorTimelineState(
        status: ExecutorTimelineStatus.done,
        content: result,
      ));
    } catch (e) {
      state = AsyncData(ExecutorTimelineState(
        status: ExecutorTimelineStatus.error,
        error: e.toString(),
      ));
    }
  }
}

final executorTimelineProvider = AsyncNotifierProvider.autoDispose
    .family<ExecutorTimelineNotifier, ExecutorTimelineState, String>(
  ExecutorTimelineNotifier.new,
);
```

---

## Files to Modify

### 2. `lib/features/spec_generation/spec_generator.dart`

Add one new function **after** `parseComponentNames()` (around line 230):

```dart
String buildExecutorTimelinePrompt(String projectName, String specContent) {
  final goal = _extractSection(specContent, '## 1. Immutable Goal Statement') ??
      _extractSection(specContent, '## 1. Project Goal Statement') ??
      '(see spec)';
  final constraints = _extractSection(specContent, '## 2. Hard Constraints') ?? '(see spec)';
  final componentSection = _extractSection(specContent, '## 3. Component Map') ?? '(see spec)';
  final components = parseComponentNames(specContent);
  final componentList = components.isEmpty
      ? '(no components found)'
      : components.map((c) => '- $c').join('\n');

  return '''You are a senior technical architect generating an ordered build sequence.

PROJECT: $projectName

GOAL:
$goal

HARD CONSTRAINTS:
$constraints

COMPONENT MAP (table):
$componentSection

COMPONENTS IDENTIFIED:
$componentList

Generate a concrete, ordered build sequence. Order by dependency: components with no upstream dependencies come first. Each step enables the next.

Output this exact format and nothing else:

# $projectName — Build Sequence

## Step 1: [ComponentName]
[One sentence: what to build and what it unblocks downstream]

## Step 2: [ComponentName]
[One sentence]

(continue for every component in the Component Map — one step per component, no extras)

Rules:
- Use the exact component names from the Component Map
- No TBD, no filler
- Each step's one sentence explains WHY it comes at this position
- Do not add components not in the spec''';
}
```

---

### 3. `lib/features/projects/screens/project_detail_screen.dart`

**Add `_BuildSequenceSection` widget** — insert it in the left column after `_ReferenceDocsRow`.

Read the current file first. Find the left column's `Column` children. Add:
```dart
if (project.phase == 'v1_worksheet_complete')
  _BuildSequenceSection(project: project),
```

**Widget spec for `_BuildSequenceSection`:**

```dart
class _BuildSequenceSection extends ConsumerWidget {
  final Project project;  // the drift Project row — has .path, .name, .phase, .specVersion

  // Watches executorTimelineProvider(project.path)
  // Layout: a card with title "BUILD SEQUENCE" in amber
  //
  // States:
  //   notGenerated:
  //     Show subtitle "Generate an LLM-narrated build order from your spec."
  //     Show FilledButton "Generate Build Sequence" (amber)
  //     On tap: executorTimelineProvider.notifier.generate(project.name, project.specVersion ?? 'v1')
  //
  //   generating:
  //     Show CircularProgressIndicator + "Generating..." text (same pattern as WorksheetGenerationScreen)
  //
  //   done:
  //     Show content in a scrollable Text widget (monospace, small font)
  //     Or use MarkdownBody from flutter_markdown if preferred
  //     Max height: 300px with a scrollable container
  //
  //   error:
  //     Show error text in red
  //     Show TextButton "Retry" → calls generate() again
  //
  // Visual style: match _ReferenceDocsRow card — slate border, 12px padding, same corner radius
}
```

**Important:** The `project` object comes from Drift. Read the Projects table in `lib/data/local_db/forge_database.dart` to confirm exact field names (`project.path` vs `project.projectPath`, `project.specVersion`, etc.) before writing the widget. Match the pattern used in `_PhaseTimeline` which already reads these fields.

---

## Filesystem details

| File | Path |
|---|---|
| Locked spec (input) | `{projectPath}/specs/{projectName}_LockedSpec_{specVersion}.md` |
| Build sequence (output) | `{projectPath}/handoffs/{projectName}_BuildSequence_{specVersion}.md` |

`writeHandoff(projectPath, filename, content)` already exists in `ProjectFileRepository` — use it for the output write.

For reading the locked spec: either call the existing `repo.readLockedSpec()` method (check its signature in `project_file_repository.dart`) or read directly via `File(path).readAsString()`.

---

## Key invariants (do not break)

- `dart analyze lib/` zero warnings before reporting done
- No Firebase imports (`grep -ri firebase lib/` must return nothing)
- Build sequence file is NOT write-once — if the user regenerates, overwrite is fine (unlike the locked spec)
- Do not touch `spec_generator.dart` beyond adding the single new function
- The BUILD SEQUENCE section must only render when `phase == 'v1_worksheet_complete'`
- `executorTimelineProvider` must be `autoDispose` — it's a per-detail-screen concern

---

## Out of scope

- No new navigation screen — inline widget in ProjectDetailScreen only
- No database phase update on generation — the file on disk is the source of truth
- No integration with the artifact viewer for the build sequence file (future)
- No streaming — single LLM call, full response

---

## File read order (recommended)

Before touching any file, read these in order:

1. `lib/data/local_db/forge_database.dart` — confirm Project field names
2. `lib/features/projects/screens/project_detail_screen.dart` — understand current layout
3. `lib/features/spec_generation/spec_notifier.dart` — match the generate() pattern
4. `lib/features/spec_generation/spec_generator.dart` — see where to add `buildExecutorTimelinePrompt()`
5. `lib/data/filesystem/project_file_repository.dart` — find `writeHandoff()` and `readLockedSpec()` signatures

---

*Plan written: 2026-06-11 · Ready for handoff to Gemma*
