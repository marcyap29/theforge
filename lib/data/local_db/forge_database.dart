import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'forge_database.g.dart';

/// Opens the local index on the MAIN isolate (not a background isolate).
///
/// drift_flutter's `driftDatabase()` runs the DB on a background isolate; on
/// close it tears down `sqlite3`'s FFI callbacks on that worker, which trips a
/// Dart FFI-callback assertion and aborts the whole app (SIGABRT — BUG-IMPL-008).
/// This index is tiny, so we open the SAME file (`~/Documents/forge_index.sqlite`,
/// where drift_flutter placed it) directly on the main isolate — same data, no
/// cross-isolate FFI teardown, no abort.
QueryExecutor _openForgeIndex() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'forge_index.sqlite'));
    return NativeDatabase(file);
  });
}

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get path => text()();
  TextColumn get mode => text()();
  TextColumn get phase => text()();
  TextColumn get specVersion => text().nullable()();
  IntColumn get lastOpened => integer().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A tracked feature belonging to a project. This is the structured unit the
/// Portfolio tracker manages — each has a lifecycle [status]. Mirrored to
/// `{projectPath}/tracker/features.json` so it survives a DB rebuild.
class Features extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();

  /// One of FeatureStatus: idea | planned | in_progress | blocked | shipped | archived
  TextColumn get status => text()();

  /// Legacy integer priority — no longer written; kept so old rows survive.
  IntColumn get priority => integer().nullable()();

  /// Alphanumeric build priority (e.g. "1", "1A", "2B"). Replaces the old int
  /// column. Nullable when unranked.
  TextColumn get priorityLabel => text().nullable()();
  TextColumn get targetVersion => text().nullable()();

  /// Where the feature came from: manual | scan | spec | recommend | architect
  TextColumn get source => text().withDefault(const Constant('manual'))();

  /// Build classification (BuildKind): standard (code-gen buildable) | epic
  /// (must be decomposed before building) | manual (human/ML/data/design/
  /// external work — not something the AI can code-generate).
  TextColumn get buildKind =>
      text().withDefault(const Constant('standard'))();

  /// For sub-features produced by decomposing an epic: the parent feature's id.
  TextColumn get parentId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A release groups shipped features under a version label. Created when the
/// user "cuts a release" from the tracker; carries the generated release notes
/// and (optionally) the git tag applied to the linked repo. Mirrored to
/// `{projectPath}/.forge/tracker/releases.json`.
class Releases extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text()();

  /// The version label features are grouped under (e.g. "v1", "1.2.0").
  TextColumn get version => text()();

  /// One of: planned | released
  TextColumn get status => text().withDefault(const Constant('planned'))();

  /// Epoch ms when the release was cut. Null while still planned.
  IntColumn get releasedAt => integer().nullable()();

  /// Generated release notes (markdown). Null until cut.
  TextColumn get notes => text().nullable()();

  /// Git tag applied to the linked repo when cut, if any.
  TextColumn get gitTag => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Portfolio-level tracking state for a project, kept separate from the
/// discovery-indexed [Projects] table so project rediscovery never clobbers it.
class ProjectTracking extends Table {
  TextColumn get projectId => text()();

  /// One of ProjectStatus: active | paused | shipped | archived
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get summary => text().nullable()();

  /// Review cadence in days (e.g. 7). Null = no scheduled review.
  IntColumn get reviewCadenceDays => integer().nullable()();
  IntColumn get lastReviewedAt => integer().nullable()();

  /// Git HEAD SHA captured at the last review — powers staleness detection.
  TextColumn get lastReviewHead => text().nullable()();

  @override
  Set<Column> get primaryKey => {projectId};
}

/// One saved Claude Code prompt generated for a feature.
class PromptRecords extends Table {
  TextColumn get id => text()();
  TextColumn get featureId => text()();
  TextColumn get projectId => text()();
  IntColumn get createdAt => integer()();

  /// One of: generated | copied
  TextColumn get status => text().withDefault(const Constant('generated'))();

  /// Relative path inside the project's Forge/ dir: prompts/<featureId>/<ts>.md
  TextColumn get promptPath => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Projects, Features, ProjectTracking, Releases, PromptRecords])
class ForgeDatabase extends _$ForgeDatabase {
  ForgeDatabase() : super(_openForgeIndex());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 -> v2: introduce the tracker tables. Existing Projects rows
          // are untouched.
          if (from < 2) {
            await m.createTable(features);
            await m.createTable(projectTracking);
          }
          // v2 -> v3: introduce the releases table. Existing rows untouched.
          if (from < 3) {
            await m.createTable(releases);
          }
          // v3 -> v4: feature build classification + epic sub-feature nesting.
          // Existing rows default to 'standard' / null parent.
          if (from < 4) {
            await m.addColumn(features, features.buildKind);
            await m.addColumn(features, features.parentId);
          }
          // v4 -> v5: introduce prompt generation history.
          if (from < 5) {
            await m.createTable(promptRecords);
          }
          // v5 -> v6: add text priority label (replaces int priority column).
          // Backfill: cast existing int values so nothing is lost.
          if (from < 6) {
            await m.addColumn(features, features.priorityLabel);
            await customStatement(
              'UPDATE features SET priority_label = CAST(priority AS TEXT) '
              'WHERE priority IS NOT NULL',
            );
          }
        },
      );

  // --- Projects (unchanged) ---

  Future<List<Project>> getAllProjects() => select(projects).get();

  Future<void> upsertProject(ProjectsCompanion entry) =>
      into(projects).insertOnConflictUpdate(entry);

  Future<void> removeProject(String id) =>
      (delete(projects)..where((t) => t.id.equals(id))).go();

  Future<Project?> getProjectById(String id) =>
      (select(projects)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateLastOpened(String id, int lastOpened) =>
      (update(projects)..where((t) => t.id.equals(id)))
          .write(ProjectsCompanion(lastOpened: Value(lastOpened)));

  Future<void> updateProjectPhase(
          String id, String phase, String specVersion) =>
      (update(projects)..where((t) => t.id.equals(id))).write(
        ProjectsCompanion(
          phase: Value(phase),
          specVersion: Value(specVersion),
        ),
      );

  Future<void> updateProjectNameAndPath(
          String id, String newName, String newPath) =>
      (update(projects)..where((t) => t.id.equals(id))).write(
        ProjectsCompanion(
          name: Value(newName),
          path: Value(newPath),
        ),
      );

  // --- Features ---

  Future<List<Feature>> getAllFeatures() => select(features).get();

  Future<List<Feature>> getFeaturesForProject(String projectId) =>
      (select(features)..where((t) => t.projectId.equals(projectId))).get();

  Future<Feature?> getFeatureById(String id) =>
      (select(features)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertFeature(FeaturesCompanion entry) =>
      into(features).insertOnConflictUpdate(entry);

  Future<void> deleteFeature(String id) =>
      (delete(features)..where((t) => t.id.equals(id))).go();

  Future<void> deleteFeaturesForProject(String projectId) =>
      (delete(features)..where((t) => t.projectId.equals(projectId))).go();

  // --- ProjectTracking ---

  Future<List<ProjectTrackingData>> getAllTracking() =>
      select(projectTracking).get();

  Future<ProjectTrackingData?> getTracking(String projectId) =>
      (select(projectTracking)..where((t) => t.projectId.equals(projectId)))
          .getSingleOrNull();

  Future<void> upsertTracking(ProjectTrackingCompanion entry) =>
      into(projectTracking).insertOnConflictUpdate(entry);

  Future<void> removeTracking(String projectId) =>
      (delete(projectTracking)..where((t) => t.projectId.equals(projectId)))
          .go();

  // --- Releases ---

  Future<List<Release>> getReleasesForProject(String projectId) =>
      (select(releases)..where((t) => t.projectId.equals(projectId))).get();

  Future<Release?> getReleaseForVersion(String projectId, String version) =>
      (select(releases)
            ..where((t) =>
                t.projectId.equals(projectId) & t.version.equals(version)))
          .getSingleOrNull();

  Future<void> upsertRelease(ReleasesCompanion entry) =>
      into(releases).insertOnConflictUpdate(entry);

  Future<void> deleteRelease(String id) =>
      (delete(releases)..where((t) => t.id.equals(id))).go();

  // --- PromptRecords ---

  Future<List<PromptRecord>> getPromptRecordsForFeature(
          String projectId, String featureId) =>
      (select(promptRecords)
            ..where((t) =>
                t.projectId.equals(projectId) & t.featureId.equals(featureId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<void> insertPromptRecord(PromptRecordsCompanion entry) =>
      into(promptRecords).insert(entry);

  Future<void> updatePromptStatus(String id, String status) =>
      (update(promptRecords)..where((t) => t.id.equals(id)))
          .write(PromptRecordsCompanion(status: Value(status)));
}
