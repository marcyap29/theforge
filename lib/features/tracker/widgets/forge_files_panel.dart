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
  late final Future<Map<String, List<File>>> _filesFuture;

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
                  icon: const Icon(Icons.open_in_new, size: 18),
                  tooltip: 'Reveal in Finder',
                  onPressed: () => Process.run('open', [_forgePath]),
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
                                  onTap: () =>
                                      Process.run('open', [f.path]),
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

  IconData _sectionIcon(String label) => switch (label) {
        'Specs' => Icons.article_outlined,
        'Handoffs' => Icons.handshake_outlined,
        'Worksheets' => Icons.assignment_outlined,
        'Ingested Docs' => Icons.upload_file_outlined,
        'Audit' => Icons.history_outlined,
        _ => Icons.folder_outlined,
      };
}
