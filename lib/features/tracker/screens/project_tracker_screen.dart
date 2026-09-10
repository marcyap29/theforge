import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../checkin/checkin_review_dialog.dart';
import '../checkin/checkin_service.dart';
import '../models/tracker_enums.dart';
import '../providers/tracker_providers.dart';
import '../scan/feature_scan.dart';
import '../widgets/feature_edit_dialog.dart';
import '../widgets/scan_review_sheet.dart';
import '../widgets/status_chip.dart';

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
            onSetStatus: (s) => ref
                .read(featureListProvider(project.id).notifier)
                .setStatus(f, s),
            onEdit: () => _editFeature(f),
            onDelete: () => ref
                .read(featureListProvider(project.id).notifier)
                .deleteFeature(f),
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
  });

  final Feature feature;
  final ValueChanged<FeatureStatus> onSetStatus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = FeatureStatus.fromWire(feature.status);
    return ListTile(
      dense: true,
      leading: Icon(Icons.circle, size: 12, color: status.color),
      title: Text(feature.title,
          style: const TextStyle(fontSize: 13, color: Color(0xFFE5E5E7))),
      subtitle: _subtitle(),
      trailing: PopupMenuButton<_TileAction>(
        icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF8A8A8E)),
        onSelected: (a) {
          switch (a.kind) {
            case _ActionKind.setStatus:
              onSetStatus(a.status!);
            case _ActionKind.edit:
              onEdit();
            case _ActionKind.delete:
              onDelete();
          }
        },
        itemBuilder: (_) => [
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

enum _ActionKind { setStatus, edit, delete }

class _TileAction {
  const _TileAction(this.kind, [this.status]);
  final _ActionKind kind;
  final FeatureStatus? status;

  static _TileAction move(FeatureStatus s) =>
      _TileAction(_ActionKind.setStatus, s);
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
