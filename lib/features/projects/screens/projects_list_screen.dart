import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local_db/forge_database.dart';
import '../providers/providers.dart';

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
                  'Choose a folder under\n'
                  '~/Documents/The Forge Projects\n'
                  'and tap + to create a new project.',
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
              builder: (_) => const _NewProjectStub(),
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
              builder: (_) => const _ProjectDetailStub(),
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

class _ProjectDetailStub extends ConsumerWidget {
  const _ProjectDetailStub();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeProjectProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(active.projectName ?? 'Project'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close project',
            onPressed: () {
              ref.read(activeProjectProvider.notifier).close();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: active.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Text(
                  active.readmeContent ?? '(no README.md found)',
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ),
    );
  }
}

class _NewProjectStub extends StatelessWidget {
  const _NewProjectStub();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Project')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Interview flow — coming in §5.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
