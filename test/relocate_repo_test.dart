import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:the_forge/data/filesystem/project_file_repository.dart';

/// Guards the repo-relocation duplication bug (BUG-DATA-002): moving code into a
/// folder NESTED inside the source would copy the repo into itself.
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('forge_relocate_'));
  tearDown(() => tmp.existsSync() ? tmp.deleteSync(recursive: true) : null);

  Directory _repoWith(String name, List<String> files) {
    final d = Directory(p.join(tmp.path, name))..createSync(recursive: true);
    for (final f in files) {
      File(p.join(d.path, f))
        ..createSync(recursive: true)
        ..writeAsStringSync('x');
    }
    return d;
  }

  test('REFUSES relocating into a folder nested inside the source (no dup)',
      () async {
    final src = _repoWith('ar_mechanic', ['pubspec.yaml', 'lib/main.dart']);
    final nested = p.join(src.path, 'code'); // the "I made a subfolder" case

    final r = await ProjectFileRepository.relocateRepo(
      fromPath: src.path,
      toPath: nested,
    );

    expect(r.refused, isTrue);
    expect(r.error, contains('inside the current code folder'));
    expect(r.moved, isEmpty);
    // Source is untouched — nothing moved, nothing duplicated.
    expect(File(p.join(src.path, 'pubspec.yaml')).existsSync(), isTrue);
    expect(File(p.join(src.path, 'lib', 'main.dart')).existsSync(), isTrue);
    // The nested dir was NOT populated with a copy of the repo.
    expect(Directory(p.join(nested, 'lib')).existsSync(), isFalse);
  });

  test('REFUSES when the source is nested inside the destination', () async {
    final parent = Directory(p.join(tmp.path, 'parent'))..createSync();
    final src = _repoWith(p.join('parent', 'inner'), ['a.txt']);

    final r = await ProjectFileRepository.relocateRepo(
      fromPath: src.path,
      toPath: parent.path,
    );

    expect(r.refused, isTrue);
    expect(r.moved, isEmpty);
    expect(File(p.join(src.path, 'a.txt')).existsSync(), isTrue);
  });

  test('a normal sibling relocation still MOVES the code', () async {
    final src = _repoWith('src_repo', ['pubspec.yaml', 'lib/main.dart']);
    final dst = p.join(tmp.path, 'dst_repo');

    final r = await ProjectFileRepository.relocateRepo(
      fromPath: src.path,
      toPath: dst,
    );

    expect(r.refused, isFalse);
    expect(r.moved, isNotEmpty);
    // Moved, not copied: destination has the files, source is emptied of them.
    expect(File(p.join(dst, 'pubspec.yaml')).existsSync(), isTrue);
    expect(File(p.join(dst, 'lib', 'main.dart')).existsSync(), isTrue);
    expect(File(p.join(src.path, 'pubspec.yaml')).existsSync(), isFalse);
  });

  test('same source and destination is a no-op (not refused)', () async {
    final src = _repoWith('same', ['x.txt']);
    final r = await ProjectFileRepository.relocateRepo(
      fromPath: src.path,
      toPath: src.path,
    );
    expect(r.refused, isFalse);
    expect(r.moved, isEmpty);
  });
}
