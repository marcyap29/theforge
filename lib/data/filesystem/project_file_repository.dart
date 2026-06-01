import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum ProjectMode { build, audit }

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

  static Future<Directory> _defaultRootDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'The Forge Projects'));
  }

  Future<String> createProject(String projectName, ProjectMode mode) async {
    final root = await _rootDirProvider();
    final projectDir = Directory(p.join(root.path, projectName));

    if (projectDir.existsSync()) {
      throw ProjectAlreadyExistsException(projectDir.path);
    }

    final specsDir = Directory(p.join(projectDir.path, 'specs'));
    final handoffsDir = Directory(p.join(projectDir.path, 'handoffs'));
    final worksheetsDir = Directory(p.join(projectDir.path, 'worksheets'));
    final auditDir = Directory(p.join(projectDir.path, 'audit'));

    await projectDir.create(recursive: true);
    await specsDir.create();
    await handoffsDir.create();
    await worksheetsDir.create();
    await auditDir.create();

    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final modeDisplay = mode == ProjectMode.build ? 'Build' : 'Audit';

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
        '- Begin $modeDisplay Interview\n'
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

  Future<void> writeLockedSpec(
      String projectPath,
      String projectName,
      String specVersion,
      String content) async {
    final specsDir = Directory(p.join(projectPath, 'specs'));
    final specPath =
        p.join(specsDir.path, '${projectName}_LockedSpec_$specVersion.md');

    if (File(specPath).existsSync()) {
      throw SpecAlreadyExistsException(specPath);
    }

    final tmpPath = '$specPath.tmp';
    final tmpFile = File(tmpPath);
    await tmpFile.writeAsString(content);

    File(tmpPath).renameSync(specPath);
  }

  Future<void> appendAuditLog(
      String projectPath, String projectName, String entry) async {
    final auditDir = Directory(p.join(projectPath, 'audit'));
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
    final handoffsDir = Directory(p.join(projectPath, 'handoffs'));
    final handoffFile = File(p.join(handoffsDir.path, filename));
    await handoffFile.writeAsString(content);
  }

  Future<void> writeWorksheet(
      String projectPath, String filename, String content) async {
    final worksheetsDir = Directory(p.join(projectPath, 'worksheets'));
    final worksheetFile = File(p.join(worksheetsDir.path, filename));
    await worksheetFile.writeAsString(content);
  }

  Future<void> writeHandoffPackage(
      String projectPath, String version, Map<String, dynamic> data) async {
    final packageFile =
        File(p.join(projectPath, 'handoff_package_v$version.json'));
    await packageFile.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
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
}
