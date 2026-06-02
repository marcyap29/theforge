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

@DriftDatabase(tables: [Projects])
class ForgeDatabase extends _$ForgeDatabase {
  ForgeDatabase() : super(driftDatabase(name: 'forge_index'));

  @override
  int get schemaVersion => 1;

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
}
