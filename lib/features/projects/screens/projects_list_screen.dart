import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local_db/forge_database.dart';
import '../providers/providers.dart';
import 'new_project_screen.dart';
import 'project_detail_screen.dart';

class ProjectsListScreen extends ConsumerWidget {
  const ProjectsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider);
    final notifier = ref.read(projectListProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Forge — Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: notifier.refresh,
          ),
        ],
      ),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text('Failed to load projects: $error'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(projectListProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (projects) {
          if (projects.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No projects yet.\n\n'
                  'Tap + to create a new project\n'
                  '(Build interview or Audit interview).',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView.separated(
              itemCount: projects.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _ProjectRow(project: projects[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New Project',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const NewProjectScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ProjectRow extends ConsumerWidget {
  const _ProjectRow({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeLabel = project.mode == 'build' ? 'Build' : 'Audit';
    final lastOpened = project.lastOpened == null
        ? 'never opened'
        : 'last opened ${_formatDate(project.lastOpened!)}';

    return ListTile(
      title: Text(project.name),
      subtitle: Text('${project.phase} · $modeLabel · $lastOpened'),
      trailing: _ModeBadge(mode: modeLabel),
      onTap: () async {
        final repo = ref.read(projectFileRepositoryProvider);
        final db = ref.read(forgeDatabaseProvider);
        final navigator = Navigator.of(context);
        await ref
            .read(activeProjectProvider.notifier)
            .open(project.path, repo, db);
        if (context.mounted) {
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => ProjectDetailScreen(project: project),
            ),
          );
        }
      },
    );
  }

  String _formatDate(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    final isBuild = mode == 'Build';
    final bg = isBuild ? const Color(0x33E8A04C) : const Color(0x3364748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        mode,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'Menlo',
          color: isBuild
              ? const Color(0xFFE8A04C)
              : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
