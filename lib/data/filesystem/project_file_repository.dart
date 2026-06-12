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
    final forgeDir = Directory(p.join(projectDir.path, 'forge'));
    final ingestedDir = Directory(p.join(projectDir.path, 'ingested'));

    await projectDir.create(recursive: true);
    await specsDir.create();
    await handoffsDir.create();
    await worksheetsDir.create();
    await auditDir.create();
    await forgeDir.create();
    await ingestedDir.create();

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

  Future<void> writeForgeFiles(
    String projectPath,
    String projectName,
    String specVersion, {
    required String lockedSpecContent,
    required String decisionContextContent,
    required String openFlagsContent,
  }) async {
    final forgeDir = Directory(p.join(projectPath, 'forge'));
    await File(p.join(forgeDir.path, '${projectName}_LockedSpec_$specVersion.md'))
        .writeAsString(lockedSpecContent);
    await File(p.join(forgeDir.path, '${projectName}_DecisionContext_$specVersion.md'))
        .writeAsString(decisionContextContent);
    await File(p.join(forgeDir.path, '${projectName}_OpenFlags_$specVersion.md'))
        .writeAsString(openFlagsContent);
  }

  Future<void> writeWorksheet(
      String projectPath, String filename, String content) async {
    final worksheetsDir = Directory(p.join(projectPath, 'worksheets'));
    final worksheetFile = File(p.join(worksheetsDir.path, filename));
    await worksheetFile.writeAsString(content);
  }

  Future<void> writeHandoffPackage(
      String projectPath, String projectName, String version, Map<String, dynamic> data) async {
    final handoffsDir = Directory(p.join(projectPath, 'handoffs'));
    final packageFile =
        File(p.join(handoffsDir.path, '${projectName}_HandoffPackage_$version.json'));
    await packageFile.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<String> readLockedSpec(
      String projectPath, String projectName, String specVersion) async {
    final specPath = p.join(
        projectPath, 'specs', '${projectName}_LockedSpec_$specVersion.md');
    return File(specPath).readAsString();
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
    final ingestedDir = Directory(p.join(projectPath, 'ingested'));
    final summaryFile =
        File(p.join(ingestedDir.path, 'reference_context.md'));
    await summaryFile.writeAsString(content);
  }

  Future<String?> readIngestedSummary(String projectPath) async {
    final summaryFile =
        File(p.join(projectPath, 'ingested', 'reference_context.md'));
    if (!summaryFile.existsSync()) return null;
    return summaryFile.readAsString();
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

  Future<List<File>> listReferenceDocs(String projectPath) async {
    final ingestedDir = Directory(p.join(projectPath, 'ingested'));
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
    final ingestedDir = Directory(p.join(projectPath, 'ingested'));
    final destPath = p.join(ingestedDir.path, filename);
    return source.copy(destPath);
  }

  Future<void> writeIngestedFile(
      String projectPath, String filename, String content) async {
    final ingestedDir = Directory(p.join(projectPath, 'ingested'));
    final file = File(p.join(ingestedDir.path, filename));
    await file.writeAsString(content);
  }

  Future<void> writeInterviewProgress(
      String projectPath, String projectName, Map<String, dynamic> data) async {
    final auditDir = Directory(p.join(projectPath, 'audit'));
    final file = File(p.join(auditDir.path, '${projectName}_InterviewState.json'));
    await file.writeAsString(jsonEncode(data));
  }

  Future<Map<String, dynamic>?> readInterviewProgress(
      String projectPath, String projectName) async {
    final file = File(
        p.join(projectPath, 'audit', '${projectName}_InterviewState.json'));
    if (!file.existsSync()) return null;
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }
}
