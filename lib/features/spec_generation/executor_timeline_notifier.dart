import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/filesystem/project_file_repository.dart';
import '../../features/projects/providers/providers.dart';
import '../../services/llm/llm_provider.dart';
import '../../services/llm/llm_service_provider.dart';
import 'spec_generator.dart';


enum ExecutorTimelineStatus { notGenerated, generating, done, error }

class ExecutorTimelineState {
  final ExecutorTimelineStatus status;
  final String? content; // markdown content when done
  final String? error;
  const ExecutorTimelineState({required this.status, this.content, this.error});
}

class ExecutorTimelineNotifier extends AutoDisposeFamilyAsyncNotifier<ExecutorTimelineState, String> {
  @override
  Future<ExecutorTimelineState> build(String arg) async {
    try {
      final handoffsDir =
          Directory(p.join(arg, ProjectFileRepository.forgeDirName, 'handoffs'));
      if (!handoffsDir.existsSync()) {
        return const ExecutorTimelineState(status: ExecutorTimelineStatus.notGenerated);
      }

      // Collect files from version subfolders and flat root.
      final files = <File>[];
      for (final entry in handoffsDir.listSync()) {
        if (entry is Directory) {
          files.addAll(entry.listSync().whereType<File>());
        } else if (entry is File) {
          files.add(entry);
        }
      }
      final sequenceFile = files.firstWhereOrNull(
        (f) => p.basename(f.path).contains('_BuildSequence_'),
      );

      if (sequenceFile != null) {
        final content = await sequenceFile.readAsString();
        return ExecutorTimelineState(status: ExecutorTimelineStatus.done, content: content);
      }
    } catch (e) {
      // Silently fail and return notGenerated as per spec
    }
    return const ExecutorTimelineState(status: ExecutorTimelineStatus.notGenerated);
  }

  Future<void> generate(String projectName, String specVersion) async {
    if (state.value?.status == ExecutorTimelineStatus.generating) return;
    
    state = const AsyncData(ExecutorTimelineState(status: ExecutorTimelineStatus.generating));

    try {
      final repo = ref.read(projectFileRepositoryProvider);
      final llmService = ref.read(llmServiceProvider);
      final projectPath = arg;

      // 1. Read locked spec from disk
      final specContent = await repo.readLockedSpec(projectPath, projectName, specVersion);

      // 2. Build prompt
      final prompt = buildExecutorTimelinePrompt(projectName, specContent);

      // 3. Call LLM
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

extension IterableX<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
