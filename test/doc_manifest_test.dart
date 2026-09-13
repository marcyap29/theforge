// Tests for the unified doc-pool manifest and safe entry retrieval — the
// backbone of the doc-aware scout (§CTX3).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:the_forge/data/filesystem/project_file_repository.dart';

void main() {
  late Directory tmp;
  final repo = ProjectFileRepository();

  String forge(String sub) =>
      p.join(tmp.path, ProjectFileRepository.forgeDirName, sub);

  void writeForge(String sub, String name, String content) {
    final dir = Directory(forge(sub))..createSync(recursive: true);
    File(p.join(dir.path, name)).writeAsStringSync(content);
  }

  setUp(() => tmp = Directory.systemTemp.createTempSync('forge_dm_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('gatherDocManifest', () {
    test('is empty for a project with no docs', () async {
      expect(await repo.gatherDocManifest(tmp.path), isEmpty);
    });

    test('lists reference docs and build-memory with stable ids', () async {
      writeForge('ingested', 'Physics.facts.md',
          '### Physics\n**Definitions:** torque is force times distance.');
      writeForge('build_memory', 'feat-1.md',
          '### Add login (v1)\n**What was built:** a login screen.');

      final manifest = await repo.gatherDocManifest(tmp.path);
      final ids = manifest.map((e) => e.id).toSet();
      expect(ids, containsAll(['ref:Physics.facts.md', 'mem:feat-1.md']));

      final ref = manifest.firstWhere((e) => e.id == 'ref:Physics.facts.md');
      expect(ref.kind, 'reference');
      expect(ref.title, 'Physics');

      final mem = manifest.firstWhere((e) => e.id == 'mem:feat-1.md');
      expect(mem.kind, 'build-memory');
      expect(mem.title, contains('Add login'));
    });

    test('ignores the .fp fingerprints and raw source docs', () async {
      writeForge('ingested', 'Doc.facts.md', '### Doc\nfacts');
      writeForge('ingested', 'Doc.pdf.fp', '12:abc');
      writeForge('ingested', 'reference_context.md', '# Reference Context');

      final manifest = await repo.gatherDocManifest(tmp.path);
      expect(manifest.map((e) => e.id), ['ref:Doc.facts.md']);
    });
  });

  group('readDocEntry', () {
    test('round-trips a reference entry by id', () async {
      writeForge('ingested', 'Doc.facts.md', 'the full body');
      expect(await repo.readDocEntry(tmp.path, 'ref:Doc.facts.md'),
          'the full body');
    });

    test('round-trips a build-memory entry by id', () async {
      writeForge('build_memory', 'feat-1.md', 'prior build');
      expect(await repo.readDocEntry(tmp.path, 'mem:feat-1.md'), 'prior build');
    });

    test('rejects path escapes and unknown kinds', () async {
      writeForge('ingested', 'Doc.facts.md', 'x');
      expect(await repo.readDocEntry(tmp.path, 'ref:../../etc/passwd'), '');
      expect(await repo.readDocEntry(tmp.path, 'ref:sub/Doc.facts.md'), '');
      expect(await repo.readDocEntry(tmp.path, 'bad:Doc.facts.md'), '');
      expect(await repo.readDocEntry(tmp.path, 'noColon'), '');
    });

    test('returns empty for a missing entry', () async {
      expect(await repo.readDocEntry(tmp.path, 'ref:Nope.facts.md'), '');
    });
  });
}
