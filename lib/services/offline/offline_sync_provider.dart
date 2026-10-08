import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_monitor.dart';
import 'offline_sync_service.dart';

/// App-wide connectivity monitor. Kept alive for the app's lifetime so the
/// probe timer isn't torn down when a screen that watches it is disposed.
final connectivityMonitorProvider = Provider<ConnectivityMonitor>((ref) {
  final monitor = ConnectivityMonitor();
  ref.onDispose(monitor.dispose);
  return monitor;
});

/// App-wide offline sync service. Every mutation is queued here and flushed to
/// the cloud when connectivity returns.
final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  final service = OfflineSyncService(
    connectivity: ref.watch(connectivityMonitorProvider),
  );
  ref.onDispose(service.stop);
  return service;
});
