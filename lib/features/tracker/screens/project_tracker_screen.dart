import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../../../services/diag_log.dart';
import '../../../services/donor_service.dart';
import '../../../services/ingest_service.dart';
import '../../../services/llm/llm_service_provider.dart';
import '../../chat/screens/direct_chat_screen.dart';
import '../checkin/checkin_review_dialog.dart';
import '../checkin/checkin_service.dart';
import '../data/spec_snapshot_generator.dart';
import '../models/tracker_enums.dart';
import '../providers/tracker_providers.dart';
import '../releases/release_providers.dart';
import '../scan/feature_dedup.dart';
import '../scan/feature_scan.dart';
import '../widgets/active_model_chip.dart';
import '../widgets/architect_review_sheet.dart';
import '../widgets/dedup_review_sheet.dart';
import '../widgets/feature_edit_dialog.dart';
import '../widgets/forge_files_panel.dart';
import '../widgets/relocate_repo.dart';
import '../widgets/roadmap_review_sheet.dart';
import '../widgets/scan_review_sheet.dart';
import '../widgets/status_chip.dart';
import 'architecture_screen.dart';
import 'capability_summary_screen.dart';
import 'prompt_screen.dart';
import 'refine_features_screen.dart';
import 'releases_screen.dart';
import 'security_check_screen.dart';

/// The per-project feature board: features grouped by status with add/edit/
/// delete + quick status changes, plus project-level status, review cadence,
/// and repo scanning.
class ProjectTrackerScreen extends ConsumerStatefulWidget {
  const ProjectTrackerScreen({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<ProjectTrackerScreen> createState() =>
      _ProjectTrackerScreenState();
}

class _ProjectTrackerScreenState extends ConsumerState<ProjectTrackerScreen> {
  Project get project => widget.project;

  StalenessInfo? _staleness;
  bool _bannerDismissed = false;
  String? _repoPath;
  bool _repoLoaded = false;
  String? _donorPath;
  String? _donorRepoName;
  bool _donorLoaded = false;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Board grouping mode.
  _BoardView _boardView = _BoardView.buildOrder;

  /// The feature the user is currently focused on (highlighted). Set on click,
  /// right-click, or opening a feature's actions menu.
  String? _focusedFeatureId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadStaleness);
    Future.microtask(_loadRepoPath);
    Future.microtask(_loadDonorMeta);
    Future.microtask(_reconcileStatuses);
  }

  /// On open, self-heal any feature that was shipped but lost its status (the
  /// pre-v0.4.56 write bug where the shipped→DB write could be skipped on
  /// navigation). No active build runs exist in the PM tool, so every
  /// build-memory record is safe to reconcile.
  Future<void> _reconcileStatuses() async {
    final healed = await ref
        .read(featureListProvider(project.id).notifier)
        .reconcileStatuses({});
    if (healed > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reconciled $healed feature${healed == 1 ? '' : 's'} to '
            'shipped — found a build record but the status had been lost.'),
      ));
    }
  }

  Future<void> _loadRepoPath() async {
    final config = await ProjectFileRepository.readProjectConfig(project.path);
    if (mounted) {
      setState(() {
        _repoPath = config['repoPath'] as String?;
        _repoLoaded = true;
      });
    }
  }

  Future<void> _loadDonorMeta() async {
    final meta = await ProjectFileRepository.readDonorMeta(project.path);
    if (mounted) {
      setState(() {
        _donorPath = meta?['donorPath'] as String?;
        _donorRepoName = meta?['repoName'] as String?;
        _donorLoaded = true;
      });
    }
  }

  Future<void> _changeDonorRepo() async {
    final picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select donor repo for ${project.name}',
      lockParentWindow: true,
    );
    if (picked == null || !mounted) return;
    final repoName = picked.split('/').last;
    await ProjectFileRepository.writeDonorMeta(project.path, {
      'donorPath': picked,
      'repoName': repoName,
    });
    if (mounted) {
      setState(() {
        _donorPath = picked;
        _donorRepoName = repoName;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Donor repo set to $repoName — tap Index to scan it'),
      ));
    }
  }

  Future<void> _indexDonorRepo() async {
    final donorPath = _donorPath;
    if (donorPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a donor repo first')),
      );
      return;
    }
    _showBlockingSpinner('Indexing donor repo…');
    try {
      final result = await DonorService.indexDonor(
        donorPath: donorPath,
        projectPath: project.path,
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      setState(() => _donorRepoName = result.repoName);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Indexed ${result.fileCount} files from ${result.repoName}'),
      ));
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) await _showError('Index donor repo', e);
    }
  }

  /// Set or move where this project's code lives — the linked repo used to scan
  /// existing code and to generate new source into. Reachable right from the
  /// board header so it's the first thing you can do on a project.
  Future<void> _changeCodeLocation() async {
    final config = await ProjectFileRepository.readProjectConfig(project.path);
    final current = config['repoPath'] as String?;
    if (!mounted) return;
    final newPath = await relocateRepoFlow(
      context: context,
      projectPath: project.path,
      projectName: project.name,
      currentRepoPath: (current != null && current.isNotEmpty) ? current : null,
    );
    if (newPath != null && mounted) setState(() => _repoPath = newPath);
  }

  /// On open, check whether the repo has advanced since the last review so we
  /// can nudge the user to run a check-in.
  Future<void> _loadStaleness() async {
    final repo = ref.read(trackerRepositoryProvider);
    final tracking = await repo.tracking(project.id);
    final config = await ProjectFileRepository.readProjectConfig(project.path);
    final repoPath = config['repoPath'] as String?;
    final info = await ref.read(checkinServiceProvider).checkStaleness(
          repoPath: repoPath,
          lastReviewHead: tracking?.lastReviewHead,
          lastReviewedAt: tracking?.lastReviewedAt,
        );
    if (mounted) setState(() => _staleness = info);
  }

  @override
  Widget build(BuildContext context) {
    final featuresAsync = ref.watch(featureListProvider(project.id));
    final trackingAsync = ref.watch(projectTrackingProvider(project.id));
    final status =
        ProjectStatus.fromWire(trackingAsync.valueOrNull?.status ?? 'active');

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: ForgeFilesPanel(project: project, onGenerateSpec: _generateSnapshot),
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(child: Text(project.name, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            const Text('· Tracker',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8E))),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: ActiveModelChip(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: _ProjectStatusMenu(
              current: status,
              onSelected: (s) => ref
                  .read(projectTrackingProvider(project.id).notifier)
                  .setStatus(s),
            ),
          ),
          // Remaining AI-driven actions not yet folded into the chat rail.
          _barMenu(Icons.auto_awesome_outlined, 'AI tools', [
            _menuEntry(Icons.auto_awesome_outlined, 'What this app can do',
                _openCapabilitySummary),
            _menuEntry(Icons.account_tree_outlined, 'Architecture view',
                _openArchitecture),
            _menuEntry(Icons.radar, 'Scan repo & documents', _scanRepo),
            _menuEntry(
                Icons.lightbulb_outline, 'Recommend features', _recommendFeatures),
            _menuEntry(Icons.route_outlined, 'Plan build order', _planBuildOrder),
            _menuEntry(Icons.cleaning_services_outlined, 'Remove duplicates',
                _removeDuplicates),
            const PopupMenuDivider(),
            _menuEntry(
                Icons.shield_outlined, 'Security check', _openSecurityCheck),
            _menuEntry(Icons.fact_check_outlined, 'Run check-in', _runCheckin),
            const PopupMenuDivider(),
            _menuEntry(Icons.account_tree_outlined, 'Index donor repo',
                _indexDonorRepo),
          ]),
          IconButton(
            icon: const Icon(Icons.attach_file_outlined),
            tooltip: 'Add context files',
            onPressed: _addContextFiles,
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Ingest a folder',
            onPressed: _addContextFolder,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Forge docs',
            onPressed: _openForgeFolder,
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Ask anything',
            onPressed: _askAnything,
          ),
          _barMenu(Icons.more_horiz, 'More', [
            _menuEntry(Icons.rocket_launch_outlined, 'Releases', _openReleases),
            _menuEntry(Icons.schedule, 'Review cadence',
                () => _editCadence(trackingAsync.valueOrNull)),
          ]),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add feature',
            onPressed: _addFeature,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_repoLoaded)
            _CodeLocationBar(
              repoPath: _repoPath,
              onChange: _changeCodeLocation,
              onScan: _scanRepo,
            ),
          if (_donorLoaded)
            _DonorBar(
              donorPath: _donorPath,
              donorRepoName: _donorRepoName,
              onChange: _changeDonorRepo,
              onIndex: _indexDonorRepo,
            ),
          if (_showStalenessBanner) _StalenessBanner(
            info: _staleness!,
            onRun: _runCheckin,
            onDismiss: () => setState(() => _bannerDismissed = true),
          ),
          _GroupModeBar(
            view: _boardView,
            onChanged: (v) => setState(() => _boardView = v),
            onPlan: _planBuildOrder,
          ),
          Expanded(
            child: featuresAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Failed to load features: $e')),
              data: (features) {
                if (features.isEmpty) {
                  return _EmptyState(onAdd: _addFeature, onScan: _scanRepo);
                }
                // Subtasks nest under their epic, so status columns are built
                // from top-level features only; children ride along under them.
                final (topLevel, childrenOf) = _splitEpics(features);
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (_boardView == _BoardView.buildOrder)
                      ..._buildOrderGroups(features)
                    else if (_boardView == _BoardView.recentlyShipped)
                      ..._recentlyShippedGroups(features)
                    else
                      for (final s in FeatureStatus.board)
                        ..._group(
                            s,
                            topLevel
                                .where((f) => f.status == s.wire)
                                .toList(),
                            childrenOf),
                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool get _showStalenessBanner =>
      !_bannerDismissed && (_staleness?.stale ?? false);

  /// A labeled dropdown in the app bar (e.g. "AI tools ▾"), grouping related
  /// actions so the toolbar reads as a few clear choices, not a wall of icons.
  Widget _barMenu(
      IconData icon, String label, List<PopupMenuEntry<VoidCallback>> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
      child: PopupMenuButton<VoidCallback>(
        tooltip: label,
        onSelected: (fn) => fn(),
        itemBuilder: (_) => items,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E22),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: const Color(0xFFCFCFD2)),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12.5, color: Color(0xFFCFCFD2))),
            const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF8A8A8E)),
          ]),
        ),
      ),
    );
  }

  /// One entry in a [_barMenu]: an icon + label whose value is the action to run.
  PopupMenuEntry<VoidCallback> _menuEntry(
          IconData icon, String label, VoidCallback onTap) =>
      PopupMenuItem<VoidCallback>(
        value: onTap,
        child: Row(children: [
          Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 10),
          Text(label),
        ]),
      );

  List<Widget> _group(FeatureStatus status, List<Feature> roots,
      Map<String, List<Feature>> childrenOf) {
    if (roots.isEmpty) return const [];
    final rows = _withSubtasks(roots, childrenOf);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Row(
          children: [
            StatusChip(label: status.label, color: status.color, dense: true),
            const SizedBox(width: 8),
            Text('${rows.length}',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          ],
        ),
      ),
      ...rows.map((n) => _FeatureTile(
            feature: n.feature,
            indent: n.depth,
            onSetStatus: (s) => ref
                .read(featureListProvider(project.id).notifier)
                .setStatus(n.feature, s),
            onEdit: () => _editFeature(n.feature),
            onDelete: () => ref
                .read(featureListProvider(project.id).notifier)
                .deleteFeature(n.feature),
            onBuild: () => _buildFeature(n.feature),
            onAdvice: () => _openBuildAdvice(n.feature),
            onArchitect: () => _architectFeature(n.feature),
            onArchitectChat: () => _architectChat(n.feature),
            onWorkOn: () => _workOnFeature(n.feature),
            selected: n.feature.id == _focusedFeatureId,
            onFocus: () => setState(() => _focusedFeatureId = n.feature.id),
          )),
    ];
  }

  /// Build-order grouping: the not-yet-built features (idea / planned /
  /// blocked / in-progress) grouped by their target version, versions in
  /// ascending order (next up first) and priority-ordered within each version.
  /// This is the sequence to feed features into Build-with-AI. Run "Plan build
  /// order" first to assign versions + priority; anything still unversioned
  /// lands in a trailing "Unversioned" group as a nudge to plan it.
  List<Widget> _buildOrderGroups(List<Feature> features) {
    final (topLevel, childrenOf) = _splitEpics(features);
    bool active(Feature f) => FeatureStatus.fromWire(f.status).isActive;

    // The build queue = the unbuilt work PLUS every epic/subtask that contains
    // it, so a step never orphans and always renders under its epic. Walk each
    // active feature up to its root, marking the chain to keep.
    final byId = {for (final f in features) f.id: f};
    final keep = <String>{};
    for (final f in features) {
      if (!active(f)) continue;
      var cur = f;
      while (keep.add(cur.id)) {
        final pid = cur.parentId;
        if (pid == null) break;
        final p = byId[pid];
        if (p == null) break;
        cur = p;
      }
    }

    final roots = topLevel.where((f) => keep.contains(f.id)).toList();
    if (roots.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Nothing left to build — every feature is shipped or archived.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
        ),
      ];
    }
    final byVersion = groupFeaturesByVersion(roots);
    final versions = byVersion.keys.toList()..sort(_compareVersions);

    final widgets = <Widget>[];
    var firstConcrete = true;
    for (final v in versions) {
      final items = [...byVersion[v]!]..sort(_byBuildOrder);
      final rows = _withSubtasks(items, childrenOf, keep: keep);
      final isNextUp = firstConcrete && v != 'Unversioned';
      if (v != 'Unversioned') firstConcrete = false;
      widgets.add(_VersionGroupHeader(
        version: v,
        count: rows.length,
        nextUp: isNextUp,
      ));
      // Capture loop-locals for the closure.
      final version = v;
      final versionRows = rows;
      final allFeatures = features;
      widgets.add(ReorderableListView(
        key: ValueKey('drag_$v'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: (old, neo) =>
            _reorderInVersion(version, versionRows, old, neo, allFeatures),
        children: [
          for (int i = 0; i < rows.length; i++)
            _FeatureTile(
              key: ValueKey(rows[i].feature.id),
              feature: rows[i].feature,
              indent: rows[i].depth,
              // Only top-level features get a drag handle.
              dragIndex: rows[i].depth == 0 ? i : null,
              onSetStatus: (s) => ref
                  .read(featureListProvider(project.id).notifier)
                  .setStatus(rows[i].feature, s),
              onEdit: () => _editFeature(rows[i].feature),
              onDelete: () => ref
                  .read(featureListProvider(project.id).notifier)
                  .deleteFeature(rows[i].feature),
              onBuild: () => _buildFeature(rows[i].feature),
              onAdvice: () => _openBuildAdvice(rows[i].feature),
              onArchitect: () => _architectFeature(rows[i].feature),
              onArchitectChat: () => _architectChat(rows[i].feature),
              onWorkOn: () => _workOnFeature(rows[i].feature),
              selected: rows[i].feature.id == _focusedFeatureId,
              onFocus: () =>
                  setState(() => _focusedFeatureId = rows[i].feature.id),
            ),
        ],
      ));
    }
    return widgets;
  }

  /// Called when the user drag-reorders items inside a version group.
  /// Renumbers ALL active top-level features globally (across every version)
  /// so priorities stay consistent: within [version] the new order is applied;
  /// other versions keep their current sort order.
  Future<void> _reorderInVersion(
    String version,
    List<({Feature feature, int depth})> rows,
    int oldIndex,
    int newIndex,
    List<Feature> allFeatures,
  ) async {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    if (rows[oldIndex].depth != 0) return; // subtasks stay put

    final reordered = [...rows];
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    // Build the full global order across all version groups.
    final (topLevel, _) = _splitEpics(allFeatures);
    final active = topLevel
        .where((f) => FeatureStatus.fromWire(f.status).isActive)
        .toList();
    final byVer = groupFeaturesByVersion(active);
    final versions = byVer.keys.toList()..sort(_compareVersions);

    final globalOrder = <Feature>[];
    for (final v in versions) {
      if (v == version) {
        globalOrder
            .addAll(reordered.where((n) => n.depth == 0).map((n) => n.feature));
      } else {
        final sorted = [...byVer[v]!]..sort(_byBuildOrder);
        globalOrder.addAll(sorted);
      }
    }

    // Assign sequential text priorities.
    final notifier = ref.read(featureListProvider(project.id).notifier);
    for (int i = 0; i < globalOrder.length; i++) {
      final f = globalOrder[i];
      final newLabel = (i + 1).toString();
      if (f.priorityLabel != newLabel) {
        await notifier.updateFeature(f, priorityLabel: newLabel);
      }
    }
  }

  /// Recently-shipped view: shipped features sorted by [updatedAt] descending
  /// (most recent first) so the user can see what just landed.
  List<Widget> _recentlyShippedGroups(List<Feature> features) {
    final shipped = features
        .where((f) => f.status == FeatureStatus.shipped.wire)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (shipped.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('No shipped features yet.',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Row(children: [
          const Icon(Icons.check_circle_outline,
              size: 14, color: Color(0xFF81C784)),
          const SizedBox(width: 6),
          Text('${shipped.length} shipped',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280))),
        ]),
      ),
      ...shipped.map((f) => _FeatureTile(
            feature: f,
            indent: 0,
            onSetStatus: (s) => ref
                .read(featureListProvider(project.id).notifier)
                .setStatus(f, s),
            onEdit: () => _editFeature(f),
            onDelete: () => ref
                .read(featureListProvider(project.id).notifier)
                .deleteFeature(f),
            onBuild: () => _buildFeature(f),
            onAdvice: () => _openBuildAdvice(f),
            onArchitect: () => _architectFeature(f),
            onArchitectChat: () => _architectChat(f),
            onWorkOn: () => _workOnFeature(f),
            selected: f.id == _focusedFeatureId,
            onFocus: () => setState(() => _focusedFeatureId = f.id),
          )),
    ];
  }

  /// Splits [all] into top-level features and a map of epic-id → its subtasks.
  /// A feature whose [parentId] resolves to another feature in this list is a
  /// subtask (filed under its parent); everything else — including orphans whose
  /// parent was deleted — stays top-level so nothing ever disappears. Subtasks
  /// are pre-sorted into build order.
  static (List<Feature>, Map<String, List<Feature>>) _splitEpics(
      List<Feature> all) {
    final ids = {for (final f in all) f.id};
    final childrenOf = <String, List<Feature>>{};
    final topLevel = <Feature>[];
    for (final f in all) {
      final pid = f.parentId;
      if (pid != null && ids.contains(pid)) {
        (childrenOf[pid] ??= []).add(f);
      } else {
        topLevel.add(f);
      }
    }
    for (final list in childrenOf.values) {
      list.sort(_byBuildOrder);
    }
    return (topLevel, childrenOf);
  }

  /// Flattens [roots] into display rows where every epic is immediately followed
  /// by its own subtasks (recursively), each tagged with its nesting [depth].
  /// This is what pins a subtask under its epic no matter how the board is
  /// grouped or sorted — switching views can never restage a step above or away
  /// from its parent. When [keep] is given, only ids in the set are emitted
  /// (build-order uses this to drop already-built leaf steps while still
  /// anchoring the rest under their epic).
  static List<({Feature feature, int depth})> _withSubtasks(
    List<Feature> roots,
    Map<String, List<Feature>> childrenOf, {
    Set<String>? keep,
  }) {
    final out = <({Feature feature, int depth})>[];
    void emit(Feature f, int depth) {
      if (keep != null && !keep.contains(f.id)) return;
      out.add((feature: f, depth: depth));
      for (final c in childrenOf[f.id] ?? const <Feature>[]) {
        emit(c, depth + 1);
      }
    }

    for (final r in roots) {
      emit(r, 0);
    }
    return out;
  }

  /// Within a version: lowest priority first (P1 < P1A < P1B < P2, nulls last),
  /// then by status (in-progress/blocked ahead of planned/idea), then title.
  static int _byBuildOrder(Feature a, Feature b) {
    final pa = parsePriorityLabel(a.priorityLabel);
    final pb = parsePriorityLabel(b.priorityLabel);
    final nc = pa.num.compareTo(pb.num);
    if (nc != 0) return nc;
    final sc = pa.suffix.compareTo(pb.suffix);
    if (sc != 0) return sc;
    final sa = FeatureStatus.board.indexOf(FeatureStatus.fromWire(a.status));
    final sb = FeatureStatus.board.indexOf(FeatureStatus.fromWire(b.status));
    if (sa != sb) return sa.compareTo(sb);
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  /// Ascending version compare that treats numeric segments numerically
  /// (v0.9 before v0.10) and always sorts 'Unversioned' last.
  static int _compareVersions(String a, String b) {
    if (a == b) return 0;
    if (a == 'Unversioned') return 1;
    if (b == 'Unversioned') return -1;
    final na = RegExp(r'\d+').allMatches(a).map((m) => int.parse(m[0]!)).toList();
    final nb = RegExp(r'\d+').allMatches(b).map((m) => int.parse(m[0]!)).toList();
    for (var i = 0; i < na.length && i < nb.length; i++) {
      final c = na[i].compareTo(nb[i]);
      if (c != 0) return c;
    }
    final lc = na.length.compareTo(nb.length);
    return lc != 0 ? lc : a.compareTo(b);
  }

  Future<void> _addFeature() async {
    final result = await showFeatureEditDialog(context);
    if (result == null) return;
    await ref.read(featureListProvider(project.id).notifier).addFeature(
          title: result.title,
          description: result.description,
          status: result.status,
          priorityLabel: result.priorityLabel,
          targetVersion: result.targetVersion,
          buildKind: result.buildKind,
        );
    ref.invalidate(portfolioProvider);
  }

  Future<void> _editFeature(Feature feature) async {
    final result = await showFeatureEditDialog(context, existing: feature);
    if (result == null) return;
    await ref.read(featureListProvider(project.id).notifier).updateFeature(
          feature,
          title: result.title,
          description: result.description,
          status: result.status,
          priorityLabel: result.priorityLabel,
          targetVersion: result.targetVersion,
          buildKind: result.buildKind,
        );
    ref.invalidate(portfolioProvider);
  }

  void _openReleases() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReleasesScreen(project: project),
    ));
  }

  /// Walks up [feature]'s parent chain and returns its nesting depth.
  /// 0 = top-level, 1 = sub-feature, 2 = sub-sub-feature, etc.
  int _featureDepth(Feature feature, List<Feature> all) {
    int depth = 0;
    String? parentId = feature.parentId;
    while (parentId != null && depth < 10) {
      depth++;
      final parent = all.where((f) => f.id == parentId).firstOrNull;
      parentId = parent?.parentId;
    }
    return depth;
  }

  /// Fast local heuristic: returns true when title + description are short and
  /// contain no compound-task signals — catches obvious atomic features before
  /// spending any tokens on the LLM self-assessment.
  bool _looksAtomic(Feature feature) {
    final combined = '${feature.title} ${feature.description ?? ''}'.trim();
    final wordCount =
        combined.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (wordCount > 60) return false;
    final lower = combined.toLowerCase();
    const compoundPhrases = ['and also', 'as well as', 'in addition', 'including'];
    if (compoundPhrases.any((p) => lower.contains(p))) return false;
    if (RegExp(r'\band\b').allMatches(lower).length > 2) return false;
    return wordCount < 50;
  }

  /// Architects a feature: runs three guards (depth, heuristic, LLM assessment)
  /// before spending tokens on full decomposition. If all guards pass, asks the
  /// LLM to decompose it into typed sub-features, lets the user review, then
  /// creates the kept sub-features nested under this feature (which becomes epic).
  Future<void> _architectFeature(Feature feature) async {
    final all =
        ref.read(featureListProvider(project.id)).valueOrNull ?? const [];

    // --- Guard 1: depth limit (≥ 2 levels deep = implementation steps, not features) ---
    if (_featureDepth(feature, all) >= 2) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Too deeply nested to decompose'),
          content: const Text(
            'This feature is already two levels deep. Decomposing further '
            'produces implementation steps, not trackable features.\n\n'
            'If you need finer breakdown, add sub-tasks manually.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }

    // --- Guard 2: complexity heuristic (fast, no tokens) ---
    if (_looksAtomic(feature)) {
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('This looks buildable as-is'),
          content: Text(
            '”${feature.title}” looks like a single focused task. '
            'Architecting it may just add unnecessary sub-tasks.\n\n'
            'Build it directly, or continue to Architect if you think '
            'it is more complex than it appears.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'build'),
              child: const Text('Build directly'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'architect'),
              child: const Text('Architect anyway'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == 'build') { _buildFeature(feature); return; }
      if (choice != 'architect') return; // dismissed
    }

    // --- Guard 3: LLM self-assessment (~250 tokens vs ~2500 for full decompose) ---
    _showBlockingSpinner('Checking if “${feature.title}” needs decomposition…');
    late final (bool shouldDecompose, String reason) assessment;
    try {
      assessment = await ref
          .read(featureScannerProvider)
          .assessDecomposition(feature: feature);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showError('Architect feature', e);
      return;
    }
    if (!mounted) return;

    if (!assessment.$1) {
      Navigator.of(context).pop(); // dismiss spinner
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('”${feature.title}” can be built directly. '
            '${assessment.$2}'),
        action: SnackBarAction(
          label: 'Build',
          onPressed: () => _buildFeature(feature),
        ),
        duration: const Duration(seconds: 7),
      ));
      return;
    }

    // All guards passed — run full decomposition (reuse the spinner already open).
    ArchitectPlan plan;
    try {
      plan = await ref.read(featureScannerProvider).architectFeature(
            projectPath: project.path,
            repoPath: _repoPath,
            feature: feature,
            allFeatures: all,
          );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showError('Architect feature', e);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss spinner

    final kept = await showArchitectReviewSheet(context, plan);
    if (kept == null || kept.isEmpty || !mounted) return;

    final notifier = ref.read(featureListProvider(project.id).notifier);

    // NOT an epic: the architect judged this a single buildable feature. Don't
    // wrap it in an epic and nest a clone of itself — that's what caused the
    // architect → build-gate → architect loop. Instead sharpen it in place and
    // adopt the single sub-feature's buildKind (usually "standard", which the
    // build gate lets through; "manual" if it's really human/ML work). This
    // also DEMOTES a feature that was mis-marked as an epic, breaking the loop.
    if (!plan.isEpic) {
      final only = kept.first;
      await notifier.updateFeature(
        feature,
        description: only.description ?? feature.description,
        buildKind: only.buildKind,
      );
      if (mounted) {
        final manual = only.buildKind == BuildKind.manual;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(manual
                ? '“${feature.title}” is a single feature that needs human/ML '
                    'work — see “How to build this”.'
                : '“${feature.title}” is a single buildable feature — ready to '
                    'Build with AI.')));
      }
      return;
    }

    // A real epic: mark the parent so the board tags it and the build gate
    // steers to its sub-features, then nest the kept sub-features under it.
    await notifier.updateFeature(feature, buildKind: BuildKind.epic);
    for (final s in kept) {
      await notifier.addFeature(
        title: s.title,
        description: s.description,
        status: FeatureStatus.planned,
        source: 'architect',
        buildKind: s.buildKind,
        parentId: feature.id,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Added ${kept.length} sub-features under '
              '“${feature.title}”.')));
    }
  }

  void _openBuildAdvice(Feature feature) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PromptScreen(
        project: project,
        feature: feature,
        repoPath: _repoPath,
      ),
    ));
  }

  /// Opens the Security Check for the whole app/repo (secret pre-scan + LLM
  /// security review).
  void _openSecurityCheck() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SecurityCheckScreen(project: project, repoPath: _repoPath),
    ));
  }

  /// Opens the live "what this app can do" capability summary (LLM reads the
  /// current repo/docs). Works with docs alone, so it doesn't require a repo.
  void _openCapabilitySummary() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CapabilitySummaryScreen(
        project: project,
        repoPath: _repoPath,
      ),
    ));
  }

  void _openArchitecture() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ArchitectureScreen(
        project: project,
        repoPath: _repoPath,
      ),
    ));
  }

  /// Reads the feature board, calls the LLM once, and saves a lightweight
  /// spec snapshot to Forge/specs/. Overwrites the same-day snapshot on
  /// repeated runs so the file count stays manageable.
  Future<void> _generateSnapshot() async {
    final featuresAsync = ref.read(featureListProvider(project.id));
    final features = featuresAsync.valueOrNull ?? [];
    if (features.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some features first')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating spec snapshot…'),
        duration: Duration(seconds: 30),
      ),
    );

    final llm = ref.read(llmServiceProvider);
    try {
      final content = await SpecSnapshotGenerator(llm).generate(
        projectName: project.name,
        features: features,
        projectPath: project.path,
        onProgress: (_) {},
      );

      final now = DateTime.now();
      final date =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      await ProjectFileRepository.writeSpecSnapshot(
        projectPath: project.path,
        projectName: project.name,
        date: date,
        content: content,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spec snapshot saved — open Forge docs to view'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Snapshot failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _buildFeature(Feature feature) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PromptScreen(
        project: project,
        feature: feature,
        repoPath: _repoPath,
      ),
    ));
  }

  Future<void> _scanRepo() async {
    final messenger = ScaffoldMessenger.of(context);
    // Derive features from the project's own documents, plus the linked repo if
    // one exists — no folder prompt (a doc-only project still works).
    final config = await ProjectFileRepository.readProjectConfig(project.path);
    final rp = config['repoPath'] as String?;
    final repoPath = (rp != null && rp.isNotEmpty) ? rp : null;

    _showBlockingSpinner(
        repoPath != null ? 'Reading docs + repo…' : 'Reading project documents…');
    List<ProposedFeature> proposals;
    try {
      proposals = await ref
          .read(featureScannerProvider)
          .scan(projectPath: project.path, repoPath: repoPath);
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) await _showError('Scan', e);
      return;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close spinner

    // Dedup against features already tracked (and within the scan itself) so a
    // re-scan can't double planned/idea items. Match on a normalized title.
    final existing =
        ref.read(featureListProvider(project.id)).valueOrNull ?? const [];
    final seen = existing.map((f) => _normTitle(f.title)).toSet();
    final fresh = <ProposedFeature>[];
    for (final pf in proposals) {
      final key = _normTitle(pf.title);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      fresh.add(pf);
    }
    final skipped = proposals.length - fresh.length;
    if (fresh.isEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text(skipped > 0
            ? 'No new features — all $skipped already tracked.'
            : 'No features found to import.'),
      ));
      return;
    }

    final accepted = await showScanReviewSheet(context, fresh);
    if (accepted == null || accepted.isEmpty) return;

    final notifier = ref.read(featureListProvider(project.id).notifier);
    for (final f in accepted) {
      await notifier.addFeature(
        title: f.title,
        description: f.description,
        status: f.status,
        targetVersion: f.targetVersion,
        source: 'scan',
      );
    }
    ref.invalidate(portfolioProvider);
    messenger.showSnackBar(SnackBar(
      content: Text('Imported ${accepted.length} feature(s) from scan'
          '${skipped > 0 ? ' · skipped $skipped already tracked' : ''}'),
    ));
  }

  /// Records an error to diag.log (with any raw model output) AND shows a
  /// persistent dialog that stays until dismissed — so an error can be read/
  /// screenshot/copied instead of a toast flashing by. [what] tags the action.
  Future<void> _showError(String what, Object e) async {
    final raw = e is FeatureScanException ? e.raw : null;
    await DiagLog.log(
        'ERROR [$what] $e${raw != null ? '\n--- raw model output ---\n$raw' : ''}');
    if (!mounted) return;
    final msg = e.toString();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141416),
        title: Text('$what failed'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: SelectableText(msg,
                style: const TextStyle(fontSize: 13, color: Color(0xFFE5E5E7))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: msg)),
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  /// Normalized feature title for dedup — case-insensitive and punctuation-/
  /// whitespace-insensitive, so "V2: Multi‑Part" and "v2 multi part" collide.
  static String _normTitle(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  /// The virtual-PM move: analyze what's already built/tracked (+ docs + code)
  /// and recommend NEW features/enhancements to build next. Dedups against the
  /// board and imports the ones you accept (source 'recommend').
  /// Conversational "refine features": re-open a chat on this project and add
  /// features by talking. Features land on the board; ordering is the separate
  /// Plan-build-order step.
  /// Double-click a feature tile → open the chat hub with that feature
  /// pre-selected; the fork card lets the user choose to discuss or build.
  void _workOnFeature(Feature feature) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RefineFeaturesScreen(
        project: project,
        repoPath: _repoPath,
        initialFeature: feature,
        onBuildFeature: _buildFeature,
      ),
    ));
  }

  /// Picks files from disk and ingests them into the project's reference
  /// context. Images are described by the Architect LLM; text/markdown is read
  /// directly. Output appends to Forge/ingested/reference_context.md.
  Future<void> _addContextFiles() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'png', 'jpg', 'jpeg', 'heic', 'gif', 'webp',
        'txt', 'md', 'markdown',
      ],
    );
    if (picked == null || !mounted) return;
    final paths =
        picked.files.map((f) => f.path).whereType<String>().toList();
    if (paths.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Processing context files…')),
    );

    final llm = ref.read(llmServiceProvider);
    final result = await IngestService(llm).ingestFiles(
      filePaths: paths,
      projectPath: project.path,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    final msg = result.hasProcessed
        ? '${result.processed.length} file${result.processed.length == 1 ? '' : 's'} added to project context'
        : result.hasErrors
            ? 'Error: ${result.errors.first}'
            : 'No supported files — use PNG, JPG, HEIC, TXT, or MD';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  /// Picks an entire folder and ingests all supported files within it.
  /// Walks recursively, skips hidden entries, caps at 50 files.
  Future<void> _addContextFolder() async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null || !mounted) return;

    const supported = {
      '.png', '.jpg', '.jpeg', '.heic', '.gif', '.webp',
      '.txt', '.md', '.markdown',
    };

    final dir = Directory(dirPath);
    final paths = <String>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.')) continue;
      final ext = '.${name.split('.').last.toLowerCase()}';
      if (supported.contains(ext)) {
        paths.add(entity.path);
        if (paths.length >= 50) break;
      }
    }

    if (!mounted) return;
    if (paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No supported files found — use PNG, JPG, TXT, or MD'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Processing ${paths.length} files…')),
    );

    final llm = ref.read(llmServiceProvider);
    final result = await IngestService(llm).ingestFiles(
      filePaths: paths,
      projectPath: project.path,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    final msg = result.hasProcessed
        ? '${result.processed.length} file${result.processed.length == 1 ? '' : 's'} added to project context'
        : result.hasErrors
            ? 'Error: ${result.errors.first}'
            : 'No files processed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  /// Opens the in-app Forge Files drawer (slides in from the right).
  void _openForgeFolder() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  /// Opens the free-form Direct Chat screen — a general-purpose AI chat
  /// separate from Build (Build Brief) and Architect Mode (RefineFeaturesScreen).
  void _askAnything() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DirectChatScreen(
        project: project,
        repoPath: _repoPath,
      ),
    ));
  }

  /// Architect icon on a tile → open Architect Mode and auto-send the
  /// discussion prompt for [feature] (skips the fork card).
  void _architectChat(Feature feature) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RefineFeaturesScreen(
        project: project,
        repoPath: _repoPath,
        initialFeature: feature,
        autoDiscuss: true,
        onBuildFeature: _buildFeature,
      ),
    ));
  }

  Future<void> _recommendFeatures() async {
    final messenger = ScaffoldMessenger.of(context);
    final config = await ProjectFileRepository.readProjectConfig(project.path);
    final rp = config['repoPath'] as String?;
    final repoPath = (rp != null && rp.isNotEmpty) ? rp : null;
    final existing =
        ref.read(featureListProvider(project.id)).valueOrNull ?? const [];

    if (!mounted) return;
    _showBlockingSpinner('Analyzing your app for ideas…');
    List<ProposedFeature> proposals;
    try {
      proposals = await ref.read(featureScannerProvider).recommend(
            projectPath: project.path,
            repoPath: repoPath,
            existing: existing,
          );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) await _showError('Recommendations', e);
      return;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close spinner

    // Dedup against what's already tracked (recommendations should be new).
    final seen = existing.map((f) => _normTitle(f.title)).toSet();
    final fresh = <ProposedFeature>[];
    for (final pf in proposals) {
      final key = _normTitle(pf.title);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      fresh.add(pf);
    }
    if (fresh.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('No new recommendations right now — you\'re on top of it.')));
      return;
    }

    final accepted = await showScanReviewSheet(context, fresh);
    if (accepted == null || accepted.isEmpty) return;

    final notifier = ref.read(featureListProvider(project.id).notifier);
    for (final f in accepted) {
      await notifier.addFeature(
        title: f.title,
        description: f.description,
        status: f.status,
        targetVersion: f.targetVersion,
        source: 'recommend',
      );
    }
    ref.invalidate(portfolioProvider);
    messenger.showSnackBar(SnackBar(
      content: Text('Added ${accepted.length} recommended feature(s)')),
    );
  }

  /// Sequences the not-yet-shipped features into a dependency-aware, phased
  /// build roadmap and, on approval, writes each phase's version + a running
  /// priority to the board (which sorts by priority) so it reflects build order.
  Future<void> _planBuildOrder() async {
    final messenger = ScaffoldMessenger.of(context);
    final config = await ProjectFileRepository.readProjectConfig(project.path);
    final rp = config['repoPath'] as String?;
    final repoPath = (rp != null && rp.isNotEmpty) ? rp : null;
    final features =
        ref.read(featureListProvider(project.id)).valueOrNull ?? const [];
    final toSequence = features
        .where((f) => f.status != 'shipped' && f.status != 'archived')
        .length;
    if (toSequence < 2) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Add a couple of planned features first, then I can '
              'sequence them.')));
      return;
    }

    if (!mounted) return;
    _showBlockingSpinner('Planning the build order…');
    List<RoadmapPhase> phases;
    try {
      phases = await ref.read(featureScannerProvider).planRoadmap(
            projectPath: project.path,
            repoPath: repoPath,
            features: features,
          );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) await _showError('Build order planning', e);
      return;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close spinner

    final apply = await showRoadmapReviewSheet(context, phases);
    if (apply != true) return;

    // Map roadmap entries (by normalized title) back to features; write a
    // running priority (build order) + the phase's target version.
    final byTitle = {for (final f in features) _normTitle(f.title): f};
    final notifier = ref.read(featureListProvider(project.id).notifier);
    var order = 0;
    var applied = 0;
    for (final phase in phases) {
      for (final entry in phase.entries) {
        final f = byTitle[_normTitle(entry.title)];
        if (f == null) continue;
        order += 1;
        await notifier.updateFeature(
          f,
          priorityLabel: order.toString(),
          targetVersion: phase.version.isEmpty ? null : phase.version,
        );
        applied += 1;
      }
    }
    ref.invalidate(portfolioProvider);
    messenger.showSnackBar(SnackBar(
        content: Text('Build order applied to $applied feature(s) across '
            '${phases.length} phase(s).')));
  }

  /// Cleans out duplicate features already on the board — exact title matches
  /// plus same-feature entries the scanner worded differently across runs.
  /// Finds groups (LLM + exact), lets the user review, then deletes the extras.
  Future<void> _removeDuplicates() async {
    final messenger = ScaffoldMessenger.of(context);
    final features =
        ref.read(featureListProvider(project.id)).valueOrNull ?? const [];
    if (features.length < 2) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Nothing to deduplicate yet.')));
      return;
    }

    _showBlockingSpinner('Finding duplicates…');
    DedupResult result;
    try {
      result =
          await ref.read(featureDeduplicatorProvider).findDuplicates(features);
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) await _showError('Duplicate check', e);
      return;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close spinner

    final groups = result.groups;
    if (groups.isEmpty) {
      // Distinguish "genuinely none" from "the semantic pass couldn't run" —
      // the latter is why reworded duplicates were being silently missed.
      if (!result.semanticOk) {
        await _showError(
            'Duplicate check',
            Exception(
                'The exact-title pass found no duplicates, and the semantic '
                '(AI) pass couldn\'t run — so reworded duplicates were NOT '
                'checked. The Architect model likely didn\'t return JSON '
                '(e.g. glm-5.3 on Ollama Cloud). Switch Architect to '
                'qwen3.5:cloud in Settings and try again. Details in diag.log.\n\n'
                '${result.error ?? ''}'));
      } else {
        messenger.showSnackBar(
            const SnackBar(content: Text('No duplicates found.')));
      }
      return;
    }

    final toDelete = await showDedupReviewSheet(context, groups);
    if (toDelete == null || toDelete.isEmpty) return;

    final notifier = ref.read(featureListProvider(project.id).notifier);
    final byId = {for (final f in features) f.id: f};
    for (final id in toDelete) {
      final f = byId[id];
      if (f != null) await notifier.deleteFeature(f);
    }
    ref.invalidate(portfolioProvider);
    messenger.showSnackBar(
      SnackBar(content: Text('Removed ${toDelete.length} duplicate(s)')),
    );
  }

  Future<void> _runCheckin() async {
    final messenger = ScaffoldMessenger.of(context);
    final repoPath = await _resolveRepoPath();
    if (repoPath == null) return;

    final repo = ref.read(trackerRepositoryProvider);
    final tracking = await repo.tracking(project.id);
    final features =
        ref.read(featureListProvider(project.id)).valueOrNull ?? const [];

    if (!mounted) return;
    _showBlockingSpinner('Running check-in…');
    CheckinProposal proposal;
    try {
      proposal = await ref.read(checkinServiceProvider).run(
            repoPath: repoPath,
            features: features,
            lastReviewedAt: tracking?.lastReviewedAt,
          );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) await _showError('Check-in', e);
      return;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close spinner

    final apply = await showCheckinReviewDialog(context, proposal);
    if (apply != true) return;

    final featureNotifier =
        ref.read(featureListProvider(project.id).notifier);
    for (final c in proposal.changes.where((c) => c.accepted)) {
      await featureNotifier.setStatus(c.feature, c.proposed);
    }
    // Dedup new check-in features against what's already tracked, same as scan.
    final tracked = (ref.read(featureListProvider(project.id)).valueOrNull ??
            const [])
        .map((f) => _normTitle(f.title))
        .toSet();
    for (final nf in proposal.newFeatures.where((f) => f.selected)) {
      final key = _normTitle(nf.title);
      if (key.isEmpty || tracked.contains(key)) continue;
      tracked.add(key);
      await featureNotifier.addFeature(
        title: nf.title,
        description: nf.description,
        status: nf.status,
        source: 'checkin',
      );
    }
    await ref
        .read(projectTrackingProvider(project.id).notifier)
        .markReviewed(head: proposal.head);
    ref.invalidate(portfolioProvider);
    if (mounted) {
      setState(() {
        _staleness = const StalenessInfo(stale: false);
        _bannerDismissed = true;
      });
    }
    messenger.showSnackBar(const SnackBar(
        content: Text('Check-in applied · project marked reviewed')));
  }

  /// Returns the repo path from project config, prompting for a folder (and
  /// saving it) if none is linked yet.
  Future<String?> _resolveRepoPath() async {
    final config = await ProjectFileRepository.readProjectConfig(project.path);
    final existing = config['repoPath'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    final picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select repository to scan',
      lockParentWindow: true,
    );
    if (picked == null) return null;
    await ProjectFileRepository.writeProjectConfig(
        project.path, {'repoPath': picked});
    return picked;
  }

  void _showBlockingSpinner(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        content: Row(
          children: [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 16),
            Text(message,
                style: const TextStyle(color: Color(0xFFE5E5E7), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _editCadence(ProjectTrackingData? tracking) async {
    final controller = TextEditingController(
        text: tracking?.reviewCadenceDays?.toString() ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Review cadence',
            style: TextStyle(color: Color(0xFFE5E5E7), fontSize: 16)),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How often should this project be reviewed? Leave blank for no '
                'scheduled review. The dashboard flags a project when a review '
                'is due (checked when you open the app).',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    fontFamily: 'Menlo', fontSize: 13, color: Color(0xFFE5E5E7)),
                decoration: InputDecoration(
                  hintText: 'Days between reviews (e.g. 7)',
                  hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                  filled: true,
                  fillColor: const Color(0xFF0F0F10),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
                  ),
                ),
                onSubmitted: (v) => Navigator.pop(ctx, v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child:
                const Text('Save', style: TextStyle(color: Color(0xFFE8A04C))),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    final days = int.tryParse(result.trim());
    await ref
        .read(projectTrackingProvider(project.id).notifier)
        .setCadence(days == null || days <= 0 ? null : days);
    ref.invalidate(portfolioProvider);
  }
}

class _ProjectStatusMenu extends StatelessWidget {
  const _ProjectStatusMenu({required this.current, required this.onSelected});

  final ProjectStatus current;
  final ValueChanged<ProjectStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ProjectStatus>(
      tooltip: 'Project status',
      onSelected: onSelected,
      itemBuilder: (_) => ProjectStatus.all
          .map((s) => PopupMenuItem(
                value: s,
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: s.color),
                    const SizedBox(width: 8),
                    Text(s.label),
                  ],
                ),
              ))
          .toList(),
      child: Center(
        child: StatusChip(
          label: current.label,
          color: current.color,
          icon: Icons.arrow_drop_down,
          dense: true,
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    super.key,
    required this.feature,
    required this.onSetStatus,
    required this.onEdit,
    required this.onDelete,
    required this.onBuild,
    required this.onAdvice,
    required this.onArchitect,
    required this.onArchitectChat,
    required this.selected,
    required this.onFocus,
    required this.onWorkOn,
    this.indent = 0,
    this.dragIndex,
  });

  final Feature feature;

  /// Nesting depth: 0 = an epic or standalone feature, 1+ = a subtask rendered
  /// indented directly under its epic. Drives the left inset and branch glyph.
  final int indent;

  /// When non-null, shows a drag handle in the leading area and registers a
  /// [ReorderableDragStartListener] at this list index (build-order view only).
  final int? dragIndex;

  final ValueChanged<FeatureStatus> onSetStatus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onBuild;
  // Double-click → open the "Work on" chat focused on this feature.
  final VoidCallback onWorkOn;
  final VoidCallback onAdvice;
  final VoidCallback onArchitect;
  /// Architect Mode chat button on the tile — opens the chat hub and auto-sends
  /// a discussion message for this feature (skips the fork card).
  final VoidCallback onArchitectChat;

  /// Whether this is the focused feature (highlighted).
  final bool selected;

  /// Marks this feature as focused — fired on click, right-click, or opening
  /// the actions menu so the user always knows which feature is in focus.
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final status = FeatureStatus.fromWire(feature.status);
    return GestureDetector(
      // Right-click anywhere on the row → focus it + the same actions menu.
      onSecondaryTapDown: (d) {
        onFocus();
        _showContextMenu(context, status, d.globalPosition);
      },
      // Double-click → open the chat hub pre-filled with this feature's title.
      onDoubleTap: onWorkOn,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? const Color(0x2264B5F6) : null,
          border: Border(
            left: BorderSide(
              width: 3,
              color: selected ? const Color(0xFF64B5F6) : Colors.transparent,
            ),
          ),
        ),
        child: _tile(context, status),
      ),
    );
  }

  Widget _tile(BuildContext context, FeatureStatus status) {
    return ListTile(
      dense: true,
      // Indent subtasks so they read as nested under their epic.
      contentPadding: EdgeInsets.only(left: 16.0 + indent * 22, right: 16),
      onTap: onFocus,
      mouseCursor: SystemMouseCursors.click,
      leading: dragIndex != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReorderableDragStartListener(
                  index: dragIndex!,
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.drag_handle,
                          size: 16, color: Color(0xFF3F3F46)),
                    ),
                  ),
                ),
                Icon(Icons.circle, size: 12, color: status.color),
              ],
            )
          : Icon(Icons.circle, size: 12, color: status.color),
      title: Row(
        children: [
          if (indent > 0) ...[
            const Icon(Icons.subdirectory_arrow_right,
                size: 13, color: Color(0xFF6B7280)),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(feature.title,
                style: const TextStyle(fontSize: 13, color: Color(0xFFE5E5E7))),
          ),
          if (BuildKind.fromWire(feature.buildKind) != BuildKind.standard) ...[
            const SizedBox(width: 8),
            _KindTag(BuildKind.fromWire(feature.buildKind)),
          ],
        ],
      ),
      subtitle: _subtitle(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.forum_outlined, size: 16),
            tooltip: 'Architect Mode — discuss & refine',
            color: const Color(0xFF64B5F6),
            visualDensity: VisualDensity.compact,
            onPressed: onArchitectChat,
          ),
          IconButton(
            icon: const Icon(Icons.construction, size: 16),
            tooltip: 'Generate Prompt (coming soon)',
            color: const Color(0xFFE8A04C),
            visualDensity: VisualDensity.compact,
            onPressed: onBuild,
          ),
          PopupMenuButton<_TileAction>(
            icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF8A8A8E)),
            onOpened: onFocus,
            onSelected: _handleAction,
            itemBuilder: (_) => _menuItems(status),
          ),
        ],
      ),
    );
  }

  /// Dispatches a chosen menu action to the right callback (shared by the ⋮
  /// button and the right-click context menu).
  void _handleAction(_TileAction a) {
    switch (a.kind) {
      case _ActionKind.setStatus:
        onSetStatus(a.status!);
      case _ActionKind.build:
        onBuild();
      case _ActionKind.advice:
        onAdvice();
      case _ActionKind.architect:
        onArchitect();
      case _ActionKind.edit:
        onEdit();
      case _ActionKind.delete:
        onDelete();
    }
  }

  /// Shows the actions menu at [position] (right-click), reusing the same items.
  Future<void> _showContextMenu(
      BuildContext context, FeatureStatus status, Offset position) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final choice = await showMenu<_TileAction>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: _menuItems(status),
    );
    if (choice != null) _handleAction(choice);
  }

  /// The actions menu items — one source of truth for the ⋮ button and
  /// right-click.
  List<PopupMenuEntry<_TileAction>> _menuItems(FeatureStatus status) => [
        // Available on any non-archived feature — including shipped ones, so
        // a finished feature can be re-opened and edited/extended.
        if (status != FeatureStatus.archived) ...[
          const PopupMenuItem(
            value: _TileAction.build_,
            child: Row(children: [
              Icon(Icons.auto_awesome, size: 16, color: Color(0xFFE8A04C)),
              SizedBox(width: 8),
              Text('Build'),
            ]),
          ),
          const PopupMenuItem(
            value: _TileAction.advice_,
            child: Row(children: [
              Icon(Icons.tips_and_updates_outlined,
                  size: 16, color: Color(0xFF64B5F6)),
              SizedBox(width: 8),
              Text('How to build this'),
            ]),
          ),
          const PopupMenuItem(
            value: _TileAction.architect_,
            child: Row(children: [
              Icon(Icons.account_tree_outlined,
                  size: 16, color: Color(0xFFBA68C8)),
              SizedBox(width: 8),
              Text('Architect'),
            ]),
          ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(
          enabled: false,
          height: 28,
          child: Text('Move to',
              style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ),
        ...FeatureStatus.board.where((s) => s != status).map(
              (s) => PopupMenuItem(
                value: _TileAction.move(s),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: s.color),
                    const SizedBox(width: 8),
                    Text(s.label),
                  ],
                ),
              ),
            ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _TileAction.edit_,
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 16),
            SizedBox(width: 8),
            Text('Edit'),
          ]),
        ),
        const PopupMenuItem(
          value: _TileAction.delete_,
          child: Row(children: [
            Icon(Icons.delete_outline, size: 16, color: Color(0xFFFF453A)),
            SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: Color(0xFFFF453A))),
          ]),
        ),
      ];

  Widget? _subtitle() {
    final bits = <String>[];
    if (feature.targetVersion != null) bits.add(feature.targetVersion!.toLowerCase());
    if (feature.priorityLabel != null) bits.add('P${feature.priorityLabel}');
    if (feature.source != 'manual') bits.add(feature.source);
    final meta = bits.join(' · ');
    final desc = feature.description;
    if (desc == null && meta.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (desc != null)
          Text(desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        if (meta.isNotEmpty)
          Text(meta,
              style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
      ],
    );
  }
}

/// A small colored tag marking a feature as an epic or manual (human/ML) item,
/// so the board shows at a glance what shouldn't be code-generated directly.
class _KindTag extends StatelessWidget {
  const _KindTag(this.kind);
  final BuildKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: kind.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(kind.label.toLowerCase(),
          style: TextStyle(fontSize: 9.5, color: kind.color)),
    );
  }
}

enum _ActionKind { setStatus, build, advice, architect, edit, delete }

class _TileAction {
  const _TileAction(this.kind, [this.status]);
  final _ActionKind kind;
  final FeatureStatus? status;

  static _TileAction move(FeatureStatus s) =>
      _TileAction(_ActionKind.setStatus, s);
  static const _TileAction build_ = _TileAction(_ActionKind.build);
  static const _TileAction advice_ = _TileAction(_ActionKind.advice);
  static const _TileAction architect_ = _TileAction(_ActionKind.architect);
  static const _TileAction edit_ = _TileAction(_ActionKind.edit);
  static const _TileAction delete_ = _TileAction(_ActionKind.delete);
}

/// Single toggle button that flips between "Status" and "Build order" grouping.
enum _BoardView { buildOrder, status, recentlyShipped }

class _GroupModeBar extends StatelessWidget {
  const _GroupModeBar({
    required this.view,
    required this.onChanged,
    required this.onPlan,
  });

  final _BoardView view;
  final ValueChanged<_BoardView> onChanged;
  final VoidCallback onPlan;

  static const _labels = {
    _BoardView.buildOrder: ('Build order', Icons.low_priority),
    _BoardView.status: ('Status', Icons.view_column_outlined),
    _BoardView.recentlyShipped: ('Recently shipped', Icons.check_circle_outline),
  };

  _BoardView get _next => switch (view) {
        _BoardView.buildOrder => _BoardView.status,
        _BoardView.status => _BoardView.recentlyShipped,
        _BoardView.recentlyShipped => _BoardView.buildOrder,
      };

  @override
  Widget build(BuildContext context) {
    final (label, icon) = _labels[view]!;
    return Material(
      color: const Color(0xFF141416),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onChanged(_next),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E22),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 14, color: const Color(0xFFCFCFD2)),
                  const SizedBox(width: 6),
                  const Text('Groupings',
                      style: TextStyle(
                          fontSize: 12.5, color: Color(0xFFCFCFD2))),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF8A8A8E))),
                  const SizedBox(width: 4),
                  const Icon(Icons.swap_horiz,
                      size: 13, color: Color(0xFF8A8A8E)),
                ]),
              ),
            ),
            const Spacer(),
            if (view == _BoardView.buildOrder)
              TextButton.icon(
                onPressed: onPlan,
                icon: const Icon(Icons.route_outlined, size: 15),
                label: const Text('Plan build order'),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE8A04C)),
              ),
          ],
        ),
      ),
    );
  }
}


/// Section header for a target version in build-order mode, tagging the
/// earliest concrete version as the one to build next.
class _VersionGroupHeader extends StatelessWidget {
  const _VersionGroupHeader({
    required this.version,
    required this.count,
    required this.nextUp,
  });

  final String version;
  final int count;
  final bool nextUp;

  @override
  Widget build(BuildContext context) {
    final unversioned = version == 'Unversioned';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Icon(unversioned ? Icons.help_outline : Icons.flag_outlined,
              size: 15,
              color: unversioned
                  ? const Color(0xFF6B7280)
                  : const Color(0xFF64B5F6)),
          const SizedBox(width: 8),
          Text(unversioned ? 'Unversioned' : version,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE5E5E7))),
          const SizedBox(width: 8),
          Text('$count',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          const SizedBox(width: 10),
          if (nextUp)
            const StatusChip(
                label: 'NEXT UP', color: Color(0xFF81C784), dense: true),
          if (unversioned) ...[
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Run "Plan build order" to sequence these into versions.',
                style: TextStyle(fontSize: 11, color: Color(0xFF8A8A8E)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StalenessBanner extends StatelessWidget {
  const _StalenessBanner({
    required this.info,
    required this.onRun,
    required this.onDismiss,
  });

  final StalenessInfo info;
  final VoidCallback onRun;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final message = info.neverReviewed
        ? 'This project hasn\'t been reviewed yet.'
        : '${info.newCommits} new commit${info.newCommits == 1 ? '' : 's'} since your last review.';
    return Material(
      color: const Color(0x22E8A04C),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            const Icon(Icons.history, size: 18, color: Color(0xFFE8A04C)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: Color(0xFFE5E5E7), fontSize: 12.5)),
            ),
            TextButton(
              onPressed: onRun,
              child: const Text('Run check-in',
                  style: TextStyle(color: Color(0xFFE8A04C))),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Dismiss',
              color: const Color(0xFF8A8A8E),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

/// Always-visible bar showing where this project's code lives, with one tap to
/// set/move it (relocate flow) and — once linked — to scan it. This is the
/// entry point for "choose the repo location" so a scan or a code-generating
/// build has somewhere to point immediately.
class _CodeLocationBar extends StatelessWidget {
  const _CodeLocationBar({
    required this.repoPath,
    required this.onChange,
    required this.onScan,
  });
  final String? repoPath;
  final VoidCallback onChange;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final linked = repoPath != null && repoPath!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F10),
        border: Border(bottom: BorderSide(color: Color(0xFF1C1C1E))),
      ),
      child: Row(
        children: [
          Icon(linked ? Icons.code : Icons.folder_off_outlined,
              size: 15,
              color: linked ? const Color(0xFF64B5F6) : const Color(0xFFE8A04C)),
          const SizedBox(width: 8),
          Text('Code:',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              linked ? repoPath! : 'No code location set',
              style: TextStyle(
                fontFamily: 'Menlo',
                fontSize: 12,
                color: linked
                    ? const Color(0xFFE5E5E7)
                    : const Color(0xFF9CA3AF),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (linked)
            TextButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.radar, size: 15),
              label: const Text('Scan'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64B5F6),
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (linked)
            TextButton(
              onPressed: onChange,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('Change', style: TextStyle(fontSize: 12)),
            )
          else
            FilledButton.icon(
              onPressed: onChange,
              icon: const Icon(Icons.create_new_folder_outlined, size: 15),
              label: const Text('Set code location'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact row showing the donor repo name and quick actions (Set / Change /
/// Index). Mirrors [_CodeLocationBar] but uses a purple accent to distinguish
/// it from the primary code repo.
class _DonorBar extends StatelessWidget {
  const _DonorBar({
    required this.donorPath,
    required this.donorRepoName,
    required this.onChange,
    required this.onIndex,
  });
  final String? donorPath;
  final String? donorRepoName;
  final VoidCallback onChange;
  final VoidCallback onIndex;

  @override
  Widget build(BuildContext context) {
    final linked = donorPath != null && donorPath!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0D),
        border: Border(bottom: BorderSide(color: Color(0xFF1C1C1E))),
      ),
      child: Row(
        children: [
          Icon(Icons.account_tree_outlined,
              size: 15,
              color: linked
                  ? const Color(0xFFBA68C8)
                  : const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Text('Donor:',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              linked ? (donorRepoName ?? donorPath!) : 'No donor repo set',
              style: TextStyle(
                fontFamily: 'Menlo',
                fontSize: 12,
                color: linked
                    ? const Color(0xFFD4B2E8)
                    : const Color(0xFF6B7280),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (linked)
            TextButton.icon(
              onPressed: onIndex,
              icon: const Icon(Icons.sync, size: 15),
              label: const Text('Index'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFBA68C8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          linked
              ? TextButton(
                  onPressed: onChange,
                  style:
                      TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child:
                      const Text('Change', style: TextStyle(fontSize: 12)),
                )
              : TextButton.icon(
                  onPressed: onChange,
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Set donor repo'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFBA68C8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.onScan});
  final VoidCallback onAdd;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.checklist_rtl, size: 48, color: Color(0xFF3A3A3C)),
          const SizedBox(height: 12),
          const Text('No features tracked yet',
              style: TextStyle(color: Color(0xFF9CA3AF))),
          const SizedBox(height: 4),
          const Text(
            'Scan this project\'s documents (and repo, if linked) to propose a '
            'feature list, or add manually.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.radar, size: 18),
                label: const Text('Scan Repo and Documents'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add feature'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
