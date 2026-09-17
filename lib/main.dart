import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'core/app.dart';
import 'services/diag_log.dart';
import 'services/paste_receiver.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Persistent error log (see diag.log in the app-support dir), so failures are
  // inspectable even when the app is launched from Finder and after a toast has
  // vanished.
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

  // Accept dictated text from Sabihin via the theforge://paste URL scheme.
  PasteReceiver.register();
  runApp(
    const ProviderScope(
      child: TheForgeApp(),
    ),
  );
}

const _appVersion = '0.4.37';
