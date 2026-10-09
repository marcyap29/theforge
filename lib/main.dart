import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'core/app.dart';
import 'services/crash_diagnostics.dart';
import 'services/diag_log.dart';
import 'services/offline/offline_sync_provider.dart';
import 'services/paste_receiver.dart';

void main() {
  // runZonedGuarded catches async errors that escape the widget tree (the third
  // leg of error capture, alongside FlutterError.onError + onError below) so no
  // Dart failure goes unlogged. Native aborts are caught separately by
  // CrashDiagnostics (abnormal-exit detection + crash-report harvest).
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      // Persistent error log (see diag.log in the app-support dir), so failures
      // are inspectable even when the app is launched from Finder and after a
      // toast has vanished.
      DiagLog.directoryProvider = getApplicationSupportDirectory;
      final priorOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        priorOnError?.call(details);
        DiagLog.error('flutter', details.exceptionAsString(), details.stack);
      };
      WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
        DiagLog.error('uncaught', error, stack);
        return false;
      };
      DiagLog.log('--- app start (v$_appVersion) ---');

      // Crash diagnostics: detect an abnormal exit from last session (a crash),
      // harvest any native crash reports, and keep a clean-shutdown sentinel.
      CrashDiagnostics.onStartup(getApplicationSupportDirectory);
      // Retained in a top-level field so it isn't GC'd. onDetach fires as the app
      // shuts down — clearing the sentinel marks a clean shutdown. (If it ever
      // doesn't fire, we conservatively report a "possible crash" next launch —
      // a safe over-report, never a miss.)
      _lifecycle = AppLifecycleListener(
        onDetach: CrashDiagnostics.markCleanShutdown,
      );

      // Accept dictated text from Sabihin via the theforge://paste URL scheme.
      PasteReceiver.register();

      // Local-first offline sync: load the persisted mutation queue and begin
      // watching connectivity so queued changes flush the moment we're online.
      final container = ProviderContainer();
      unawaited(container.read(offlineSyncServiceProvider).start());

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const TheForgeApp(),
        ),
      );
    },
    (error, stack) {
      DiagLog.error('zone', error, stack);
    },
  );
}

const _appVersion = '0.5.35';

/// Retained so the lifecycle listener isn't garbage-collected (see main()).
// ignore: unused_element
AppLifecycleListener? _lifecycle;
