import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Receives dictated text from Sabihin (or any tool) via the `theforge://paste`
/// URL scheme.
///
/// Why a URL scheme instead of a synthetic ⌘V: Flutter text fields on macOS do
/// not reliably receive CGEvent-based keystrokes, so Sabihin's default paste
/// (clipboard + synthetic ⌘V) silently fails here. Instead Sabihin puts the
/// transcript on the clipboard and opens `theforge://paste`; the native side
/// forwards that to this channel, and we insert at the caret using Flutter's
/// own [PasteTextIntent] — the same action ⌘V maps to inside the app, invoked
/// programmatically so it works regardless of how the keystroke was delivered.
class PasteReceiver {
  static const _channel = MethodChannel('theforge/paste');

  static void register() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'paste') {
        _pasteIntoFocusedField();
      }
      return null;
    });
  }

  static void _pasteIntoFocusedField() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return;
    // EditableText registers a PasteTextIntent action; invoking it reads the
    // clipboard and inserts at the current selection/caret.
    Actions.maybeInvoke(
      ctx,
      const PasteTextIntent(SelectionChangedCause.keyboard),
    );
  }
}
