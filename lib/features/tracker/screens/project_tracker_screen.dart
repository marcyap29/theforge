import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../../../services/diag_log.dart';
import '../../implementation/models/run_session.dart';
import '../../implementation/providers/implementation_notifier.dart';
import '../../implementation/providers/implementation_providers.dart';
import '../../implementation/screens/implementation_screen.dart';
import '../../projects/providers/providers.dart';
import '../../run/run_preview_screen.dart';
import '../checkin/checkin_review_dialog.dart';
import '../checkin/checkin_service.dart';
import '../models/tracker_enums.dart';
import '../providers/tracker_providers.dart';
import '../releases/release_providers.dart';
import '../scan/feature_dedup.dart';
import '../scan/feature_scan.dart';
import '../widgets/active_model_chip.dart';
import '../widgets/architect_review_sheet.dart';
import '../widgets/dedup_review_sheet.dart';
import '../widgets/feature_edit_dialog.dart';
import '../widgets/platform_picker.dart';
import '../widgets/relocate_repo.dart';
import '../widgets/roadmap_review_sheet.dart';
import '../widgets/scan_review_sheet.dart';
import '../widgets/status_chip.dart';
import 'build_advice_screen.dart';
import 'capability_summary_screen.dart';
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

  /// Board grouping: false = by status (default), true = by target version in
  /// build order (the sequence to feed features into Build-with-AI).
  bool _buildOrderView = false;

  /// The feature the user is currently focused on (highlighted). Set on click,
  /// right-click, or opening a feature's actions menu.
  String? _focusedFeatureId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadStaleness);
    Future.microtask(_loadRepoPath);
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
          // AI-driven analysis actions, grouped so the board isn't a wall of
          // mystery icons. Everything the AI does to read/organize the project.
          _barMenu(Icons.auto_awesome_outlined, 'AI tools', [
            _menuEntry(Icons.auto_awesome_outlined, 'What this app can do',
                _openCapabilitySummary),
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
          ]),
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'Run & preview',
            onPressed: _openRunPreview,
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
          if (_showStalenessBanner) _StalenessBanner(
            info: _staleness!,
            onRun: _runCheckin,
            onDismiss: () => setState(() => _bannerDismissed = true),
          ),
          _GroupModeBar(
            buildOrder: _buildOrderView,
            onChanged: (v) => setState(() => _buildOrderView = v),
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
                    if (_buildOrderView)
                      ..._buildOrderGroups(features)
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
    final activeRuns = ref.watch(implActiveRunsProvider);
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
            runPhase: activeRuns[n.feature.id],
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
    final activeRuns = ref.watch(implActiveRunsProvider);

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
      widgets.addAll(rows.map((n) => _FeatureTile(
            feature: n.feature,
            indent: n.depth,
            runPhase: activeRuns[n.feature.id],
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
            selected: n.feature.id == _focusedFeatureId,
            onFocus: () => setState(() => _focusedFeatureId = n.feature.id),
          )));
    }
    return widgets;
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

  /// Within a version: lowest priority number first (nulls last), then by
  /// status (in-progress/blocked ahead of planned/idea), then title.
  static int _byBuildOrder(Feature a, Feature b) {
    final pa = a.priority ?? 1 << 30;
    final pb = b.priority ?? 1 << 30;
    if (pa != pb) return pa.compareTo(pb);
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
          priority: result.priority,
          targetVersion: result.targetVersion,
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
          priority: result.priority,
          targetVersion: result.targetVersion,
        );
    ref.invalidate(portfolioProvider);
  }

  void _openReleases() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReleasesScreen(project: project),
    ));
  }

  /// The pre-build gate for an epic / manual feature: steer to Architect or
  /// How-to-build. Returns true only if the user chooses "Build anyway".
  Future<bool?> _confirmBuildDespiteKind(Feature feature, BuildKind kind) {
    final epic = kind == BuildKind.epic;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141416),
        title: Text(epic ? 'This is an epic' : 'This needs human / ML work'),
        content: Text(
          epic
              ? '“${feature.title}” is too big to build in one go. Break it into '
                  'sub-features first — otherwise the AI will only scaffold part '
                  'of it and mark it done.'
              : '“${feature.title}” isn\'t a code-generation task (it needs a '
                  'human, a dataset, model training, design, or an external '
                  'service). Build-with-AI can\'t complete it. See how to '
                  'approach it instead.',
          style: const TextStyle(fontSize: 13, color: Color(0xFFE5E5E7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Build anyway',
                style: TextStyle(color: Color(0xFF8A8A8E))),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              if (epic) {
                _architectFeature(feature);
              } else {
                _openBuildAdvice(feature);
              }
            },
            child: Text(epic ? 'Architect it' : 'How to build this'),
          ),
        ],
      ),
    );
  }

  /// Architects a feature: asks the LLM to decompose it into typed sub-features,
  /// lets the user review, then creates the kept sub-features nested under this
  /// feature (which becomes an epic).
  Future<void> _architectFeature(Feature feature) async {
    _showBlockingSpinner('Architecting “${feature.title}”…');
    ArchitectPlan plan;
    try {
      final all =
          ref.read(featureListProvider(project.id)).valueOrNull ?? const [];
      plan = await ref.read(featureScannerProvider).architectFeature(
            projectPath: project.path,
            repoPath: _repoPath,
            feature: feature,
            allFeatures: all,
          );
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // dismiss spinner
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

  /// Opens scale-aware build advice for a single feature (LLM reads the repo:
  /// scope, feasibility, approach, effort, risks, breakdown).
  void _openBuildAdvice(Feature feature) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BuildAdviceScreen(
        project: project,
        repoPath: _repoPath,
        feature: feature,
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

  /// Opens the Run & Preview window: run the app on a simulator/emulator and
  /// watch it (live screenshot mirror + console). Needs a linked, runnable repo.
  Future<void> _openRunPreview() async {
    final repoPath = await _ensureRepoPath();
    if (repoPath == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RunPreviewScreen(project: project, repoPath: repoPath),
    ));
  }

  /// "Build with AI" (Pro): assemble the brief (feature + spec/handoff as
  /// context), open the implementation window, and update tracking on ship.
  /// Returns a valid linked repo path, offering to create a fresh code folder
  /// or link an existing one if the project has none yet. Null = cancelled.
  Future<String?> _ensureRepoPath() async {
    final config = await ProjectFileRepository.readProjectConfig(project.path);
    final existing = config['repoPath'] as String?;
    if (existing != null && Directory(existing).existsSync()) return existing;
    if (!mounted) return null;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('This project has no code repo'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'create'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.create_new_folder_outlined),
              title: Text('Create a new code folder'),
              subtitle: Text('Makes ~/Development/<name> and git-inits it'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'existing'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.folder_open_outlined),
              title: Text('Link an existing folder'),
            ),
          ),
        ],
      ),
    );
    final messenger = ScaffoldMessenger.of(context);
    if (choice == 'create') {
      // Ask which platforms so the folder is scaffolded runnable from the start.
      if (!mounted) return null;
      final platforms = await pickPlatforms(context, projectName: project.name);
      if (platforms == null) return null; // cancelled
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Creating the app… (scaffolding platforms)')));
      }
      try {
        final path = await ProjectFileRepository.createCodeRepo(project.name,
            platforms: platforms);
        await ProjectFileRepository.writeProjectConfig(
            project.path, {'repoPath': path, 'platforms': platforms});
        if (mounted) {
          messenger.showSnackBar(
              SnackBar(content: Text('Created and linked $path')));
        }
        return path;
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text('Could not create folder: $e'),
            backgroundColor: const Color(0xFF3F0A0A),
          ));
        }
        return null;
      }
    } else if (choice == 'existing') {
      final picked = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select code repo for ${project.name}',
        lockParentWindow: true,
      );
      if (picked == null) return null;
      // Never let the Forge project workspace be used as a code repo — that
      // scatters generated code among the deliverables (the AR Mechanic bug).
      if (await ProjectFileRepository.isInsideProjectsRoot(picked)) {
        if (mounted) {
          messenger.showSnackBar(const SnackBar(
            content: Text(
                "That folder is inside The Forge's project workspace. Pick a "
                'code folder outside it (e.g. under ~/Development).'),
            backgroundColor: Color(0xFF3F0A0A),
          ));
        }
        return null;
      }
      await ProjectFileRepository.writeProjectConfig(
          project.path, {'repoPath': picked});
      return picked;
    }
    return null;
  }

  Future<void> _buildFeature(Feature feature) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!ref.read(entitlementProvider)) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Build with AI is a Pro feature.')));
      return;
    }

    // If a run for this feature already exists (still working, awaiting
    // approval, or finished), just re-open its window — never start a second
    // run or re-flip status. This is what keeps a build going when you leave
    // and come back, without resending the task.
    final activePhase = ref.read(implActiveRunsProvider)[feature.id];
    if (activePhase != null && activePhase != RunPhase.idle) {
      // Re-attaching to an existing run: still carry the linked repo path so
      // repo-dependent actions (Commit & push, Make runnable) stay enabled —
      // passing '' here previously greyed them out on any reopened feature.
      final config = await ProjectFileRepository.readProjectConfig(project.path);
      final rp = (config['repoPath'] as String?) ?? '';
      if (!mounted) return;
      await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ImplementationScreen(
          brief: ImplBrief(
            projectPath: project.path,
            projectName: project.name,
            repoPath: rp,
            featureId: feature.id,
            featureTitle: feature.title,
          ),
        ),
      ));
      if (mounted) await _handleBuildResult(feature);
      return;
    }

    // Build gate: don't silently code-generate (and stub) an epic or work that
    // isn't a code-gen task. Steer to Architect / How-to-build instead; allow an
    // explicit override.
    final kind = BuildKind.fromWire(feature.buildKind);
    if (!kind.isDirectlyBuildable) {
      final proceed = await _confirmBuildDespiteKind(feature, kind);
      if (proceed != true) return;
    }

    final repoPath = await _ensureRepoPath();
    if (repoPath == null) return; // user cancelled the create/link prompt

    // Load spec/handoff context if a spec has been generated.
    String? lockedSpec;
    String? goalStatement;
    var components = <String>[];
    var checklist = <Map<String, dynamic>>[];
    final version = project.specVersion;
    if (version != null && version.isNotEmpty) {
      final fileRepo = ref.read(projectFileRepositoryProvider);
      try {
        lockedSpec =
            await fileRepo.readLockedSpec(project.path, project.name, version);
      } catch (_) {}
      final handoff = await ProjectFileRepository.readHandoffPackage(
          project.path, project.name, version);
      if (handoff != null) {
        goalStatement = handoff['goalStatement'] as String?;
        components =
            ((handoff['components'] as List?) ?? const []).cast<String>();
        checklist = ((handoff['verificationChecklist'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }

    final brief = ImplBrief(
      projectPath: project.path,
      projectName: project.name,
      repoPath: repoPath,
      featureId: feature.id,
      featureTitle: feature.title,
      featureDescription: feature.description,
      targetVersion: feature.targetVersion,
      lockedSpec: lockedSpec,
      goalStatement: goalStatement,
      components: components,
      checklist: checklist,
    );

    // Mark in-progress while the build runs.
    await ref
        .read(featureListProvider(project.id).notifier)
        .setStatus(feature, FeatureStatus.inProgress);
    ref.invalidate(portfolioProvider);

    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ImplementationScreen(brief: brief)),
    );
    if (mounted) await _handleBuildResult(feature);
  }

  /// After the build window closes, reflect a "Mark shipped" into the tracker —
  /// set the feature shipped and ensure a release row for its version. Reads the
  /// keepAlive run state so it works whether the window was freshly launched or
  /// re-attached (the reattach path previously dropped this).
  Future<void> _handleBuildResult(Feature feature) async {
    if (!ref.read(implRunProvider(feature.id)).featureShipped) return;
    await ref
        .read(featureListProvider(project.id).notifier)
        .setStatus(feature, FeatureStatus.shipped);
    final v = feature.targetVersion?.trim();
    if (v != null && v.isNotEmpty) {
      await ref
          .read(releaseListProvider(project.id).notifier)
          .ensureForVersion(v, projectPath: project.path);
    }
    ref.invalidate(portfolioProvider);
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
          priority: order,
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
    required this.feature,
    required this.onSetStatus,
    required this.onEdit,
    required this.onDelete,
    required this.onBuild,
    required this.onAdvice,
    required this.onArchitect,
    required this.selected,
    required this.onFocus,
    this.indent = 0,
    this.runPhase,
  });

  final Feature feature;

  /// Nesting depth: 0 = an epic or standalone feature, 1+ = a subtask rendered
  /// indented directly under its epic. Drives the left inset and branch glyph.
  final int indent;
  final ValueChanged<FeatureStatus> onSetStatus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onBuild;
  final VoidCallback onAdvice;
  final VoidCallback onArchitect;

  /// Whether this is the focused feature (highlighted).
  final bool selected;

  /// Marks this feature as focused — fired on click, right-click, or opening
  /// the actions menu so the user always knows which feature is in focus.
  final VoidCallback onFocus;

  /// Non-null when a Build with AI run for this feature is live (any phase);
  /// drives the status dot on the board.
  final RunPhase? runPhase;

  @override
  Widget build(BuildContext context) {
    final status = FeatureStatus.fromWire(feature.status);
    final phase = runPhase;
    final hasRun = phase != null && phase != RunPhase.idle;
    return GestureDetector(
      // Right-click anywhere on the row → focus it + the same actions menu.
      onSecondaryTapDown: (d) {
        onFocus();
        _showContextMenu(context, status, d.globalPosition);
      },
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
        child: _tile(context, status, phase, hasRun),
      ),
    );
  }

  Widget _tile(BuildContext context, FeatureStatus status, RunPhase? phase,
      bool hasRun) {
    return ListTile(
      dense: true,
      // Indent subtasks so they read as nested under their epic.
      contentPadding: EdgeInsets.only(left: 16.0 + indent * 22, right: 16),
      // Single click focuses (highlights) the row; a feature with a live AI
      // build also re-opens its build window.
      onTap: () {
        onFocus();
        if (hasRun) onBuild();
      },
      mouseCursor: SystemMouseCursors.click,
      leading: hasRun
          ? _RunDot(phase!)
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
          if (hasRun) ...[
            const SizedBox(width: 8),
            Icon(Icons.open_in_new, size: 12, color: phase!.dotColor),
          ],
        ],
      ),
      subtitle: _subtitle(),
      trailing: PopupMenuButton<_TileAction>(
        icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF8A8A8E)),
        onOpened: onFocus,
        onSelected: _handleAction,
        itemBuilder: (_) => _menuItems(status),
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
          PopupMenuItem(
            value: _TileAction.build_,
            child: Row(children: [
              const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFE8A04C)),
              const SizedBox(width: 8),
              Text(status == FeatureStatus.shipped
                  ? 'Re-build / edit with AI'
                  : 'Build with AI'),
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
              Text('Architect (break into sub-features)'),
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
    if (feature.targetVersion != null) bits.add(feature.targetVersion!);
    if (feature.priority != null) bits.add('P${feature.priority}');
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

/// The board's live indicator for a feature with a Build-with-AI run:
/// yellow (pulsing) = the AI is actively working; blue = waiting for your
/// approval; green = done; red = failed/stopped.
class _RunDot extends StatefulWidget {
  const _RunDot(this.phase);
  final RunPhase phase;

  @override
  State<_RunDot> createState() => _RunDotState();
}

class _RunDotState extends State<_RunDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  ({bool pulse, String tip}) get _spec => switch (widget.phase) {
        RunPhase.awaitingApproval => (
            pulse: false,
            tip: 'Waiting for your approval — tap to open'
          ),
        RunPhase.done => (pulse: false, tip: 'Build complete — tap to open'),
        RunPhase.failed || RunPhase.stopped => (
            pulse: false,
            tip: 'Build failed or stopped — tap to open'
          ),
        _ => (pulse: true, tip: 'AI is working… tap to watch'),
      };

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    final dot = Container(
      width: 12,
      height: 12,
      decoration:
          BoxDecoration(color: widget.phase.dotColor, shape: BoxShape.circle),
    );
    return Tooltip(
      message: spec.tip,
      child: SizedBox(
        width: 16,
        height: 16,
        child: Center(
          child: spec.pulse ? FadeTransition(opacity: _c, child: dot) : dot,
        ),
      ),
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

/// The board grouping toggle: "By status" (the columns) vs "Build order"
/// (features grouped by target version in the sequence to build them). When in
/// build-order mode it offers a shortcut to re-run "Plan build order".
class _GroupModeBar extends StatelessWidget {
  const _GroupModeBar({
    required this.buildOrder,
    required this.onChanged,
    required this.onPlan,
  });

  final bool buildOrder;
  final ValueChanged<bool> onChanged;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF141416),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(
          children: [
            const Text('Group by',
                style: TextStyle(color: Color(0xFF8A8A8E), fontSize: 12)),
            const SizedBox(width: 10),
            _Segment(
              label: 'Status',
              icon: Icons.view_column_outlined,
              selected: !buildOrder,
              onTap: () => onChanged(false),
            ),
            const SizedBox(width: 6),
            _Segment(
              label: 'Build order',
              icon: Icons.low_priority,
              selected: buildOrder,
              onTap: () => onChanged(true),
            ),
            const Spacer(),
            if (buildOrder)
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

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? const Color(0xFF0E0E10) : const Color(0xFFCFCFD2);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF64B5F6) : const Color(0xFF1E1E22),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  color: fg,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400)),
        ]),
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
