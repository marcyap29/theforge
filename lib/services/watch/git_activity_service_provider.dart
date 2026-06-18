import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/engineer_roster_notifier.dart';
import '../../features/settings/github_config_notifier.dart';
import 'git_activity_service.dart';

final gitActivityServiceProvider = Provider<GitActivityService?>((ref) {
  final configAsync = ref.watch(githubConfigProvider);
  final rosterAsync = ref.watch(engineerRosterProvider);
  final config = configAsync.valueOrNull;
  final roster = rosterAsync.valueOrNull;
  if (config == null || roster == null || !config.isConfigured) return null;
  return GitActivityService(config: config, roster: roster);
});