// Unit tests for the agent's path sandbox — never let a model-supplied edit
// path escape the linked repo.

import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/features/implementation/data/impl_workspace.dart';

void main() {
  const repo = '/Users/x/Development/app';

  group('ImplWorkspace.isPathSafe', () {
    test('accepts normal repo-relative paths', () {
      expect(ImplWorkspace.isPathSafe(repo, 'lib/main.dart'), isTrue);
      expect(ImplWorkspace.isPathSafe(repo, 'test/foo/bar_test.dart'), isTrue);
      expect(ImplWorkspace.isPathSafe(repo, 'pubspec.yaml'), isTrue);
    });

    test('rejects absolute paths', () {
      expect(ImplWorkspace.isPathSafe(repo, '/etc/passwd'), isFalse);
      expect(ImplWorkspace.isPathSafe(repo, '/Users/x/Development/app/lib/a.dart'),
          isFalse);
    });

    test('rejects .. escapes', () {
      expect(ImplWorkspace.isPathSafe(repo, '../other/secret.txt'), isFalse);
      expect(ImplWorkspace.isPathSafe(repo, 'lib/../../escape.dart'), isFalse);
    });

    test('rejects empty and the repo root itself', () {
      expect(ImplWorkspace.isPathSafe(repo, ''), isFalse);
      expect(ImplWorkspace.isPathSafe(repo, '   '), isFalse);
      expect(ImplWorkspace.isPathSafe(repo, '.'), isFalse);
    });
  });
}
