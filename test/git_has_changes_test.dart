import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/data/filesystem/project_file_repository.dart';

/// Exercises the redundant-ship guard's load-bearing helper (BUG-IMPL-010):
/// `gitHasChanges` must be true iff `git add -A && git commit` would produce a
/// commit — so the ship flow can skip the non-deterministic ARCHITECTURE rewrite
/// + commit when nothing new actually changed.
void main() {
  late Directory tmp;

  Future<void> git(List<String> args) async {
    final r = await Process.run('git', args, workingDirectory: tmp.path);
    if (r.exitCode != 0) {
      throw Exception('git ${args.join(' ')} failed: ${r.stderr}');
    }
  }

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('forge_git_');
    await git(['init']);
    // Local identity so commits work without global config (CI-safe).
    await git(['config', 'user.email', 'test@example.com']);
    await git(['config', 'user.name', 'Test']);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('a freshly-initialised repo with no files is clean', () async {
    expect(await ProjectFileRepository.gitHasChanges(tmp.path), isFalse);
  });

  test('an untracked file counts as a change', () async {
    File('${tmp.path}/a.txt').writeAsStringSync('hello');
    expect(await ProjectFileRepository.gitHasChanges(tmp.path), isTrue);
  });

  test('after committing everything the tree is clean (the redundant-ship case)',
      () async {
    File('${tmp.path}/a.txt').writeAsStringSync('hello');
    await git(['add', '-A']);
    await git(['commit', '-m', 'init']);
    expect(await ProjectFileRepository.gitHasChanges(tmp.path), isFalse);
  });

  test('modifying a committed file is a change again', () async {
    final f = File('${tmp.path}/a.txt')..writeAsStringSync('hello');
    await git(['add', '-A']);
    await git(['commit', '-m', 'init']);
    f.writeAsStringSync('changed');
    expect(await ProjectFileRepository.gitHasChanges(tmp.path), isTrue);
  });

  test('a non-git directory reports no changes (never throws)', () async {
    final plain = Directory.systemTemp.createTempSync('forge_nogit_');
    try {
      expect(await ProjectFileRepository.gitHasChanges(plain.path), isFalse);
    } finally {
      plain.deleteSync(recursive: true);
    }
  });

  test('gitChangedFiles lists uncommitted files, empty when clean', () async {
    expect(await ProjectFileRepository.gitChangedFiles(tmp.path), isEmpty);
    File('${tmp.path}/a.txt').writeAsStringSync('hello');
    File('${tmp.path}/b.dart').writeAsStringSync('void main() {}');
    final changed = await ProjectFileRepository.gitChangedFiles(tmp.path);
    expect(changed.length, 2);
    expect(changed.any((l) => l.contains('a.txt')), isTrue);
    expect(changed.any((l) => l.contains('b.dart')), isTrue);
    // After committing, the list is empty again.
    await git(['add', '-A']);
    await git(['commit', '-m', 'init']);
    expect(await ProjectFileRepository.gitChangedFiles(tmp.path), isEmpty);
  });

  test('gitChangedFiles on a non-git dir returns empty (never throws)',
      () async {
    final plain = Directory.systemTemp.createTempSync('forge_nogit2_');
    try {
      expect(await ProjectFileRepository.gitChangedFiles(plain.path), isEmpty);
    } finally {
      plain.deleteSync(recursive: true);
    }
  });
}
