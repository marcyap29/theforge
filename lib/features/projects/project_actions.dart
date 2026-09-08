import 'package:flutter/material.dart';

import '../../data/filesystem/project_file_repository.dart';
import '../../data/local_db/forge_database.dart';

/// Permanently deletes a project everywhere it lives: the on-disk folder
/// (which also carries the tracker `tracker/*.json` mirror), the drift
/// `Projects` index row, and its tracker rows (`Features` + `ProjectTracking`).
/// Filesystem failures are swallowed so DB rows are still cleaned up.
Future<void> deleteProjectCascade(
  ProjectFileRepository repo,
  ForgeDatabase db,
  Project project,
) async {
  try {
    await repo.deleteProject(project.path);
  } catch (_) {
    // Folder may already be gone or unwritable — still purge the index.
  }
  await db.deleteFeaturesForProject(project.id);
  await db.removeTracking(project.id);
  await db.removeProject(project.id);
}

/// Two-step confirmation for destructive deletes. Returns true only if the user
/// confirms BOTH dialogs. Used for single and bulk project deletion.
Future<bool> confirmDoubleDelete(
  BuildContext context, {
  required String firstTitle,
  required String firstMessage,
  required String secondTitle,
  required String secondMessage,
  String confirmLabel = 'Delete',
  String finalLabel = 'Delete permanently',
}) async {
  final first = await _confirm(
    context,
    title: firstTitle,
    message: firstMessage,
    actionLabel: confirmLabel,
  );
  if (first != true) return false;
  if (!context.mounted) return false;

  final second = await _confirm(
    context,
    title: secondTitle,
    message: secondMessage,
    actionLabel: finalLabel,
  );
  return second == true;
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: Text(title, style: const TextStyle(color: Color(0xFFE5E5E7))),
      content: Text(message, style: const TextStyle(color: Color(0xFFAEAEB2))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(actionLabel,
              style: const TextStyle(color: Color(0xFFFF453A))),
        ),
      ],
    ),
  );
}
