import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_notifier.dart';

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, LlmSettingsState>(
  SettingsNotifier.new,
);
