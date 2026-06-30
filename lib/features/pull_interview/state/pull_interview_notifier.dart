import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/projects/models/pull_ingestion_summary.dart';
import '../../../features/projects/providers/providers.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service_provider.dart';
import 'pull_interview_state.dart';

class PullInterviewNotifier
    extends FamilyAsyncNotifier<PullInterviewState, PullInterviewArgs> {
  @override
  Future<PullInterviewState> build(PullInterviewArgs arg) async {
    final repo = ref.watch(projectFileRepositoryProvider);
    final summary =
        await repo.readIngestionSummary(arg.projectPath, arg.projectName);

    final greeting = _buildGreeting(summary, arg.projectName);
    return PullInterviewState(
      projectPath: arg.projectPath,
      projectName: arg.projectName,
      turns: [PullInterviewTurn(isUser: false, text: greeting)],
    );
  }

  Future<void> addUserMessage(String text) async {
    final current = state.requireValue;
    if (current.isLoading) return;

    final withUser = current.copyWith(
      turns: [
        ...current.turns,
        PullInterviewTurn(isUser: true, text: text),
      ],
      isLoading: true,
    );
    state = AsyncData(withUser);

    try {
      final repo = ref.read(projectFileRepositoryProvider);
      final service = ref.read(llmServiceProvider);
      final summary = await repo.readIngestionSummary(
          current.projectPath, current.projectName);

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
          PullInterviewTurn(isUser: false, text: response),
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

  Future<void> markComplete() async {
    final current = state.requireValue;
    final repo = ref.read(projectFileRepositoryProvider);
    await repo.writePullInterviewLog(
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

    return 'You are The Forge pull mode engineer. You are interviewing an '
        'engineer about an existing codebase called "$projectName" to capture '
        'context the code alone cannot provide.\n\n'
        '$summaryBlock$gapsBlock\n\n'
        'RULES:\n'
        '- Ask only about what the code does NOT reveal\n'
        '- One question per turn, concise\n'
        '- When a gap is addressed, move to the next\n'
        '- Do not re-ask what the ingestion summary already captured\n'
        '- When all gaps are addressed, say: "I have what I need. Tap '
        '\'Generate As-Built Spec\' when you\'re ready."';
  }
}
