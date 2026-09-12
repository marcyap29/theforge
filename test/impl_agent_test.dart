// Unit tests for the build agent's context assembly — the always-on reference
// slot (wiring the ingested pool into builds) and visible over-budget trimming.

import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/features/implementation/data/impl_agent.dart';

void main() {
  group('ImplAgent.buildUserContext', () {
    test('includes ingested reference context when provided', () {
      final out = ImplAgent.buildUserContext(
        featureTitle: 'Add login',
        files: const ['lib/main.dart'],
        ingestedContext: 'Definitions: a widget is a piece of UI.',
      );
      expect(out, contains('## Reference context (ingested documents)'));
      expect(out, contains('a widget is a piece of UI'));
    });

    test('omits the reference block when no context is given', () {
      final out = ImplAgent.buildUserContext(
        featureTitle: 'Add login',
        files: const ['lib/main.dart'],
      );
      expect(out, isNot(contains('Reference context')));
    });

    test('includes prior-build memory when provided', () {
      final out = ImplAgent.buildUserContext(
        featureTitle: 'Add logout',
        files: const ['lib/main.dart'],
        buildMemory: '### Add login\n**Files changed:** lib/auth.dart',
      );
      expect(out, contains('## Prior builds on this project'));
      expect(out, contains('lib/auth.dart'));
    });

    test('omits the prior-builds block when no memory exists', () {
      final out = ImplAgent.buildUserContext(
        featureTitle: 'Add login',
        files: const ['lib/main.dart'],
      );
      expect(out, isNot(contains('Prior builds')));
    });

    test('marks over-budget reference context visibly instead of cutting silently',
        () {
      final huge = 'x' * 20000;
      final out = ImplAgent.buildUserContext(
        featureTitle: 'Add login',
        files: const [],
        ingestedContext: huge,
      );
      expect(out, contains('reference context trimmed'));
      expect(out, contains('chars dropped'));
    });

    test('marks over-budget spec visibly (no more silent 6k cut)', () {
      final hugeSpec = 'y' * 20000;
      final out = ImplAgent.buildUserContext(
        featureTitle: 'Add login',
        files: const [],
        lockedSpec: hugeSpec,
      );
      expect(out, contains('spec trimmed'));
      // The old code cut silently at 6000 chars; the new cap keeps far more.
      expect(out.length, greaterThan(10000));
    });
  });
}
