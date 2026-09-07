import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/providers/providers.dart';
import '../../projects/screens/new_project_screen.dart';
import '../../projects/screens/project_detail_screen.dart';
import '../providers/tracker_providers.dart';
import '../widgets/project_card.dart';
import 'project_tracker_screen.dart';

/// The portfolio dashboard — the app's home. Shows every project as a card with
/// its status and feature roll-up, plus a summary strip and review nudges.
class PortfolioDashboardScreen extends ConsumerWidget {
  const PortfolioDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolioAsync = ref.watch(portfolioProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Forge — Portfolio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'All projects',
            onPressed: () => Navigator.of(context).pushNamed('/projects'),
          ),
          IconButton(
            icon: const Icon(Icons.monitor_heart_outlined),
            tooltip: 'Watch Mode',
            onPressed: () => Navigator.of(context).pushNamed('/watch'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(projectListProvider);
              ref.invalidate(portfolioProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NewProjectScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
      body: portfolioAsync.when(
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
            onRefresh: () async {
              ref.invalidate(projectListProvider);
              ref.invalidate(portfolioProvider);
              await ref.read(portfolioProvider.future);
            },
            child: CustomScrollView(
              slivers: [
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
                              onOpen: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ProjectTrackerScreen(
                                      project: entry.project),
                                ),
                              ),
                              onOpenDetail: () =>
                                  _openDetail(context, ref, entry),
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
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    PortfolioEntry entry,
  ) async {
    final repo = ref.read(projectFileRepositoryProvider);
    final db = ref.read(forgeDatabaseProvider);
    final navigator = Navigator.of(context);
    await ref
        .read(activeProjectProvider.notifier)
        .open(entry.project.path, repo, db);
    if (context.mounted) {
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
