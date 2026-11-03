import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service.dart';
import '../models/tracker_enums.dart';

/// Generates a lightweight spec snapshot from the current feature board.
/// Single LLM call — no interview, no multi-phase pipeline.
class SpecSnapshotGenerator {
  const SpecSnapshotGenerator(this._llm);
  final LlmService _llm;

  Future<String> generate({
    required String projectName,
    required List<Feature> features,
    required String projectPath,
    void Function(String label)? onProgress,
  }) async {
    onProgress?.call('Reading project context…');
    final refContext =
        await ProjectFileRepository.readReferenceContext(projectPath);

    onProgress?.call('Generating spec snapshot…');

    final shipped =
        features.where((f) => f.status == FeatureStatus.shipped).toList();
    final inProgress =
        features.where((f) => f.status == FeatureStatus.inProgress).toList();
    final planned = features
        .where((f) =>
            f.status != FeatureStatus.shipped &&
            f.status != FeatureStatus.inProgress)
        .toList();

    String _featureLine(Feature f) {
      final desc = (f.description != null && f.description!.isNotEmpty)
          ? ' — ${f.description}'
          : '';
      return '- ${f.title}$desc';
    }

    final boardSection = StringBuffer();
    if (shipped.isNotEmpty) {
      boardSection.writeln('### Shipped (${shipped.length})');
      for (final f in shipped) boardSection.writeln(_featureLine(f));
    }
    if (inProgress.isNotEmpty) {
      boardSection.writeln('\n### In Progress (${inProgress.length})');
      for (final f in inProgress) boardSection.writeln(_featureLine(f));
    }
    if (planned.isNotEmpty) {
      boardSection.writeln('\n### Planned (${planned.length})');
      for (final f in planned) boardSection.writeln(_featureLine(f));
    }

    final contextBlock = (refContext != null && refContext.isNotEmpty)
        ? '\n\n## Reference Context\n${refContext.substring(0, refContext.length.clamp(0, 3000))}'
        : '';

    final userPrompt = '''
Project: $projectName

## Feature Board
${boardSection.toString().trim()}
$contextBlock

Generate a concise spec snapshot in clean markdown with exactly these sections:
1. **What This Is** — 2-3 sentences describing the project and its purpose
2. **Status Summary** — one sentence on overall progress (${shipped.length} shipped, ${inProgress.length} in progress, ${planned.length} planned)
3. **Shipped** — brief bullet list of completed work (skip if empty)
4. **In Progress / Next** — what's actively being built (skip if empty)
5. **Planned** — remaining scope items (skip if empty)
6. **Key Decisions** — settled decisions from the reference context; skip this section entirely if none are available
7. **Scope Boundary** — what is explicitly deferred to later (if determinable from context)

Be concise. This is a living snapshot, not a formal spec. Output markdown only — no preamble.
''';

    const systemPrompt =
        'You generate concise project spec snapshots in clean markdown. '
        'Output only the requested sections. No meta-commentary, no preamble, no code fences.';

    final content = await _llm.complete(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: 0.3,
      role: LlmRole.architect,
      think: false,
    );

    return content;
  }
}
