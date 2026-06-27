import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/settings_providers.dart';
import 'swarmspace_service.dart';

final swarmspaceServiceProvider = Provider<SwarmSpaceService?>(
  (ref) {
    final settings = ref.watch(settingsProvider);
    final apiKey = settings.value?.settings.swarmspaceApiKey;

    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    return SwarmSpaceService(apiKey: apiKey);
  },
);
