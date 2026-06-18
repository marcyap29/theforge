import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'watch_signal_service.dart';

// WatchSignalService is always available — it does no HTTP fetching
// and has no config dependencies. It is a pure computation engine.
final watchSignalServiceProvider = Provider<WatchSignalService>((ref) {
  return const WatchSignalService();
});