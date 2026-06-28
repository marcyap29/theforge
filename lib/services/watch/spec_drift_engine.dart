import '../../data/filesystem/project_file_repository.dart';

class SpecDriftResult {
  final String projectName;
  final String projectPath;
  final String specVersion;
  final int driftScore;
  final int failedCount;
  final int uncertainCount;
  final DateTime checkedAt;

  const SpecDriftResult({
    required this.projectName,
    required this.projectPath,
    required this.specVersion,
    required this.driftScore,
    required this.failedCount,
    required this.uncertainCount,
    required this.checkedAt,
  });
}

class SpecDriftEngine {
  static Future<SpecDriftResult?> evaluateProject(
    String projectPath,
    String projectName,
  ) async {
    String? specVersion;
    Map<String, dynamic>? handoff;
    for (final v in ['v3', 'v2', 'v1']) {
      final pkg = await ProjectFileRepository.readHandoffPackage(
        projectPath, projectName, v,
      );
      if (pkg != null &&
          (pkg['verificationChecklist'] as List<dynamic>? ?? []).isNotEmpty) {
        specVersion = v;
        handoff = pkg;
        break;
      }
    }
    if (handoff == null) return null;

    final projectConfig =
        await ProjectFileRepository.readProjectConfig(projectPath);
    final repoPath = projectConfig['repoPath'] as String?;
    if (repoPath == null) return null;

    final lockedAt = handoff['lockedAt'] as String?;
    if (lockedAt == null) return null;

    final changedFiles = await ProjectFileRepository.getGitChangedFiles(
      repoPath,
      since: lockedAt,
    );

    final checklistRaw =
        handoff['verificationChecklist'] as List<dynamic>;
    final checklist = checklistRaw.whereType<Map<String, dynamic>>().toList();

    int failedCount = 0;
    int uncertainCount = 0;

    for (final item in checklist) {
      final autoVerifiable = item['autoVerifiable'] as bool? ?? false;
      if (!autoVerifiable) continue;

      final expectedFiles =
          ((item['expectedFiles'] as List<dynamic>?) ?? []).cast<String>();
      final matched = expectedFiles.where((f) => changedFiles.contains(f)).toList();

      if (matched.length == expectedFiles.length) {
      } else if (matched.isNotEmpty) {
        uncertainCount++;
      } else {
        failedCount++;
      }
    }

    final driftScore =
        (failedCount * 10 + uncertainCount * 3).clamp(0, 100);

    return SpecDriftResult(
      projectName: projectName,
      projectPath: projectPath,
      specVersion: specVersion!,
      driftScore: driftScore,
      failedCount: failedCount,
      uncertainCount: uncertainCount,
      checkedAt: DateTime.now(),
    );
  }
}
