import 'dart:io';

/// Appends timestamped diagnostic/error lines to `diag.log` in the app-support
/// directory, so failures can be inspected even when the app is launched from
/// Finder (where stderr/debugPrint is invisible) and even after an ephemeral
/// error toast has vanished. Modeled on Sabihin's DiagLog.
///
/// Deliberately Flutter-free. Wire [directoryProvider] at startup to
/// path_provider's getApplicationSupportDirectory.
class DiagLog {
  static File? _file;

  /// Resolves the directory `diag.log` lives in. Set once at startup.
  static Future<Directory> Function()? directoryProvider;

  /// The log file, resolved on first use. Null when no provider is wired.
  static Future<File?> resolveFile() async {
    if (_file != null) return _file;
    final provider = directoryProvider;
    if (provider == null) return null;
    final dir = await provider();
    _file = File('${dir.path}${Platform.pathSeparator}diag.log');
    return _file;
  }

  /// Appends one timestamped line (multi-line messages are kept as-is).
  static Future<void> log(String line) async {
    assert(() {
      // ignore: avoid_print
      print('[diag] $line');
      return true;
    }());
    try {
      final file = await resolveFile();
      if (file == null) return;
      await file.writeAsString(
        '${DateTime.now().toIso8601String()} $line\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // Diagnostics must never break the app.
    }
  }

  /// Logs an error with an optional context tag and stack — the common case.
  static Future<void> error(String context, Object error, [StackTrace? stack]) {
    final s = stack == null ? '' : '\n$stack';
    return log('ERROR [$context] $error$s');
  }
}
