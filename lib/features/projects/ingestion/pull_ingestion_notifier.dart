import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/llm/llm_service_provider.dart';
import '../models/pull_ingestion_summary.dart';
import '../providers/providers.dart';
import 'pull_codebase_ingestion_engine.dart';

class PullIngestionState {
  final IngestionState state;
  final String? error;

  const PullIngestionState({
    required this.state,
    this.error,
  });

  PullIngestionState copyWith({
    IngestionState? state,
    String? error,
  }) {
    return PullIngestionState(
      state: state ?? this.state,
      error: error ?? this.error,
    );
  }
}

class PullIngestionNotifier extends Notifier<PullIngestionState> {
  @override
  PullIngestionState build() {
    return const PullIngestionState(state: IngestionState.idle);
  }

  Future<void> startIngestion(String projectPath) async {
    state = state.copyWith(state: IngestionState.scanning);

    try {
      final repo = ref.watch(projectFileRepositoryProvider);
      final service = ref.watch(llmServiceProvider);

      state = state.copyWith(state: IngestionState.scanning);

      final extensions = ['.dart', '.swift', '.ts', '.js', '.py'];
      final files = await repo.scanProjectCodebase(projectPath, extensions);

      if (files.isEmpty) {
        state = state.copyWith(state: IngestionState.error, error: 'No supported files found');
        return;
      }

      state = state.copyWith(state: IngestionState.processing);

      final allComponents = <ComponentInfo>[];
      final allDependencies = <DependencyInfo>[];
      final allPatterns = <InfrastructurePattern>[];

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final filePath = file['filePath'] as String;

        final components = await extractComponentInfo(service, filePath, file['content'] as String);

        for (final component in components) {
          allComponents.add(component);
          allDependencies.addAll(component.externalDependencies);
          allPatterns.addAll(component.infrastructurePatterns);
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      final gaps = identifyGaps(allComponents);
      final projectName = _extractProjectName(projectPath);

      final summary = aggregateComponents(
        projectName: projectName,
        projectPath: projectPath,
        fileCount: files.length,
        components: allComponents,
        dependencies: allDependencies,
        patterns: allPatterns,
        gaps: gaps,
      );

      await repo.writeIngestionSummary(projectPath, projectName, summary);

      state = state.copyWith(state: IngestionState.done);
    } catch (e) {
      state = state.copyWith(state: IngestionState.error, error: e.toString());
    }
  }

  Future<void> clearIngestion() async {
    state = const PullIngestionState(state: IngestionState.idle);
  }

  String _extractProjectName(String projectPath) {
    final parts = projectPath.split('/');
    return parts.isNotEmpty ? parts.last : 'Unknown';
  }
}

final pullIngestionNotifierProvider =
    NotifierProvider<PullIngestionNotifier, PullIngestionState>(
  PullIngestionNotifier.new,
);
