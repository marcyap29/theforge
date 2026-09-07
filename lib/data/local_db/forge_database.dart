import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'forge_database.g.dart';

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

  /// Lower = higher priority. Nullable when unranked.
  IntColumn get priority => integer().nullable()();
  TextColumn get targetVersion => text().nullable()();

  /// Where the feature came from: manual | scan | spec
  TextColumn get source => text().withDefault(const Constant('manual'))();
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

@DriftDatabase(tables: [Projects, Features, ProjectTracking])
class ForgeDatabase extends _$ForgeDatabase {
  ForgeDatabase() : super(driftDatabase(name: 'forge_index'));

  @override
  int get schemaVersion => 2;

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
}
