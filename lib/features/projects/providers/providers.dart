import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import 'active_project_notifier.dart';
import 'project_list_notifier.dart';

final projectFileRepositoryProvider = Provider<ProjectFileRepository>(
  (ref) => ProjectFileRepository(),
);

final forgeDatabaseProvider = Provider<ForgeDatabase>(
  (ref) => ForgeDatabase(),
);

final projectListProvider =
    AsyncNotifierProvider<ProjectListNotifier, List<Project>>(
  ProjectListNotifier.new,
);

final activeProjectProvider =
    NotifierProvider<ActiveProjectNotifier, ActiveProjectState>(
  ActiveProjectNotifier.new,
);
