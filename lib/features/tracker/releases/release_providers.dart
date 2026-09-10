import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../models/tracker_enums.dart';
import '../providers/tracker_providers.dart';

/// Per-project release list, keyed by project id.
final releaseListProvider =
    AsyncNotifierProvider.family<ReleaseListNotifier, List<Release>, String>(
  ReleaseListNotifier.new,
);

class ReleaseListNotifier extends FamilyAsyncNotifier<List<Release>, String> {
  String get _projectId => arg;

  @override
  Future<List<Release>> build(String arg) {
    final repo = ref.watch(trackerRepositoryProvider);
    return repo.releasesForProject(arg);
  }

  /// Ensures a `planned` release row exists for [version] (called when a
  /// feature ships under that version).
  Future<void> ensureForVersion(String version, {String? projectPath}) async {
    final repo = ref.read(trackerRepositoryProvider);
    await repo.ensureRelease(_projectId, version, projectPath: projectPath);
    ref.invalidateSelf();
  }

  /// Cuts a release: generates notes from the version's shipped features,
  /// prepends them to the linked repo's CHANGELOG.md, optionally git-tags the
  /// repo, and marks the release `released`.
  Future<Release> cut({
    required Release release,
    required List<Feature> shippedFeatures,
    required String projectName,
    String? repoPath,
    String? projectPath,
    bool tagRepo = false,
  }) async {
    final repo = ref.read(trackerRepositoryProvider);
    final notes = buildNotes(projectName, release.version, shippedFeatures);

    String? gitTag;
    if (repoPath != null && Directory(repoPath).existsSync()) {
      await _prependChangelog(repoPath, release.version, notes);
      if (tagRepo) {
        final ok = await ProjectFileRepository.gitTag(repoPath, release.version,
            message: 'Release ${release.version}');
        if (ok) gitTag = release.version;
      }
    }

    final updated = release.copyWith(
      status: 'released',
      releasedAt: Value(DateTime.now().millisecondsSinceEpoch),
      notes: Value(notes),
      gitTag: Value(gitTag),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await repo.saveRelease(updated, projectPath: projectPath);
    ref.invalidateSelf();
    return updated;
  }

  /// Ensures a release row for [version] then cuts it — the one call the
  /// Releases screen uses.
  Future<Release> cutVersion({
    required String version,
    required List<Feature> allFeatures,
    required String projectName,
    String? repoPath,
    String? projectPath,
    bool tagRepo = false,
  }) async {
    final repo = ref.read(trackerRepositoryProvider);
    final release =
        await repo.ensureRelease(_projectId, version, projectPath: projectPath);
    return cut(
      release: release,
      shippedFeatures: shippedInVersion(allFeatures, version),
      projectName: projectName,
      repoPath: repoPath,
      projectPath: projectPath,
      tagRepo: tagRepo,
    );
  }

  /// Deterministic release notes (markdown) from the shipped features.
  static String buildNotes(
      String projectName, String version, List<Feature> shipped) {
    final b = StringBuffer()
      ..writeln('## $version')
      ..writeln();
    if (shipped.isEmpty) {
      b.writeln('_No shipped features recorded for this version._');
    } else {
      for (final f in shipped) {
        b.writeln('- **${f.title}**'
            '${f.description != null && f.description!.trim().isNotEmpty ? ' — ${f.description!.trim()}' : ''}');
      }
    }
    return b.toString().trimRight();
  }

  Future<void> _prependChangelog(
      String repoPath, String version, String notes) async {
    final file = File(p.join(repoPath, 'CHANGELOG.md'));
    const header = '# Changelog\n\n';
    if (!file.existsSync()) {
      await file.writeAsString('$header$notes\n');
      return;
    }
    final existing = await file.readAsString();
    if (existing.startsWith('# Changelog')) {
      final body = existing.substring(existing.indexOf('\n') + 1).trimLeft();
      await file.writeAsString('$header$notes\n\n$body');
    } else {
      await file.writeAsString('$header$notes\n\n$existing');
    }
  }
}

/// Groups a project's features by their target version for the Releases view.
/// Features with no target version fall under a synthetic "Unversioned" bucket.
Map<String, List<Feature>> groupFeaturesByVersion(List<Feature> features) {
  final map = <String, List<Feature>>{};
  for (final f in features) {
    final v = (f.targetVersion == null || f.targetVersion!.trim().isEmpty)
        ? 'Unversioned'
        : f.targetVersion!.trim();
    (map[v] ??= []).add(f);
  }
  return map;
}

/// Shipped features for a given version.
List<Feature> shippedInVersion(List<Feature> features, String version) =>
    features
        .where((f) =>
            (f.targetVersion ?? '').trim() == version &&
            FeatureStatus.fromWire(f.status) == FeatureStatus.shipped)
        .toList();
