import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/features/tracker/models/tracker_enums.dart';

void main() {
  group('BuildKind', () {
    test('wire round-trips and defaults to standard on unknown/null', () {
      for (final k in BuildKind.values) {
        expect(BuildKind.fromWire(k.wire), k);
      }
      expect(BuildKind.fromWire(null), BuildKind.standard);
      expect(BuildKind.fromWire('nonsense'), BuildKind.standard);
    });

    test('only standard is directly buildable', () {
      expect(BuildKind.standard.isDirectlyBuildable, isTrue);
      expect(BuildKind.epic.isDirectlyBuildable, isFalse);
      expect(BuildKind.manual.isDirectlyBuildable, isFalse);
    });
  });
}
