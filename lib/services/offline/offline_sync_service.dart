import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'connectivity_monitor.dart';

/// One queued mutation awaiting cloud sync.
class PendingMutation {
  const PendingMutation({
    required this.id,
    required this.op,
    required this.payload,
    required this.queuedAt,
  });

  final String id;
  final String op;
  final Map<String, dynamic> payload;
  final int queuedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'op': op,
    'payload': payload,
    'queuedAt': queuedAt,
  };

  static PendingMutation fromJson(Map<String, dynamic> json) => PendingMutation(
    id: json['id'] as String,
    op: json['op'] as String,
    payload: (json['payload'] as Map).cast<String, dynamic>(),
    queuedAt: json['queuedAt'] as int,
  );
}

/// A sink that ships a mutation to the cloud. The Forge has no Forge server, so
/// the default sink is a no-op; a real deployment (or a test) injects one.
/// Returning normally means the mutation was accepted and can be dequeued.
typedef CloudSink = Future<void> Function(PendingMutation mutation);

/// Local-first sync engine.
///
/// Every mutation is written to a durable on-disk queue FIRST (so nothing is
/// lost if the app quits offline), then flushed to the cloud whenever
/// connectivity is available. When offline, mutations simply accumulate; when
/// the network returns, the queue drains in order. The queue file lives in the
/// app-support directory so it survives restarts.
class OfflineSyncService {
  OfflineSyncService({
    required ConnectivityMonitor connectivity,
    CloudSink? sink,
    Future<Directory> Function()? dirProvider,
  }) : _connectivity = connectivity,
       _sink = sink ?? _noopSink,
       _dirProvider = dirProvider ?? getApplicationSupportDirectory;

  final ConnectivityMonitor _connectivity;
  final CloudSink _sink;
  final Future<Directory> Function() _dirProvider;

  final List<PendingMutation> _queue = [];
  bool _started = false;
  Future<void>? _flushFuture;
  int _seq = 0;

  static Future<void> _noopSink(PendingMutation _) async {}

  /// Number of mutations still waiting to reach the cloud.
  int get pendingCount => _queue.length;

  /// Whether the last known connectivity state is online.
  bool get isOnline => _connectivity.isOnline;

  /// Loads the persisted queue and begins watching connectivity. Idempotent.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _load();
    _connectivity.addListener(_onConnectivityChanged);
    _connectivity.start();
    if (_connectivity.isOnline) {
      unawaited(flush());
    }
  }

  /// Stops watching connectivity. The queue stays on disk.
  void stop() {
    _connectivity.removeListener(_onConnectivityChanged);
    _connectivity.stop();
    _started = false;
  }

  /// Records a mutation locally and attempts to ship it. Always persists to
  /// disk first, so an offline mutation is never lost. Returns immediately.
  Future<void> enqueue(String op, Map<String, dynamic> payload) async {
    final mutation = PendingMutation(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_seq++}',
      op: op,
      payload: payload,
      queuedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _queue.add(mutation);
    await _persist();
    if (_connectivity.isOnline) {
      // Await the flush attempt so a caller that enqueues while online sees a
      // deterministic queue (either shipped or still queued on sink failure).
      await flush();
    }
  }

  /// Drains the queue in order, shipping each mutation to the cloud sink.
  /// Stops early if the network drops mid-flush; the remaining mutations stay
  /// queued for the next attempt. Safe to call concurrently — a second call
  /// while a flush is running awaits the in-flight flush rather than returning
  /// early, so callers always observe a settled queue.
  Future<void> flush() {
    final inFlight = _flushFuture;
    if (inFlight != null) return inFlight;
    final future = _drain();
    _flushFuture = future;
    return future.whenComplete(() {
      if (identical(_flushFuture, future)) _flushFuture = null;
    });
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty) {
      if (!_connectivity.isOnline) break;
      final mutation = _queue.first;
      try {
        await _sink(mutation);
      } catch (_) {
        // Sink failed (server down, auth, etc.) — keep it queued and stop.
        break;
      }
      _queue.removeAt(0);
      await _persist();
    }
  }

  void _onConnectivityChanged() {
    if (_connectivity.isOnline) {
      unawaited(flush());
    }
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<File> _queueFile() async {
    final dir = await _dirProvider();
    return File(p.join(dir.path, 'forge_offline_queue.json'));
  }

  Future<void> _load() async {
    try {
      final file = await _queueFile();
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is List) {
        _queue
          ..clear()
          ..addAll(
            raw.cast<Map<String, dynamic>>().map(PendingMutation.fromJson),
          );
      }
    } catch (_) {
      // Corrupt or unreadable queue — start clean rather than crash.
    }
  }

  Future<void> _persist() async {
    try {
      final file = await _queueFile();
      await file.writeAsString(
        jsonEncode(_queue.map((m) => m.toJson()).toList()),
      );
    } catch (_) {
      // Best-effort: a failed persist must never break the mutation itself.
    }
  }
}
