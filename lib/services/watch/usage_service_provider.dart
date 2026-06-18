import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/engineer_roster_notifier.dart';
import 'usage_service.dart';

final usageServiceProvider = Provider<UsageService?>((ref) {
  final rosterAsync = ref.watch(engineerRosterProvider);
  final roster = rosterAsync.valueOrNull;
  if (roster == null) return null;
  return UsageService(roster: roster);
});