import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../features/projects/models/pull_ingestion_summary.dart';

enum ProjectMode { build, audit, pull }

class ProjectAlreadyExistsException implements Exception {
  final String path;
  const ProjectAlreadyExistsException(this.path);

  @override
  String toString() => 'Project already exists at: $path';
}

class SpecAlreadyExistsException implements Exception {
  final String path;
  const SpecAlreadyExistsException(this.path);

  @override
  String toString() => 'Spec already exists at: $path';
}

class ProjectFileRepository {
  final Future<Directory> Function() _rootDirProvider;

  ProjectFileRepository({Future<Directory> Function()? rootDirProvider})
      : _rootDirProvider = rootDirProvider ?? _defaultRootDir;

  /// All Forge-generated deliverables for a project live under this hidden
  /// subfolder inside the project workspace. README.md and user_notes.md stay
  /// at the project root as the human-facing entry points.
  static const forgeDirName = '.forge';

  /// The canonical, fixed home for all Forge project workspaces. It is
  /// deliberately NOT user-configurable and is never a code repo, so the Forge
  /// can always find a project's documentation even as code repos move or are
  /// deleted. Link a code repo per-project via the Repo Path row instead, and
  /// use "Export docs…" to copy deliverables into a repo when wanted.
  static Future<String> canonicalRootPath() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'The Forge Projects');
  }

  static Future<Directory> _defaultRootDir() async =>
      Directory(await canonicalRootPath());

  Future<String> createProject(String projectName, ProjectMode mode) async {
    final root = await _rootDirProvider();
    final projectDir = Directory(p.join(root.path, projectName));

    if (projectDir.existsSync()) {
      throw ProjectAlreadyExistsException(projectDir.path);
    }

    final base = Directory(p.join(projectDir.path, forgeDirName));
    final specsDir = Directory(p.join(base.path, 'specs'));
    final handoffsDir = Directory(p.join(base.path, 'handoffs'));
    final worksheetsDir = Directory(p.join(base.path, 'worksheets'));
    final auditDir = Directory(p.join(base.path, 'audit'));
    final forgeMetaDir = Directory(p.join(base.path, 'forge'));
    final ingestedDir = Directory(p.join(base.path, 'ingested'));

    await projectDir.create(recursive: true);
    await specsDir.create(recursive: true);
    await handoffsDir.create(recursive: true);
    await worksheetsDir.create(recursive: true);
    await auditDir.create(recursive: true);
    await forgeMetaDir.create(recursive: true);
    await ingestedDir.create(recursive: true);

    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final modeDisplay = switch (mode) {
      ProjectMode.build => 'Build',
      ProjectMode.audit => 'Audit',
      ProjectMode.pull => 'Pull',
    };

    final readmeContent = '# $projectName — Project State\n'
        '**Interview mode:** $modeDisplay\n'
        '**Current phase:** v1_interview\n'
        '**Last updated:** $dateStr\n'
        '**Spec version:** v1\n'
        '**Setup worksheet:** Incomplete\n'
        '**Executor status:** Not started\n'
        '## What\'s Done\n'
        '- Project folder created\n'
        '## What\'s Next\n'
        '${mode == ProjectMode.pull ? '- Ingest target codebase (link repo via Repo Path row)\n' : '- Begin $modeDisplay Interview\n'}'
        '## Open Flags\n'
        '- (none)\n';

    final readmeFile = File(p.join(projectDir.path, 'README.md'));
    await readmeFile.writeAsString(readmeContent);

    final auditLogFile =
        File(p.join(auditDir.path, '${projectName}_AuditLog.md'));
    final auditLogContent = '# $projectName — Audit Log\n'
        '---\n';
    await auditLogFile.writeAsString(auditLogContent);

    return projectDir.path;
  }

  Future<String?> readReadme(String projectPath) async {
    final readmeFile = File(p.join(projectPath, 'README.md'));
    if (!readmeFile.existsSync()) {
      return null;
    }
    return readmeFile.readAsString();
  }

  Future<void> writeReadme(String projectPath, String content) async {
    final readmeFile = File(p.join(projectPath, 'README.md'));
    await readmeFile.writeAsString(content);
  }

  /// Before a caller overwrites [file], renames the existing copy to
  /// {stem}{letter}-{M-D-YYYY}{ext} so no data is lost.
  /// Letters cycle a→z. Sync rename — fast, atomic on the same volume.
  Future<void> _archiveIfExists(File file) async {
    if (!file.existsSync()) return;
    final dir = file.parent;
    final stem = p.basenameWithoutExtension(file.path);
    final ext = p.extension(file.path);
    final now = DateTime.now();
    final date = '${now.month}-${now.day}-${now.year}';
    for (final letter in 'abcdefghijklmnopqrstuvwxyz'.split('')) {
      final archive = File(p.join(dir.path, '$stem$letter-$date$ext'));
      if (!archive.existsSync()) {
        file.renameSync(archive.path);
        return;
      }
    }
    // All 26 letters taken on this date — let the caller overwrite.
  }

  Future<void> writeLockedSpec(
      String projectPath,
      String projectName,
      String specVersion,
      String content) async {
    final versionDir = Directory(p.join(projectPath, forgeDirName, 'specs', specVersion));
    await versionDir.create(recursive: true);
    final specPath = p.join(versionDir.path, '${projectName}_LockedSpec_$specVersion.md');

    if (File(specPath).existsSync()) {
      throw SpecAlreadyExistsException(specPath);
    }

    final tmpPath = '$specPath.tmp';
    await File(tmpPath).writeAsString(content);
    File(tmpPath).renameSync(specPath);
  }

  Future<void> appendAuditLog(
      String projectPath, String projectName, String entry) async {
    final auditDir = Directory(p.join(projectPath, forgeDirName, 'audit'));
    final logPath = p.join(auditDir.path, '${projectName}_AuditLog.md');
    final logFile = File(logPath);

    if (!logFile.existsSync()) {
      await logFile.create(recursive: true);
      await logFile.writeAsString('# $projectName — Audit Log\n---\n');
    }

    await logFile.writeAsString(entry, mode: FileMode.append);
  }

  Future<void> writeHandoff(
      String projectPath, String filename, String content) async {
    final version = _extractVersion(filename);
    final dir = version != null
        ? Directory(p.join(projectPath, forgeDirName, 'handoffs', version))
        : Directory(p.join(projectPath, forgeDirName, 'handoffs'));
    await dir.create(recursive: true);
    final handoffFile = File(p.join(dir.path, filename));
    await _archiveIfExists(handoffFile);
    await handoffFile.writeAsString(content);
  }

  Future<void> writeForgeFiles(
    String projectPath,
    String projectName,
    String specVersion, {
    required String lockedSpecContent,
    required String decisionContextContent,
    required String openFlagsContent,
  }) async {
    final versionDir = Directory(p.join(projectPath, forgeDirName, 'forge', specVersion));
    await versionDir.create(recursive: true);
    await File(p.join(versionDir.path, '${projectName}_LockedSpec_$specVersion.md'))
        .writeAsString(lockedSpecContent);
    await File(p.join(versionDir.path, '${projectName}_DecisionContext_$specVersion.md'))
        .writeAsString(decisionContextContent);
    await File(p.join(versionDir.path, '${projectName}_OpenFlags_$specVersion.md'))
        .writeAsString(openFlagsContent);
  }

  Future<void> writeWorksheet(
      String projectPath, String filename, String content) async {
    final version = _extractVersion(filename);
    final dir = version != null
        ? Directory(p.join(projectPath, forgeDirName, 'worksheets', version))
        : Directory(p.join(projectPath, forgeDirName, 'worksheets'));
    await dir.create(recursive: true);
    final worksheetFile = File(p.join(dir.path, filename));
    await _archiveIfExists(worksheetFile);
    await worksheetFile.writeAsString(content);
  }

  Future<void> writeHandoffPackage(
      String projectPath, String projectName, String version, Map<String, dynamic> data) async {
    final versionDir = Directory(p.join(projectPath, forgeDirName, 'handoffs', version));
    await versionDir.create(recursive: true);
    final packageFile = File(p.join(versionDir.path, '${projectName}_HandoffPackage_$version.json'));
    await _archiveIfExists(packageFile);
    await packageFile.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<String> readLockedSpec(
      String projectPath, String projectName, String specVersion) async {
    // Check versioned subfolder first, fall back to flat for existing projects.
    final versionedPath = p.join(
        projectPath, forgeDirName, 'specs', specVersion, '${projectName}_LockedSpec_$specVersion.md');
    if (File(versionedPath).existsSync()) return File(versionedPath).readAsString();
    final flatPath = p.join(
        projectPath, forgeDirName, 'specs', '${projectName}_LockedSpec_$specVersion.md');
    return File(flatPath).readAsString();
  }

  static String? _extractVersion(String filename) {
    final match = RegExp(r'_(v\d+)[._]').firstMatch(filename);
    return match?.group(1);
  }

  static const _versionedFolders = ['specs', 'forge', 'handoffs', 'worksheets'];

  /// Returns true if the project has any flat versioned files that should be
  /// inside a version subfolder.
  Future<bool> hasFlatVersionedFiles(String projectPath) async {
    for (final folder in _versionedFolders) {
      final dir = Directory(p.join(projectPath, forgeDirName, folder));
      if (!dir.existsSync()) continue;
      for (final entry in dir.listSync()) {
        if (entry is File && _extractVersion(p.basename(entry.path)) != null) {
          return true;
        }
      }
    }
    return false;
  }

  /// Migrates flat versioned files into version subfolders.
  /// - Files not yet in a version subfolder are moved there.
  /// - Flat files that are exact duplicates of the versioned copy are deleted.
  /// Returns the number of files moved/cleaned.
  Future<int> migrateToVersionFolders(String projectPath) async {
    int count = 0;
    for (final folder in _versionedFolders) {
      final dir = Directory(p.join(projectPath, forgeDirName, folder));
      if (!dir.existsSync()) continue;
      for (final entry in dir.listSync()) {
        if (entry is! File) continue;
        final filename = p.basename(entry.path);
        final version = _extractVersion(filename);
        if (version == null) continue;

        final destDir = Directory(p.join(projectPath, forgeDirName, folder, version));
        final destFile = File(p.join(destDir.path, filename));

        if (destFile.existsSync()) {
          // Versioned copy already exists — delete the flat duplicate.
          await entry.delete();
        } else {
          // No versioned copy yet — move the flat file there.
          await destDir.create(recursive: true);
          await entry.rename(destFile.path);
        }
        count++;
      }
    }
    return count;
  }

  Future<List<String>> scanProjectPaths() async {
    final root = await _rootDirProvider();
    if (!root.existsSync()) {
      return [];
    }

    final projects = <String>[];
    final entries = root.listSync();
    for (final entry in entries) {
      if (entry is Directory) {
        projects.add(entry.path);
      }
    }

    return projects;
  }

  Future<void> writeIngestedSummary(
      String projectPath, String content) async {
    final ingestedDir = Directory(p.join(projectPath, forgeDirName, 'ingested'));
    final summaryFile =
        File(p.join(ingestedDir.path, 'reference_context.md'));
    await summaryFile.writeAsString(content);
  }

  Future<String?> readIngestedSummary(String projectPath) async {
    final summaryFile =
        File(p.join(projectPath, forgeDirName, 'ingested', 'reference_context.md'));
    if (!summaryFile.existsSync()) return null;
    return summaryFile.readAsString();
  }

  /// Writes/overwrites the durable build-memory record for one feature into
  /// `.forge/build_memory/<featureId>.md`. One file per feature (overwritten on
  /// re-ship) so re-building a feature updates its record instead of appending a
  /// duplicate. This is the "gained" half of accumulating project context.
  Future<void> writeBuildMemory(
      String projectPath, String featureId, String content) async {
    final dir = Directory(p.join(projectPath, forgeDirName, 'build_memory'));
    await dir.create(recursive: true);
    final safe = featureId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    await File(p.join(dir.path, '$safe.md')).writeAsString(content);
  }

  /// Concatenates every shipped feature's build-memory record into one block for
  /// the build agent to read back — this is how context "remains" and grows
  /// across features instead of every build starting cold. Returns null if no
  /// features have shipped yet.
  Future<String?> readBuildMemory(String projectPath) async {
    final dir = Directory(p.join(projectPath, forgeDirName, 'build_memory'));
    if (!dir.existsSync()) return null;
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.extension(f.path) == '.md')
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) return null;
    final buf = StringBuffer();
    for (final f in files) {
      final c = (await f.readAsString()).trim();
      if (c.isEmpty) continue;
      buf..writeln(c)..writeln();
    }
    final s = buf.toString().trim();
    return s.isEmpty ? null : s;
  }

  Future<void> deleteProject(String projectPath) async {
    final dir = Directory(projectPath);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  Future<String> renameProject(String oldPath, String newName) async {
    final oldDir = Directory(oldPath);
    final newPath = p.join(oldDir.parent.path, newName);
    await oldDir.rename(newPath);
    return newPath;
  }

  /// Reads project configuration from {projectPath}/forge/project_config.json
  /// Returns empty map if file doesn't exist
  static Future<Map<String, dynamic>> readProjectConfig(String projectPath) async {
    final configPath = p.join(projectPath, forgeDirName, 'forge', 'project_config.json');
    final config = File(configPath);
    if (!config.existsSync()) {
      return {};
    }
    try {
      return jsonDecode(await config.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  /// Writes project configuration to {projectPath}/forge/project_config.json
  /// Merges with existing config if present
  static Future<void> writeProjectConfig(String projectPath, Map<String, dynamic> data) async {
    final configPath = p.join(projectPath, forgeDirName, 'forge', 'project_config.json');
    final config = File(configPath);
    Map<String, dynamic> existing = {};
    if (config.existsSync()) {
      try {
        existing = jsonDecode(await config.readAsString()) as Map<String, dynamic>;
      } catch (e) {
        // Ignore errors and use empty map
      }
    }
    final merged = {...existing, ...data};
    await config.writeAsString(jsonEncode(merged));
  }

  /// Reads handoff package from versioned subfolder first, falls back to flat
  static Future<Map<String, dynamic>?> readHandoffPackage(
      String projectPath, String projectName, String version) async {
    // Check versioned subfolder first
    final versionedPath = p.join(
        projectPath, forgeDirName, 'handoffs', version, '${projectName}_HandoffPackage_$version.json');
    if (File(versionedPath).existsSync()) {
      try {
        return jsonDecode(await File(versionedPath).readAsString()) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    // Fall back to flat
    final flatPath = p.join(
        projectPath, forgeDirName, 'handoffs', '${projectName}_HandoffPackage_$version.json');
    if (File(flatPath).existsSync()) {
      try {
        return jsonDecode(await File(flatPath).readAsString()) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<List<String>> readValidatedVersions(String projectPath) async {
    final config = await readProjectConfig(projectPath);
    final raw = config['validatedVersions'];
    if (raw is List) return raw.cast<String>();
    return [];
  }

  static Future<void> markVersionValidated(
      String projectPath, String version) async {
    final config = await readProjectConfig(projectPath);
    final current =
        (config['validatedVersions'] as List?)?.cast<String>() ?? [];
    if (current.contains(version)) return;
    config['validatedVersions'] = [...current, version];
    await writeProjectConfig(projectPath, config);
  }

  /// Gets list of changed files from git history in a repository
  /// Returns empty list on any error (not throwing)
  static Future<Set<String>> getGitChangedFiles(String repoPath, {required String since}) async {
    try {
      final process = await Process.run(
        'git',
        ['log', '--name-only', '--pretty=format:', '--since=$since'],
        workingDirectory: repoPath,
      );
      
      if (process.exitCode != 0) {
        return {};
      }
      
      final lines = process.stdout
          .toString()
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
      
      return lines.toSet(); // Remove duplicates
    } catch (e) {
      return {};
    }
  }

  /// Gets list of commit messages from git history in a repository
  /// Returns empty list on any error (not throwing)
  static Future<List<String>> getGitCommitMessages(String repoPath, {required String since}) async {
    try {
      final process = await Process.run(
        'git',
        ['log', '--oneline', '--since=$since'],
        workingDirectory: repoPath,
      );
      
      if (process.exitCode != 0) {
        return [];
      }
      
      final lines = process.stdout
          .toString()
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
      
      return lines;
    } catch (e) {
      return [];
    }
  }

  /// Gets current git HEAD commit hash
  /// Returns null on any error (not throwing)
  static Future<String?> getGitHead(String repoPath) async {
    try {
      final process = await Process.run(
        'git',
        ['rev-parse', 'HEAD'],
        workingDirectory: repoPath,
      );
      
      if (process.exitCode != 0) {
        return null;
      }
      
      return process.stdout.toString().trim();
    } catch (e) {
      return null;
    }
  }

  /// The default place a user's code lives (`~/Development`). New code folders
  /// created from within The Forge go here, so a non-technical user never has
  /// to make or find a repo folder themselves.
  static String defaultCodeRoot() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return p.join(home, 'Development');
  }

  /// Creates a fresh code folder for [projectName] under [defaultCodeRoot],
  /// `git init`s it, and seeds a README so it's a valid, non-empty repo that
  /// Build with AI can write into. Never overwrites — appends `-2`, `-3`… if a
  /// folder of that name already exists. Returns the created absolute path.
  static Future<String> createCodeRepo(String projectName) async {
    final root = Directory(defaultCodeRoot());
    await root.create(recursive: true);

    final safe = projectName.trim().replaceAll(RegExp(r'[^\w.\-]+'), '-');
    final base = safe.isEmpty ? 'project' : safe;
    var dest = Directory(p.join(root.path, base));
    var n = 2;
    while (dest.existsSync()) {
      dest = Directory(p.join(root.path, '$base-$n'));
      n++;
    }
    await dest.create(recursive: true);

    await File(p.join(dest.path, 'README.md'))
        .writeAsString('# $projectName\n\nCreated by The Forge.\n');
    // git init is best-effort — a machine without git still gets a usable
    // folder that a user can init later.
    try {
      await Process.run('git', ['init'], workingDirectory: dest.path);
    } catch (_) {}
    return dest.path;
  }

  /// Stages all changes and commits them in the linked repo. Returns true on
  /// success. Never throws — a non-repo or a failed commit returns false.
  static Future<bool> gitCommitAll(String repoPath, String message) async {
    try {
      final add =
          await Process.run('git', ['add', '-A'], workingDirectory: repoPath);
      if (add.exitCode != 0) return false;
      final commit = await Process.run(
        'git',
        ['commit', '-m', message],
        workingDirectory: repoPath,
      );
      return commit.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Pushes the linked repo's current branch to its remote. Returns true on
  /// success; false (never throws) if there's no remote / auth fails.
  static Future<bool> gitPush(String repoPath) async {
    try {
      final res =
          await Process.run('git', ['push'], workingDirectory: repoPath);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Creates an annotated git tag in the linked repo. Returns true on success.
  static Future<bool> gitTag(String repoPath, String tag,
      {String? message}) async {
    try {
      final res = await Process.run(
        'git',
        ['tag', '-a', tag, '-m', message ?? tag],
        workingDirectory: repoPath,
      );
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Writes verification result cache to forge/{version}/Name_Verification_{version}.json
  static Future<void> writeVerificationResult(
      String projectPath, String projectName, String specVersion,
      Map<String, dynamic> data) async {
    final versionDir = Directory(p.join(projectPath, forgeDirName, 'forge', specVersion));
    await versionDir.create(recursive: true);
    final cacheFile = File(p.join(versionDir.path, '${projectName}_Verification_$specVersion.json'));
    await cacheFile.writeAsString(jsonEncode(data));
  }

  /// Reads verification result cache from forge/{version}/Name_Verification_{version}.json
  static Future<Map<String, dynamic>?> readVerificationResult(
      String projectPath, String projectName, String specVersion) async {
    final cacheFile = File(p.join(
        projectPath, forgeDirName, 'forge', specVersion, '${projectName}_Verification_$specVersion.json'));
    if (!cacheFile.existsSync()) return null;
    try {
      return jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<List<File>> listReferenceDocs(String projectPath) async {
    final ingestedDir = Directory(p.join(projectPath, forgeDirName, 'ingested'));
    if (!ingestedDir.existsSync()) return [];
    final all = ingestedDir
        .listSync()
        .whereType<File>()
        .where((f) {
          final name = p.basename(f.path);
          return name != 'reference_context.md' && !name.endsWith('.facts.md');
        })
        .toList();
    return all;
  }

  Future<File> copyReferenceDoc(
      String projectPath, String sourcePath) async {
    final source = File(sourcePath);
    final filename = p.basename(sourcePath);
    final ingestedDir = Directory(p.join(projectPath, forgeDirName, 'ingested'));
    final destPath = p.join(ingestedDir.path, filename);
    return source.copy(destPath);
  }

  Future<void> writeIngestedFile(
      String projectPath, String filename, String content) async {
    final ingestedDir = Directory(p.join(projectPath, forgeDirName, 'ingested'));
    final file = File(p.join(ingestedDir.path, filename));
    await file.writeAsString(content);
  }

  /// Appends a story amendment entry to ingested/{projectName}_StoryAmendments_{specVersion}.md.
  /// Returns the label used (e.g. "V1a", "V1b").
  Future<String> appendStoryAmendment({
    required String projectPath,
    required String projectName,
    required String specVersion,
    required String amendmentText,
  }) async {
    final ingestedDir = Directory(p.join(projectPath, forgeDirName, 'ingested'));
    await ingestedDir.create(recursive: true);
    final file = File(p.join(ingestedDir.path,
        '${projectName}_StoryAmendments_$specVersion.md'));

    // Count existing amendments to derive the next label letter (a, b, c, ...).
    int existingCount = 0;
    if (await file.exists()) {
      final content = await file.readAsString();
      existingCount = RegExp(r'^## Amendment', multiLine: true)
          .allMatches(content)
          .length;
    }
    final letter = String.fromCharCode(
        'a'.codeUnitAt(0) + existingCount);
    final versionUpper = specVersion.toUpperCase();
    final label = '$versionUpper$letter';
    final date = DateTime.now().toIso8601String().substring(0, 10);

    final entry = '\n## Amendment $label — $date\n$amendmentText\n';

    if (await file.exists()) {
      await file.writeAsString(entry, mode: FileMode.append);
    } else {
      await file.writeAsString('# $projectName — Story Amendments ($versionUpper)\n\n$entry');
    }

    return label;
  }

  Future<void> writeInterviewProgress(
      String projectPath, String projectName, Map<String, dynamic> data) async {
    final auditDir = Directory(p.join(projectPath, forgeDirName, 'audit'));
    final file = File(p.join(auditDir.path, '${projectName}_InterviewState.json'));
    await file.writeAsString(jsonEncode(data));
  }

  Future<Map<String, dynamic>?> readInterviewProgress(
      String projectPath, String projectName) async {
    final file = File(
        p.join(projectPath, forgeDirName, 'audit', '${projectName}_InterviewState.json'));
    if (!file.existsSync()) return null;
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  Future<void> clearInterviewProgress(
      String projectPath, String projectName) async {
    final file = File(
        p.join(projectPath, forgeDirName, 'audit', '${projectName}_InterviewState.json'));
    if (file.existsSync()) await file.delete();
  }

  Future<void> updateHandoffPackageField(String projectPath, String projectName,
      String specVersion, Map<String, dynamic> updates) async {
    final file = File(p.join(
        projectPath, forgeDirName, 'handoffs', '${projectName}_HandoffPackage_$specVersion.json'));
    if (!await file.exists()) return;
    try {
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      data.addAll(updates);
      await file.writeAsString(jsonEncode(data));
    } on FormatException {
      return;
    }
  }

  Future<String?> readFeatureContext(
      String projectPath, String projectName, String priorSpecVersion) async {
    final versionMatch = RegExp(r'^v(\d+)$').firstMatch(priorSpecVersion);
    if (versionMatch == null) return null;
    final priorN = int.parse(versionMatch.group(1)!);

    final parts = <String>[];

    // Read ALL locked specs v1 → priorSpecVersion so the LLM has the full
    // product history (who it's for, what shipped, what was deferred).
    for (int i = 1; i <= priorN; i++) {
      final version = 'v$i';
      // Versioned subfolder first, flat fallback (mirrors readLockedSpec).
      final versionedPath = p.join(
          projectPath, forgeDirName, 'specs', version, '${projectName}_LockedSpec_$version.md');
      final flatPath = p.join(
          projectPath, forgeDirName, 'specs', '${projectName}_LockedSpec_$version.md');
      final specFile = File(versionedPath).existsSync()
          ? File(versionedPath)
          : File(flatPath);
      if (!specFile.existsSync()) continue;
      final specContent = await specFile.readAsString();
      final label = i == priorN
          ? 'PRIOR LOCKED SPEC ($version — immutable, most recent shipped)'
          : 'SHIPPED SPEC ($version — immutable)';
      parts.add('$label:\n$specContent');
    }

    // Backlog seeds are always from the most recent prior version.
    final seedsFile =
        File(p.join(projectPath, forgeDirName, 'ingested', '${projectName}_V2Seeds.md'));
    if (seedsFile.existsSync()) {
      final seedsContent = await seedsFile.readAsString();
      parts.add(
          'BACKLOG SEEDS (features deferred from $priorSpecVersion, candidates for this version):\n$seedsContent');
    }

    return parts.isEmpty ? null : parts.join('\n\n---\n\n');
  }

  Future<String> readUserNotes(String projectPath) async {
    final file = File(p.join(projectPath, 'user_notes.md'));
    if (!file.existsSync()) return '';
    return file.readAsString();
  }

  Future<void> writeUserNotes(String projectPath, String content) async {
    final file = File(p.join(projectPath, 'user_notes.md'));
    await file.writeAsString(content);
  }

  Future<List<String>> readUserBacklog(String projectPath) async {
    final file = File(p.join(projectPath, 'user_backlog.md'));
    if (!file.existsSync()) return [];
    final lines = await file.readAsString();
    return lines
        .split('\n')
        .map((l) => l.startsWith('- ') ? l.substring(2).trim() : l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  Future<void> writeUserBacklog(String projectPath, List<String> items) async {
    final file = File(p.join(projectPath, 'user_backlog.md'));
    await file.writeAsString(items.map((i) => '- $i').join('\n'));
  }

  Future<List<Map<String, dynamic>>> scanProjectCodebase(
      String projectPath, List<String> extensions) async {
    final rootDir = Directory(projectPath);
    final results = <Map<String, dynamic>>[];

    final queue = [rootDir];
    while (queue.isNotEmpty) {
      final dir = queue.removeAt(0);
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync()) {
        if (entity is Directory) {
          final baseName = p.basename(entity.path);
          if (baseName != '.git' && baseName != '.build') {
            queue.add(entity);
          }
        } else if (entity is File) {
          final ext = p.extension(entity.path);
          if (extensions.contains(ext)) {
            try {
              final content = await entity.readAsString();
              results.add({
                'filePath': entity.path,
                'extension': ext,
                'content': content,
                'filename': p.basename(entity.path),
              });
            } catch (e) {
              continue;
            }
          }
        }
      }
    }

    return results;
  }

  Future<void> writeIngestionSummary(
      String projectPath, String projectName, IngestionSummary summary) async {
    final ingestedDir = Directory(p.join(projectPath, forgeDirName, 'ingested'));
    await ingestedDir.create(recursive: true);

    final jsonPath = p.join(ingestedDir.path,
        '${projectName}_IngestionSummary_${summary.scannedAt.millisecondsSinceEpoch}.json');
    final jsonFile = File(jsonPath);
    await jsonFile.writeAsString(jsonEncode(summary.toJson()));

    final mdContent = summary.toMarkdown();
    final mdPath = p.join(ingestedDir.path,
        '${projectName}_IngestionSummary.md');
    final mdFile = File(mdPath);
    await mdFile.writeAsString(mdContent);
  }

  Future<IngestionSummary?> readIngestionSummary(
      String projectPath, String projectName) async {
    final ingestedDir = Directory(p.join(projectPath, forgeDirName, 'ingested'));
    if (!ingestedDir.existsSync()) return null;

    final jsonFiles = ingestedDir
        .listSync()
        .where((e) => e is File && p.basename(e.path).endsWith('_IngestionSummary.json'))
        .cast<File>()
        .toList();

    if (jsonFiles.isEmpty) return null;

    jsonFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final latestFile = jsonFiles.first;

    try {
      final data = jsonDecode(await latestFile.readAsString()) as Map<String, dynamic>;
      return IngestionSummary.fromJson(data);
    } on FormatException {
      return null;
    }
  }

  Future<void> writeAsBuiltSpec(
      String projectPath, String projectName, String content) async {
    final versionDir = Directory(p.join(projectPath, forgeDirName, 'specs', 'v1'));
    await versionDir.create(recursive: true);
    final specPath =
        p.join(versionDir.path, '${projectName}_AsBuiltSpec_v1.md');
    await _archiveIfExists(File(specPath));
    final tmpPath = '$specPath.tmp';
    await File(tmpPath).writeAsString(content);
    File(tmpPath).renameSync(specPath);
  }

  Future<void> writePullInterviewLog(String projectPath, String projectName,
      List<Map<String, dynamic>> turns) async {
    final auditDir = Directory(p.join(projectPath, forgeDirName, 'audit'));
    final file =
        File(p.join(auditDir.path, '${projectName}_PullInterview.json'));
    await file.writeAsString(jsonEncode(turns));
  }

  Future<List<Map<String, dynamic>>> readPullInterviewLog(
      String projectPath, String projectName) async {
    final file = File(
        p.join(projectPath, forgeDirName, 'audit', '${projectName}_PullInterview.json'));
    if (!file.existsSync()) return [];
    try {
      return (jsonDecode(await file.readAsString()) as List<dynamic>)
          .cast<Map<String, dynamic>>();
    } on FormatException {
      return [];
    }
  }

  /// Finds the locked spec file for [version] inside [projectPath]/specs/.
  /// Searches specs/v{version}/ for a file ending in
  /// `_LockedSpec_v{version}.md` or `_LockedSpec_{version}.md`.
  /// Returns null if nothing found.
  Future<File?> findSpecFile(String projectPath, String version) async {
    final vDir = Directory('$projectPath/specs/v$version');
    if (!await vDir.exists()) return null;
    final suffix1 = '_LockedSpec_v$version.md';
    final suffix2 = '_LockedSpec_$version.md';
    await for (final entity in vDir.list()) {
      if (entity is File) {
        final name = p.basename(entity.path);
        if (name.endsWith(suffix1) || name.endsWith(suffix2)) {
          return entity;
        }
      }
    }
    return null;
  }

  /// Writes a minor-version locked spec file at:
  /// [projectPath]/specs/v[minorVersion]/[projectName]_LockedSpec_[minorVersion].md
  Future<void> writeMinorLockedSpec(
    String projectPath,
    String projectName,
    String minorVersion,
    String content,
  ) async {
    final dir = Directory('$projectPath/specs/v$minorVersion');
    await dir.create(recursive: true);
    final file = File(
        '${dir.path}/${projectName}_LockedSpec_$minorVersion.md');
    await file.writeAsString(content);
  }
}
