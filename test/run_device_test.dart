import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/features/run/run_controller.dart';

void main() {
  group('RunDevice.fromJson + screenshotKind', () {
    test('iOS Simulator → simctl mirror', () {
      final d = RunDevice.fromJson(const {
        'id': 'UDID-123',
        'name': 'iPhone 15',
        'targetPlatform': 'ios',
        'emulator': true,
      });
      expect(d.screenshotKind, ScreenshotKind.iosSim);
      expect(d.platformLabel, 'iOS Simulator');
      expect(d.opensOwnWindow, isFalse);
    });

    test('physical iOS device → no mirror (no simctl)', () {
      final d = RunDevice.fromJson(const {
        'id': 'phone',
        'name': 'Marc iPhone',
        'targetPlatform': 'ios',
        'emulator': false,
      });
      expect(d.screenshotKind, ScreenshotKind.none);
      expect(d.platformLabel, 'iOS device');
    });

    test('Android (emulator or device) → adb mirror', () {
      final emu = RunDevice.fromJson(const {
        'id': 'emulator-5554',
        'name': 'Pixel 7',
        'targetPlatform': 'android-arm64',
        'emulator': true,
      });
      expect(emu.screenshotKind, ScreenshotKind.android);
      expect(emu.platformLabel, 'Android emulator');
    });

    test('macOS and web open their own window, no mirror', () {
      final mac = RunDevice.fromJson(const {
        'id': 'macos',
        'name': 'macOS',
        'targetPlatform': 'darwin-arm64',
        'emulator': false,
      });
      expect(mac.screenshotKind, ScreenshotKind.none);
      expect(mac.opensOwnWindow, isTrue);

      final web = RunDevice.fromJson(const {
        'id': 'chrome',
        'name': 'Chrome',
        'targetPlatform': 'web-javascript',
        'emulator': false,
      });
      expect(web.opensOwnWindow, isTrue);
      expect(web.platformLabel, 'Web (Chrome)');
    });

    test('missing fields degrade gracefully', () {
      final d = RunDevice.fromJson(const {'id': 'x'});
      expect(d.name, 'x');
      expect(d.emulator, isFalse);
      expect(d.screenshotKind, ScreenshotKind.none);
    });
  });

  group('iosVersionFromRuntime', () {
    test('parses the runtime identifier', () {
      expect(
          iosVersionFromRuntime(
              'com.apple.CoreSimulator.SimRuntime.iOS-18-0'),
          '18.0');
      expect(iosVersionFromRuntime('com.apple.CoreSimulator.SimRuntime.tvOS-17-0'),
          '');
    });
  });

  group('parseIosSimulators', () {
    const json = '''
{"devices": {
  "com.apple.CoreSimulator.SimRuntime.iOS-18-0": [
    {"udid":"AAA","name":"iPhone 16 Pro","state":"Shutdown","isAvailable":true},
    {"udid":"BBB","name":"iPhone 16","state":"Booted","isAvailable":true},
    {"udid":"CCC","name":"iPhone SE","state":"Shutdown","isAvailable":false}
  ],
  "com.apple.CoreSimulator.SimRuntime.watchOS-11-0": [
    {"udid":"WWW","name":"Apple Watch","state":"Shutdown","isAvailable":true}
  ]
}}''';

    test('returns only bootable, available iOS sims (skips booted/unavailable/non-iOS)', () {
      final sims = parseIosSimulators(json, {});
      expect(sims.map((d) => d.id), ['AAA']);
      final d = sims.single;
      expect(d.needsBoot, isTrue);
      expect(d.bootMethod, BootMethod.iosSim);
      expect(d.screenshotKind, ScreenshotKind.iosSim);
      expect(d.name, contains('iOS 18.0'));
      expect(d.menuLabel, contains('tap to boot'));
    });

    test('excludes UDIDs already live via flutter devices', () {
      expect(parseIosSimulators(json, {'AAA'}), isEmpty);
    });

    test('bad JSON yields empty, not a throw', () {
      expect(parseIosSimulators('not json', {}), isEmpty);
    });
  });

  group('parseAndroidEmulators', () {
    const json = '''
[
  {"id":"Pixel_7_API_34","name":"Pixel 7","platformType":"android","category":"mobile"},
  {"id":"apple_ios_simulator","name":"iOS Simulator","platformType":"ios"}
]''';

    test('returns Android AVDs only, marked bootable', () {
      final emus = parseAndroidEmulators(json);
      expect(emus.map((d) => d.id), ['Pixel_7_API_34']);
      final d = emus.single;
      expect(d.needsBoot, isTrue);
      expect(d.bootMethod, BootMethod.androidEmu);
      expect(d.screenshotKind, ScreenshotKind.android);
    });
  });
}
