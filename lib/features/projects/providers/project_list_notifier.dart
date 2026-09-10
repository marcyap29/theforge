import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../data/local_db/forge_database.dart';
import 'providers.dart';

class ProjectListNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    final fileRepo = ref.watch(projectFileRepositoryProvider);
    final db = ref.watch(forgeDatabaseProvider);

    final paths = await fileRepo.scanProjectPaths();
    final now = DateTime.now().millisecondsSinceEpoch;
    final foundIds = paths.map(p.basename).toSet();

    for (final path in paths) {
      final id = p.basename(path);
      final existing = await db.getProjectById(id);
      if (existing == null) {
        await db.upsertProject(
          ProjectsCompanion.insert(
            id: id,
            name: id,
            path: path,
            mode: 'build',
            phase: 'v1_interview',
            createdAt: now,
          ),
        );
      }
    }

    // Prune stale index rows: any project no longer present under the canonical
    // projects root (e.g. left over from a previous root that pointed at a code
    // repo). This removes ONLY index/tracker rows — never a folder — so a
    // mis-indexed source repo can't linger as a deletable project.
    for (final proj in await db.getAllProjects()) {
      if (!foundIds.contains(proj.id)) {
        await db.deleteFeaturesForProject(proj.id);
        await db.removeTracking(proj.id);
        await db.removeProject(proj.id);
      }
    }

    return db.getAllProjects();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
