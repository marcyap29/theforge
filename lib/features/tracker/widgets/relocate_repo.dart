import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../data/filesystem/project_file_repository.dart';

/// Lets the user move a project's linked code repo to a new location AT ANY
/// TIME. Offers to create a fresh folder under `~/Development` or pick an
/// existing one, then MOVES the current repo's code there (leaving the Forge
/// deliverables `.forge/` behind) and repoints the project config.
///
/// Returns the new repo path, or null if cancelled. Guards against using a
/// Forge project workspace as a code repo (the AR Mechanic bug, where generated
/// code ended up scattered among specs/handoffs).
Future<String?> relocateRepoFlow({
  required BuildContext context,
  required String projectPath,
  required String projectName,
  required String? currentRepoPath,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final hasCurrent = currentRepoPath != null && currentRepoPath.isNotEmpty;

  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(hasCurrent ? 'Move code to a new location' : 'Set code location'),
      children: [
        if (hasCurrent)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'Currently: $currentRepoPath',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'create'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.create_new_folder_outlined),
            title: Text('New folder under ~/Development'),
            subtitle: Text('Creates a fresh, git-initialised folder and moves the code into it'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'existing'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.folder_open_outlined),
            title: Text('Choose an existing folder'),
            subtitle: Text('Moves the code into the folder you pick'),
          ),
        ),
      ],
    ),
  );
  if (choice == null) return null;

  String newPath;
  if (choice == 'create') {
    try {
      newPath = await ProjectFileRepository.createEmptyCodeFolder(projectName);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not create folder: $e'),
        backgroundColor: const Color(0xFF3F0A0A),
      ));
      return null;
    }
  } else {
    final picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose the new code location for $projectName',
      lockParentWindow: true,
    );
    if (picked == null) return null;
    // Guard: never let the Forge project workspace be used as a code repo.
    if (await ProjectFileRepository.isInsideProjectsRoot(picked)) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            "That folder is inside The Forge's project workspace. Pick a code "
            'folder outside it (e.g. under ~/Development).'),
        backgroundColor: Color(0xFF3F0A0A),
      ));
      return null;
    }
    newPath = picked;
  }

  // Move existing code across, if there is any and it's a different place.
  if (hasCurrent &&
      !p.equals(currentRepoPath, newPath) &&
      Directory(currentRepoPath).existsSync()) {
    final r = await ProjectFileRepository.relocateRepo(
      fromPath: currentRepoPath,
      toPath: newPath,
    );
    final parts = <String>[];
    if (r.moved.isNotEmpty) parts.add('moved ${r.moved.length} item(s)');
    if (r.skipped.isNotEmpty) parts.add('skipped ${r.skipped.length}');
    if (r.failed.isNotEmpty) parts.add('${r.failed.length} failed');
    messenger.showSnackBar(SnackBar(
      content: Text('Code → $newPath${parts.isEmpty ? '' : ' (${parts.join(', ')})'}'),
      backgroundColor: r.failed.isEmpty ? null : const Color(0xFF3F0A0A),
    ));
  } else {
    messenger.showSnackBar(
        SnackBar(content: Text('Code location set to $newPath')));
  }

  await ProjectFileRepository.writeProjectConfig(projectPath, {'repoPath': newPath});
  return newPath;
}
