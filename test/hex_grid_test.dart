import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/features/game/hex_grid.dart';

void main() {
  group('HexGrid.spiral', () {
    test('empty for 0, single hub for 1', () {
      expect(HexGrid.spiral(0), isEmpty);
      expect(HexGrid.spiral(1), [const HexCell(0, 0)]);
    });

    test('hub is always first', () {
      expect(HexGrid.spiral(19).first, const HexCell(0, 0));
    });

    test('cells are all distinct (no two features share a hex)', () {
      final cells = HexGrid.spiral(50);
      expect(cells.length, 50);
      expect(cells.toSet().length, 50);
    });

    test('ring 1 has exactly 6 cells around the hub', () {
      final cells = HexGrid.spiral(7); // hub + ring 1
      final ring1 = cells.skip(1).toList();
      expect(ring1.length, 6);
      // each ring-1 cell is a unit step from the hub (|q|+|r|+|q+r| == 2)
      for (final c in ring1) {
        final dist = (c.q.abs() + c.r.abs() + (c.q + c.r).abs()) ~/ 2;
        expect(dist, 1);
      }
    });

    test('deterministic — same count yields identical cells', () {
      expect(HexGrid.spiral(30), HexGrid.spiral(30));
    });
  });

  group('HexGrid.toIso', () {
    test('the hub projects to the origin', () {
      expect(HexGrid.toIso(const HexCell(0, 0), 48), Offset.zero);
    });

    test('vertical axis is squashed relative to a flat hex grid', () {
      const size = 48.0;
      final p = HexGrid.toIso(const HexCell(0, 1), size, squash: 0.5);
      // y should be the flat spacing (size*sqrt(3)) * squash, not the full value
      expect(p.dy, lessThan(size * 1.74)); // < size*sqrt(3)
      expect(p.dy, greaterThan(0));
    });
  });
}
