import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service_provider.dart';
import '../providers/interview_providers.dart';
import 'interview_dimension.dart';
import 'interview_state.dart';

typedef StubLlmResult = ({
  String interviewerText,
  Map<String, DimensionState> confidenceUpdates,
  List<ConflictItem> newConflicts,
});

ConflictItem _stubConflictFor(InterviewState state) {
  final a = state.dimensions[0].label;
  final b = state.dimensions[2].label;
  return ConflictItem(
    id: '${state.dimensions[0].id}_${state.dimensions[2].id}',
    dimensionALabel: a,
    dimensionBLabel: b,
    description:
        'Your answers on $a and $b pull in opposite directions. '
        '$a implies one direction. $b implies another. '
        'I recommend the conservative reading for v1 because it keeps '
        'the spec internally consistent. Do you accept this scope?',
    recommendation: 'Conservative $a for v1',
  );
}

StubLlmResult stubInterviewStep(InterviewState state, String userMessage) {
  final userTurnCount = state.turns.where((t) => t.isUser).length;
  final hasOpenConflict = state.openConflicts.isNotEmpty;
  final dims = state.dimensions;
  final total = dims.length;

  if (userTurnCount == 3 && total >= 3) {
    final conflict = _stubConflictFor(state);
    return (
      interviewerText: 'I want to flag a tension here.\n\n${conflict.description}',
      confidenceUpdates: {dims[2].id: DimensionState.partial},
      newConflicts: [conflict],
    );
  }

  if (userTurnCount >= 1 && userTurnCount <= 2 && total >= userTurnCount) {
    final resolvedIndex = userTurnCount - 1;
    final nextIndex = userTurnCount;
    return (
      interviewerText: 'Understood. ${dims[nextIndex].question}',
      confidenceUpdates: {dims[resolvedIndex].id: DimensionState.resolved},
      newConflicts: const [],
    );
  }

  if (userTurnCount >= 4 && userTurnCount <= total + 1 && total >= 3) {
    final resolvedIndex = userTurnCount - 2;
    if (userTurnCount == total + 1) {
      return (
        interviewerText:
            'All $total dimensions resolved. Click Generate Spec when you are ready.',
        confidenceUpdates: {dims[resolvedIndex].id: DimensionState.resolved},
        newConflicts: const [],
      );
    }
    final nextIndex = userTurnCount - 1;
    return (
      interviewerText: 'Understood. ${dims[nextIndex].question}',
      confidenceUpdates: {dims[resolvedIndex].id: DimensionState.resolved},
      newConflicts: const [],
    );
  }

  if (userTurnCount > total + 1 || (total < 3 && userTurnCount > total)) {
    if (hasOpenConflict) {
      return (
        interviewerText: _stubConflictFor(state).description,
        confidenceUpdates: const {},
        newConflicts: const [],
      );
    }
    return (
      interviewerText: 'Interview complete. Nothing left to ask.',
      confidenceUpdates: const {},
      newConflicts: const [],
    );
  }

  return (
    interviewerText: dims[0].question,
    confidenceUpdates: const {},
    newConflicts: const [],
  );
}

String _interviewSystemPrompt(InterviewState state) {
  final modeLabel =
      state.dimensions == buildDimensions ? 'Build Interview' : 'Audit Interview';

  final resolved = state.dimensions
      .where((d) => state.confidenceMap[d.id] == DimensionState.resolved)
      .map((d) => d.label)
      .join(', ');
  final remaining = state.dimensions
      .where((d) => state.confidenceMap[d.id] != DimensionState.resolved)
      .map((d) => '${d.label}: ${d.question}')
      .join('\n');

  return '''You are The Forge interviewer — a sharp, direct product architect
running a $modeLabel for a project called "${state.projectName}".

Your goal: resolve ${state.dimensions.length} confidence dimensions through conversation.
Ask ONE question per turn. Be concise. Acknowledge the user's answer first.

Resolved so far: ${resolved.isEmpty ? 'none yet' : resolved}
Still needed:
$remaining

If a conflict exists between answers, surface it with:
"Your answers on [X] and [Y] pull in opposite directions. [X] implies [A]. [Y] implies [B].
I recommend [conservative option] for v1 because [reason]. Do you accept this scope?"

Do not ask about resolved dimensions. If all are resolved, confirm and stop.''';
}

class InterviewNotifier extends FamilyAsyncNotifier<InterviewState, InterviewArgs> {
  @override
  Future<InterviewState> build(InterviewArgs args) async {
    final dims = dimensionsFor(args.mode);
    return InterviewState.empty(args.path, args.name, dims);
  }

  Future<void> addUserMessage(String text) async {
    final initial = state.valueOrNull;
    if (initial == null || initial.isLoading) return;
    if (text.trim().isEmpty) return;

    final userTurn = InterviewTurn(
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );
    final withUser = initial.copyWith(
      turns: [...initial.turns, userTurn],
      isLoading: true,
    );
    state = AsyncData(withUser);

    final llmService = ref.read(llmServiceProvider);
    String llmText;
    try {
      llmText = await llmService.complete(
        systemPrompt: _interviewSystemPrompt(withUser),
        userPrompt: text.trim(),
        temperature: 0.1,
        role: LlmRole.executor,
      );
    } catch (e) {
      llmText =
          'Connection error: $e\n\nCheck Settings to configure a provider.';
    }

    final stub = stubInterviewStep(withUser, text);

    final newMap = Map<String, DimensionState>.from(withUser.confidenceMap);
    stub.confidenceUpdates.forEach((k, v) => newMap[k] = v);
    final allResolved =
        newMap.values.every((s) => s == DimensionState.resolved);
    final newConflicts = [...withUser.openConflicts, ...stub.newConflicts];
    final specGenEnabled = allResolved && newConflicts.isEmpty;

    final interviewerTurn = InterviewTurn(
      role: 'interviewer',
      content: llmText,
      timestamp: DateTime.now(),
    );

    state = AsyncData(
      withUser.copyWith(
        confidenceMap: newMap,
        turns: [...withUser.turns, interviewerTurn],
        openConflicts: newConflicts,
        specGenEnabled: specGenEnabled,
        isLoading: false,
      ),
    );
  }

  void resolveConflict(String conflictId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.openConflicts
        .where((c) => c.id != conflictId)
        .toList(growable: false);
    final allResolved = current.confidenceMap.values
        .every((s) => s == DimensionState.resolved);
    state = AsyncData(
      current.copyWith(
        openConflicts: updated,
        specGenEnabled: allResolved && updated.isEmpty,
      ),
    );
  }

  void reset() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      InterviewState.empty(
        current.projectPath,
        current.projectName,
        current.dimensions,
      ),
    );
  }
}
