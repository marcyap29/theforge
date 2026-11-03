import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';

class ForgeFilesPanel extends StatefulWidget {
  const ForgeFilesPanel({super.key, required this.project});

  final Project project;

  @override
  State<ForgeFilesPanel> createState() => _ForgeFilesPanelState();
}

class _ForgeFilesPanelState extends State<ForgeFilesPanel> {
  late final String _forgePath;
  late Future<Map<String, List<File>>> _filesFuture;

  static const _sections = [
    ('Specs', 'specs'),
    ('Handoffs', 'handoffs'),
    ('Worksheets', 'worksheets'),
    ('Ingested Docs', 'ingested'),
    ('Audit', 'audit'),
  ];

  @override
  void initState() {
    super.initState();
    _forgePath =
        p.join(widget.project.path, ProjectFileRepository.forgeDirName);
    _filesFuture = _loadFiles();
  }

  void _refresh() => setState(() { _filesFuture = _loadFiles(); });

  Future<Map<String, List<File>>> _loadFiles() async {
    final result = <String, List<File>>{};
    for (final (label, subdir) in _sections) {
      final dir = Directory(p.join(_forgePath, subdir));
      final files = <File>[];
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File && !p.basename(entity.path).startsWith('.')) {
            files.add(entity);
          }
        }
        files.sort(
            (a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
      }
      result[label] = files;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.folder_special_outlined, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Forge Files',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Refresh',
                  onPressed: _refresh,
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  tooltip: 'Reveal in Finder',
                  onPressed: () => Process.run('open', [_forgePath]),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<Map<String, List<File>>>(
              future: _filesFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  children: snapshot.data!.entries.map((entry) {
                    final files = entry.value;
                    return ExpansionTile(
                      leading:
                          Icon(_sectionIcon(entry.key), size: 18),
                      title: Text(entry.key,
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        files.isEmpty
                            ? 'empty'
                            : '${files.length} file${files.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      initiallyExpanded: files.isNotEmpty,
                      children: files.isEmpty
                          ? [
                              const ListTile(
                                dense: true,
                                title: Text(
                                  'No files yet',
                                  style: TextStyle(
                                    color: Color(0xFF8A8A8E),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ]
                          : files
                              .map(
                                (f) => ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.description_outlined,
                                    size: 16,
                                  ),
                                  title: Text(
                                    p.basename(f.path),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  onTap: () => _openFileInApp(context, f),
                                  onLongPress: () =>
                                      _showFileMenu(context, f),
                                ),
                              )
                              .toList(),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Opens a file's contents in a full-height in-app reader sheet.
  Future<void> _openFileInApp(BuildContext context, File f) async {
    String content;
    try {
      content = await f.readAsString();
    } catch (e) {
      content = '(Could not read file: $e)';
    }
    if (!context.mounted) return;

    final fileName = p.basename(f.path);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Container(
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
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined,
                        size: 16, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE5E5E7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      tooltip: 'Open in Finder',
                      onPressed: () => Process.run('open', [f.path]),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2C2C2E)),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    content,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      fontFamily: 'Menlo',
                      color: Color(0xFFD1D5DB),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Long-press context menu for a file — currently just "Set as example".
  void _showFileMenu(BuildContext context, File f) {
    final baseName = p.basenameWithoutExtension(f.path).toLowerCase();
    // Infer example key from filename: "build_brief_example" → "build_brief"
    final key = baseName
        .replaceAll(RegExp(r'[_\-]?(example|sample|template)$'), '')
        .trim()
        .replaceAll(' ', '_');
    final displayKey = key.isEmpty ? p.basenameWithoutExtension(f.path) : key;

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                p.basename(f.path),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFCFCFD2)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.star_outline, size: 18),
              title: const Text('Set as example'),
              subtitle: Text(
                'Saves as Forge/examples/$displayKey — Inspector uses this '
                'as the quality benchmark.',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await ProjectFileRepository.setAsExample(
                      f.path, widget.project.path, displayKey);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'Saved as example: $displayKey'),
                      duration: const Duration(seconds: 2),
                    ));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Failed to save example: $e'),
                      backgroundColor: const Color(0xFFEF4444),
                    ));
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _sectionIcon(String label) => switch (label) {
        'Specs' => Icons.article_outlined,
        'Handoffs' => Icons.handshake_outlined,
        'Worksheets' => Icons.assignment_outlined,
        'Ingested Docs' => Icons.upload_file_outlined,
        'Audit' => Icons.history_outlined,
        _ => Icons.folder_outlined,
      };
}
