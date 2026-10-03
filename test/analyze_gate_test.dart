import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/data/filesystem/project_file_repository.dart';

/// Guards the pre-build commit gate (BUG-IMPL-011): The Forge must never offer
/// to commit AI output that doesn't compile. [classifyAnalyzeOutput] is the
/// pure decision the "Commit & push" vs "Discard broken edits" branch rides on.
void main() {
  group('classifyAnalyzeOutput', () {
    test('clean analyze → clean', () {
      final r = ProjectFileRepository.classifyAnalyzeOutput(
          'Analyzing app...\nNo issues found!', 0);
      expect(r.status, AnalyzeStatus.clean);
      expect(r.isClean, isTrue);
      expect(r.errorCount, 0);
    });

    test('error lines → errors with a count (gate blocks the commit)', () {
      const out = '''
Analyzing app...
  error • The name 'Text' isn't a class • lib/main.dart:513:26 • creation_with_non_type
  error • Expected to find '}' • lib/main.dart:727:35 • expected_token
2 issues found.''';
      final r = ProjectFileRepository.classifyAnalyzeOutput(out, 1);
      expect(r.status, AnalyzeStatus.errors);
      expect(r.hasErrors, isTrue);
      expect(r.errorCount, 2);
    });

    test('warnings/infos only → clean (no compile errors, commit allowed)', () {
      const out = '''
Analyzing app...
  warning • The declaration '_foo' isn't referenced • lib/main.dart:66:7 • unused_element
  info • Prefer const • lib/main.dart:10:3 • prefer_const
1 issue found.''';
      final r = ProjectFileRepository.classifyAnalyzeOutput(out, 1);
      expect(r.status, AnalyzeStatus.clean);
      expect(r.errorCount, 0);
    });

    test('no analyzer signal (toolchain missing) → skipped, not clean', () {
      final r = ProjectFileRepository.classifyAnalyzeOutput(
          'command not found: flutter', 127);
      expect(r.status, AnalyzeStatus.skipped);
      expect(r.isClean, isFalse);
      expect(r.hasErrors, isFalse);
    });
  });
}
