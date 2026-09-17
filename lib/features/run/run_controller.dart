import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../data/filesystem/ios_deployment.dart';
import '../../services/diag_log.dart';

/// How a device has to be brought up before `flutter run` can target it.
enum BootMethod { none, iosSim, androidEmu }

/// A device/target `flutter run` can deploy to. Some are already live
/// (physical devices, booted simulators, macOS, Chrome); others are simulators/
/// emulators that exist but need booting first ([needsBoot]).
class RunDevice {
  RunDevice({
    required this.id,
    required this.name,
    required this.targetPlatform,
    required this.emulator,
    this.needsBoot = false,
    this.bootMethod = BootMethod.none,
  });

  final String id;
  final String name;
  final String targetPlatform; // e.g. ios, android-arm64, darwin-arm64, web-javascript
  final bool emulator;
  final bool needsBoot;
  final BootMethod bootMethod;

  factory RunDevice.fromJson(Map<String, dynamic> j) => RunDevice(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? j['id'] ?? 'device').toString(),
        targetPlatform: (j['targetPlatform'] ?? '').toString(),
        emulator: j['emulator'] == true,
      );

  /// How (if at all) we can grab a live frame of the running app for the
  /// in-app mirror: iOS Simulator → `simctl`, Android → `adb`, otherwise none
  /// (macOS/web/physical iOS run in their own window/browser/device).
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

  /// Label for the device dropdown, flagging entries that will be booted.
  String get menuLabel =>
      '$name  ·  $platformLabel${needsBoot ? '  (tap to boot)' : ''}';
}

enum ScreenshotKind { iosSim, android, none }

enum RunState { idle, booting, starting, running, stopping }

/// One line of streamed output from the running app.
class RunLine {
  RunLine(this.text, {required this.isError});
  final String text;
  final bool isError;
}

/// Extracts an iOS version ("18.0") from a CoreSimulator runtime identifier
/// like "com.apple.CoreSimulator.SimRuntime.iOS-18-0". Empty if not iOS.
String iosVersionFromRuntime(String runtime) {
  const key = 'iOS-';
  final i = runtime.indexOf(key);
  if (i == -1) return '';
  return runtime.substring(i + key.length).replaceAll('-', '.');
}

/// Parses `xcrun simctl list devices available --json` into bootable iOS
/// simulators, skipping ones already booted or present in [excludeUdids]
/// (they show up as live devices via `flutter devices`). Pure + testable.
List<RunDevice> parseIosSimulators(String json, Set<String> excludeUdids) {
  final out = <RunDevice>[];
  try {
    final decoded = jsonDecode(json);
    final devices = (decoded is Map) ? decoded['devices'] : null;
    if (devices is! Map) return out;
    devices.forEach((runtime, list) {
      if (runtime is! String || !runtime.contains('iOS') || list is! List) return;
      final ver = iosVersionFromRuntime(runtime);
      for (final d in list) {
        if (d is! Map) continue;
        final udid = (d['udid'] ?? '').toString();
        final state = (d['state'] ?? '').toString();
        if (udid.isEmpty || d['isAvailable'] != true) continue;
        if (state == 'Booted' || excludeUdids.contains(udid)) continue;
        final base = (d['name'] ?? 'iPhone').toString();
        out.add(RunDevice(
          id: udid,
          name: ver.isEmpty ? base : '$base · iOS $ver',
          targetPlatform: 'ios',
          emulator: true,
          needsBoot: true,
          bootMethod: BootMethod.iosSim,
        ));
      }
    });
  } catch (_) {}
  return out;
}

/// Parses `flutter emulators --machine` into bootable Android emulators (AVDs).
/// iOS entries are handled via [parseIosSimulators] instead. Pure + testable.
List<RunDevice> parseAndroidEmulators(String json) {
  final out = <RunDevice>[];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return out;
    for (final e in decoded) {
      if (e is! Map) continue;
      if ((e['platformType'] ?? '').toString() != 'android') continue;
      final id = (e['id'] ?? '').toString();
      if (id.isEmpty) continue;
      out.add(RunDevice(
        id: id,
        name: (e['name'] ?? id).toString(),
        targetPlatform: 'android',
        emulator: true,
        needsBoot: true,
        bootMethod: BootMethod.androidEmu,
      ));
    }
  } catch (_) {}
  return out;
}

/// Drives a long-lived `flutter run` in a project's repo so The Forge can show
/// the app running: discovers devices (including simulators/emulators that need
/// booting), boots the chosen one, streams the console, forwards hot-reload /
/// restart / quit over stdin, and mirrors a live screenshot of the running
/// simulator/emulator into the app.
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

  bool get isBusy =>
      state == RunState.booting ||
      state == RunState.starting ||
      state == RunState.running;

  /// Lists deployable targets: live devices (`flutter devices`) plus bootable
  /// iOS simulators (`simctl`) and Android emulators (`flutter emulators`).
  /// Never throws — returns [] on failure so the UI can show an install hint.
  static Future<List<RunDevice>> listDevices() async {
    final live = await _liveDevices();
    final liveIosUdids =
        live.where((d) => d.targetPlatform == 'ios').map((d) => d.id).toSet();
    final sims = await _bootableIosSimulators(liveIosUdids);
    final emus = await _bootableAndroidEmulators();
    return [...live, ...sims, ...emus];
  }

  static Future<List<RunDevice>> _liveDevices() async {
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

  static Future<List<RunDevice>> _bootableIosSimulators(
      Set<String> excludeUdids) async {
    if (!Platform.isMacOS) return const [];
    try {
      final res = await Process.run(
              'xcrun', ['simctl', 'list', 'devices', 'available', '--json'])
          .timeout(const Duration(seconds: 20));
      return parseIosSimulators((res.stdout ?? '').toString(), excludeUdids);
    } catch (e, st) {
      await DiagLog.error('run.simulators', e, st);
      return const [];
    }
  }

  static Future<List<RunDevice>> _bootableAndroidEmulators() async {
    try {
      final res = await Process.run('flutter', ['emulators', '--machine'])
          .timeout(const Duration(seconds: 20));
      return parseAndroidEmulators((res.stdout ?? '').toString());
    } catch (_) {
      return const []; // no Android SDK / no AVDs — fine.
    }
  }

  void _add(String text, {required bool isError}) {
    lines.add(RunLine(text, isError: isError));
    if (lines.length > _maxLines) lines.removeRange(0, lines.length - _maxLines);
    notifyListeners();
  }

  /// Starts the app on [d]: boots it first if needed, then `flutter run`.
  Future<void> start(RunDevice d) async {
    if (isBusy) return;
    device = d;
    _sawReady = false;
    preview = null;
    previewNote = d.screenshotKind == ScreenshotKind.none
        ? 'This target runs in its own window${d.targetPlatform.startsWith('web') ? '/browser' : d.targetPlatform == 'ios' ? ' on the device' : ''}. '
            'The console shows build progress and errors here.'
        : null;
    lines.clear();
    state = d.needsBoot ? RunState.booting : RunState.starting;
    notifyListeners();

    try {
      var runId = d.id;
      if (d.needsBoot) {
        final booted = await _boot(d);
        if (booted == null) {
          state = RunState.idle;
          notifyListeners();
          return;
        }
        runId = booted;
      }

      // Safety net: raise the iOS deployment target so Xcode 27 doesn't reject
      // the build (covers Podfiles generated after the app was scaffolded).
      if (d.targetPlatform == 'ios') {
        final changed = await applyMinIosDeploymentTarget(repoPath);
        if (changed.isNotEmpty) {
          _add('Raised iOS deployment target to $kMinIosDeploymentTarget '
              '(Xcode 27 compatibility).', isError: false);
        }
      }

      state = RunState.starting;
      _add('\$ flutter run -d $runId   (${d.platformLabel})', isError: false);
      final proc = await Process.start(
        'flutter',
        ['run', '-d', runId],
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

  /// Boots a simulator/emulator and returns the id to `flutter run -d`, or null
  /// if it didn't come up.
  Future<String?> _boot(RunDevice d) async {
    if (d.bootMethod == BootMethod.iosSim) {
      _add('Booting ${d.name}…', isError: false);
      try {
        await Process.run('xcrun', ['simctl', 'boot', d.id]);
      } catch (_) {}
      final ok = await _waitIosBooted(d.id);
      if (!ok) {
        _add('The simulator did not boot in time.', isError: true);
        return null;
      }
      // Best-effort: bring the Simulator window forward if it exists.
      try {
        await Process.run('open', ['-a', 'Simulator']);
      } catch (_) {}
      return d.id;
    }
    // Android emulator: launch the AVD, then wait for its device id to appear.
    _add('Launching ${d.name}…', isError: false);
    final before = (await _liveDevices())
        .where((x) => x.targetPlatform.startsWith('android'))
        .map((x) => x.id)
        .toSet();
    try {
      unawaited(Process.run('flutter', ['emulators', '--launch', d.id]));
    } catch (_) {}
    final id = await _waitNewAndroidDevice(before);
    if (id == null) {
      _add('The emulator did not come up in time.', isError: true);
      return null;
    }
    return id;
  }

  Future<bool> _waitIosBooted(String udid) async {
    for (var i = 0; i < 60; i++) {
      try {
        final res = await Process.run('xcrun', ['simctl', 'list', 'devices']);
        final out = (res.stdout ?? '').toString();
        for (final line in out.split('\n')) {
          if (line.contains(udid) && line.contains('Booted')) return true;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  Future<String?> _waitNewAndroidDevice(Set<String> before) async {
    for (var i = 0; i < 90; i++) {
      final now = await _liveDevices();
      for (final a in now.where((x) => x.targetPlatform.startsWith('android'))) {
        if (!before.contains(a.id)) return a.id;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  void _onLine(String line, {required bool isError}) {
    _add(line, isError: isError);
    if (!_sawReady &&
        (line.contains('Flutter run key commands') ||
            line.contains('is available at:') ||
            line.contains('Syncing files to device'))) {
      _sawReady = true;
      state = RunState.running;
      notifyListeners();
      _scheduleCapture(const Duration(seconds: 3));
    }
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
