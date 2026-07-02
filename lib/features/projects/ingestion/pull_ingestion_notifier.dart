import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/llm/llm_service_provider.dart';
import '../models/pull_ingestion_summary.dart';
import '../providers/providers.dart';
import 'invariant_extractor.dart';
import 'module_discovery.dart';
import 'module_ingestion_pipeline.dart';
import 'pull_codebase_ingestion_engine.dart';

class PullIngestionState {
  final IngestionState state;
  final String? error;
  final IngestionTier tier;
  final List<String>? detectedModules;

  const PullIngestionState({
    required this.state,
    this.error,
    this.tier = IngestionTier.single,
    this.detectedModules,
  });

  PullIngestionState copyWith({
    IngestionState? state,
    String? error,
    IngestionTier? tier,
    List<String>? detectedModules,
  }) {
    return PullIngestionState(
      state: state ?? this.state,
      error: error ?? this.error,
      tier: tier ?? this.tier,
      detectedModules: detectedModules ?? this.detectedModules,
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
        state = state.copyWith(
          state: IngestionState.error,
          error: 'No supported files found',
        );
        return;
      }

      // Module discovery — deterministic, no LLM call
      final discovery = await ModuleDiscovery().discover(
        repoPath: projectPath,
        fileCount: files.length,
      );

      if (discovery.tier == IngestionTier.moduleAware) {
        state = state.copyWith(
          state: IngestionState.awaitingConfirmation,
          tier: IngestionTier.moduleAware,
          detectedModules: discovery.moduleNames,
        );
        return; // confirmModules() resumes execution
      }

      state = state.copyWith(state: IngestionState.processing);

      final allComponents = <ComponentInfo>[];
      final allDependencies = <DependencyInfo>[];
      final allPatterns = <InfrastructurePattern>[];

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final filePath = file['filePath'] as String;

        final components = await extractComponentInfo(
          service,
          filePath,
          file['content'] as String,
        );

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

      state = state.copyWith(state: IngestionState.aggregating);

      final invariants = await InvariantExtractor(service).extract(
        referenceContext: summary.toMarkdown(),
        components: summary.components,
      );
      final summaryWithInvariants = summary.copyWith(invariants: invariants);
      await repo.writeIngestionSummary(
        projectPath,
        projectName,
        summaryWithInvariants,
      );

      state = state.copyWith(state: IngestionState.done);
    } catch (e) {
      state = state.copyWith(state: IngestionState.error, error: e.toString());
    }
  }

  Future<void> confirmModules(
    List<String> confirmed,
    String projectPath,
  ) async {
    state = state.copyWith(state: IngestionState.processing);

    try {
      final repo = ref.watch(projectFileRepositoryProvider);
      final service = ref.watch(llmServiceProvider);

      final extensions = ['.dart', '.swift', '.ts', '.js', '.py'];
      final files = await repo.scanProjectCodebase(projectPath, extensions);

      final pipeline = ModuleIngestionPipeline(service);
      final moduleResults = await pipeline.ingestModules(
        confirmedModules: confirmed,
        repoFiles: files,
      );

      state = state.copyWith(state: IngestionState.synthesizing);
      final synthesizedOverview = await pipeline.synthesize(
        moduleResults: moduleResults,
        invariants: const [],
      );

      final allComponents = moduleResults.expand((m) => m.components).toList();
      final allDeps = moduleResults.expand((m) => m.dependencies).toList();

      state = state.copyWith(state: IngestionState.aggregating);

      final invariants = await InvariantExtractor(service).extract(
        referenceContext: synthesizedOverview,
        components: allComponents,
      );

      final projectName = _extractProjectName(projectPath);
      final gaps = identifyGaps(allComponents);

      final summary =
          aggregateComponents(
            projectName: projectName,
            projectPath: projectPath,
            fileCount: files.length,
            components: allComponents,
            dependencies: allDeps,
            patterns: const [],
            gaps: gaps,
          ).copyWith(
            tier: IngestionTier.moduleAware,
            moduleResults: moduleResults,
            invariants: invariants,
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
