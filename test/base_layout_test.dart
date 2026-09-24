import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/data/local_db/forge_database.dart';
import 'package:the_forge/features/game/base_layout.dart';

Feature _f(String id, String title) => Feature(
      id: id,
      projectId: 'p1',
      title: title,
      description: null,
      status: 'planned',
      priority: null,
      targetVersion: null,
      source: 'test',
      buildKind: 'standard',
      parentId: null,
      createdAt: 0,
      updatedAt: 0,
    );

void main() {
  group('BaseLayout.columnsFor', () {
    test('is 1 for 0 or 1 buildings', () {
      expect(BaseLayout.columnsFor(0), 1);
      expect(BaseLayout.columnsFor(1), 1);
    });

    test('grows squarish and clamps at 6', () {
      expect(BaseLayout.columnsFor(4), 2);
      expect(BaseLayout.columnsFor(9), 3);
      expect(BaseLayout.columnsFor(100), 6); // clamp
    });
  });

  group('BaseLayout.place', () {
    test('empty features → no slots', () {
      expect(BaseLayout.place(const []), isEmpty);
    });

    test('lays out left-to-right, top-to-bottom in row-major order', () {
      final features = [for (var i = 0; i < 5; i++) _f('f$i', 'Feature $i')];
      final slots = BaseLayout.place(features, columns: 2);
      // 5 features, 2 cols → rows: (0,0)(0,1)(1,0)(1,1)(2,0)
      expect(slots.map((s) => [s.col, s.row]).toList(), [
        [0, 0],
        [1, 0],
        [0, 1],
        [1, 1],
        [0, 2],
      ]);
      // Preserves feature order.
      expect(slots.map((s) => s.feature.id).toList(),
          ['f0', 'f1', 'f2', 'f3', 'f4']);
    });

    test('centers are deterministic and spaced by cell + gap', () {
      final features = [_f('a', 'A'), _f('b', 'B')];
      final slots = BaseLayout.place(
        features,
        columns: 2,
        cell: const Size(100, 100),
        gap: 20,
        padding: 40,
      );
      // first center: pad + cell/2 = 40 + 50 = 90
      expect(slots[0].center, const Offset(90, 90));
      // second center x: 90 + (cell + gap) = 90 + 120 = 210
      expect(slots[1].center, const Offset(210, 90));
    });
  });

  group('BaseLayout.canvasSize', () {
    test('fits the grid with padding and gaps', () {
      // 2 buildings, 2 cols, 1 row: w = 80 + 2*100 + 1*20 = 300; h = 80 + 100
      final s = BaseLayout.canvasSize(2,
          columns: 2, cell: const Size(100, 100), gap: 20, padding: 40);
      expect(s.width, 300);
      expect(s.height, 180);
    });

    test('never collapses to zero for an empty base', () {
      final s = BaseLayout.canvasSize(0);
      expect(s.width, greaterThan(0));
      expect(s.height, greaterThan(0));
    });
  });
}
