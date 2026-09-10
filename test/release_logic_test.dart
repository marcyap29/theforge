// Unit tests for the release grouping + notes logic used by the Releases view.

import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/data/local_db/forge_database.dart';
import 'package:the_forge/features/tracker/models/tracker_enums.dart';
import 'package:the_forge/features/tracker/releases/release_providers.dart';

Feature feat(
  String id,
  FeatureStatus status, {
  String? version,
  String? description,
}) =>
    Feature(
      id: id,
      projectId: 'p1',
      title: id,
      description: description,
      status: status.wire,
      targetVersion: version,
      source: 'manual',
      createdAt: 0,
      updatedAt: 0,
    );

void main() {
  group('groupFeaturesByVersion', () {
    test('buckets by target version and folds nulls into Unversioned', () {
      final groups = groupFeaturesByVersion([
        feat('a', FeatureStatus.shipped, version: 'v1'),
        feat('b', FeatureStatus.planned, version: 'v1'),
        feat('c', FeatureStatus.idea),
        feat('d', FeatureStatus.shipped, version: '  '),
      ]);
      expect(groups['v1']!.length, 2);
      expect(groups['Unversioned']!.length, 2);
    });
  });

  group('shippedInVersion', () {
    test('returns only shipped features for the exact version', () {
      final features = [
        feat('a', FeatureStatus.shipped, version: 'v1'),
        feat('b', FeatureStatus.planned, version: 'v1'),
        feat('c', FeatureStatus.shipped, version: 'v2'),
      ];
      final shipped = shippedInVersion(features, 'v1');
      expect(shipped.map((f) => f.id), ['a']);
    });
  });

  group('buildNotes', () {
    test('lists shipped features with descriptions', () {
      final notes = ReleaseListNotifier.buildNotes('Demo', 'v1', [
        feat('Login', FeatureStatus.shipped,
            version: 'v1', description: 'Email + password'),
        feat('Logout', FeatureStatus.shipped, version: 'v1'),
      ]);
      expect(notes, contains('## v1'));
      expect(notes, contains('**Login** — Email + password'));
      expect(notes, contains('**Logout**'));
    });

    test('handles an empty version gracefully', () {
      final notes = ReleaseListNotifier.buildNotes('Demo', 'v9', []);
      expect(notes, contains('No shipped features'));
    });
  });
}
