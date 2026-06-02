import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';

class ActiveProjectState {
  final String? projectPath;
  final String? projectName;
  final String? readmeContent;
  final bool isLoading;

  const ActiveProjectState({
    this.projectPath,
    this.projectName,
    this.readmeContent,
    this.isLoading = false,
  });

  ActiveProjectState copyWith({
    String? projectPath,
    String? projectName,
    String? readmeContent,
    bool? isLoading,
  }) {
    return ActiveProjectState(
      projectPath: projectPath ?? this.projectPath,
      projectName: projectName ?? this.projectName,
      readmeContent: readmeContent ?? this.readmeContent,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  static const empty = ActiveProjectState();
}

class ActiveProjectNotifier extends Notifier<ActiveProjectState> {
  @override
  ActiveProjectState build() => ActiveProjectState.empty;

  Future<void> open(
    String projectPath,
    ProjectFileRepository repo,
    ForgeDatabase db,
  ) async {
    state = const ActiveProjectState(isLoading: true);

    final projectName = projectPath.split('/').last;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.updateLastOpened(projectName, now);
    final readme = await repo.readReadme(projectPath);

    state = ActiveProjectState(
      projectPath: projectPath,
      projectName: projectName,
      readmeContent: readme,
      isLoading: false,
    );
  }

  void close() {
    state = ActiveProjectState.empty;
  }
}
