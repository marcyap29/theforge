import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/filesystem/project_file_repository.dart';

/// Copies a project's Forge deliverables out of the canonical workspace into a
/// user-chosen [destDir], under a **visible** `forge-docs/` folder (so it reads
/// cleanly when dropped into a code repo). The canonical `.forge/` workspace
/// remains the source of truth; this is a one-way export/snapshot.
///
/// Returns the number of files written.
Future<int> exportProjectDocs({
  required String projectPath,
  required String projectName,
  required String destDir,
}) async {
  final out = Directory(p.join(destDir, 'forge-docs'));
  await out.create(recursive: true);
  var count = 0;

  // Human-facing root files.
  for (final name in const ['README.md', 'user_notes.md', 'user_backlog.md']) {
    final f = File(p.join(projectPath, name));
    if (f.existsSync()) {
      await f.copy(p.join(out.path, name));
      count++;
    }
  }

  // Everything under .forge/ (specs, worksheets, handoffs, audit, forge,
  // ingested, exports, tracker), flattened into the visible forge-docs/ tree.
  final forge = Directory(p.join(projectPath, ProjectFileRepository.forgeDirName));
  if (forge.existsSync()) {
    await for (final entity in forge.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (p.basename(entity.path) == '.DS_Store') continue;
      final rel = p.relative(entity.path, from: forge.path);
      final dest = File(p.join(out.path, rel));
      await dest.parent.create(recursive: true);
      await entity.copy(dest.path);
      count++;
    }
  }

  return count;
}
