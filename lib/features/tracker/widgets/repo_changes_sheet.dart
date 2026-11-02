import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../data/filesystem/project_file_repository.dart';

enum _ChangeKind { staged, modified, added, deleted, renamed, untracked }

class _FileChange {
  const _FileChange({required this.kind, required this.path, this.renamedTo});
  final _ChangeKind kind;
  final String path;
  final String? renamedTo; // for renames
}

class RepoChangesSheet extends StatefulWidget {
  const RepoChangesSheet({
    super.key,
    required this.projectPath,
    this.repoPath,
  });

  final String projectPath;
  final String? repoPath;

  @override
  State<RepoChangesSheet> createState() => _RepoChangesSheetState();
}

class _RepoChangesSheetState extends State<RepoChangesSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = false;

  // Repo tab state
  List<_FileChange> _repoChanges = [];
  String? _repoError;

  // Forge docs tab state
  List<FileSystemEntity> _recentForgeFiles = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _repoError = null; });
    await Future.wait([_loadRepoChanges(), _loadForgeFiles()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadRepoChanges() async {
    final repo = widget.repoPath;
    if (repo == null || repo.isEmpty) return;
    try {
      final lines = await ProjectFileRepository.gitChangedFiles(repo);
      if (!mounted) return;
      _repoChanges = lines.map(_parseLine).whereType<_FileChange>().toList();
    } catch (e) {
      if (mounted) _repoError = e.toString();
    }
  }

  Future<void> _loadForgeFiles() async {
    final forgeDir = Directory(
        p.join(widget.projectPath, ProjectFileRepository.forgeDirName));
    if (!forgeDir.existsSync()) return;
    final all = <FileSystemEntity>[];
    try {
      await for (final entity in forgeDir.list(recursive: true)) {
        if (entity is File && !p.basename(entity.path).startsWith('.')) {
          all.add(entity);
        }
      }
    } catch (_) {}
    // Sort newest first by modification time
    all.sort((a, b) {
      final sa = (a as File).lastModifiedSync();
      final sb = (b as File).lastModifiedSync();
      return sb.compareTo(sa);
    });
    if (mounted) _recentForgeFiles = all.take(40).toList();
  }

  _FileChange? _parseLine(String line) {
    if (line.length < 4) return null;
    final xy = line.substring(0, 2);
    final rest = line.substring(3);

    if (xy == '??') {
      return _FileChange(kind: _ChangeKind.untracked, path: rest);
    }
    if (xy.startsWith('R') || xy.endsWith('R')) {
      final parts = rest.split(' -> ');
      return _FileChange(
          kind: _ChangeKind.renamed,
          path: parts.first,
          renamedTo: parts.length > 1 ? parts[1] : null);
    }
    if (xy.contains('D')) {
      return _FileChange(kind: _ChangeKind.deleted, path: rest);
    }
    if (xy == 'A ' || xy == 'AM') {
      return _FileChange(kind: _ChangeKind.added, path: rest);
    }
    if (xy.contains('M')) {
      return _FileChange(
          kind: xy[0] == 'M' ? _ChangeKind.staged : _ChangeKind.modified,
          path: rest);
    }
    return _FileChange(kind: _ChangeKind.modified, path: rest);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111113),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3F3F46),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Text(
                      'Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE5E5E7),
                      ),
                    ),
                    const Spacer(),
                    if (_loading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Refresh',
                        onPressed: _refresh,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabs,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Repo'),
                        if (_repoChanges.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _CountBadge(count: _repoChanges.length),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'Forge docs'),
                ],
                labelColor: const Color(0xFFE5E5E7),
                unselectedLabelColor: const Color(0xFF6B7280),
                indicatorColor: const Color(0xFFF59E0B),
                dividerColor: const Color(0xFF2C2C2E),
              ),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _RepoChangesTab(
                      repoPath: widget.repoPath,
                      changes: _repoChanges,
                      error: _repoError,
                      loading: _loading,
                      scrollController: scrollController,
                    ),
                    _ForgeDocsTab(
                      projectPath: widget.projectPath,
                      files: _recentForgeFiles,
                      loading: _loading,
                      scrollController: scrollController,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Repo changes tab ─────────────────────────────────────────────────────────

class _RepoChangesTab extends StatelessWidget {
  const _RepoChangesTab({
    required this.repoPath,
    required this.changes,
    required this.error,
    required this.loading,
    required this.scrollController,
  });

  final String? repoPath;
  final List<_FileChange> changes;
  final String? error;
  final bool loading;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (repoPath == null || repoPath!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No linked repo.\nLink a repo from the tracker to see changes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
        ),
      );
    }
    if (loading) return const SizedBox.shrink();
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $error',
              style: const TextStyle(
                  color: Color(0xFFEF4444), fontSize: 13)),
        ),
      );
    }
    if (changes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 32, color: Color(0xFF22C55E)),
            SizedBox(height: 8),
            Text('Clean — no uncommitted changes',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
          ],
        ),
      );
    }

    // Group by kind
    final groups = <_ChangeKind, List<_FileChange>>{};
    for (final c in changes) {
      groups.putIfAbsent(c.kind, () => []).add(c);
    }

    final kindOrder = [
      _ChangeKind.staged,
      _ChangeKind.added,
      _ChangeKind.modified,
      _ChangeKind.deleted,
      _ChangeKind.renamed,
      _ChangeKind.untracked,
    ];

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (final kind in kindOrder)
          if (groups.containsKey(kind)) ...[
            _GroupHeader(kind: kind, count: groups[kind]!.length),
            const SizedBox(height: 4),
            for (final change in groups[kind]!)
              _ChangeRow(change: change),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.kind, required this.count});

  final _ChangeKind kind;
  final int count;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (kind) {
      _ChangeKind.staged => ('Staged', const Color(0xFF22C55E)),
      _ChangeKind.added => ('Added', const Color(0xFF22C55E)),
      _ChangeKind.modified => ('Modified', const Color(0xFFF59E0B)),
      _ChangeKind.deleted => ('Deleted', const Color(0xFFEF4444)),
      _ChangeKind.renamed => ('Renamed', const Color(0xFF818CF8)),
      _ChangeKind.untracked => ('Untracked', const Color(0xFF9CA3AF)),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          _CountBadge(count: count, color: color),
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});
  final _FileChange change;

  @override
  Widget build(BuildContext context) {
    final color = switch (change.kind) {
      _ChangeKind.staged || _ChangeKind.added => const Color(0xFF22C55E),
      _ChangeKind.modified || _ChangeKind.staged => const Color(0xFFF59E0B),
      _ChangeKind.deleted => const Color(0xFFEF4444),
      _ChangeKind.renamed => const Color(0xFF818CF8),
      _ChangeKind.untracked => const Color(0xFF9CA3AF),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 8, top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          Expanded(
            child: Text(
              change.renamedTo != null
                  ? '${change.path} → ${change.renamedTo}'
                  : change.path,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Menlo',
                color: Color(0xFFD1D5DB),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Forge docs tab ───────────────────────────────────────────────────────────

class _ForgeDocsTab extends StatelessWidget {
  const _ForgeDocsTab({
    required this.projectPath,
    required this.files,
    required this.loading,
    required this.scrollController,
  });

  final String projectPath;
  final List<FileSystemEntity> files;
  final bool loading;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox.shrink();
    if (files.isEmpty) {
      return const Center(
        child: Text('No Forge documents yet.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
      );
    }

    final forgePath = p.join(projectPath, ProjectFileRepository.forgeDirName);

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: files.length,
      separatorBuilder: (_, __) => const Divider(
          height: 1, color: Color(0xFF1C1C1E)),
      itemBuilder: (context, i) {
        final file = files[i] as File;
        final rel = p.relative(file.path, from: forgePath);
        final modified = file.lastModifiedSync();
        final label = _formatTime(modified);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.description_outlined,
                  size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Menlo',
                    color: Color(0xFFD1D5DB),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, this.color});

  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: (color ?? const Color(0xFF9CA3AF)).withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (color ?? const Color(0xFF9CA3AF)).withAlpha(80),
        ),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color ?? const Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}
