import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/features/interview/state/interview_notifier.dart';
import 'package:the_forge/features/interview/state/interview_state.dart';

String _block(String confidenceJson) => '''
Here is my question.

```forge-state
{
  "layer": "L1",
  "layerComplete": false,
  "extracted": {"outcome": "ship faster"},
  "confidence": $confidenceJson,
  "conflicts": []
}
```
''';

void main() {
  group('parseForgeState confidence', () {
    test('parses per-dimension quality read into DimensionState', () {
      final p = parseForgeState(
          _block('{"corePurpose": "resolved", "primaryUser": "partial"}'));
      expect(p.parseOk, isTrue);
      expect(p.confidence['corePurpose'], DimensionState.resolved);
      expect(p.confidence['primaryUser'], DimensionState.partial);
    });

    test('ignores unrecognized confidence words', () {
      final p = parseForgeState(
          _block('{"corePurpose": "definitely", "primaryUser": "unknown"}'));
      expect(p.confidence.containsKey('corePurpose'), isFalse);
      expect(p.confidence['primaryUser'], DimensionState.unknown);
    });

    test('missing confidence block yields an empty map (falls back to presence)',
        () {
      const raw = '''
Question here.

```forge-state
{"layer": "L1", "layerComplete": false, "extracted": {}, "conflicts": []}
```
''';
      final p = parseForgeState(raw);
      expect(p.parseOk, isTrue);
      expect(p.confidence, isEmpty);
    });

    test('no forge-state block → empty confidence, parseOk false', () {
      final p = parseForgeState('just prose, no block');
      expect(p.parseOk, isFalse);
      expect(p.confidence, isEmpty);
    });
  });
}
