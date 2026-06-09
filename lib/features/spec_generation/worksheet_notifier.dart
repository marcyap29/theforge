import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      final repo = ref.read(projectFileRepositoryProvider);
      final specFile =
          await repo.readLockedSpec(projectPath, projectName, specVersion);

      final llmService = ref.read(llmServiceProvider);
      final rawWorksheet = await llmService.complete(
        systemPrompt: buildWorksheetPrompt(projectName, specFile),
        userPrompt: 'Generate the setup worksheet now.',
        temperature: 0.3,
        role: LlmRole.architect,
        maxTokens: 4096,
      );

      await repo.writeWorksheet(projectPath, worksheetFilename, rawWorksheet.trim());

      final currentReadme = await repo.readReadme(projectPath) ?? '';
      final updatedReadme = currentReadme.replaceFirst(
        '**Setup worksheet:** Incomplete',
        '**Setup worksheet:** Complete',
      );
      await repo.writeReadme(projectPath, updatedReadme);

      await repo.appendAuditLog(
        projectPath,
        projectName,
        buildWorksheetAuditEntry(projectName, worksheetFilename),
      );

      await ref.read(forgeDatabaseProvider).updateProjectPhase(
            projectName,
            'v1_worksheet_complete',
            specVersion,
          );
      await ref.read(projectListProvider.notifier).refresh();

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
