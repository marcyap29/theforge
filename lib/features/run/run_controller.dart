import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../services/diag_log.dart';

/// A device/target `flutter run` can deploy to, as reported by
/// `flutter devices --machine`.
class RunDevice {
  RunDevice({
    required this.id,
    required this.name,
    required this.targetPlatform,
    required this.emulator,
  });

  final String id;
  final String name;
  final String targetPlatform; // e.g. ios, android-arm64, darwin-arm64, web-javascript
  final bool emulator;

  factory RunDevice.fromJson(Map<String, dynamic> j) => RunDevice(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? j['id'] ?? 'device').toString(),
        targetPlatform: (j['targetPlatform'] ?? '').toString(),
        emulator: j['emulator'] == true,
      );

  /// How (if at all) we can grab a live frame of the running app for the
  /// in-app mirror: iOS Simulator → `simctl`, Android → `adb`, otherwise none
  /// (macOS/web run in their own window/browser).
  ScreenshotKind get screenshotKind {
    if (targetPlatform.startsWith('android')) return ScreenshotKind.android;
    if (targetPlatform == 'ios' && emulator) return ScreenshotKind.iosSim;
    return ScreenshotKind.none;
  }

  bool get opensOwnWindow =>
      targetPlatform.startsWith('darwin') ||
      targetPlatform.startsWith('web') ||
      targetPlatform.startsWith('windows') ||
      targetPlatform.startsWith('linux');

  String get platformLabel {
    if (targetPlatform.startsWith('android')) {
      return emulator ? 'Android emulator' : 'Android device';
    }
    if (targetPlatform == 'ios') return emulator ? 'iOS Simulator' : 'iOS device';
    if (targetPlatform.startsWith('darwin')) return 'macOS';
    if (targetPlatform.startsWith('web')) return 'Web (Chrome)';
    return targetPlatform.isEmpty ? 'device' : targetPlatform;
  }
}

enum ScreenshotKind { iosSim, android, none }

enum RunState { idle, starting, running, stopping }

/// One line of streamed output from the running app.
class RunLine {
  RunLine(this.text, {required this.isError});
  final String text;
  final bool isError;
}

/// Drives a long-lived `flutter run` in a project's repo so The Forge can show
/// the app running: streams the console, forwards hot-reload / hot-restart /
/// quit over stdin, and mirrors a live screenshot of the running simulator /
/// emulator into the app. Unlike [CommandRunner] (fire-and-forget with a
/// timeout), this keeps the process alive and interactive.
class RunController extends ChangeNotifier {
  RunController(this.repoPath);

  final String repoPath;

  Process? _proc;
  RunState state = RunState.idle;
  RunDevice? device;
  final List<RunLine> lines = [];
  Uint8List? preview; // last captured frame of the running app
  String? previewNote; // shown when we can't mirror (macOS/web/physical iOS)
  bool _sawReady = false;

  static const _maxLines = 600;

  bool get isBusy => state == RunState.starting || state == RunState.running;

  /// Lists deployable targets. Never throws — returns [] and logs on failure
  /// (e.g. `flutter` not on PATH), so the UI can show an install hint.
  static Future<List<RunDevice>> listDevices() async {
    try {
      final res = await Process.run('flutter', ['devices', '--machine'])
          .timeout(const Duration(seconds: 25));
      final out = (res.stdout ?? '').toString();
      final start = out.indexOf('[');
      final end = out.lastIndexOf(']');
      if (start == -1 || end <= start) return const [];
      final decoded = jsonDecode(out.substring(start, end + 1));
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RunDevice.fromJson)
          .where((d) => d.id.isNotEmpty)
          .toList();
    } catch (e, st) {
      await DiagLog.error('run.devices', e, st);
      return const [];
    }
  }

  void _add(String text, {required bool isError}) {
    lines.add(RunLine(text, isError: isError));
    if (lines.length > _maxLines) lines.removeRange(0, lines.length - _maxLines);
    notifyListeners();
  }

  /// Starts `flutter run -d <device>` in [repoPath] and begins streaming.
  Future<void> start(RunDevice d) async {
    if (isBusy) return;
    device = d;
    state = RunState.starting;
    _sawReady = false;
    preview = null;
    previewNote = d.screenshotKind == ScreenshotKind.none
        ? 'This target runs in its own window${d.targetPlatform.startsWith('web') ? '/browser' : ''}. '
            'The console shows build progress and errors here.'
        : null;
    lines.clear();
    _add('\$ flutter run -d ${d.id}   (${d.platformLabel})', isError: false);
    notifyListeners();

    try {
      final proc = await Process.start(
        'flutter',
        ['run', '-d', d.id],
        workingDirectory: repoPath,
        runInShell: false,
      );
      _proc = proc;
      proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _onLine(line, isError: false));
      proc.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _onLine(line, isError: true));
      unawaited(proc.exitCode.then(_onExit));
    } catch (e, st) {
      await DiagLog.error('run.start', e, st);
      _add('Could not start: $e (is Flutter installed and on PATH?)',
          isError: true);
      state = RunState.idle;
      _proc = null;
      notifyListeners();
    }
  }

  void _onLine(String line, {required bool isError}) {
    _add(line, isError: isError);
    // First sign the app is up → flip to running and grab an initial frame.
    if (!_sawReady &&
        (line.contains('Flutter run key commands') ||
            line.contains('is available at:') ||
            line.contains('Syncing files to device'))) {
      _sawReady = true;
      state = RunState.running;
      notifyListeners();
      _scheduleCapture(const Duration(seconds: 3));
    }
    // A completed reload/restart → refresh the mirror.
    if (line.contains('Reloaded ') || line.contains('Restarted application')) {
      _scheduleCapture(const Duration(milliseconds: 1400));
    }
  }

  void _onExit(int code) {
    _add('— flutter run exited (code $code) —', isError: code != 0);
    state = RunState.idle;
    _proc = null;
    notifyListeners();
  }

  void hotReload() {
    if (state != RunState.running) return;
    _add('↻ hot reload', isError: false);
    _stdin('r');
  }

  void hotRestart() {
    if (state != RunState.running) return;
    _add('⟳ hot restart', isError: false);
    _stdin('R');
  }

  /// Asks flutter to quit (`q`), then force-kills after a short grace period.
  Future<void> stop() async {
    if (_proc == null) return;
    state = RunState.stopping;
    notifyListeners();
    _stdin('q');
    await Future<void>.delayed(const Duration(seconds: 2));
    _proc?.kill();
  }

  void _stdin(String key) {
    try {
      _proc?.stdin.write('$key\n');
    } catch (_) {}
  }

  Timer? _captureTimer;
  void _scheduleCapture(Duration delay) {
    _captureTimer?.cancel();
    _captureTimer = Timer(delay, capturePreview);
  }

  /// Grabs the current frame of the running simulator/emulator into [preview].
  /// No-op (with a note) for targets we can't mirror.
  Future<void> capturePreview() async {
    final d = device;
    if (d == null) return;
    try {
      switch (d.screenshotKind) {
        case ScreenshotKind.iosSim:
          final path =
              p.join(Directory.systemTemp.path, 'forge_ios_preview.png');
          final res = await Process.run(
                  'xcrun', ['simctl', 'io', 'booted', 'screenshot', path])
              .timeout(const Duration(seconds: 15));
          if (res.exitCode == 0) {
            preview = await File(path).readAsBytes();
            previewNote = null;
          } else {
            previewNote = 'Could not capture the simulator screen.';
          }
        case ScreenshotKind.android:
          final res = await Process.run('adb', ['exec-out', 'screencap', '-p'],
                  stdoutEncoding: null)
              .timeout(const Duration(seconds: 15));
          if (res.exitCode == 0 && res.stdout is List<int>) {
            preview = Uint8List.fromList(res.stdout as List<int>);
            previewNote = null;
          } else {
            previewNote = 'Could not capture the emulator screen '
                '(is `adb` on PATH?).';
          }
        case ScreenshotKind.none:
          break;
      }
    } catch (e, st) {
      await DiagLog.error('run.capture', e, st);
      previewNote = 'Preview capture failed: $e';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _proc?.kill();
    _proc = null;
    super.dispose();
  }
}
