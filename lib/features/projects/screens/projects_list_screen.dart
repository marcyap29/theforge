import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../project_actions.dart';
import '../providers/providers.dart';
import 'new_project_screen.dart';
import 'project_detail_screen.dart';

class ProjectsListScreen extends ConsumerStatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  ConsumerState<ProjectsListScreen> createState() =>
      _ProjectsListScreenState();
}

class _ProjectsListScreenState extends ConsumerState<ProjectsListScreen> {
  final Set<String> _selectedIds = {};
  bool _isSelecting = false;

  void _enterSelection(String id) {
    setState(() {
      _isSelecting = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelecting = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected(List<Project> allProjects) async {
    final toDelete =
        allProjects.where((p) => _selectedIds.contains(p.id)).toList();
    if (toDelete.isEmpty) return;

    final n = toDelete.length;
    final confirmed = await confirmDoubleDelete(
      context,
      firstTitle: 'Delete Projects',
      firstMessage:
          'Delete $n project${n == 1 ? '' : 's'}? This removes their folders '
          'and tracked features. This cannot be undone.',
      secondTitle: 'Are you absolutely sure?',
      secondMessage:
          'This permanently deletes $n project${n == 1 ? '' : 's'} and '
          'everything in their folders.',
      finalLabel: 'Delete $n permanently',
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(projectFileRepositoryProvider);
    final db = ref.read(forgeDatabaseProvider);
    for (final project in toDelete) {
      await deleteProjectCascade(repo, db, project);
    }

    if (mounted) {
      _cancelSelection();
      await ref.read(projectListProvider.notifier).refresh();
    }
  }

  Future<void> _deleteOne(Project project) async {
    final confirmed = await confirmDoubleDelete(
      context,
      firstTitle: 'Delete Project',
      firstMessage:
          'Delete "${project.name}"? This removes the project folder and its '
          'tracked features. This cannot be undone.',
      secondTitle: 'Are you absolutely sure?',
      secondMessage:
          'This permanently deletes "${project.name}" and everything in its '
          'folder.',
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(projectFileRepositoryProvider);
    final db = ref.read(forgeDatabaseProvider);
    try {
      await deleteProjectCascade(repo, db, project);
      if (mounted) {
        await ref.read(projectListProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: const Color(0xFF3F0A0A),
          ),
        );
      }
    }
  }

  Future<void> _rename(BuildContext context, Project project) async {
    final controller = TextEditingController(text: project.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Rename Project',
            style: TextStyle(color: Color(0xFFE5E5E7))),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(
              fontFamily: 'Menlo',
              fontSize: 13,
              color: Color(0xFFE5E5E7),
            ),
            decoration: InputDecoration(
              hintText: 'Project name',
              hintStyle: const TextStyle(color: Color(0xFF6B7280)),
              filled: true,
              fillColor: const Color(0xFF0F0F10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE8A04C)),
              ),
            ),
            onSubmitted: (_) => Navigator.pop(ctx, true),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rename',
                style: TextStyle(color: Color(0xFFE8A04C))),
          ),
        ],
      ),
    );
    final newName = controller.text.trim();
    controller.dispose();

    if (confirmed != true || newName.isEmpty || newName == project.name) return;
    if (!context.mounted) return;

    final repo = ref.read(projectFileRepositoryProvider);
    final db = ref.read(forgeDatabaseProvider);
    try {
      final newPath = await repo.renameProject(project.path, newName);
      await db.updateProjectNameAndPath(project.id, newName, newPath);
      if (context.mounted) {
        await ref.read(projectListProvider.notifier).refresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rename failed: $e'),
            backgroundColor: const Color(0xFF3F0A0A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectListProvider);
    final notifier = ref.read(projectListProvider.notifier);
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
                  onPressed: count == 0
                      ? null
                      : () {
                          final projects =
                              projectsAsync.valueOrNull ?? [];
                          _deleteSelected(projects);
                        },
                ),
              ],
            )
          : AppBar(
              title: const Text('The Forge — Projects'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.monitor_heart_outlined),
                  tooltip: 'Watch Mode',
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/watch'),
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Settings',
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/settings'),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: notifier.refresh,
                ),
              ],
            ),
      body: projectsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
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
                  onPressed: () =>
                      ref.invalidate(projectListProvider),
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
              separatorBuilder: (_, __) =>
                  const Divider(height: 1),
              itemBuilder: (context, i) => _ProjectRow(
                project: projects[i],
                isSelecting: _isSelecting,
                isSelected: _selectedIds.contains(projects[i].id),
                onLongPress: () => _enterSelection(projects[i].id),
                onToggleSelection: () =>
                    _toggleSelection(projects[i].id),
                onRename: () => _rename(context, projects[i]),
                onDelete: () => _deleteOne(projects[i]),
              ),
            ),
          );
        },
      ),
      floatingActionButton: _isSelecting
          ? null
          : FloatingActionButton(
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

class _ProjectRow extends ConsumerStatefulWidget {
  const _ProjectRow({
    required this.project,
    required this.isSelecting,
    required this.isSelected,
    required this.onLongPress,
    required this.onToggleSelection,
    required this.onRename,
    required this.onDelete,
  });

  final Project project;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelection;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  ConsumerState<_ProjectRow> createState() => _ProjectRowState();
}

class _ProjectRowState extends ConsumerState<_ProjectRow> {
  String? _goal;

  @override
  void initState() {
    super.initState();
    _loadGoal();
  }

  Future<void> _loadGoal() async {
    final sv = widget.project.specVersion;
    if (sv == null) return;
    try {
      final file = File(p.join(
        widget.project.path, ProjectFileRepository.forgeDirName, 'specs',
        '${widget.project.name}_LockedSpec_$sv.md',
      ));
      if (!file.existsSync()) return;
      final content = await file.readAsString();
      final goal = _parseGoal(content);
      if (mounted && goal != null) setState(() => _goal = goal);
    } catch (_) {}
  }

  String? _parseGoal(String spec) {
    final lines = spec.split('\n');
    bool inSection = false;
    for (final line in lines) {
      if (RegExp(r'##\s+\d*\.?\s*(Immutable )?Goal Statement',
              caseSensitive: false)
          .hasMatch(line)) {
        inSection = true;
        continue;
      }
      if (inSection) {
        final t = line.trim();
        if (t.isEmpty) continue;
        if (t.startsWith('#')) break;
        return t.replaceAll(RegExp(r'^\*+|\*+$'), '').trim();
      }
    }
    return null;
  }

  Future<void> _showContextMenu(
      BuildContext context, Offset globalPosition) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      globalPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    );

    final choice = await showMenu<_RowAction>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(
          value: _RowAction.rename,
          child: Row(children: [
            Icon(Icons.drive_file_rename_outline, size: 18),
            SizedBox(width: 10),
            Text('Rename'),
          ]),
        ),
        const PopupMenuItem(
          value: _RowAction.delete,
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: Color(0xFFFF453A)),
            SizedBox(width: 10),
            Text('Delete', style: TextStyle(color: Color(0xFFFF453A))),
          ]),
        ),
      ],
    );

    if (choice == _RowAction.rename) widget.onRename();
    if (choice == _RowAction.delete) widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final modeLabel = project.mode == 'build' ? 'Build' : 'Audit';
    final lastOpened = project.lastOpened == null
        ? 'never opened'
        : 'last opened ${_formatDate(project.lastOpened!)}';
    final phaseRow = '${project.phase} · $modeLabel · $lastOpened';

    return GestureDetector(
      onSecondaryTapUp: widget.isSelecting
          ? null
          : (details) =>
              _showContextMenu(context, details.globalPosition),
      child: ListTile(
        leading: widget.isSelecting
            ? Checkbox(
                value: widget.isSelected,
                activeColor: const Color(0xFFE8A04C),
                onChanged: (_) => widget.onToggleSelection(),
              )
            : null,
        selected: widget.isSelected,
        selectedTileColor: const Color(0x1AE8A04C),
        title: Text(project.name),
        subtitle: _goal != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _goal!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  Text(phaseRow),
                ],
              )
            : Text(phaseRow),
        trailing: widget.isSelecting ? null : _ModeBadge(mode: modeLabel),
        onLongPress: widget.isSelecting ? null : widget.onLongPress,
        onTap: widget.isSelecting
            ? widget.onToggleSelection
            : () async {
                final repo = ref.read(projectFileRepositoryProvider);
                final db = ref.read(forgeDatabaseProvider);
                final navigator = Navigator.of(context);
                await ref
                    .read(activeProjectProvider.notifier)
                    .open(project.path, repo, db);
                if (context.mounted) {
                  navigator.push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ProjectDetailScreen(project: project),
                    ),
                  );
                }
              },
      ),
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

enum _RowAction { rename, delete }

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    final isBuild = mode == 'Build';
    final bg =
        isBuild ? const Color(0x33E8A04C) : const Color(0x3364748B);

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
