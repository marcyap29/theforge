import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/data/filesystem/project_file_repository.dart';

void main() {
  group('capability summary cache', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('forge_cap_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('returns null before anything is written', () async {
      expect(await ProjectFileRepository.readCapabilitySummary(tmp.path),
          isNull);
    });

    test('write then read round-trips markdown + commit', () async {
      await ProjectFileRepository.writeCapabilitySummary(
        tmp.path,
        markdown: '# App\n\n## What it can do now\n- Takes photos',
        commit: 'abc123',
      );
      final read =
          await ProjectFileRepository.readCapabilitySummary(tmp.path);
      expect(read, isNotNull);
      expect(read!['markdown'], contains('Takes photos'));
      expect(read['commit'], 'abc123');
      expect(read['generatedAt'], isNotEmpty);
      // Cached under .forge/, not the project root.
      expect(
          File('${tmp.path}/.forge/capability_summary.json').existsSync(),
          isTrue);
    });

    test('re-writing overwrites (stale commit is replaced)', () async {
      await ProjectFileRepository.writeCapabilitySummary(tmp.path,
          markdown: 'v1', commit: 'old');
      await ProjectFileRepository.writeCapabilitySummary(tmp.path,
          markdown: 'v2', commit: 'new');
      final read =
          await ProjectFileRepository.readCapabilitySummary(tmp.path);
      expect(read!['markdown'], 'v2');
      expect(read['commit'], 'new');
    });
  });
}
