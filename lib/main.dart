import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app.dart';
import 'services/paste_receiver.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Accept dictated text from Sabihin via the theforge://paste URL scheme.
  PasteReceiver.register();
  runApp(
    const ProviderScope(
      child: TheForgeApp(),
    ),
  );
}
