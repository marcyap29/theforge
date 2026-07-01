import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/projects/providers/providers.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service_provider.dart';

class AddendumInterviewArgs {
  final String projectPath;
  final String projectName;
  final String baseVersion;
  const AddendumInterviewArgs({
    required this.projectPath,
    required this.projectName,
    required this.baseVersion,
  });
}

class AddendumTurn {
  final bool isUser;
  final String text;
  const AddendumTurn({required this.isUser, required this.text});
}

class AddendumInterviewState {
  final String projectPath;
  final String projectName;
  final String baseVersion;
  final String minorVersion;
  final List<AddendumTurn> turns;
  final bool isLoading;
  final bool isComplete;
  final String? specFilename;
  final String? error;

  const AddendumInterviewState({
    required this.projectPath,
    required this.projectName,
    required this.baseVersion,
    required this.minorVersion,
    required this.turns,
    this.isLoading = false,
    this.isComplete = false,
    this.specFilename,
    this.error,
  });

  AddendumInterviewState copyWith({
    List<AddendumTurn>? turns,
    bool? isLoading,
    bool? isComplete,
    String? specFilename,
    String? error,
  }) =>
      AddendumInterviewState(
        projectPath: projectPath,
        projectName: projectName,
        baseVersion: baseVersion,
        minorVersion: minorVersion,
        turns: turns ?? this.turns,
        isLoading: isLoading ?? this.isLoading,
        isComplete: isComplete ?? this.isComplete,
        specFilename: specFilename ?? this.specFilename,
        error: error ?? this.error,
      );
}

class AddendumInterviewNotifier extends FamilyAsyncNotifier<
    AddendumInterviewState, AddendumInterviewArgs> {
  @override
  Future<AddendumInterviewState> build(AddendumInterviewArgs arg) async {
    final repo = ref.watch(projectFileRepositoryProvider);
    final minorVersion = '${arg.baseVersion}.1';

    String? baseSpec;
    try {
      final file = await repo.findSpecFile(arg.projectPath, arg.baseVersion);
      baseSpec = file != null ? await file.readAsString() : null;
    } catch (_) {}

    final greeting = baseSpec != null
        ? 'I\'ve reviewed ${arg.projectName} ${arg.baseVersion}. '
            'What would you like to add or change in $minorVersion?'
        : 'We\'re creating an addendum to ${arg.projectName} ${arg.baseVersion}. '
            'What would you like to add or change in $minorVersion?';

    return AddendumInterviewState(
      projectPath: arg.projectPath,
      projectName: arg.projectName,
      baseVersion: arg.baseVersion,
      minorVersion: minorVersion,
      turns: [AddendumTurn(isUser: false, text: greeting)],
    );
  }

  Future<void> addUserMessage(String text) async {
    final current = state.requireValue;
    if (current.isLoading) return;

    final withUser = current.copyWith(
      turns: [...current.turns, AddendumTurn(isUser: true, text: text)],
      isLoading: true,
    );
    state = AsyncData(withUser);

    try {
      final repo = ref.read(projectFileRepositoryProvider);
      final service = ref.read(llmServiceProvider);

      String? baseSpec;
      try {
        final file =
            await repo.findSpecFile(current.projectPath, current.baseVersion);
        baseSpec = file != null ? await file.readAsString() : null;
      } catch (_) {}

      final systemPrompt = '''You are The Forge interviewer helping extend a spec.
Project: ${current.projectName}
Base version: ${current.baseVersion}
Creating: ${current.minorVersion}

${baseSpec != null ? 'BASE SPEC:\n$baseSpec\n\n' : ''}RULES:
- Ask one focused question per turn to clarify what the user wants to add
- After 2-3 turns, when you have enough detail, say exactly:
  "I have what I need. Tap 'Generate ${current.minorVersion} Spec' when ready."
- Do not suggest large rewrites — focus only on targeted additions''';

      final history = withUser.turns
          .map((t) => '${t.isUser ? "USER" : "FORGE"}: ${t.text}')
          .join('\n\n');

      final response = await service.complete(
        role: LlmRole.architect,
        systemPrompt: systemPrompt,
        userPrompt: history,
        temperature: 0.4,
        maxTokens: 512,
      );

      state = AsyncData(withUser.copyWith(
        turns: [...withUser.turns, AddendumTurn(isUser: false, text: response)],
        isLoading: false,
      ));
    } catch (e) {
      state =
          AsyncData(withUser.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> generateMinorSpec() async {
    final current = state.requireValue;
    if (current.isLoading) return;
    state = AsyncData(current.copyWith(isLoading: true));

    try {
      final repo = ref.read(projectFileRepositoryProvider);
      final service = ref.read(llmServiceProvider);

      String? baseSpec;
      try {
        final file =
            await repo.findSpecFile(current.projectPath, current.baseVersion);
        baseSpec = file != null ? await file.readAsString() : null;
      } catch (_) {}

      final transcript = current.turns
          .map((t) => '${t.isUser ? "USER" : "FORGE"}: ${t.text}')
          .join('\n\n');

      final prompt =
          '${baseSpec != null ? 'BASE SPEC (${current.baseVersion}):\n$baseSpec\n\n' : ''}'
          'ADDENDUM INTERVIEW TRANSCRIPT:\n$transcript\n\n'
          'Produce a ${current.minorVersion} addendum spec in this exact format:\n\n'
          '# ${current.projectName} — ${current.minorVersion} Addendum Spec\n\n'
          '## Base Version\n${current.baseVersion}\n\n'
          '## Addendum Summary\n[One sentence describing what this addendum adds]\n\n'
          '## New or Changed Capabilities\n[Bullet list of additions/changes only]\n\n'
          '## Updated Constraints\n[Any constraints added or tightened — if none, "(none)"]\n\n'
          '## Out-of-Scope (this addendum)\n[What was NOT included — if none, "(none)"]\n\n'
          'Output only the spec — no preamble, no code fences.';

      final spec = await service.complete(
        role: LlmRole.architect,
        systemPrompt: 'You produce concise addendum spec documents.',
        userPrompt: prompt,
        temperature: 0.3,
        maxTokens: 2048,
      );

      await repo.writeMinorLockedSpec(
        current.projectPath,
        current.projectName,
        current.minorVersion,
        spec,
      );

      state = AsyncData(current.copyWith(
        isLoading: false,
        isComplete: true,
        specFilename:
            '${current.projectName}_LockedSpec_${current.minorVersion}.md',
      ));
    } catch (e) {
      state = AsyncData(
          state.requireValue.copyWith(isLoading: false, error: e.toString()));
    }
  }
}

final addendumInterviewProvider = AsyncNotifierProviderFamily<
    AddendumInterviewNotifier,
    AddendumInterviewState,
    AddendumInterviewArgs>(AddendumInterviewNotifier.new);
