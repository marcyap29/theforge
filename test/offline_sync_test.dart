import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/services/offline/connectivity_monitor.dart';
import 'package:the_forge/services/offline/offline_sync_service.dart';

/// A connectivity monitor whose state we control directly, so tests don't
/// depend on the real network.
class _FakeConnectivity extends ConnectivityMonitor {
  _FakeConnectivity(this._online);

  bool _online;

  @override
  bool get isOnline => _online;

  void setOnline(bool value) {
    _online = value;
    notifyListeners();
  }

  @override
  void start() {}

  @override
  void stop() {}
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('forge_offline_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('queues mutations while offline and flushes on reconnect', () async {
    final connectivity = _FakeConnectivity(false);
    final shipped = <PendingMutation>[];
    final service = OfflineSyncService(
      connectivity: connectivity,
      sink: (m) async => shipped.add(m),
      dirProvider: () async => tempDir,
    );

    await service.start();
    await service.enqueue('feature.save', {'id': 'f1'});
    await service.enqueue('feature.save', {'id': 'f2'});

    // Offline: nothing shipped, both queued.
    expect(shipped, isEmpty);
    expect(service.pendingCount, 2);

    // Reconnect: the queue drains in order. flush() awaits any in-flight
    // flush, so both mutations are shipped by the time it returns.
    connectivity.setOnline(true);
    await service.flush();

    expect(shipped.length, 2);
    expect(shipped[0].payload['id'], 'f1');
    expect(shipped[1].payload['id'], 'f2');
    expect(service.pendingCount, 0);
  });

  test('persists the queue across a restart', () async {
    final connectivity = _FakeConnectivity(false);
    final service1 = OfflineSyncService(
      connectivity: connectivity,
      sink: (_) async {},
      dirProvider: () async => tempDir,
    );
    await service1.start();
    await service1.enqueue('project.upsert', {'id': 'p1'});
    expect(service1.pendingCount, 1);

    // A fresh service pointed at the same dir should reload the queue.
    final service2 = OfflineSyncService(
      connectivity: connectivity,
      sink: (_) async {},
      dirProvider: () async => tempDir,
    );
    await service2.start();
    expect(service2.pendingCount, 1);
  });

  test('keeps a mutation queued when the sink fails', () async {
    final connectivity = _FakeConnectivity(true);
    final service = OfflineSyncService(
      connectivity: connectivity,
      sink: (_) async => throw Exception('server down'),
      dirProvider: () async => tempDir,
    );
    await service.start();
    await service.enqueue('feature.save', {'id': 'f1'});
    await service.flush();
    expect(service.pendingCount, 1);
  });
}
