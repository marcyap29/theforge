import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local_db/forge_database.dart';
import '../../projects/providers/providers.dart';
import '../data/tracker_repository.dart';
import '../models/tracker_enums.dart';

const _uuid = Uuid();

final trackerRepositoryProvider = Provider<TrackerRepository>(
  (ref) => TrackerRepository(ref.watch(forgeDatabaseProvider)),
);

/// Per-project feature list, mutable via the notifier's methods. Keyed by
/// project id.
final featureListProvider =
    AsyncNotifierProvider.family<FeatureListNotifier, List<Feature>, String>(
  FeatureListNotifier.new,
);

class FeatureListNotifier extends FamilyAsyncNotifier<List<Feature>, String> {
  String get _projectId => arg;

  @override
  Future<List<Feature>> build(String arg) async {
    final repo = ref.watch(trackerRepositoryProvider);
    final list = await repo.featuresForProject(arg);
    return _sorted(list);
  }

  Future<String?> _projectPath() async {
    final db = ref.read(forgeDatabaseProvider);
    final project = await db.getProjectById(_projectId);
    return project?.path;
  }

  Future<void> addFeature({
    required String title,
    String? description,
    FeatureStatus status = FeatureStatus.planned,
    int? priority,
    String? targetVersion,
    String source = 'manual',
  }) async {
    final repo = ref.read(trackerRepositoryProvider);
    final path = await _projectPath();
    final now = DateTime.now().millisecondsSinceEpoch;
    final feature = Feature(
      id: _uuid.v4(),
      projectId: _projectId,
      title: title,
      description: description,
      status: status.wire,
      priority: priority,
      targetVersion: targetVersion,
      source: source,
      createdAt: now,
      updatedAt: now,
    );
    await repo.saveFeature(feature, projectPath: path);
    ref.invalidateSelf();
  }

  Future<void> updateFeature(
    Feature feature, {
    String? title,
    String? description,
    FeatureStatus? status,
    int? priority,
    String? targetVersion,
  }) async {
    final repo = ref.read(trackerRepositoryProvider);
    final path = await _projectPath();
    final updated = feature.copyWith(
      title: title ?? feature.title,
      description: Value(description ?? feature.description),
      status: status?.wire ?? feature.status,
      priority: Value(priority ?? feature.priority),
      targetVersion: Value(targetVersion ?? feature.targetVersion),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await repo.saveFeature(updated, projectPath: path);
    ref.invalidateSelf();
  }

  Future<void> setStatus(Feature feature, FeatureStatus status) =>
      updateFeature(feature, status: status);

  Future<void> deleteFeature(Feature feature) async {
    final repo = ref.read(trackerRepositoryProvider);
    final path = await _projectPath();
    await repo.deleteFeature(feature.id, _projectId, projectPath: path);
    ref.invalidateSelf();
  }

  /// Bulk-replace (used by scan import). [features] should already carry ids.
  Future<void> replaceAll(List<Feature> features) async {
    final repo = ref.read(trackerRepositoryProvider);
    final path = await _projectPath();
    await repo.replaceFeatures(_projectId, features, projectPath: path);
    ref.invalidateSelf();
  }

  static List<Feature> _sorted(List<Feature> list) {
    final copy = [...list];
    copy.sort((a, b) {
      final sa = FeatureStatus.fromWire(a.status);
      final sb = FeatureStatus.fromWire(b.status);
      final oa = FeatureStatus.board.indexOf(sa);
      final ob = FeatureStatus.board.indexOf(sb);
      if (oa != ob) return oa.compareTo(ob);
      final pa = a.priority ?? 1 << 30;
      final pb = b.priority ?? 1 << 30;
      if (pa != pb) return pa.compareTo(pb);
      return a.createdAt.compareTo(b.createdAt);
    });
    return copy;
  }
}

/// One row of the portfolio dashboard: a project plus its tracking state and
/// feature roll-up.
class PortfolioEntry {
  PortfolioEntry({
    required this.project,
    required this.tracking,
    required this.features,
  });

  final Project project;
  final ProjectTrackingData? tracking;
  final List<Feature> features;

  ProjectStatus get status =>
      ProjectStatus.fromWire(tracking?.status ?? 'active');

  Map<FeatureStatus, int> get counts {
    final map = <FeatureStatus, int>{};
    for (final f in features) {
      final s = FeatureStatus.fromWire(f.status);
      map[s] = (map[s] ?? 0) + 1;
    }
    return map;
  }

  int get shippedCount => counts[FeatureStatus.shipped] ?? 0;
  int get totalCount => features.length;
  int get blockedCount => counts[FeatureStatus.blocked] ?? 0;

  bool get reviewDue {
    final cadence = tracking?.reviewCadenceDays;
    if (cadence == null || cadence <= 0) return false;
    final last = tracking?.lastReviewedAt;
    if (last == null) return true;
    final dueAt = last + cadence * 86400000;
    return DateTime.now().millisecondsSinceEpoch > dueAt;
  }
}

/// Aggregated portfolio view across all projects.
final portfolioProvider = FutureProvider<List<PortfolioEntry>>((ref) async {
  final projects = await ref.watch(projectListProvider.future);
  final repo = ref.watch(trackerRepositoryProvider);

  final entries = <PortfolioEntry>[];
  for (final project in projects) {
    final tracking = await repo.tracking(project.id);
    final features = await repo.featuresForProject(project.id);
    entries.add(PortfolioEntry(
      project: project,
      tracking: tracking,
      features: features,
    ));
  }
  return entries;
});

/// Per-project tracking state (status, review cadence). Mutable via methods.
final projectTrackingProvider = AsyncNotifierProvider.family<
    ProjectTrackingNotifier, ProjectTrackingData?, String>(
  ProjectTrackingNotifier.new,
);

class ProjectTrackingNotifier
    extends FamilyAsyncNotifier<ProjectTrackingData?, String> {
  String get _projectId => arg;

  @override
  Future<ProjectTrackingData?> build(String arg) {
    final repo = ref.watch(trackerRepositoryProvider);
    return repo.tracking(arg);
  }

  Future<String?> _projectPath() async {
    final db = ref.read(forgeDatabaseProvider);
    final project = await db.getProjectById(_projectId);
    return project?.path;
  }

  ProjectTrackingData _current() =>
      state.valueOrNull ??
      ProjectTrackingData(projectId: _projectId, status: 'active');

  Future<void> _save(ProjectTrackingData data) async {
    final repo = ref.read(trackerRepositoryProvider);
    final path = await _projectPath();
    await repo.saveTracking(data, projectPath: path);
    ref.invalidateSelf();
    ref.invalidate(portfolioProvider);
  }

  Future<void> setStatus(ProjectStatus status) =>
      _save(_current().copyWith(status: status.wire));

  Future<void> setSummary(String? summary) =>
      _save(_current().copyWith(summary: Value(summary)));

  Future<void> setCadence(int? days) =>
      _save(_current().copyWith(reviewCadenceDays: Value(days)));

  Future<void> markReviewed({String? head}) => _save(_current().copyWith(
        lastReviewedAt: Value(DateTime.now().millisecondsSinceEpoch),
        lastReviewHead: Value(head),
      ));
}
