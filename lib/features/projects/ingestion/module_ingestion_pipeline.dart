import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service.dart';
import '../models/pull_ingestion_summary.dart';
import 'invariant_extractor.dart';
import 'pull_codebase_ingestion_engine.dart';

class ModuleIngestionPipeline {
  ModuleIngestionPipeline(this._service);
  final LlmService _service;

  /// Pass 1: per-module LLM calls via the shared batch analyzer.
  ///
  /// [repoFiles] is the full `List<Map<String, dynamic>>` from
  /// `ProjectFileRepository.scanProjectCodebase` — each map has
  /// `filePath` (String) and `content` (String) keys.
  Future<List<ModuleIngestionResult>> ingestModules({
    required List<String> confirmedModules,
    required List<Map<String, dynamic>> repoFiles,
  }) async {
    final results = <ModuleIngestionResult>[];
    final skippedModules = <String>[];

    for (final moduleName in confirmedModules) {
      final moduleFiles = repoFiles.where((f) {
        final path = f['filePath'] as String;
        // Match on path segments, not substrings (e.g. "auth" shouldn't
        // match "authentication"). Split on / and \ and check each
        // segment equals the module name.
        final parts = path
            .replaceAll('\\', '/')
            .split('/')
            .where((p) => p.isNotEmpty);
        return parts.contains(moduleName);
      }).toList();

      if (moduleFiles.isEmpty) {
        skippedModules.add(moduleName);
        continue;
      }

      final components = await analyzeFileBatch(_service, moduleFiles);
      final deps = components.expand((c) => c.externalDependencies).toList();

      final summary = components
          .where((c) => c.responsibilities.isNotEmpty)
          .map((c) => '${c.name}: ${c.responsibilities}')
          .join('\n');

      results.add(
        ModuleIngestionResult(
          moduleName: moduleName,
          moduleSummary: summary.isEmpty ? 'No components extracted' : summary,
          components: components,
          dependencies: deps,
        ),
      );
    }

    return results;
  }

  /// Pass 2: one synthesis LLM call combining per-module results and
  /// pre-extracted invariants into a unified codebase overview.
  ///
  /// [invariants] are passed in by the caller — this method does not
  /// derive them itself.
  Future<String> synthesize({
    required List<ModuleIngestionResult> moduleResults,
    required List<ExtractedInvariant> invariants,
  }) async {
    final moduleBlock = moduleResults
        .map((m) => '## Module: ${m.moduleName}\n${m.moduleSummary}')
        .join('\n\n');

    final invariantBlock = invariants.isEmpty
        ? ''
        : '\n\n## Cross-Cutting Invariants '
                  '(pre-extracted — do not re-derive)\n' +
              invariants
                  .map((i) => '- ${i.rule} [${i.confidence.name}]')
                  .join('\n');

    return _service.complete(
      role: LlmRole.architect,
      systemPrompt:
          'You are a senior software architect. Synthesize per-module '
          'ingestion results into a unified codebase overview in markdown. '
          'Preserve invariants as-is. Do not invent details.',
      userPrompt:
          '$moduleBlock$invariantBlock\n\n'
          'Produce a unified codebase reference organized by module.',
      temperature: 0.2,
      maxTokens: 4096,
    );
  }
}
