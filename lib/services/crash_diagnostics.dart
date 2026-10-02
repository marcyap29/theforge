import 'dart:io';

import 'diag_log.dart';

/// Durable, server-free crash diagnostics for the distributed macOS app.
///
/// Today's switch-model→Build crash (BUG-IMPL-011) was *invisible*: a native
/// abort leaves no Dart error and — on the affected machine — no findable crash
/// report, so there was nothing to hand off. This makes every crash leave a
/// trail, with a one-click way to export it.
///
/// Three best-effort jobs (nothing here ever throws into the app):
/// 1. **Abnormal-exit detection** — a sentinel file is written at startup and
///    removed on a clean shutdown. If it's still there next launch, the previous
///    session died hard (a crash), even a native one that logged nothing.
/// 2. **Native crash harvest** — copies macOS `.ips`/`.crash` reports the OS
///    writes for this app (`~/Library/Logs/DiagnosticReports`) into our own
///    `crashes/` folder, so the real stack travels next to `diag.log`.
/// 3. **Hand-off** — reveals the diagnostics folder in Finder so the user can
///    send `diag.log` + `crashes/` without hunting for hidden paths.
class CrashDiagnostics {
  static Directory? _supportDir;
  static bool _priorCrashDetected = false;
  static int _harvestedThisLaunch = 0;

  /// True when the previous session ended without a clean shutdown (a crash).
  static bool get priorCrashDetected => _priorCrashDetected;

  /// Native crash reports harvested this launch (from the prior crash).
  static int get harvestedThisLaunch => _harvestedThisLaunch;

  /// The folder holding `diag.log` + `crashes/` — what the user hands off.
  static Directory? get diagnosticsDir => _supportDir;

  static File? _sentinel() {
    final dir = _supportDir;
    return dir == null ? null : File('${dir.path}/session.running');
  }

  /// Call once at startup, AFTER `DiagLog.directoryProvider` is wired.
  static Future<void> onStartup(
      Future<Directory> Function() supportDirProvider) async {
    try {
      final dir = await supportDirProvider();
      _supportDir = dir;
      final sentinel = _sentinel()!;
      if (sentinel.existsSync()) {
        // The sentinel outlived its session → we never shut down cleanly.
        _priorCrashDetected = true;
        DateTime? when;
        try {
          when = sentinel.lastModifiedSync();
        } catch (_) {}
        DiagLog.log('⚠ PREVIOUS SESSION ENDED ABNORMALLY (possible crash)'
            '${when == null ? '' : ' — last alive ~${when.toIso8601String()}'}');
      }
      sentinel.writeAsStringSync(DateTime.now().toIso8601String());
      await _harvestNativeReports(dir);
    } catch (_) {
      // Diagnostics must never break startup.
    }
  }

  /// Call on a clean shutdown (lifecycle `detached`) to clear the sentinel, so
  /// the next launch doesn't falsely report a crash.
  static void markCleanShutdown() {
    try {
      DiagLog.breadcrumb('clean shutdown');
      final s = _sentinel();
      if (s != null && s.existsSync()) s.deleteSync();
    } catch (_) {}
  }

  /// Copies this app's native crash reports written since the last harvest into
  /// `<support>/crashes/`, so a native SIGABRT's stack lands in our bundle.
  static Future<void> _harvestNativeReports(Directory support) async {
    try {
      final home = Platform.environment['HOME'];
      if (home == null) return;
      final reports = Directory('$home/Library/Logs/DiagnosticReports');
      if (!reports.existsSync()) return;
      final crashes = Directory('${support.path}/crashes')
        ..createSync(recursive: true);
      final marker = File('${support.path}/.last_harvest');
      final since = marker.existsSync()
          ? marker.lastModifiedSync()
          : DateTime.fromMillisecondsSinceEpoch(0);
      for (final e in reports.listSync()) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        final lower = name.toLowerCase();
        final mine =
            lower.contains('the_forge') || lower.contains('theforge');
        final isReport = lower.endsWith('.ips') || lower.endsWith('.crash');
        if (!mine || !isReport) continue;
        if (e.lastModifiedSync().isBefore(since)) continue;
        try {
          e.copySync('${crashes.path}/$name');
          _harvestedThisLaunch++;
        } catch (_) {}
      }
      marker.writeAsStringSync(DateTime.now().toIso8601String());
      if (_harvestedThisLaunch > 0) {
        DiagLog.log('Harvested $_harvestedThisLaunch native crash report(s) '
            '→ crashes/');
      }
    } catch (_) {}
  }

  /// Opens the diagnostics folder in Finder (un-sandboxed app) so the user can
  /// grab `diag.log` + `crashes/` to send. Best-effort.
  static Future<void> revealInFinder() async {
    final dir = _supportDir;
    if (dir == null) return;
    try {
      await Process.run('open', [dir.path]);
    } catch (_) {}
  }
}
