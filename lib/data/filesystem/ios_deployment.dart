import 'dart:io';

import 'package:path/path.dart' as p;

/// The minimum iOS deployment target The Forge scaffolds apps at. Xcode 27
/// rejects anything below 15.0 ("the range of supported deployment target
/// versions is 15.0 to 27.0.x"), which used to break `flutter run` on freshly
/// created apps. We bump new apps to this at scaffold time so no one hits it.
const kMinIosDeploymentTarget = '15.0';

/// True when [ver] (e.g. "12.0") is >= [min] (e.g. "15.0"), compared segment by
/// segment numerically. A malformed version is treated as below the minimum so
/// it gets bumped rather than silently left too low.
bool iosVersionAtLeast(String ver, String min) {
  final a = ver.split('.').map((s) => int.tryParse(s.trim())).toList();
  final b = min.split('.').map((s) => int.tryParse(s.trim())).toList();
  if (a.any((x) => x == null)) return false;
  for (var i = 0; i < a.length && i < b.length; i++) {
    final c = a[i]!.compareTo(b[i] ?? 0);
    if (c != 0) return c > 0;
  }
  return a.length >= b.length;
}

/// Rewrites `IPHONEOS_DEPLOYMENT_TARGET = X;` lines in an Xcode `project.pbxproj`
/// so any below [version] are raised to it (never downgrades a higher one).
String bumpPbxproj(String content, {String version = kMinIosDeploymentTarget}) {
  final re = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9]+(?:\.[0-9]+)?);');
  return content.replaceAllMapped(re, (m) {
    final cur = m.group(1)!;
    return iosVersionAtLeast(cur, version)
        ? m.group(0)!
        : 'IPHONEOS_DEPLOYMENT_TARGET = $version;';
  });
}

/// Ensures an iOS `Podfile` pins the platform to at least [version] and forces
/// every pod to that deployment target in `post_install` (pods otherwise
/// inherit an older minimum from their own podspec and re-break the build).
/// Idempotent — safe to run repeatedly.
String bumpPodfile(String content, {String version = kMinIosDeploymentTarget}) {
  var out = content;

  // 1) The `platform :ios, 'X'` line — flutter's default ships it commented at
  //    an old version. Uncomment/raise it; leave an already-higher one alone.
  final platRe = RegExp(
    r"""^[ \t]*#?[ \t]*platform[ \t]+:ios[ \t]*,[ \t]*['"]([0-9.]+)['"].*$""",
    multiLine: true,
  );
  final m = platRe.firstMatch(out);
  if (m != null) {
    final cur = m.group(1)!;
    final target = iosVersionAtLeast(cur, version) ? cur : version;
    out = out.replaceRange(m.start, m.end, "platform :ios, '$target'");
  } else {
    out = "platform :ios, '$version'\n$out";
  }

  // 2) The post_install override that forces pods to the target.
  const marker = "config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']";
  if (!out.contains(marker)) {
    final inject = '\n    target.build_configurations.each do |config|\n'
        "      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '$version'\n"
        '    end';
    const anchor = 'flutter_additional_ios_build_settings(target)';
    final idx = out.indexOf(anchor);
    if (idx != -1) {
      final at = idx + anchor.length;
      out = out.substring(0, at) + inject + out.substring(at);
    } else {
      out = '$out\n\npost_install do |installer|\n'
          '  installer.pods_project.targets.each do |target|$inject\n'
          '  end\nend\n';
    }
  }
  return out;
}

/// Applies [kMinIosDeploymentTarget] to a repo's iOS project + Podfile (whichever
/// exist). Returns the list of files it actually changed (empty if already fine
/// or there's no `ios/` folder). Never throws — a write failure is swallowed so
/// it can't break a scaffold/run.
Future<List<String>> applyMinIosDeploymentTarget(
  String repoPath, {
  String version = kMinIosDeploymentTarget,
}) async {
  final changed = <String>[];
  if (!Directory(p.join(repoPath, 'ios')).existsSync()) return changed;
  final targets = <String, String Function(String)>{
    p.join('ios', 'Runner.xcodeproj', 'project.pbxproj'): (c) =>
        bumpPbxproj(c, version: version),
    p.join('ios', 'Podfile'): (c) => bumpPodfile(c, version: version),
  };
  for (final entry in targets.entries) {
    try {
      final f = File(p.join(repoPath, entry.key));
      if (!f.existsSync()) continue;
      final orig = await f.readAsString();
      final next = entry.value(orig);
      if (next != orig) {
        await f.writeAsString(next);
        changed.add(entry.key);
      }
    } catch (_) {
      // best-effort; leave the file as-is on any read/write error.
    }
  }
  return changed;
}
