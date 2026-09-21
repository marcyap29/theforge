import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/features/implementation/data/completion_guard.dart';
import 'package:the_forge/features/implementation/models/run_session.dart';

ProposedEdit _edit(String path, String newContent, {String old = ''}) =>
    ProposedEdit(
      path: path,
      rationale: 'test',
      oldContent: old,
      newContent: newContent,
    );

void main() {
  group('CompletionGuard', () {
    test('empty diff is flagged as noEdits', () {
      final v = CompletionGuard.inspect(const []);
      expect(v.suspicious, isTrue);
      expect(v.issue, CompletionIssue.noEdits);
    });

    test('docs/config-only diff is flagged (the shell-script / docs fake)', () {
      final v = CompletionGuard.inspect([
        _edit('CHANGELOG.md', '## v0.5\n- fixed the deploy script'),
        _edit('pubspec.yaml', 'version: 1.2.3'),
        _edit('README.md', 'Now auto-deploys.'),
      ]);
      expect(v.suspicious, isTrue);
      expect(v.issue, CompletionIssue.docsConfigOnly);
    });

    test('dotfiles and Dockerfile count as config, not a code artifact', () {
      final v = CompletionGuard.inspect([
        _edit('.gitignore', 'build/'),
        _edit('Dockerfile', 'FROM dart'),
      ]);
      expect(v.issue, CompletionIssue.docsConfigOnly);
    });

    test('a real code artifact passes', () {
      final v = CompletionGuard.inspect([
        _edit('tool/deploy_ios.sh', '#!/bin/bash\n'
            'set -euo pipefail\n'
            'DEVICE=\$(xcrun devicectl list devices)\n'
            'flutter build ios --release\n'
            'xcrun devicectl device install app --device "\$DEVICE" build/app'),
        _edit('CHANGELOG.md', '## added deploy script'),
      ]);
      expect(v.suspicious, isFalse);
      expect(v.issue, CompletionIssue.none);
    });

    test('a stub-only code diff is flagged (the simulate() fake)', () {
      final v = CompletionGuard.inspect([
        _edit('lib/detector.dart',
            'class Detector {\n'
            '  Future<String> detect() async {\n'
            '    // TODO: implement real detection\n'
            '    return simulateResult(); // placeholder for now\n'
            '  }\n'
            '}'),
      ]);
      expect(v.suspicious, isTrue);
      expect(v.issue, CompletionIssue.placeholderOnly);
    });

    test('real code with one stray TODO comment is NOT flagged', () {
      final v = CompletionGuard.inspect([
        _edit('lib/parser.dart',
            'int sum(List<int> xs) {\n'
            '  var total = 0;\n'
            '  for (final x in xs) {\n'
            '    total += x;\n'
            '  }\n'
            '  // TODO: handle overflow one day\n'
            '  return total;\n'
            '}'),
      ]);
      expect(v.suspicious, isFalse);
    });

    test('only added lines are judged, not unchanged old content', () {
      // Old file was all stub; the edit adds real working code around it.
      final v = CompletionGuard.inspect([
        _edit(
          'lib/detector.dart',
          old: '// TODO: implement\n// placeholder\n',
          'int classify(List<double> px) {\n'
          '  var best = 0;\n'
          '  var score = px[0];\n'
          '  for (var i = 1; i < px.length; i++) {\n'
          '    if (px[i] > score) { score = px[i]; best = i; }\n'
          '  }\n'
          '  return best;\n'
          '}',
        ),
      ]);
      expect(v.suspicious, isFalse);
    });
  });
}
