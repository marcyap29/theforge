import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// A minimal, dependency-free connectivity monitor.
///
/// The Forge is local-first: the app must work with no network at all. Rather
/// than pull in a platform connectivity plugin (which reports link state, not
/// reachability), this monitor periodically attempts a lightweight DNS/TCP
/// probe and reports whether the network is actually usable. It is deliberately
/// conservative — a failed probe flips to offline, and the next successful
/// probe flips back online — so queued mutations flush the moment the network
/// returns.
class ConnectivityMonitor extends ChangeNotifier {
  ConnectivityMonitor({
    this.probeHost = 'one.one.one.one',
    this.probePort = 443,
    this.interval = const Duration(seconds: 15),
    this.probeTimeout = const Duration(seconds: 4),
  });

  final String probeHost;
  final int probePort;
  final Duration interval;
  final Duration probeTimeout;

  Timer? _timer;
  bool _online = true;
  bool _started = false;

  /// Whether the last probe succeeded. Optimistic default (true) so the app
  /// doesn't flash "offline" before the first probe completes.
  bool get isOnline => _online;

  /// Fires when connectivity transitions. [online] is the new state.
  final _transitions = StreamController<bool>.broadcast();
  Stream<bool> get onTransition => _transitions.stream;

  /// Begins periodic probing. Idempotent — safe to call more than once.
  void start() {
    if (_started) return;
    _started = true;
    // Probe immediately, then on the interval.
    unawaited(_probe());
    _timer = Timer.periodic(interval, (_) => _probe());
  }

  /// Stops probing and releases resources.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  /// Runs a single probe now and returns the resulting state. Useful for tests
  /// and for forcing a check before a manual sync.
  Future<bool> checkNow() => _probe();

  Future<bool> _probe() async {
    bool reachable;
    try {
      final socket = await Socket.connect(
        probeHost,
        probePort,
        timeout: probeTimeout,
      );
      socket.destroy();
      reachable = true;
    } catch (_) {
      reachable = false;
    }
    _setOnline(reachable);
    return reachable;
  }

  void _setOnline(bool value) {
    if (_online == value) return;
    _online = value;
    _transitions.add(value);
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _transitions.close();
    super.dispose();
  }
}
