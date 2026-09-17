import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/data/filesystem/ios_deployment.dart';

void main() {
  group('iosVersionAtLeast', () {
    test('compares numerically, not lexically', () {
      expect(iosVersionAtLeast('15.0', '15.0'), isTrue);
      expect(iosVersionAtLeast('16.0', '15.0'), isTrue);
      expect(iosVersionAtLeast('12.0', '15.0'), isFalse);
      expect(iosVersionAtLeast('9.0', '15.0'), isFalse); // not fooled by "9" > "1"
      expect(iosVersionAtLeast('15.4', '15.0'), isTrue);
      expect(iosVersionAtLeast('nonsense', '15.0'), isFalse);
    });
  });

  group('bumpPbxproj', () {
    test('raises low targets and leaves higher ones alone', () {
      const input = '''
				IPHONEOS_DEPLOYMENT_TARGET = 12.0;
				IPHONEOS_DEPLOYMENT_TARGET = 13.0;
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
''';
      final out = bumpPbxproj(input);
      expect(out.contains('= 12.0;'), isFalse);
      expect(out.contains('= 13.0;'), isFalse);
      expect('= 15.0;'.allMatches(out).length, 2); // the 12 and 13 bumped
      expect(out.contains('= 16.0;'), isTrue); // higher one untouched
    });
  });

  group('bumpPodfile', () {
    // flutter's default Podfile (platform line commented at an old version).
    const flutterDefault = '''
# Uncomment this line to define a global platform for your project
# platform :ios, '12.0'

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
''';

    test('uncomments/raises the platform line and adds the pod override', () {
      final out = bumpPodfile(flutterDefault);
      expect(out.contains("platform :ios, '15.0'"), isTrue);
      expect(out.contains('# platform :ios'), isFalse);
      expect(
          out.contains(
              "config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'"),
          isTrue);
      // Override sits inside the post_install block, after the flutter helper.
      expect(
          out.indexOf('flutter_additional_ios_build_settings(target)') <
              out.indexOf("config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']"),
          isTrue);
    });

    test('is idempotent — running twice changes nothing further', () {
      final once = bumpPodfile(flutterDefault);
      final twice = bumpPodfile(once);
      expect(twice, once);
    });

    test('leaves an already-higher platform version in place', () {
      const higher = "platform :ios, '16.0'\n\npost_install do |installer|\n"
          '  installer.pods_project.targets.each do |target|\n'
          '    flutter_additional_ios_build_settings(target)\n  end\nend\n';
      final out = bumpPodfile(higher);
      expect(out.contains("platform :ios, '16.0'"), isTrue);
      expect(out.contains("platform :ios, '15.0'"), isFalse);
    });
  });
}
