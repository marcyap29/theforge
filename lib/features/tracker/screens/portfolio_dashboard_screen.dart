import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/project_actions.dart';
import '../../projects/providers/providers.dart';
import '../../projects/screens/new_project_screen.dart';
import '../../projects/screens/project_detail_screen.dart';
import '../providers/tracker_providers.dart';
import '../widgets/active_model_chip.dart';
import '../widgets/portfolio_digest.dart';
import '../widgets/project_card.dart';
import 'project_tracker_screen.dart';

/// The portfolio dashboard — the app's home. Shows every project as a card with
/// its status and feature roll-up, plus a summary strip and review nudges.
/// Supports right-click and multi-select deletion (with double confirmation).
class PortfolioDashboardScreen extends ConsumerStatefulWidget {
  const PortfolioDashboardScreen({super.key});

  @override
  ConsumerState<PortfolioDashboardScreen> createState() =>
      _PortfolioDashboardScreenState();
}

class _PortfolioDashboardScreenState
    extends ConsumerState<PortfolioDashboardScreen> {
  final Set<String> _selectedIds = {};
  bool _isSelecting = false;

  void _enterSelection(String id) => setState(() {
        _isSelecting = true;
        _selectedIds.add(id);
      });

  void _toggleSelection(String id) => setState(() {
        if (!_selectedIds.remove(id)) _selectedIds.add(id);
        if (_selectedIds.isEmpty) _isSelecting = false;
      });

  void _cancelSelection() => setState(() {
        _isSelecting = false;
        _selectedIds.clear();
      });

  Future<void> _refresh() async {
    ref.invalidate(projectListProvider);
    ref.invalidate(portfolioProvider);
    await ref.read(portfolioProvider.future);
  }

  Future<void> _deleteOne(PortfolioEntry entry) async {
    final confirmed = await confirmDoubleDelete(
      context,
      firstTitle: 'Delete Project',
      firstMessage:
          'Delete "${entry.project.name}"?\n\nFolder to be deleted:\n'
          '${entry.project.path}\n\nThis removes the Forge project folder and '
          'its tracked features. Your linked code repo is NOT touched. This '
          'cannot be undone.',
      secondTitle: 'Are you absolutely sure?',
      secondMessage:
          'Permanently delete "${entry.project.name}" and everything in\n'
          '${entry.project.path}?',
    );
    if (confirmed != true) return;

    final repo = ref.read(projectFileRepositoryProvider);
    final db = ref.read(forgeDatabaseProvider);
    await deleteProjectCascade(repo, db, entry.project);
    await ref.read(projectListProvider.notifier).refresh();
    ref.invalidate(portfolioProvider);
    if (mounted) _cancelSelection();
  }

  Future<void> _deleteSelected(List<PortfolioEntry> entries) async {
    final targets =
        entries.where((e) => _selectedIds.contains(e.project.id)).toList();
    if (targets.isEmpty) return;
    final n = targets.length;
    final paths = targets.map((e) => e.project.path).join('\n');
    final confirmed = await confirmDoubleDelete(
      context,
      firstTitle: 'Delete Projects',
      firstMessage:
          'Delete $n project${n == 1 ? '' : 's'}?\n\nFolders to be deleted:\n'
          '$paths\n\nThis removes their Forge folders and tracked features. '
          'Linked code repos are NOT touched. This cannot be undone.',
      secondTitle: 'Are you absolutely sure?',
      secondMessage:
          'Permanently delete these $n folder${n == 1 ? '' : 's'}?\n\n$paths',
      finalLabel: 'Delete $n permanently',
    );
    if (confirmed != true) return;

    final repo = ref.read(projectFileRepositoryProvider);
    final db = ref.read(forgeDatabaseProvider);
    for (final e in targets) {
      await deleteProjectCascade(repo, db, e.project);
    }
    await ref.read(projectListProvider.notifier).refresh();
    ref.invalidate(portfolioProvider);
    if (mounted) _cancelSelection();
  }

  Future<void> _showContextMenu(
      Offset position, PortfolioEntry entry) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: 'open', child: Text('Open tracker')),
        PopupMenuItem(value: 'select', child: Text('Select')),
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Color(0xFFFF453A))),
        ),
      ],
    );
    if (choice == 'open') {
      _openTracker(entry);
    } else if (choice == 'select') {
      _enterSelection(entry.project.id);
    } else if (choice == 'delete') {
      await _deleteOne(entry);
    }
  }

  void _openTracker(PortfolioEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectTrackerScreen(project: entry.project),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final portfolioAsync = ref.watch(portfolioProvider);
    final entries = portfolioAsync.valueOrNull ?? const <PortfolioEntry>[];
    final count = _selectedIds.length;

    return Scaffold(
      appBar: _isSelecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel selection',
                onPressed: _cancelSelection,
              ),
              title: Text('$count selected'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFFF453A)),
                  tooltip: 'Delete selected',
                  onPressed:
                      count == 0 ? null : () => _deleteSelected(entries),
                ),
              ],
            )
          : null,
      floatingActionButton: _isSelecting
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const NewProjectScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('New Project'),
            ),
      body: Column(
        children: [
          if (!_isSelecting)
            ForgeAppHeader(trailing: [
              const ActiveModelChip(),
              IconButton(
                icon: const Icon(Icons.folder_outlined, size: 18),
                tooltip: 'All projects',
                onPressed: () => Navigator.of(context).pushNamed('/projects'),
              ),
              IconButton(
                icon: const Icon(Icons.monitor_heart_outlined, size: 18),
                tooltip: 'Watch Mode',
                onPressed: () => Navigator.of(context).pushNamed('/watch'),
              ),
              IconButton(
                icon: const Icon(Icons.settings, size: 18),
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).pushNamed('/settings'),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh',
                onPressed: _refresh,
              ),
            ]),
          Expanded(
            child: portfolioAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text('Failed to load portfolio: $e'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(portfolioProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const _EmptyPortfolio();
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 22, 26, 0),
                    child: PortfolioDigestPanel(
                      onCatchUp: _catchMeUp,
                      onOpenProject: _openTracker,
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _SummaryStrip(entries: entries)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.crossAxisExtent;
                      final columns = width ~/ 320 < 1 ? 1 : width ~/ 320;
                      return SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 168,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final entry = entries[i];
                            return ProjectCard(
                              entry: entry,
                              selecting: _isSelecting,
                              selected:
                                  _selectedIds.contains(entry.project.id),
                              onLongPress: () =>
                                  _enterSelection(entry.project.id),
                              onToggleSelect: () =>
                                  _toggleSelection(entry.project.id),
                              onContextMenu: (pos) =>
                                  _showContextMenu(pos, entry),
                              onOpen: () => _openTracker(entry),
                              onOpenDetail: () => _openDetail(entry),
                            );
                          },
                          childCount: entries.length,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
              ),
            ),
          ],
        ),
    );
  }

  Future<void> _catchMeUp() async {
    final digest = ref.read(portfolioDigestProvider).valueOrNull;
    final moved = digest?.moved ?? const [];
    final all = digest?.deltas ?? const [];
    final target = moved.isNotEmpty
        ? moved.first.entry
        : (all.isNotEmpty ? all.first.entry : null);
    await markPortfolioSeen(ref);
    ref.invalidate(portfolioProvider);
    ref.invalidate(portfolioDigestProvider);
    if (target != null && mounted) _openTracker(target);
  }

  Future<void> _openDetail(PortfolioEntry entry) async {
    final repo = ref.read(projectFileRepositoryProvider);
    final db = ref.read(forgeDatabaseProvider);
    final navigator = Navigator.of(context);
    await ref
        .read(activeProjectProvider.notifier)
        .open(entry.project.path, repo, db);
    if (mounted) {
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ProjectDetailScreen(project: entry.project),
        ),
      );
    }
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.entries});
  final List<PortfolioEntry> entries;

  @override
  Widget build(BuildContext context) {
    final projects = entries.length;
    final shipped =
        entries.fold<int>(0, (a, e) => a + e.shippedCount);
    final due = entries.where((e) => e.reviewDue).length;
    final blocked = entries.fold<int>(0, (a, e) => a + e.blockedCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _Stat(label: 'Projects', value: '$projects'),
          _Stat(label: 'Features shipped', value: '$shipped'),
          _Stat(
            label: 'Blocked',
            value: '$blocked',
            color: blocked > 0 ? const Color(0xFFE57373) : null,
          ),
          _Stat(
            label: 'Reviews due',
            value: '$due',
            color: due > 0 ? const Color(0xFFE8A04C) : null,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color ?? const Color(0xFFE5E5E7),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF8A8A8E)),
          ),
        ],
      ),
    );
  }
}

class _EmptyPortfolio extends StatelessWidget {
  const _EmptyPortfolio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dashboard_customize_outlined,
                size: 48, color: Color(0xFF3A3A3C)),
            SizedBox(height: 12),
            Text('No projects yet.',
                style: TextStyle(color: Color(0xFFE5E5E7))),
            SizedBox(height: 4),
            Text(
              'Tap "New Project" to create one, or open "All projects".',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8A8A8E), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
