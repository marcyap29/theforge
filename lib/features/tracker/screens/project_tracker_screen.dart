import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../../implementation/models/run_session.dart';
import '../../implementation/providers/implementation_notifier.dart';
import '../../implementation/providers/implementation_providers.dart';
import '../../implementation/screens/implementation_screen.dart';
import '../../projects/providers/providers.dart';
import '../checkin/checkin_review_dialog.dart';
import '../checkin/checkin_service.dart';
import '../models/tracker_enums.dart';
import '../providers/tracker_providers.dart';
import '../releases/release_providers.dart';
import '../scan/feature_scan.dart';
import '../widgets/active_model_chip.dart';
import '../widgets/feature_edit_dialog.dart';
import '../widgets/scan_review_sheet.dart';
import '../widgets/status_chip.dart';
import 'releases_screen.dart';

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

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadStaleness);
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
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'Run check-in',
            onPressed: _runCheckin,
          ),
          IconButton(
            icon: const Icon(Icons.radar),
            tooltip: 'Scan Repo and Documents',
            onPressed: _scanRepo,
          ),
          IconButton(
            icon: const Icon(Icons.rocket_launch_outlined),
            tooltip: 'Releases',
            onPressed: _openReleases,
          ),
          IconButton(
            icon: const Icon(Icons.schedule),
            tooltip: 'Review cadence',
            onPressed: () => _editCadence(trackingAsync.valueOrNull),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add feature',
            onPressed: _addFeature,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showStalenessBanner) _StalenessBanner(
            info: _staleness!,
            onRun: _runCheckin,
            onDismiss: () => setState(() => _bannerDismissed = true),
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
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final s in FeatureStatus.board)
                      ..._group(s,
                          features.where((f) => f.status == s.wire).toList()),
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

  List<Widget> _group(FeatureStatus status, List<Feature> items) {
    if (items.isEmpty) return const [];
    final activeRuns = ref.watch(implActiveRunsProvider);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Row(
          children: [
            StatusChip(label: status.label, color: status.color, dense: true),
            const SizedBox(width: 8),
            Text('${items.length}',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          ],
        ),
      ),
      ...items.map((f) => _FeatureTile(
            feature: f,
            runPhase: activeRuns[f.id],
            onSetStatus: (s) => ref
                .read(featureListProvider(project.id).notifier)
                .setStatus(f, s),
            onEdit: () => _editFeature(f),
            onDelete: () => ref
                .read(featureListProvider(project.id).notifier)
                .deleteFeature(f),
            onBuild: () => _buildFeature(f),
          )),
    ];
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
      try {
        final path = await ProjectFileRepository.createCodeRepo(project.name);
        await ProjectFileRepository.writeProjectConfig(
            project.path, {'repoPath': path});
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
      await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ImplementationScreen(
          brief: ImplBrief(
            projectPath: project.path,
            projectName: project.name,
            repoPath: '',
            featureId: feature.id,
            featureTitle: feature.title,
          ),
        ),
      ));
      if (mounted) await _handleBuildResult(feature);
      return;
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
      messenger.showSnackBar(SnackBar(
        content: Text('Scan failed: $e'),
        backgroundColor: const Color(0xFF3F0A0A),
      ));
      return;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close spinner

    final accepted = await showScanReviewSheet(context, proposals);
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
    messenger.showSnackBar(
      SnackBar(content: Text('Imported ${accepted.length} features from scan')),
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
      messenger.showSnackBar(SnackBar(
        content: Text('Check-in failed: $e'),
        backgroundColor: const Color(0xFF3F0A0A),
      ));
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
    for (final nf in proposal.newFeatures.where((f) => f.selected)) {
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
    this.runPhase,
  });

  final Feature feature;
  final ValueChanged<FeatureStatus> onSetStatus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onBuild;

  /// Non-null when a Build with AI run for this feature is live (any phase);
  /// drives the status dot on the board.
  final RunPhase? runPhase;

  @override
  Widget build(BuildContext context) {
    final status = FeatureStatus.fromWire(feature.status);
    final phase = runPhase;
    final hasRun = phase != null && phase != RunPhase.idle;
    return ListTile(
      dense: true,
      // A feature with a live AI build is tappable — clicking it re-opens the
      // build window so you can watch progress, without going through the menu.
      onTap: hasRun ? onBuild : null,
      mouseCursor: hasRun ? SystemMouseCursors.click : null,
      leading: hasRun
          ? _RunDot(phase)
          : Icon(Icons.circle, size: 12, color: status.color),
      title: Row(
        children: [
          Flexible(
            child: Text(feature.title,
                style: const TextStyle(fontSize: 13, color: Color(0xFFE5E5E7))),
          ),
          if (hasRun) ...[
            const SizedBox(width: 8),
            Icon(Icons.open_in_new, size: 12, color: phase.dotColor),
          ],
        ],
      ),
      subtitle: _subtitle(),
      trailing: PopupMenuButton<_TileAction>(
        icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF8A8A8E)),
        onSelected: (a) {
          switch (a.kind) {
            case _ActionKind.setStatus:
              onSetStatus(a.status!);
            case _ActionKind.build:
              onBuild();
            case _ActionKind.edit:
              onEdit();
            case _ActionKind.delete:
              onDelete();
          }
        },
        itemBuilder: (_) => [
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
        ],
      ),
    );
  }

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

enum _ActionKind { setStatus, build, edit, delete }

class _TileAction {
  const _TileAction(this.kind, [this.status]);
  final _ActionKind kind;
  final FeatureStatus? status;

  static _TileAction move(FeatureStatus s) =>
      _TileAction(_ActionKind.setStatus, s);
  static const _TileAction build_ = _TileAction(_ActionKind.build);
  static const _TileAction edit_ = _TileAction(_ActionKind.edit);
  static const _TileAction delete_ = _TileAction(_ActionKind.delete);
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
