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

  /// Writes a breadcrumb **synchronously and flushed to disk**, so it survives a
  /// hard/native crash (a SIGABRT from an FFI/isolate abort can kill the process
  /// before an async write flushes — which is why a native crash leaves no trace
  /// in the async [log]). Used to bisect such crashes: the LAST `CRUMB` line in
  /// `diag.log` names the operation that was running when the process died.
  ///
  /// No-op until the log file has been resolved — which happens at startup when
  /// `main` calls [log] for the "app start" line, so it is always ready by the
  /// time a build runs.
  static void breadcrumb(String line) {
    final file = _file;
    if (file == null) return;
    try {
      file.writeAsStringSync(
        '${DateTime.now().toIso8601String()} CRUMB $line\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Diagnostics must never break the app.
    }
  }
}
