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

    return db.getAllProjects();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
