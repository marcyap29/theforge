import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/projects/providers/providers.dart';
import '../../services/llm/llm_provider.dart';
import '../../services/llm/llm_service_provider.dart';
import 'as_built_spec_generator.dart';

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
      if (summary == null) {
        throw Exception('No ingestion summary found. Run ingestion first.');
      }

      final interviewLog =
          await repo.readReverseInterviewLog(projectPath, projectName);

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

      await repo.writeAsBuiltSpec(projectPath, projectName, rawSpec);

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
