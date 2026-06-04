import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../../artifacts/artifact_viewer_screen.dart';
import '../../interview/providers/interview_providers.dart';
import '../providers/providers.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeProjectProvider);
    final isBuild = project.mode == 'build';
    final modeLabel = isBuild ? 'BUILD INTERVIEW' : 'AUDIT INTERVIEW';
    final modeColor = isBuild
        ? const Color(0xFFE8A04C)
        : const Color(0xFF94A3B8);
    final modeBackground = isBuild
        ? const Color(0x33E8A04C)
        : const Color(0x3364748B);
    final ctaLabel = isBuild ? 'Start Build Interview' : 'Start Audit Interview';

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () {
              ref.read(activeProjectProvider.notifier).close();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: modeBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              modeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                fontFamily: 'Menlo',
                color: modeColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Phase: ${project.phase}',
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Menlo',
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader('Project State'),
          if (active.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _ReadmeContent(raw: active.readmeContent),
          const SizedBox(height: 24),
          const _SectionHeader('Interview'),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: () {
                final mode = ProjectMode.values.firstWhere(
                  (m) => m.name == project.mode,
                  orElse: () => ProjectMode.build,
                );
                Navigator.of(context).pushNamed(
                  '/interview',
                  arguments: InterviewArgs(
                    path: project.path,
                    name: project.name,
                    mode: mode,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE8A04C),
                foregroundColor: const Color(0xFF0F0F10),
              ),
              child: Text(
                ctaLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Menlo',
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader('Artifacts'),
          _ArtifactsList(projectPath: project.path),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

class _ReadmeContent extends StatelessWidget {
  const _ReadmeContent({required this.raw});
  final String? raw;

  @override
  Widget build(BuildContext context) {
    if (raw == null) {
      return const Text(
        '(no README.md found)',
        style: TextStyle(
          fontFamily: 'Menlo',
          fontSize: 13,
          color: Color(0xFF6B7280),
        ),
      );
    }

    final done = _extractSection(raw!, '## What\'s Done');
    final next = _extractSection(raw!, '## What\'s Next');
    final flags = _extractSection(raw!, '## Open Flags');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F10),
        border: Border.all(color: const Color(0xFF2C2C2E)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (done != null) ...[
            const Text(
              "What's Done",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5E5E7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              done,
              style: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (next != null) ...[
            const Text(
              "What's Next",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5E5E7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              next,
              style: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (flags != null) ...[
            const Text(
              'Open Flags',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5E5E7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              flags,
              style: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _extractSection(String content, String header) {
    final startIdx = content.indexOf(header);
    if (startIdx < 0) return null;
    final afterHeader = startIdx + header.length;
    final nextHeaderIdx = content.indexOf('\n## ', afterHeader);
    final endIdx = nextHeaderIdx < 0 ? content.length : nextHeaderIdx;
    return content.substring(afterHeader, endIdx).trim();
  }
}

class _ArtifactsList extends StatelessWidget {
  const _ArtifactsList({required this.projectPath});
  final String projectPath;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ArtifactsSnapshot>(
      future: _scan(projectPath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final data = snapshot.data!;
        if (data.isEmpty) {
          return const Text(
            '(No artifacts yet — complete the interview to generate them)',
            style: TextStyle(
              fontFamily: 'Menlo',
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F10),
            border: Border.all(color: const Color(0xFF2C2C2E)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              for (var i = 0; i < data.entries.length; i++) ...[
                _ArtifactRow(
                  entry: data.entries[i],
                  onTap: () => _onArtifactTap(context, data.entries[i]),
                ),
                if (i < data.entries.length - 1)
                  const Divider(height: 1, color: Color(0xFF2C2C2E)),
              ],
            ],
          ),
        );
      },
    );
  }

  void _onArtifactTap(BuildContext context, _ArtifactEntry entry) {
    final mode = switch (entry.folder) {
      'specs' => ArtifactViewMode.spec,
      'handoffs' => ArtifactViewMode.handoff,
      'worksheets' => ArtifactViewMode.worksheet,
      _ => ArtifactViewMode.audit,
    };
    final projectName =
        p.basename(projectPath);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtifactViewerScreen(
          args: ArtifactViewArgs(
            projectPath: projectPath,
            projectName: projectName,
            filename: entry.filename,
            mode: mode,
          ),
        ),
      ),
    );
  }

  Future<_ArtifactsSnapshot> _scan(String projectPath) async {
    final entries = <_ArtifactEntry>[];
    for (final folder in const ['specs', 'handoffs', 'worksheets', 'audit']) {
      final dir = Directory(p.join(projectPath, folder));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync()) {
        if (entity is File) {
          entries.add(_ArtifactEntry(
            folder: folder,
            filename: p.basename(entity.path),
          ));
        }
      }
    }
    return _ArtifactsSnapshot(entries);
  }
}

class _ArtifactsSnapshot {
  final List<_ArtifactEntry> entries;
  const _ArtifactsSnapshot(this.entries);
  bool get isEmpty => entries.isEmpty;
}

class _ArtifactEntry {
  final String folder;
  final String filename;
  const _ArtifactEntry({required this.folder, required this.filename});
}

class _ArtifactRow extends StatelessWidget {
  const _ArtifactRow({required this.entry, this.onTap});
  final _ArtifactEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.description_outlined,
              size: 14,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.filename,
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 12,
                  color: Color(0xFFE5E5E7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              entry.folder,
              style: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 10,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
