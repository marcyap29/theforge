import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/settings_providers.dart';
import 'llm_model_config.dart';
import 'llm_service.dart';

final llmSettingsProvider = Provider<LlmSettings>((ref) {
  return ref
          .watch(settingsProvider)
          .valueOrNull
          ?.settings ??
      LlmSettings.defaults;
});

final llmServiceProvider = Provider<LlmService>((ref) {
  final settings = ref.watch(llmSettingsProvider);
  return LlmService(settings);
});
