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
}
