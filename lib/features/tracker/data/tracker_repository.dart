import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';

/// Persists tracker data (features + per-project tracking state) to the drift
/// DB and mirrors it to `{projectPath}/tracker/*.json` so it is portable,
/// git-trackable, and survives a DB rebuild — matching the repo invariant that
/// the filesystem is the source of truth and SQLite is a rebuildable index.
class TrackerRepository {
  TrackerRepository(this._db);

  final ForgeDatabase _db;

  // --- Features ---

  Future<List<Feature>> featuresForProject(String projectId) =>
      _db.getFeaturesForProject(projectId);

  Future<void> saveFeature(Feature feature, {String? projectPath}) async {
    await _db.upsertFeature(feature.toCompanion(false));
    await _mirrorFeatures(feature.projectId, projectPath);
  }

  Future<void> deleteFeature(
    String id,
    String projectId, {
    String? projectPath,
  }) async {
    await _db.deleteFeature(id);
    await _mirrorFeatures(projectId, projectPath);
  }

  /// Replaces the full feature set for a project in one shot (used by the
  /// repo scanner when the user accepts a proposed list).
  Future<void> replaceFeatures(
    String projectId,
    List<Feature> features, {
    String? projectPath,
  }) async {
    await _db.deleteFeaturesForProject(projectId);
    for (final f in features) {
      await _db.upsertFeature(f.toCompanion(false));
    }
    await _mirrorFeatures(projectId, projectPath);
  }

  // --- Tracking ---

  Future<ProjectTrackingData?> tracking(String projectId) =>
      _db.getTracking(projectId);

  Future<void> saveTracking(
    ProjectTrackingData data, {
    String? projectPath,
  }) async {
    await _db.upsertTracking(data.toCompanion(false));
    if (projectPath != null) {
      await _writeJson(projectPath, 'tracker.json', {
        'projectId': data.projectId,
        'status': data.status,
        'summary': data.summary,
        'reviewCadenceDays': data.reviewCadenceDays,
        'lastReviewedAt': data.lastReviewedAt,
        'lastReviewHead': data.lastReviewHead,
      });
    }
  }

  // --- Releases ---

  Future<List<Release>> releasesForProject(String projectId) =>
      _db.getReleasesForProject(projectId);

  /// Returns the release for [version], creating a `planned` one if none exists.
  Future<Release> ensureRelease(
    String projectId,
    String version, {
    String? projectPath,
  }) async {
    final existing = await _db.getReleaseForVersion(projectId, version);
    if (existing != null) return existing;
    final now = DateTime.now().millisecondsSinceEpoch;
    final release = Release(
      id: const Uuid().v4(),
      projectId: projectId,
      version: version,
      status: 'planned',
      releasedAt: null,
      notes: null,
      gitTag: null,
      createdAt: now,
      updatedAt: now,
    );
    await _db.upsertRelease(release.toCompanion(false));
    await _mirrorReleases(projectId, projectPath);
    return release;
  }

  Future<void> saveRelease(Release release, {String? projectPath}) async {
    await _db.upsertRelease(release.toCompanion(false));
    await _mirrorReleases(release.projectId, projectPath);
  }

  Future<void> _mirrorReleases(String projectId, String? projectPath) async {
    if (projectPath == null) return;
    final releases = await _db.getReleasesForProject(projectId);
    await _writeJson(projectPath, 'releases.json', {
      'projectId': projectId,
      'releases': releases
          .map((r) => {
                'id': r.id,
                'version': r.version,
                'status': r.status,
                'releasedAt': r.releasedAt,
                'notes': r.notes,
                'gitTag': r.gitTag,
                'createdAt': r.createdAt,
                'updatedAt': r.updatedAt,
              })
          .toList(),
    });
  }

  // --- JSON mirror ---

  Future<void> _mirrorFeatures(String projectId, String? projectPath) async {
    if (projectPath == null) return;
    final features = await _db.getFeaturesForProject(projectId);
    await _writeJson(projectPath, 'features.json', {
      'projectId': projectId,
      'features': features
          .map((f) => {
                'id': f.id,
                'title': f.title,
                'description': f.description,
                'status': f.status,
                'priority': f.priority,
                'targetVersion': f.targetVersion,
                'source': f.source,
                'createdAt': f.createdAt,
                'updatedAt': f.updatedAt,
              })
          .toList(),
    });
  }

  Future<void> _writeJson(
    String projectPath,
    String fileName,
    Map<String, dynamic> data,
  ) async {
    final dir =
        Directory(p.join(projectPath, ProjectFileRepository.forgeDirName, 'tracker'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }
}

/// Convenience builder for a new [Feature] with timestamps set to now.
FeaturesCompanion newFeatureCompanion({
  required String id,
  required String projectId,
  required String title,
  String? description,
  required String status,
  int? priority,
  String? targetVersion,
  String source = 'manual',
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return FeaturesCompanion(
    id: Value(id),
    projectId: Value(projectId),
    title: Value(title),
    description: Value(description),
    status: Value(status),
    priority: Value(priority),
    targetVersion: Value(targetVersion),
    source: Value(source),
    createdAt: Value(now),
    updatedAt: Value(now),
  );
}
