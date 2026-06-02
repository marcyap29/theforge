import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/interview_providers.dart';
import 'interview_state.dart';

typedef StubLlmResult = ({
  String interviewerText,
  Map<ConfidenceDimension, DimensionState> confidenceUpdates,
  List<ConflictItem> newConflicts,
});

StubLlmResult stubInterviewStep(InterviewState state, String userMessage) {
  final userTurnCount = state.turns.where((t) => t.isUser).length;
  final hasOpenConflict = state.openConflicts.isNotEmpty;

  switch (userTurnCount) {
    case 1:
      return (
        interviewerText:
            'Got it. ${ConfidenceDimension.primaryUser.question}',
        confidenceUpdates: const {
          ConfidenceDimension.corePurpose: DimensionState.resolved,
        },
        newConflicts: const [],
      );
    case 2:
      return (
        interviewerText:
            'Understood. ${ConfidenceDimension.identityModel.question}',
        confidenceUpdates: const {
          ConfidenceDimension.primaryUser: DimensionState.resolved,
        },
        newConflicts: const [],
      );
    case 3:
      return (
        interviewerText: 'I want to flag a tension here.\n\n${_stubConflict.description}',
        confidenceUpdates: const {
          ConfidenceDimension.identityModel: DimensionState.partial,
        },
        newConflicts: const [_stubConflict],
      );
    case 4:
      return (
        interviewerText: 'Acknowledged. ${ConfidenceDimension.inputModel.question}',
        confidenceUpdates: {
          ConfidenceDimension.identityModel: DimensionState.resolved,
        },
        newConflicts: const [],
      );
    case 5:
      return (
        interviewerText:
            'Understood. ${ConfidenceDimension.outputModel.question}',
        confidenceUpdates: const {
          ConfidenceDimension.inputModel: DimensionState.resolved,
        },
        newConflicts: const [],
      );
    case 6:
      return (
        interviewerText: 'Got it. ${ConfidenceDimension.platform.question}',
        confidenceUpdates: const {
          ConfidenceDimension.outputModel: DimensionState.resolved,
        },
        newConflicts: const [],
      );
    case 7:
      return (
        interviewerText:
            'Understood. ${ConfidenceDimension.scopeBoundary.question}',
        confidenceUpdates: const {
          ConfidenceDimension.platform: DimensionState.resolved,
        },
        newConflicts: const [],
      );
    case 8:
      return (
        interviewerText:
            'Got it. ${ConfidenceDimension.externalServices.question}',
        confidenceUpdates: const {
          ConfidenceDimension.scopeBoundary: DimensionState.resolved,
        },
        newConflicts: const [],
      );
    case 9:
      return (
        interviewerText:
            'All 8 dimensions resolved. Click Generate Spec when you are ready.',
        confidenceUpdates: const {
          ConfidenceDimension.externalServices: DimensionState.resolved,
        },
        newConflicts: const [],
      );
    default:
      if (hasOpenConflict) {
        return (
          interviewerText: _stubConflict.description,
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
}

const _stubConflict = ConflictItem(
  id: 'corePurpose_identityModel',
  dimensionA: ConfidenceDimension.corePurpose,
  dimensionB: ConfidenceDimension.identityModel,
  description:
      'Your answers on Core purpose and Identity model pull in opposite '
      'directions. A simple core job typically needs no identity. A '
      'user-account system adds friction and complexity. I recommend '
      '"no accounts" for v1 because it keeps the core job single-purpose '
      'and shipping fast. Do you accept this scope?',
  recommendation: 'No accounts for v1',
);

class InterviewNotifier extends FamilyAsyncNotifier<InterviewState, InterviewArgs> {
  @override
  Future<InterviewState> build(InterviewArgs args) async {
    return InterviewState.empty(args.path, args.name);
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

    await Future<void>.delayed(const Duration(milliseconds: 400));

    // §5 LLM STUB: replace with `await llmProvider.complete(...)` when §4 lands.
    // Single call site — search for `stubInterviewStep` to find it.
    final stub = stubInterviewStep(withUser, text);

    final newMap = Map<ConfidenceDimension, DimensionState>.from(
      withUser.confidenceMap,
    );
    stub.confidenceUpdates.forEach((k, v) => newMap[k] = v);
    final allResolved =
        newMap.values.every((s) => s == DimensionState.resolved);
    final newConflicts = [...withUser.openConflicts, ...stub.newConflicts];
    final specGenEnabled = allResolved && newConflicts.isEmpty;

    final interviewerTurn = InterviewTurn(
      role: 'interviewer',
      content: stub.interviewerText,
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
      InterviewState.empty(current.projectPath, current.projectName),
    );
  }
}
