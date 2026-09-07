// Tracker unit tests. (Replaces the stale starter-template smoke test that
// referenced a non-existent `MyApp`.)

import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/data/local_db/forge_database.dart';
import 'package:the_forge/features/tracker/models/tracker_enums.dart';
import 'package:the_forge/features/tracker/providers/tracker_providers.dart';

void main() {
  group('FeatureStatus', () {
    test('wire round-trips for every value, incl. in_progress snake_case', () {
      for (final s in FeatureStatus.values) {
        expect(FeatureStatus.fromWire(s.wire), s);
      }
      expect(FeatureStatus.inProgress.wire, 'in_progress');
      expect(FeatureStatus.fromWire('inProgress'), FeatureStatus.inProgress);
    });

    test('unknown value falls back to planned', () {
      expect(FeatureStatus.fromWire('bogus'), FeatureStatus.planned);
      expect(FeatureStatus.fromWire(null), FeatureStatus.planned);
    });
  });

  group('ProjectStatus', () {
    test('wire round-trips and defaults to active', () {
      for (final s in ProjectStatus.values) {
        expect(ProjectStatus.fromWire(s.wire), s);
      }
      expect(ProjectStatus.fromWire(null), ProjectStatus.active);
    });
  });

  group('PortfolioEntry', () {
    Feature feat(String id, FeatureStatus status) => Feature(
          id: id,
          projectId: 'p1',
          title: id,
          status: status.wire,
          source: 'manual',
          createdAt: 0,
          updatedAt: 0,
        );

    final project = Project(
      id: 'p1',
      name: 'Demo',
      path: '/tmp/demo',
      mode: 'build',
      phase: 'v1_interview',
      createdAt: 0,
    );

    test('counts roll up by status', () {
      final entry = PortfolioEntry(
        project: project,
        tracking: null,
        features: [
          feat('a', FeatureStatus.shipped),
          feat('b', FeatureStatus.shipped),
          feat('c', FeatureStatus.blocked),
          feat('d', FeatureStatus.inProgress),
        ],
      );
      expect(entry.totalCount, 4);
      expect(entry.shippedCount, 2);
      expect(entry.blockedCount, 1);
      expect(entry.counts[FeatureStatus.inProgress], 1);
      expect(entry.status, ProjectStatus.active); // no tracking -> active
    });

    test('reviewDue: no cadence => never due', () {
      final entry = PortfolioEntry(
        project: project,
        tracking: ProjectTrackingData(projectId: 'p1', status: 'active'),
        features: const [],
      );
      expect(entry.reviewDue, false);
    });

    test('reviewDue: cadence set but never reviewed => due', () {
      final entry = PortfolioEntry(
        project: project,
        tracking: ProjectTrackingData(
            projectId: 'p1', status: 'active', reviewCadenceDays: 7),
        features: const [],
      );
      expect(entry.reviewDue, true);
    });

    test('reviewDue: reviewed recently => not due; long ago => due', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final recent = PortfolioEntry(
        project: project,
        tracking: ProjectTrackingData(
          projectId: 'p1',
          status: 'active',
          reviewCadenceDays: 7,
          lastReviewedAt: now - 2 * 86400000, // 2 days ago
        ),
        features: const [],
      );
      expect(recent.reviewDue, false);

      final overdue = PortfolioEntry(
        project: project,
        tracking: ProjectTrackingData(
          projectId: 'p1',
          status: 'active',
          reviewCadenceDays: 7,
          lastReviewedAt: now - 10 * 86400000, // 10 days ago
        ),
        features: const [],
      );
      expect(overdue.reviewDue, true);
    });
  });
}
