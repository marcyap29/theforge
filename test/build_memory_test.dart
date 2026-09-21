// Tests for feature-build memory — the "gained + remains" pool: a record is
// written per shipped feature and read back into future builds.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/data/filesystem/project_file_repository.dart';
import 'package:the_forge/features/implementation/models/run_session.dart';
import 'package:the_forge/features/implementation/providers/implementation_notifier.dart';

void main() {
  group('ImplRunNotifier.buildMemoryRecord', () {
    ImplBrief brief() => ImplBrief(
          projectPath: '/tmp/p',
          projectName: 'p',
          repoPath: '/tmp/p/repo',
          featureId: 'feat-1',
          featureTitle: 'Add login',
          targetVersion: 'v1',
        );

    const plan = AgentPlan(
      summary: 'Add a login screen',
      rationale: 'Reuse the existing auth service',
      edits: [],
      commands: [],
    );

    test('captures title, version, summary, rationale, and files', () {
      final rec = ImplRunNotifier.buildMemoryRecord(
          brief(), plan, const ['lib/auth.dart', 'lib/login.dart']);
      expect(rec, contains('### Add login (v1)'));
      expect(rec, contains('**What was built:** Add a login screen'));
      expect(rec, contains('**Why / approach:** Reuse the existing auth service'));
      expect(rec, contains('**Files changed:** lib/auth.dart, lib/login.dart'));
    });
  });

  group('ProjectFileRepository build memory', () {
    late Directory tmp;
    final repo = ProjectFileRepository();

    setUp(() => tmp = Directory.systemTemp.createTempSync('forge_bm_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('returns null before any feature ships', () async {
      expect(await repo.readBuildMemory(tmp.path), isNull);
    });

    test('hasBuildMemory reflects whether a feature was shipped (the '
        'reconciliation ground-truth signal)', () async {
      expect(ProjectFileRepository.hasBuildMemory(tmp.path, 'feat-1'), isFalse);
      await repo.writeBuildMemory(tmp.path, 'feat-1', '### Add login\nbody');
      expect(ProjectFileRepository.hasBuildMemory(tmp.path, 'feat-1'), isTrue);
      // A different feature is unaffected.
      expect(ProjectFileRepository.hasBuildMemory(tmp.path, 'feat-2'), isFalse);
    });

    test('hasBuildMemory matches the same id-sanitisation as writeBuildMemory',
        () async {
      // UUID-with-colons or other unsafe chars must resolve to the same file.
      const messyId = 'proj:1/feat 2';
      await repo.writeBuildMemory(tmp.path, messyId, '### x');
      expect(ProjectFileRepository.hasBuildMemory(tmp.path, messyId), isTrue);
    });

    test('write then read round-trips the record', () async {
      await repo.writeBuildMemory(tmp.path, 'feat-1', '### Add login\nbody');
      final out = await repo.readBuildMemory(tmp.path);
      expect(out, contains('### Add login'));
      expect(out, contains('body'));
    });

    test('re-shipping a feature overwrites, not duplicates', () async {
      await repo.writeBuildMemory(tmp.path, 'feat-1', '### Add login v1');
      await repo.writeBuildMemory(tmp.path, 'feat-1', '### Add login v2');
      final out = await repo.readBuildMemory(tmp.path);
      expect(out, contains('v2'));
      expect(out, isNot(contains('v1')));
    });

    test('accumulates distinct features into one block', () async {
      await repo.writeBuildMemory(tmp.path, 'feat-1', '### Add login');
      await repo.writeBuildMemory(tmp.path, 'feat-2', '### Add logout');
      final out = await repo.readBuildMemory(tmp.path);
      expect(out, contains('### Add login'));
      expect(out, contains('### Add logout'));
    });
  });
}
