import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/filesystem/project_file_repository.dart';
import '../../features/projects/providers/providers.dart';
import '../../services/llm/llm_provider.dart';
import '../../services/llm/llm_service_provider.dart';
import '../interview/state/interview_state.dart';
import 'spec_generator.dart';
import 'spec_parser.dart';

enum SpecGenStatus { idle, generating, done, error }

class SpecGenState {
  final SpecGenStatus status;
  final String? specFilename;
  final String? errorMessage;
  const SpecGenState({
    this.status = SpecGenStatus.idle,
    this.specFilename,
    this.errorMessage,
  });
}

class SpecNotifier extends AutoDisposeNotifier<SpecGenState> {
  @override
  SpecGenState build() => const SpecGenState();

  Future<void> generate(InterviewState interviewState) async {
    if (state.status == SpecGenStatus.generating) return;
    state = const SpecGenState(status: SpecGenStatus.generating);

    const specVersion = 'v1';
    final projectName = interviewState.projectName;
    final projectPath = interviewState.projectPath;
    final specFilename = '${projectName}_LockedSpec_$specVersion.md';

    try {
      final llmService = ref.read(llmServiceProvider);
      final rawSpec = await llmService.complete(
        systemPrompt: buildSpecPrompt(interviewState),
        userPrompt: 'Generate the complete locked spec now.',
        temperature: 0.6,
        role: LlmRole.architect,
        maxTokens: 4096,
      );
      final specContent = SpecParser.clean(rawSpec);

      final repo = ref.read(projectFileRepositoryProvider);

      await repo.writeLockedSpec(
          projectPath, projectName, specVersion, specContent);

      final handoffContent =
          buildBulletHandoff(interviewState, specVersion);
      await repo.writeHandoff(
        projectPath,
        '${projectName}_BulletHandoff_${specVersion}_Interview.md',
        handoffContent,
      );

      final settings = ref.read(llmSettingsProvider);
      final providerName = settings
              .roleAssignments[LlmRole.architect]
              ?.providerType
              .name ??
          'unknown';
      await repo.appendAuditLog(
        projectPath,
        projectName,
        buildAuditEntry(projectName, specVersion, providerName),
      );

      final currentReadme = await repo.readReadme(projectPath) ?? '';
      final updatedReadme = _updateReadme(currentReadme, specVersion);
      await repo.writeReadme(projectPath, updatedReadme);

      final db = ref.read(forgeDatabaseProvider);
      await db.updateProjectPhase(projectName, 'v1_spec_locked', specVersion);

      await ref.read(projectListProvider.notifier).refresh();

      state = SpecGenState(
          status: SpecGenStatus.done, specFilename: specFilename);
    } on SpecAlreadyExistsException {
      state = const SpecGenState(
        status: SpecGenStatus.done,
        specFilename: 'already exists',
      );
    } catch (e) {
      state = SpecGenState(
          status: SpecGenStatus.error, errorMessage: e.toString());
    }
  }

  String _updateReadme(String current, String specVersion) {
    return current
        .replaceFirst(RegExp(r'\*\*Current phase:\*\*.*'),
            '**Current phase:** v1_spec_locked')
        .replaceFirst(RegExp(r'\*\*Spec version:\*\*.*'),
            '**Spec version:** $specVersion')
        .replaceFirst(
            '## What\'s Next\n- Begin Build Interview\n',
            '## What\'s Next\n- Review locked spec\n- Begin Setup Worksheet\n')
        .replaceFirst(
            '## What\'s Next\n- Begin Audit Interview\n',
            '## What\'s Next\n- Review locked spec\n- Begin Setup Worksheet\n');
  }
}
