import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/data/local_db/forge_database.dart';
import 'package:the_forge/features/game/base_layout.dart';

Feature _f(String id, {String kind = 'standard'}) => Feature(
      id: id,
      projectId: 'p1',
      title: 'Feature $id',
      description: null,
      status: 'planned',
      priority: null,
      targetVersion: null,
      source: 'test',
      buildKind: kind,
      parentId: null,
      createdAt: 0,
      updatedAt: 0,
    );

void main() {
  group('BaseLayout ring math', () {
    test('ring radius and capacity grow outward', () {
      expect(BaseLayout.ringRadius(1), greaterThan(BaseLayout.ringRadius(0)));
      expect(BaseLayout.ringRadius(2), greaterThan(BaseLayout.ringRadius(1)));
      // Outer rings have more circumference → hold more buildings.
      expect(BaseLayout.ringCapacity(1),
          greaterThanOrEqualTo(BaseLayout.ringCapacity(0)));
      expect(BaseLayout.ringCapacity(0), greaterThan(0));
    });

    test('cell size varies by build kind (epic > standard > manual)', () {
      final epic = BaseLayout.cellFor('epic');
      final std = BaseLayout.cellFor('standard');
      final manual = BaseLayout.cellFor('manual');
      expect(epic.width, greaterThan(std.width));
      expect(std.width, greaterThan(manual.width));
    });
  });

  group('BaseLayout.scene', () {
    test('empty base: no buildings, positive canvas, hub centered', () {
      final s = BaseLayout.scene(const []);
      expect(s.buildings, isEmpty);
      expect(s.canvas.width, greaterThan(0));
      expect(s.hub, Offset(s.canvas.width / 2, s.canvas.height / 2));
    });

    test('one building per feature, preserving order', () {
      final features = [for (var i = 0; i < 7; i++) _f('f$i')];
      final s = BaseLayout.scene(features);
      expect(s.buildings.length, 7);
      expect(s.buildings.map((b) => b.feature.id).toList(),
          ['f0', 'f1', 'f2', 'f3', 'f4', 'f5', 'f6']);
    });

    test('hub sits at the canvas center', () {
      final s = BaseLayout.scene([for (var i = 0; i < 5; i++) _f('f$i')]);
      expect(s.hub.dx, closeTo(s.canvas.width / 2, 0.001));
      expect(s.hub.dy, closeTo(s.canvas.height / 2, 0.001));
    });

    test('buildings on the same ring are equidistant from the hub', () {
      // 30 features → several rings.
      final s = BaseLayout.scene([for (var i = 0; i < 30; i++) _f('f$i')]);
      final byRing = <int, List<double>>{};
      for (final b in s.buildings) {
        byRing
            .putIfAbsent(b.ring, () => [])
            .add((b.center - s.hub).distance);
      }
      expect(byRing.length, greaterThan(1)); // actually spilled to rings
      byRing.forEach((ring, distances) {
        final expected = BaseLayout.ringRadius(ring);
        for (final d in distances) {
          expect(d, closeTo(expected, 0.5));
        }
      });
    });

    test('inner ring fills before the outer ring', () {
      final s = BaseLayout.scene([for (var i = 0; i < 40; i++) _f('f$i')]);
      final ring0 = s.buildings.where((b) => b.ring == 0).length;
      expect(ring0, BaseLayout.ringCapacity(0));
    });

    test('deterministic — same input yields identical centers', () {
      final features = [for (var i = 0; i < 12; i++) _f('f$i')];
      final a = BaseLayout.scene(features);
      final b = BaseLayout.scene(features);
      expect(a.buildings.map((s) => s.center).toList(),
          b.buildings.map((s) => s.center).toList());
    });

    test('epics render with a larger footprint', () {
      final s = BaseLayout.scene([_f('e', kind: 'epic'), _f('s')]);
      final epic = s.buildings.firstWhere((b) => b.feature.id == 'e');
      final std = s.buildings.firstWhere((b) => b.feature.id == 's');
      expect(epic.size.width, greaterThan(std.size.width));
    });
  });
}
