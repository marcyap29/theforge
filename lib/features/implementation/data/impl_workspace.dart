import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../data/filesystem/project_file_repository.dart';
import '../models/run_session.dart';

/// The "hands" of the implementation agent: all filesystem work against the
/// linked code repo, plus per-edit backups (for Undo) written into the
/// project's `.forge/impl_backups/<runId>/` folder, and deterministic
/// verification against the Handoff checklist.
class ImplWorkspace {
  /// Lists repo files for the agent's context. Prefers `git ls-files`; falls
  /// back to a filtered walk. Capped to bound prompt size.
  static Future<List<String>> gatherRepoFiles(
    String repoPath, {
    int cap = 600,
  }) async {
    try {
      final res =
          await Process.run('git', ['ls-files'], workingDirectory: repoPath);
      if (res.exitCode == 0) {
        final lines = res.stdout
            .toString()
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        if (lines.isNotEmpty) {
          return lines.length > cap ? lines.sublist(0, cap) : lines;
        }
      }
    } catch (_) {}

    const skip = {
      '.git', 'node_modules', 'build', '.dart_tool', 'dist', '.idea',
      'Pods', '.gradle', 'vendor', '__pycache__', '.next', 'target',
    };
    final out = <String>[];
    try {
      await for (final e in Directory(repoPath).list(recursive: true)) {
        if (e is! File) continue;
        final rel = p.relative(e.path, from: repoPath);
        if (rel.split(p.separator).any(skip.contains)) continue;
        out.add(rel);
        if (out.length >= cap) break;
      }
    } catch (_) {}
    return out;
  }

  /// Well-known documentation files, in priority order, that ground the agent
  /// in the project's architecture and conventions.
  static const _keyDocPaths = [
    'README.md',
    'CLAUDE.md',
    'claude.md',
    'ARCHITECTURE.md',
    'tracking md files/ARCHITECTURE.md',
    'agents md files/agents.md',
    'docs/ARCHITECTURE.md',
    'docs/architecture.md',
    'CONTRIBUTING.md',
  ];

  /// Concatenates the project's key docs (README, architecture, agent guide…)
  /// within a size budget so the agent understands the codebase's structure and
  /// conventions before proposing changes. Returns null if none are found.
  static Future<String?> gatherKeyDocs(
    String repoPath, {
    int budget = 12000,
    int perFileCap = 4000,
  }) async {
    final buf = StringBuffer();
    var remaining = budget;
    final seen = <String>{}; // dedupe case-insensitive-filesystem duplicates
    for (final rel in _keyDocPaths) {
      if (remaining <= 0) break;
      final f = File(p.join(repoPath, rel));
      if (!f.existsSync()) continue;
      if (!seen.add(f.absolute.path.toLowerCase())) continue;
      String c;
      try {
        c = await f.readAsString();
      } catch (_) {
        continue;
      }
      if (c.trim().isEmpty) continue;
      if (c.length > perFileCap) c = '${c.substring(0, perFileCap)}\n…(truncated)';
      if (c.length > remaining) c = c.substring(0, remaining);
      buf..writeln('### $rel')..writeln(c)..writeln();
      remaining -= c.length;
    }
    final s = buf.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Reads a repo-relative file, returning '' if it does not exist.
  static Future<String> readRepoFile(String repoPath, String rel) async {
    final f = File(p.join(repoPath, rel));
    if (!f.existsSync()) return '';
    try {
      return await f.readAsString();
    } catch (_) {
      return '';
    }
  }

  static Directory _backupDir(String projectPath, String runId) => Directory(
        p.join(projectPath, ProjectFileRepository.forgeDirName, 'impl_backups',
            runId),
      );

  static String _sanitize(String rel) => rel.replaceAll(RegExp(r'[/\\]'), '__');

  /// Applies one edit to the repo, backing up the prior state first so it can
  /// be undone. New files get a `.NEW` marker instead of a `.bak`.
  static Future<void> applyEdit({
    required String repoPath,
    required String projectPath,
    required String runId,
    required ProposedEdit edit,
  }) async {
    final backupDir = _backupDir(projectPath, runId);
    await backupDir.create(recursive: true);
    final target = File(p.join(repoPath, edit.path));
    final key = _sanitize(edit.path);

    if (target.existsSync()) {
      await File(p.join(backupDir.path, '$key.bak'))
          .writeAsString(await target.readAsString());
    } else {
      await File(p.join(backupDir.path, '$key.NEW')).writeAsString('');
      await target.parent.create(recursive: true);
    }
    await target.writeAsString(edit.newContent);
  }

  /// Reverses [applyEdit] for one path: restores the backup, or deletes the
  /// file if it was newly created this run.
  static Future<void> undoEdit({
    required String repoPath,
    required String projectPath,
    required String runId,
    required String rel,
  }) async {
    final backupDir = _backupDir(projectPath, runId);
    final key = _sanitize(rel);
    final target = File(p.join(repoPath, rel));
    final bak = File(p.join(backupDir.path, '$key.bak'));
    final marker = File(p.join(backupDir.path, '$key.NEW'));
    if (bak.existsSync()) {
      await target.writeAsString(await bak.readAsString());
    } else if (marker.existsSync()) {
      if (target.existsSync()) await target.delete();
    }
  }

  /// Runs the Handoff verification checklist deterministically (no LLM): for
  /// each auto-verifiable item, confirm its expected files exist and contain
  /// the expected keywords. Non-auto-verifiable items are reported as manual.
  static Future<List<VerifyResult>> verify({
    required String repoPath,
    required List<Map<String, dynamic>> checklist,
  }) async {
    final results = <VerifyResult>[];
    for (final item in checklist) {
      final requirement = (item['requirement'] ?? item['id'] ?? '?').toString();
      final autoVerifiable = item['autoVerifiable'] == true;
      final expectedFiles = ((item['expectedFiles'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      final expectedKeywords = ((item['expectedKeywords'] as List?) ?? const [])
          .map((e) => e.toString().toLowerCase())
          .toList();

      if (!autoVerifiable || expectedFiles.isEmpty) {
        results.add(VerifyResult(
          requirement: requirement,
          passed: false,
          note: 'Manual check needed',
        ));
        continue;
      }

      final missing = <String>[];
      final missingKeywords = <String>[];
      for (final rel in expectedFiles) {
        final f = File(p.join(repoPath, rel));
        if (!f.existsSync()) {
          missing.add(rel);
          continue;
        }
        if (expectedKeywords.isNotEmpty) {
          final content = (await f.readAsString()).toLowerCase();
          for (final kw in expectedKeywords) {
            if (!content.contains(kw) && !missingKeywords.contains(kw)) {
              missingKeywords.add(kw);
            }
          }
        }
      }

      final passed = missing.isEmpty && missingKeywords.isEmpty;
      final note = passed
          ? 'Files present'
          : [
              if (missing.isNotEmpty) 'missing: ${missing.join(", ")}',
              if (missingKeywords.isNotEmpty)
                'no keyword: ${missingKeywords.join(", ")}',
            ].join('; ');
      results.add(
          VerifyResult(requirement: requirement, passed: passed, note: note));
    }
    return results;
  }
}
