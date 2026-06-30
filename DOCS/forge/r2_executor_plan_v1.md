# §R2 Executor Plan v1
# Pull Interview Engine + As-Built Spec Generator

**Date:** 2026-06-28
**Status:** Ready to execute — §R1 ✅
**Executor:** Qwen3 Code
**Reviewer:** Claude Sonnet (between every chunk)

---

## Overview

§R2 builds the Pull Interview and As-Built Spec Generator. A user with a "Project Onboarding" project:
1. Links and ingests their repo (§R1 ✅)
2. Runs a Pull Interview — targeted questions to fill gaps the code can't answer
3. Generates an As-Built Spec in the same 10-section format as a Locked Spec
4. The spec is immediately usable by §W6 Spec Compliance Monitor

**6 files to create, 3 files to modify. Execute in 6 sequential chunks. STOP after each chunk, run `dart analyze lib/`, report results. Do NOT start the next chunk until Claude approves.**

---

## CRITICAL RULES — Read before touching any file

1. **If `dart analyze` fails after a file, fix only the flagged lines. Do NOT rewrite the file.**
2. **Run `dart analyze lib/` after EACH chunk — not at the end.**
3. **After every file, scan for stray backtick fences or duplicate function-closing braces.**
4. **Static methods are marked `[STATIC]` — call as `ClassName.method()`, not `instance.method()`.**
5. **The Riverpod notifier/provider pairs are spelled out exactly. Do not change them.**
6. **Provider declarations live in ONE file only. The file is named in each chunk.**
7. **New classes referenced in a file must be implemented in that same file.**

---

## Chunk A — `project_file_repository.dart` (3 new methods)

**File to modify:** `lib/data/filesystem/project_file_repository.dart`

Read the full file first. Add three methods to the `ProjectFileRepository` class, after the existing `writeAsBuiltSpec`-adjacent methods (after `readIngestionSummary`, before `deleteProject`). Do not touch any existing methods.

### Method 1 — `writeAsBuiltSpec`

```dart
Future<void> writeAsBuiltSpec(
    String projectPath, String projectName, String content) async {
  final versionDir = Directory(p.join(projectPath, 'specs', 'v1'));
  await versionDir.create(recursive: true);
  final specPath =
      p.join(versionDir.path, '${projectName}_AsBuiltSpec_v1.md');
  final tmpPath = '$specPath.tmp';
  await File(tmpPath).writeAsString(content);
  File(tmpPath).renameSync(specPath);
}
```

Note: Not write-once (unlike `writeLockedSpec`) — as-built specs can be regenerated.

### Method 2 — `writeReverseInterviewLog`

```dart
Future<void> writeReverseInterviewLog(String projectPath, String projectName,
    List<Map<String, dynamic>> turns) async {
  final auditDir = Directory(p.join(projectPath, 'audit'));
  final file =
      File(p.join(auditDir.path, '${projectName}_ReverseInterview.json'));
  await file.writeAsString(jsonEncode(turns));
}
```

### Method 3 — `readReverseInterviewLog`

```dart
Future<List<Map<String, dynamic>>> readReverseInterviewLog(
    String projectPath, String projectName) async {
  final file = File(
      p.join(projectPath, 'audit', '${projectName}_ReverseInterview.json'));
  if (!file.existsSync()) return [];
  try {
    return (jsonDecode(await file.readAsString()) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  } on FormatException {
    return [];
  }
}
```

**Verification:**
```
dart analyze lib/data/filesystem/
```
Expected: `No issues found.`

**STOP. Report results. Wait for Claude.**

---

## Chunk B — `reverse_interview_state.dart` + `reverse_interview_notifier.dart` (2 new files)

Create the directory `lib/features/reverse_interview/state/` before creating these files.

### File 1 — `lib/features/reverse_interview/state/reverse_interview_state.dart`

This file contains: `ReverseInterviewTurn`, `ReverseInterviewState`, `ReverseInterviewArgs`, and the provider declaration.

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reverse_interview_notifier.dart';

@immutable
class ReverseInterviewTurn {
  final bool isUser;
  final String text;

  const ReverseInterviewTurn({required this.isUser, required this.text});
}

@immutable
class ReverseInterviewState {
  final String projectPath;
  final String projectName;
  final List<ReverseInterviewTurn> turns;
  final bool isLoading;
  final bool isComplete;
  final String? error;

  const ReverseInterviewState({
    required this.projectPath,
    required this.projectName,
    this.turns = const [],
    this.isLoading = false,
    this.isComplete = false,
    this.error,
  });

  // Enabled after 4 user turns — enough context for the as-built spec
  bool get canGenerateSpec =>
      turns.where((t) => t.isUser).length >= 4 || isComplete;

  ReverseInterviewState copyWith({
    List<ReverseInterviewTurn>? turns,
    bool? isLoading,
    bool? isComplete,
    String? error,
  }) =>
      ReverseInterviewState(
        projectPath: projectPath,
        projectName: projectName,
        turns: turns ?? this.turns,
        isLoading: isLoading ?? this.isLoading,
        isComplete: isComplete ?? this.isComplete,
        error: error,
      );
}

@immutable
class ReverseInterviewArgs {
  final String projectPath;
  final String projectName;

  const ReverseInterviewArgs({
    required this.projectPath,
    required this.projectName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReverseInterviewArgs &&
          other.projectPath == projectPath &&
          other.projectName == projectName);

  @override
  int get hashCode => Object.hash(projectPath, projectName);
}

// Riverpod pair — DO NOT modify the extends line or this declaration independently.
// Reference: lib/features/interview/providers/interview_providers.dart uses the same pair.
// Provider declared ONLY in this file. The screen and notifier import it from here.
final reverseInterviewProvider = AsyncNotifierProvider.family<
    ReverseInterviewNotifier,
    ReverseInterviewState,
    ReverseInterviewArgs>(
  ReverseInterviewNotifier.new,
);
```

### File 2 — `lib/features/reverse_interview/state/reverse_interview_notifier.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../features/projects/models/reverse_ingestion_summary.dart';
import '../../../features/projects/providers/providers.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service_provider.dart';
import 'reverse_interview_state.dart';

// Riverpod pair (matches declaration in reverse_interview_state.dart):
// class ReverseInterviewNotifier extends FamilyAsyncNotifier<ReverseInterviewState, ReverseInterviewArgs>
// Reference: lib/features/interview/state/interview_notifier.dart uses the same pattern.
class ReverseInterviewNotifier
    extends FamilyAsyncNotifier<ReverseInterviewState, ReverseInterviewArgs> {
  @override
  Future<ReverseInterviewState> build(ReverseInterviewArgs arg) async {
    final repo = ref.watch(projectFileRepositoryProvider);
    final summary =
        await repo.readIngestionSummary(arg.projectPath, arg.projectName);
    // [INSTANCE — call as repo.readIngestionSummary(...)]

    final greeting = _buildGreeting(summary, arg.projectName);
    return ReverseInterviewState(
      projectPath: arg.projectPath,
      projectName: arg.projectName,
      turns: [ReverseInterviewTurn(isUser: false, text: greeting)],
    );
  }

  Future<void> addUserMessage(String text) async {
    final current = state.requireValue;
    if (current.isLoading) return;

    final withUser = current.copyWith(
      turns: [
        ...current.turns,
        ReverseInterviewTurn(isUser: true, text: text),
      ],
      isLoading: true,
    );
    state = AsyncData(withUser);

    try {
      final repo = ref.read(projectFileRepositoryProvider);
      final service = ref.read(llmServiceProvider);
      final summary = await repo.readIngestionSummary(
          current.projectPath, current.projectName);
      // [INSTANCE — call as repo.readIngestionSummary(...)]

      final systemPrompt = _buildSystemPrompt(current.projectName, summary);
      final history = withUser.turns
          .map((t) => '${t.isUser ? "ENGINEER" : "FORGE"}: ${t.text}')
          .join('\n\n');

      final response = await service.complete(
        role: LlmRole.architect,
        systemPrompt: systemPrompt,
        userPrompt: history,
        temperature: 0.4,
        maxTokens: 1024,
      );

      state = AsyncData(withUser.copyWith(
        turns: [
          ...withUser.turns,
          ReverseInterviewTurn(isUser: false, text: response),
        ],
        isLoading: false,
      ));
    } catch (e) {
      state = AsyncData(withUser.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  // Saves transcript to disk and marks complete.
  // Called before navigating to AsBuiltSpecScreen.
  Future<void> markComplete() async {
    final current = state.requireValue;
    final repo = ref.read(projectFileRepositoryProvider);
    // [INSTANCE — call as repo.writeReverseInterviewLog(...)]
    await repo.writeReverseInterviewLog(
      current.projectPath,
      current.projectName,
      current.turns
          .map((t) => {'isUser': t.isUser, 'text': t.text})
          .toList(),
    );
    state = AsyncData(current.copyWith(isComplete: true));
  }

  String _buildGreeting(IngestionSummary? summary, String projectName) {
    if (summary == null) {
      return 'No ingestion summary found for $projectName. '
          'Run "Ingest Repo" first, then return here.';
    }
    final gapCount = summary.gapList.length;
    final componentCount = summary.componentCount;
    return 'I\'ve reviewed the ingestion summary for $projectName. '
        'Found $componentCount components. '
        '${gapCount > 0 ? 'There are $gapCount gaps to fill. ' : ''}'
        'Let\'s start: What was the primary business goal that drove '
        'this codebase\'s architecture?';
  }

  String _buildSystemPrompt(String projectName, IngestionSummary? summary) {
    final summaryBlock = summary != null
        ? 'INGESTION SUMMARY:\n${summary.toMarkdown()}'
        : 'No ingestion summary available.';

    final gapsBlock = (summary?.gapList.isNotEmpty ?? false)
        ? '\n\nGAPS TO RESOLVE:\n'
            '${summary!.gapList.map((g) => '- $g').join('\n')}'
        : '';

    return 'You are The Forge reverse engineer. You are interviewing an '
        'engineer about an existing codebase called "$projectName" to capture '
        'context the code alone cannot provide.\n\n'
        '$summaryBlock$gapsBlock\n\n'
        'RULES:\n'
        '- Ask only about what the code does NOT reveal (business goals, '
        'architectural decisions, trade-offs, why components exist)\n'
        '- One question per turn, concise\n'
        '- When a gap is addressed, acknowledge it and move to the next\n'
        '- Do not re-ask what the ingestion summary already captured\n'
        '- When all gaps are addressed, say: "I have what I need. Tap '
        '\'Generate As-Built Spec\' when you\'re ready."';
  }
}
```

**Verification:**
```
dart analyze lib/features/reverse_interview/
```
Expected: `No issues found.`

**STOP. Report results. Wait for Claude.**

---

## Chunk C — `reverse_interview_screen.dart` (1 new file)

Create directory `lib/features/reverse_interview/ui/` before creating this file.

**File:** `lib/features/reverse_interview/ui/reverse_interview_screen.dart`

This screen is a simplified version of `InterviewScreen`. Read `lib/features/interview/ui/interview_screen.dart` for structural reference before writing.

Key behaviours:
- Watches `reverseInterviewProvider(widget.args)` — a family provider
- Shows chat bubbles for each turn (user right-aligned amber, Forge left-aligned dark)
- Text composer with Enter-to-send (same keyboard handler pattern as `InterviewScreen`)
- "Generate As-Built Spec →" FilledButton: **enabled** when `state.canGenerateSpec` is true, **disabled** (grey) otherwise
- On tap: call `notifier.markComplete()` then push `AsBuiltSpecScreen` via `MaterialPageRoute`
- Loading state: disable composer and button while `state.isLoading`
- Error state: show red error text above composer if `state.error != null`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/spec_generation/as_built_spec_screen.dart';
import '../state/reverse_interview_state.dart';

class ReverseInterviewScreen extends ConsumerStatefulWidget {
  const ReverseInterviewScreen({super.key, required this.args});

  final ReverseInterviewArgs args;

  @override
  ConsumerState<ReverseInterviewScreen> createState() =>
      _ReverseInterviewScreenState();
}

class _ReverseInterviewScreenState
    extends ConsumerState<ReverseInterviewScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final FocusNode _composerFocus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _composerFocus = FocusNode(onKeyEvent: (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey != LogicalKeyboardKey.enter) {
        return KeyEventResult.ignored;
      }
      if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      }
      if (!_isLoading) _send();
      return KeyEventResult.handled;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _composerFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    _controller.clear();
    _composerFocus.requestFocus();
    await ref
        .read(reverseInterviewProvider(widget.args).notifier)
        .addUserMessage(text);
    _scrollToBottom();
  }

  Future<void> _generateSpec(ReverseInterviewState state) async {
    await ref
        .read(reverseInterviewProvider(widget.args).notifier)
        .markComplete();
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AsBuiltSpecScreen(
        projectPath: widget.args.projectPath,
        projectName: widget.args.projectName,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(reverseInterviewProvider(widget.args));
    final state = stateAsync.valueOrNull;
    _isLoading = state?.isLoading ?? false;

    ref.listen(reverseInterviewProvider(widget.args), (_, next) {
      if (next.valueOrNull?.turns.isNotEmpty ?? false) _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Pull Interview — ${widget.args.projectName}'),
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (s) => Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: s.turns.length,
                itemBuilder: (context, i) {
                  final turn = s.turns[i];
                  return _ChatBubble(turn: turn);
                },
              ),
            ),
            if (s.error != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.error!,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontFamily: 'Menlo',
                    fontSize: 12,
                  ),
                ),
              ),
            _Composer(
              controller: _controller,
              focusNode: _composerFocus,
              isLoading: _isLoading,
              onSend: _send,
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: s.canGenerateSpec && !_isLoading
                      ? () => _generateSpec(s)
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: const Color(0xFFE8A04C),
                    foregroundColor: const Color(0xFF0F0F10),
                    disabledBackgroundColor: const Color(0xFF2C2C2E),
                    disabledForegroundColor: const Color(0xFF6B7280),
                  ),
                  child: const Text(
                    'Generate As-Built Spec →',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontFamily: 'Menlo'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ReverseInterviewTurn turn;
  const _ChatBubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final isUser = turn.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF78350F)
              : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(10),
          border: isUser
              ? null
              : Border.all(color: const Color(0xFF2C2C2E)),
        ),
        child: Text(
          turn.text,
          style: TextStyle(
            fontFamily: 'Menlo',
            fontSize: 13,
            height: 1.5,
            color: isUser
                ? const Color(0xFFFDE68A)
                : const Color(0xFFE5E5E7),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F10),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !isLoading,
              maxLines: null,
              style: const TextStyle(
                  fontFamily: 'Menlo', fontSize: 13, color: Color(0xFFE5E5E7)),
              decoration: const InputDecoration(
                hintText: 'Answer the question… (Enter to send)',
                hintStyle: TextStyle(color: Color(0xFF6B7280)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isLoading ? null : onSend,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFFE8A04C)),
                  )
                : const Icon(Icons.send, color: Color(0xFFE8A04C)),
          ),
        ],
      ),
    );
  }
}
```

**Note:** `AsBuiltSpecScreen` does not exist yet (created in Chunk E). The import will produce a linter error until Chunk E is done. That is expected — report it and wait.

**Verification:**
```
dart analyze lib/features/reverse_interview/
```
Expected: one import error for `as_built_spec_screen.dart` (not yet created) — that is acceptable. All other errors must be zero.

**STOP. Report results. Wait for Claude.**

---

## Chunk D — `as_built_spec_generator.dart` + `as_built_spec_notifier.dart` (2 new files)

### File 1 — `lib/features/spec_generation/as_built_spec_generator.dart`

Pure functions only — no Riverpod, no widgets.

Read `lib/features/projects/models/reverse_ingestion_summary.dart` before writing, specifically `IngestionSummary.toMarkdown()`. You will call `summary.toMarkdown()` as an `[INSTANCE]` method.

```dart
import '../projects/models/reverse_ingestion_summary.dart';

String buildAsBuiltSpecPrompt(
    IngestionSummary summary, List<Map<String, dynamic>> interviewLog) {
  final transcript = interviewLog.map((t) {
    final isUser = t['isUser'] as bool? ?? false;
    final text = t['text'] as String? ?? '';
    return '${isUser ? "ENGINEER" : "FORGE"}: $text';
  }).join('\n\n');

  return 'INGESTION SUMMARY:\n'
      '${summary.toMarkdown()}\n\n'
      'PULL INTERVIEW TRANSCRIPT:\n'
      '$transcript\n\n'
      '$_asBuiltSpecStructure';
}

const _asBuiltSpecStructure = '''
Produce an as-built spec in this exact 10-section format. Use the section headers verbatim.

## 1. Goal Statement
[The single primary goal of this system, derived from the interview]

## 2. Hard Constraints
[Non-negotiable constraints visible in code or confirmed in interview]

## 3. Component Map
[Table: Component | Single Responsibility — derived from ingestion summary]

## 4. Interface Contracts
[Key interfaces and their method signatures, from ingestion summary]

## 5. Completion Criteria
[Observable, verifiable behaviours this codebase delivers]

## 6. Static Content Specs
[Constants, configs, hardcoded values — if applicable, else "(none)"]

## 7. Out-of-Scope List
[What this codebase explicitly does NOT do — from interview]

## 8. Accepted Decisions
[Architectural decisions visible in code + rationale from interview.
As-built note: rejected alternatives not documented unless engineer stated them]

## 9. Open Flags
[Unknowns not resolved by ingestion or interview]

## 10. v2 Architecture Notes
[Future directions mentioned in interview — if none, "(none captured)"]
''';
```

### File 2 — `lib/features/spec_generation/as_built_spec_notifier.dart`

Read `lib/features/spec_generation/spec_notifier.dart` before writing. Mirror its structure exactly.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/filesystem/project_file_repository.dart';
import '../../features/projects/providers/providers.dart';
import '../../services/llm/llm_provider.dart';
import '../../services/llm/llm_service_provider.dart';
import 'as_built_spec_generator.dart';
import 'spec_parser.dart';

enum AsBuiltGenStatus { idle, generating, done, error }

class AsBuiltGenState {
  final AsBuiltGenStatus status;
  final String? specFilename;
  final String? errorMessage;

  const AsBuiltGenState({
    this.status = AsBuiltGenStatus.idle,
    this.specFilename,
    this.errorMessage,
  });
}

// Riverpod pair — DO NOT change independently:
// class AsBuiltSpecNotifier extends AutoDisposeNotifier<AsBuiltGenState>
// final asBuiltSpecProvider = NotifierProvider.autoDispose<AsBuiltSpecNotifier, AsBuiltGenState>(AsBuiltSpecNotifier.new)
// Reference: lib/features/spec_generation/spec_notifier.dart uses the identical AutoDisposeNotifier pattern.
// Provider declared ONLY in this file.
class AsBuiltSpecNotifier extends AutoDisposeNotifier<AsBuiltGenState> {
  @override
  AsBuiltGenState build() => const AsBuiltGenState();

  Future<void> generate(String projectPath, String projectName) async {
    if (state.status == AsBuiltGenStatus.generating) return;
    state = const AsBuiltGenState(status: AsBuiltGenStatus.generating);

    try {
      final repo = ref.read(projectFileRepositoryProvider);
      final service = ref.read(llmServiceProvider);

      final summary =
          await repo.readIngestionSummary(projectPath, projectName);
      // [INSTANCE — call as repo.readIngestionSummary(...)]
      if (summary == null) {
        throw Exception(
            'No ingestion summary found. Run ingestion first.');
      }

      final interviewLog =
          await repo.readReverseInterviewLog(projectPath, projectName);
      // [INSTANCE — call as repo.readReverseInterviewLog(...)]

      final prompt = buildAsBuiltSpecPrompt(summary, interviewLog);

      final rawSpec = await service.complete(
        role: LlmRole.architect,
        systemPrompt:
            'You produce structured as-built specification documents. '
            'Output only the spec — no code fences, no prose before or after.',
        userPrompt: prompt,
        temperature: 0.3,
        maxTokens: 8192,
      );

      final specContent = SpecParser.clean(rawSpec);
      await repo.writeAsBuiltSpec(projectPath, projectName, specContent);
      // [INSTANCE — call as repo.writeAsBuiltSpec(...)]

      await repo.appendAuditLog(
        projectPath,
        projectName,
        '\n## As-Built Spec Generated\n'
        '**Generated:** ${DateTime.now().toIso8601String()}\n\n',
      );
      // [INSTANCE — call as repo.appendAuditLog(...)]

      final db = ref.read(forgeDatabaseProvider);
      await db.updateProjectPhase(projectName, 'v1_as_built', 'v1');
      await ref.read(projectListProvider.notifier).refresh();

      state = AsBuiltGenState(
        status: AsBuiltGenStatus.done,
        specFilename: '${projectName}_AsBuiltSpec_v1.md',
      );
    } catch (e) {
      state = AsBuiltGenState(
        status: AsBuiltGenStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}

final asBuiltSpecProvider =
    NotifierProvider.autoDispose<AsBuiltSpecNotifier, AsBuiltGenState>(
  AsBuiltSpecNotifier.new,
);
```

**Verification:**
```
dart analyze lib/features/spec_generation/as_built_spec_generator.dart
dart analyze lib/features/spec_generation/as_built_spec_notifier.dart
```
Expected: `No issues found.` for both.

**STOP. Report results. Wait for Claude.**

---

## Chunk E — `as_built_spec_screen.dart` + `app.dart` (2 files)

### File 1 (new) — `lib/features/spec_generation/as_built_spec_screen.dart`

Read `lib/features/spec_generation/spec_generation_screen.dart` before writing. Mirror the idle/generating/done/error pattern exactly.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'as_built_spec_notifier.dart';

class AsBuiltSpecScreen extends ConsumerStatefulWidget {
  const AsBuiltSpecScreen({
    super.key,
    required this.projectPath,
    required this.projectName,
  });

  final String projectPath;
  final String projectName;

  @override
  ConsumerState<AsBuiltSpecScreen> createState() => _AsBuiltSpecScreenState();
}

class _AsBuiltSpecScreenState extends ConsumerState<AsBuiltSpecScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(asBuiltSpecProvider.notifier)
          .generate(widget.projectPath, widget.projectName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(asBuiltSpecProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Generating As-Built Spec — ${widget.projectName}'),
        automaticallyImplyLeading: false,
      ),
      body: switch (state.status) {
        AsBuiltGenStatus.idle || AsBuiltGenStatus.generating => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFFE8A04C)),
                SizedBox(height: 24),
                Text(
                  'Generating as-built spec…',
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        AsBuiltGenStatus.done => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle,
                    size: 80, color: Color(0xFF22C55E)),
                const SizedBox(height: 16),
                Text(
                  state.specFilename ?? 'AsBuiltSpec_v1.md',
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 14,
                    color: Color(0xFFE5E5E7),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'As-built spec generated.',
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Back to Projects'),
                ),
              ],
            ),
          ),
        AsBuiltGenStatus.error => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 80, color: Color(0xFFEF4444)),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    state.errorMessage ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFEF4444), fontFamily: 'Menlo'),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                      child: const Text('Back to Projects'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => ref
                          .read(asBuiltSpecProvider.notifier)
                          .generate(widget.projectPath, widget.projectName),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE8A04C),
                        foregroundColor: const Color(0xFF0F0F10),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      },
    );
  }
}
```

### File 2 (modify) — `lib/core/app.dart`

Read the full file first. Add two new routes and two new imports. Do not touch existing routes.

**Imports to add** (add after the existing reverse_ingestion imports, in alphabetical order by path):
```dart
import '../features/reverse_interview/state/reverse_interview_state.dart';
import '../features/reverse_interview/ui/reverse_interview_screen.dart';
import '../features/spec_generation/as_built_spec_screen.dart';
```

**Routes to add** (inside the `routes: { ... }` map, after the `/reverse-ingestion/summary` route):
```dart
'/reverse-interview': (context) {
  final args = ModalRoute.of(context)?.settings.arguments;
  if (args is ReverseInterviewArgs) {
    return ReverseInterviewScreen(args: args);
  }
  return const Scaffold(
    body: Center(child: Text('Invalid pull interview args')),
  );
},
'/as-built-spec': (context) {
  final args = ModalRoute.of(context)?.settings.arguments;
  if (args is Map<String, String>) {
    return AsBuiltSpecScreen(
      projectPath: args['projectPath']!,
      projectName: args['projectName']!,
    );
  }
  return const Scaffold(
    body: Center(child: Text('Invalid as-built spec args')),
  );
},
```

**Verification:**
```
dart analyze lib/features/spec_generation/as_built_spec_screen.dart
dart analyze lib/core/app.dart
dart analyze lib/features/reverse_interview/
```
All three expected: `No issues found.`

**STOP. Report results. Wait for Claude.**

---

## Chunk F — `project_detail_screen.dart` (wiring only)

**File to modify:** `lib/features/projects/screens/project_detail_screen.dart`

Read the file before editing. Locate `_ReverseModeWarningButton` — it appears in two places inside `_buildCta()`. Both are currently `const _ReverseModeWarningButton()`. Replace both with `_ReverseModeCta(projectPath: live.path, projectName: live.name)`.

Also add the new `_ReverseModeCta` widget class to the end of the file, before the final `}` of `_ReverseModeWarningButton`'s definition.

Additionally, add handling for the `v1_as_built` phase in the `_buildCta` switch so clicking "View As-Built Spec" works. But keep that simple — just add it to the default case check or as a new entry.

### Step 1 — Replace `_ReverseModeWarningButton` usages

In `_buildCta()`, find both occurrences of:
```dart
mode == ProjectMode.reverse
    ? const _ReverseModeWarningButton()
```
Replace both with:
```dart
mode == ProjectMode.reverse
    ? _ReverseModeCta(projectPath: live.path, projectName: live.name)
```

### Step 2 — Add the `_ReverseModeCta` widget

Add this class immediately after the closing `}` of `_ReverseModeWarningButton`:

```dart
class _ReverseModeCta extends ConsumerWidget {
  final String projectPath;
  final String projectName;

  const _ReverseModeCta({
    required this.projectPath,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingestionState = ref.watch(reverseIngestionNotifierProvider);
    final ingestionDone =
        ingestionState.state == rev_ingest.IngestionState.done;

    return FilledButton(
      onPressed: ingestionDone
          ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ReverseInterviewScreen(
                  args: ReverseInterviewArgs(
                    projectPath: projectPath,
                    projectName: projectName,
                  ),
                ),
              ))
          : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        backgroundColor:
            ingestionDone ? const Color(0xFFE8A04C) : const Color(0xFF2C2C2E),
        foregroundColor:
            ingestionDone ? const Color(0xFF0F0F10) : const Color(0xFF6B7280),
      ),
      child: Text(
        ingestionDone
            ? 'Start Pull Interview →'
            : 'Ingest Repo First',
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontFamily: 'Menlo'),
      ),
    );
  }
}
```

### Step 3 — Add the import for `ReverseInterviewScreen` and `ReverseInterviewArgs`

At the top of the file, in the import section (alphabetical order by path), add:
```dart
import '../ingestion/reverse_interview_state.dart';
```

Wait — the correct import path from `project_detail_screen.dart` to the pull interview state is:
```dart
import '../../reverse_interview/state/reverse_interview_state.dart';
import '../../reverse_interview/ui/reverse_interview_screen.dart';
```

**Important:** `project_detail_screen.dart` is at `lib/features/projects/screens/`. The pull interview is at `lib/features/reverse_interview/`. So the relative path from `screens/` goes up two levels (`../../`) to `features/`, then into `reverse_interview/`.

Add these two imports in alphabetical order with the existing imports.

### Step 4 — Handle `v1_as_built` phase in `_buildCta`

Locate the `_stageOf` switch inside `_buildCta`. Add a case for `'as_built'`:

Find where the switch maps phase stages (the `switch (_stageOf(live.phase))` block). Add before the default `_` case:
```dart
'as_built' => FilledButton(
    onPressed: () {/* view as-built spec — artifact viewer */},
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(44),
      backgroundColor: const Color(0xFF22C55E),
      foregroundColor: const Color(0xFF0F0F10),
    ),
    child: const Text(
      'View As-Built Spec →',
      style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Menlo'),
    ),
  ),
```

**Verification:**
```
dart analyze lib/features/projects/screens/project_detail_screen.dart
dart analyze lib/
```
Expected: `No issues found.`

**STOP. Report results to Claude. This is the final chunk.**

---

## Definition of done

Complete when:
1. `dart analyze lib/` → `No issues found.`
2. `ReverseInterviewScreen` can be navigated to from a Project Onboarding project (once ingestion is done)
3. `AsBuiltSpecScreen` is reachable from the "Generate As-Built Spec →" button
4. The as-built spec is written to `specs/v1/{ProjectName}_AsBuiltSpec_v1.md`

---

## Out of scope

- Do not add §R2 to the §W6 Spec Compliance Monitor integration — that wiring is a separate task
- Do not implement a "view as-built spec" artifact viewer — the `onPressed` stub is sufficient for now
- Do not add CONFIGURATION_MANAGEMENT.md or context.md updates — Claude handles session close
- Do not add any new `pubspec.yaml` dependencies
