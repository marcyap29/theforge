import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/app.dart';
import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../../artifacts/artifact_viewer_screen.dart';
import '../../interview/providers/interview_providers.dart';
import '../../interview/ui/interview_screen.dart';
import '../../spec_generation/executor_timeline_notifier.dart';
import '../../spec_generation/worksheet_generation_screen.dart';
import '../ingestion/ingestion_notifier.dart';
import '../ingestion/reference_docs_screen.dart';
import '../providers/providers.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch project list to get live phase/specVersion after generation
    final projects = ref.watch(projectListProvider).valueOrNull ?? [];
    final live = projects.firstWhere(
      (p) => p.id == project.id,
      orElse: () => project,
    );

    final active = ref.watch(activeProjectProvider);
    final isBuild = live.mode == 'build';
    final sv = live.specVersion ?? 'v1';
    final mode = ProjectMode.values.firstWhere(
      (m) => m.name == live.mode,
      orElse: () => ProjectMode.build,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Projects',
          onPressed: () {
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop();
            } else {
              nav.pushReplacementNamed('/');
            }
            ref.read(activeProjectProvider.notifier).close();
          },
        ),
        title: Text(live.name),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilesSidebar(projectPath: live.path),
          Container(width: 1, color: const Color(0xFF2C2C2E)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Mode badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isBuild
                        ? const Color(0x33E8A04C)
                        : const Color(0x3364748B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isBuild ? 'BUILD INTERVIEW' : 'AUDIT INTERVIEW',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      fontFamily: 'Menlo',
                      color: isBuild
                          ? const Color(0xFFE8A04C)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Phase timeline
                _PhaseTimeline(project: live),
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
                const _SectionHeader('Reference Documents'),
                _ReferenceDocsRow(projectPath: project.path),
                if (live.phase == 'v1_worksheet_complete')
                  _BuildSequenceSection(project: live),
                const SizedBox(height: 24),
                // Phase-aware CTA
                _SectionHeader(_ctaSectionLabel(live.phase)),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: _buildCta(context, live, mode, sv),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ctaSectionLabel(String phase) => switch (phase) {
        'v1_spec_locked' => 'NEXT STEP',
        'v1_worksheet_complete' => 'STATUS',
        _ => 'INTERVIEW',
      };

  Widget _buildCta(
      BuildContext context, Project live, ProjectMode mode, String sv) {
    return switch (live.phase) {
      'v1_spec_locked' => FilledButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => WorksheetGenerationScreen(
              projectPath: live.path,
              projectName: live.name,
              specVersion: sv,
            ),
          )),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE8A04C),
            foregroundColor: const Color(0xFF0F0F10),
          ),
          child: const Text(
            'Generate Setup Worksheet →',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontFamily: 'Menlo'),
          ),
        ),
      'v1_worksheet_complete' => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF22C55E)),
          ),
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle,
                    color: Color(0xFF22C55E), size: 14),
                SizedBox(width: 8),
                Text(
                  'Ready for executor',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Menlo',
                    color: Color(0xFF22C55E),
                  ),
                ),
              ],
            ),
          ),
        ),
      _ => FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => InterviewScreen(
                args: InterviewArgs(
                  path: live.path,
                  name: live.name,
                  mode: mode,
                ),
              ),
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE8A04C),
            foregroundColor: const Color(0xFF0F0F10),
          ),
          child: Text(
            mode == ProjectMode.build
                ? 'Start Build Interview'
                : 'Start Audit Interview',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontFamily: 'Menlo'),
          ),
        ),
    };
  }
}

// ── Phase Timeline ────────────────────────────────────────────────────────────

class _PhaseTimeline extends StatefulWidget {
  const _PhaseTimeline({required this.project});
  final Project project;

  @override
  State<_PhaseTimeline> createState() => _PhaseTimelineState();
}

class _PhaseTimelineState extends State<_PhaseTimeline>
    with SingleTickerProviderStateMixin, RouteAware {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseOpacity;
  Map<String, dynamic>? _progress;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseOpacity = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _loadProgress();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() => _loadProgress();

  void _loadProgress() {
    final repo = ProjectFileRepository();
    repo
        .readInterviewProgress(widget.project.path, widget.project.name)
        .then((data) {
      if (mounted) setState(() => _progress = data);
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _openArtifact(
      BuildContext context, String folder, String filename, ArtifactViewMode mode) {
    final file =
        File(p.join(widget.project.path, folder, filename));
    if (!file.existsSync()) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ArtifactViewerScreen(
        args: ArtifactViewArgs(
          projectPath: widget.project.path,
          projectName: widget.project.name,
          filename: filename,
          mode: mode,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pj = widget.project;
    final sv = pj.specVersion ?? 'v1';
    final mode = ProjectMode.values.firstWhere(
      (m) => m.name == pj.mode,
      orElse: () => ProjectMode.build,
    );

    final interviewDone = pj.phase != 'v1_interview';
    final worksheetDone = pj.phase == 'v1_worksheet_complete';
    final worksheetCurrent = pj.phase == 'v1_spec_locked';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 1: Interview → opens locked spec when done
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _TimelineStep(
                label: 'Interview',
                isDone: interviewDone,
                isCurrent: !interviewDone,
                pulseOpacity: _pulseOpacity,
                onTap: interviewDone
                    ? () => _openArtifact(
                        context,
                        'specs',
                        '${pj.name}_LockedSpec_$sv.md',
                        ArtifactViewMode.spec)
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => InterviewScreen(
                              args: InterviewArgs(
                                path: pj.path,
                                name: pj.name,
                                mode: mode,
                              ),
                            ),
                          ),
                        ),
              ),
              if (mode == ProjectMode.build &&
                  (!interviewDone || _progress != null))
                _LayerSubRow(
                  progress: _progress,
                  interviewDone: interviewDone,
                  pulseOpacity: _pulseOpacity,
                ),
            ],
          ),
          Expanded(child: _TimelineConnector(done: interviewDone)),
          // Step 2: Worksheet → opens worksheet when done, generates when current
          _TimelineStep(
            label: 'Worksheet',
            isDone: worksheetDone,
            isCurrent: worksheetCurrent,
            pulseOpacity: _pulseOpacity,
            onTap: worksheetDone
                ? () => _openArtifact(
                    context,
                    'worksheets',
                    '${pj.name}_SetupWorksheet_$sv.md',
                    ArtifactViewMode.worksheet)
                : worksheetCurrent
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => WorksheetGenerationScreen(
                            projectPath: pj.path,
                            projectName: pj.name,
                            specVersion: sv,
                          ),
                        ))
                    : null,
          ),
          Expanded(child: _TimelineConnector(done: worksheetDone)),
          // Step 3: Ready → opens bullet handoff when done
          _TimelineStep(
            label: 'Ready',
            isDone: worksheetDone,
            isCurrent: false,
            pulseOpacity: _pulseOpacity,
            onTap: worksheetDone
                ? () => _openArtifact(
                    context,
                    'handoffs',
                    '${pj.name}_BulletHandoff_${sv}_Interview.md',
                    ArtifactViewMode.handoff)
                : null,
          ),
        ],
      ),
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 19),
      child: Container(
        height: 1.5,
        color: done ? const Color(0xFF22C55E) : const Color(0xFF2C2C2E),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.pulseOpacity,
    this.onTap,
  });

  final String label;
  final bool isDone;
  final bool isCurrent;
  final Animation<double> pulseOpacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget dot;
    Color labelColor;

    if (isDone) {
      dot = const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 20);
      labelColor = const Color(0xFF22C55E);
    } else if (isCurrent) {
      dot = FadeTransition(
        opacity: pulseOpacity,
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE8A04C),
          ),
          child: const Center(
            child: Icon(Icons.circle, color: Color(0xFF0F0F10), size: 8),
          ),
        ),
      );
      labelColor = const Color(0xFFE8A04C);
    } else {
      dot = Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF3D4452), width: 1.5),
        ),
      );
      labelColor = const Color(0xFF4B5563);
    }

    final col = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'Menlo',
            letterSpacing: 0.4,
            fontWeight:
                isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: labelColor,
          ),
        ),
      ],
    );

    if (onTap == null) return col;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: col),
    );
  }
}

class _LayerSubRow extends StatelessWidget {
  const _LayerSubRow({
    required this.progress,
    required this.interviewDone,
    required this.pulseOpacity,
  });

  final Map<String, dynamic>? progress;
  final bool interviewDone;
  final Animation<double> pulseOpacity;

  @override
  Widget build(BuildContext context) {
    const layers = ['L1', 'L2', 'L3', 'L4'];

    final currentLayer = progress?['currentLayer'] as String?;
    final completed = (progress?['completedLayers'] as List<dynamic>?)
            ?.cast<String>() ??
        <String>[];

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < layers.length; i++) ...[
            _LayerDot(
              label: layers[i],
              isDone: interviewDone || completed.contains(layers[i]),
              isCurrent: !interviewDone && currentLayer == layers[i],
              pulseOpacity: pulseOpacity,
            ),
            if (i < layers.length - 1)
              Container(
                width: 12,
                height: 1,
                margin: const EdgeInsets.only(bottom: 10),
                color: (interviewDone || completed.contains(layers[i]))
                    ? const Color(0xFF22C55E)
                    : const Color(0xFF2C2C2E),
              ),
          ],
        ],
      ),
    );
  }
}

class _LayerDot extends StatelessWidget {
  const _LayerDot({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.pulseOpacity,
  });

  final String label;
  final bool isDone;
  final bool isCurrent;
  final Animation<double> pulseOpacity;

  @override
  Widget build(BuildContext context) {
    Widget dot;
    Color labelColor;

    if (isDone) {
      dot = const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 12);
      labelColor = const Color(0xFF22C55E);
    } else if (isCurrent) {
      dot = FadeTransition(
        opacity: pulseOpacity,
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE8A04C),
          ),
        ),
      );
      labelColor = const Color(0xFFE8A04C);
    } else {
      dot = Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF3D4452), width: 1.0),
        ),
      );
      labelColor = const Color(0xFF4B5563);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontFamily: 'Menlo',
            letterSpacing: 0.3,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

// ── Sidebar ──────────────────────────────────────────────────────────────────

typedef _FolderDef = ({String id, String label, IconData icon});

const _folders = <_FolderDef>[
  (id: 'forge', label: 'FORGE', icon: Icons.lock_outline),
  (id: 'specs', label: 'SPECS', icon: Icons.description_outlined),
  (id: 'handoffs', label: 'HANDOFFS', icon: Icons.send_outlined),
  (id: 'worksheets', label: 'WORKSHEETS', icon: Icons.checklist_outlined),
  (id: 'ingested', label: 'INGESTED', icon: Icons.input_outlined),
  (id: 'audit', label: 'AUDIT', icon: Icons.history_outlined),
];

ArtifactViewMode _modeForFolder(String folder) => switch (folder) {
      'forge' => ArtifactViewMode.forge,
      'specs' => ArtifactViewMode.spec,
      'handoffs' => ArtifactViewMode.handoff,
      'worksheets' => ArtifactViewMode.worksheet,
      _ => ArtifactViewMode.audit,
    };

class _FilesSidebar extends StatefulWidget {
  const _FilesSidebar({required this.projectPath});
  final String projectPath;

  @override
  State<_FilesSidebar> createState() => _FilesSidebarState();
}

class _FilesSidebarState extends State<_FilesSidebar> with RouteAware {
  String? _selected;
  Future<Map<String, List<String>>>? _scanFuture;

  @override
  void initState() {
    super.initState();
    _scanFuture = _scan();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    final next = _scan();
    setState(() {
      _scanFuture = next;
    });
  }

  void _open(BuildContext context, String folder, String filename) {
    setState(() => _selected = '$folder/$filename');
    final projectName = p.basename(widget.projectPath);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtifactViewerScreen(
          args: ArtifactViewArgs(
            projectPath: widget.projectPath,
            projectName: projectName,
            filename: filename,
            mode: _modeForFolder(folder),
          ),
        ),
      ),
    );
  }

  Future<Map<String, List<String>>> _scan() async {
    final result = <String, List<String>>{};
    for (final f in _folders) {
      final dir = Directory(p.join(widget.projectPath, f.id));
      if (!dir.existsSync()) continue;
      final files = dir
          .listSync()
          .whereType<File>()
          .map((e) => p.basename(e.path))
          .toList()
        ..sort();
      if (files.isNotEmpty) result[f.id] = files;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Container(
        color: const Color(0xFF141414),
        child: FutureBuilder<Map<String, List<String>>>(
          future: _scanFuture,
          builder: (context, snapshot) {
            final files = snapshot.data ?? {};
            final hasAny = files.values.any((l) => l.isNotEmpty);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 14, 12, 6),
                  child: Text(
                    'FILES',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      fontFamily: 'Menlo',
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                Expanded(
                  child: !hasAny
                      ? const Padding(
                          padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Text(
                            'No files yet.\nComplete the interview to generate them.',
                            style: TextStyle(
                              fontFamily: 'Menlo',
                              fontSize: 11,
                              height: 1.5,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 16),
                          children: [
                            for (final folder in _folders) ...[
                              if (files[folder.id]?.isNotEmpty == true) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 12, 12, 4),
                                  child: Row(
                                    children: [
                                      Icon(folder.icon,
                                          size: 11,
                                          color: const Color(0xFF6B7280)),
                                      const SizedBox(width: 5),
                                      Text(
                                        folder.label,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.6,
                                          fontFamily: 'Menlo',
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                for (final filename in files[folder.id]!)
                                  _FileRow(
                                    filename: filename,
                                    selected: _selected ==
                                        '${folder.id}/$filename',
                                    onTap: () =>
                                        _open(context, folder.id, filename),
                                  ),
                              ],
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.filename,
    required this.selected,
    required this.onTap,
  });

  final String filename;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 5, 12, 5),
          decoration: BoxDecoration(
            color: selected ? const Color(0x1AE8A04C) : Colors.transparent,
            border: selected
                ? const Border(
                    left: BorderSide(color: Color(0xFFE8A04C), width: 2),
                  )
                : null,
          ),
          child: Text(
            filename,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Menlo',
              fontSize: 11,
              color: selected
                  ? const Color(0xFFE8A04C)
                  : const Color(0xFFD1D5DB),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

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

class _ReferenceDocsRow extends ConsumerStatefulWidget {
  const _ReferenceDocsRow({required this.projectPath});
  final String projectPath;

  @override
  ConsumerState<_ReferenceDocsRow> createState() =>
      _ReferenceDocsRowState();
}

class _ReferenceDocsRowState extends ConsumerState<_ReferenceDocsRow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(ingestionNotifierProvider.notifier)
          .loadDocs(widget.projectPath);
    });
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(ingestionNotifierProvider).docs;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReferenceDocsScreen(projectPath: widget.projectPath),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F10),
            border: Border.all(color: const Color(0xFF2C2C2E)),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.upload_file_outlined,
                  size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  docs.isEmpty
                      ? 'No documents added'
                      : '${docs.length} document${docs.length == 1 ? '' : 's'} added',
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 12,
                    color: Color(0xFFE5E5E7),
                  ),
                ),
              ),
              Text(
                docs.isEmpty ? 'Add →' : 'Manage →',
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 10,
                  color: Color(0xFFE8A04C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildSequenceSection extends ConsumerWidget {
  final Project project;

  const _BuildSequenceSection({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(executorTimelineProvider(project.path));
    final sv = project.specVersion ?? 'v1';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F10),
          border: Border.all(color: const Color(0xFF2C2C2E)),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BUILD SEQUENCE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                fontFamily: 'Menlo',
                color: Color(0xFFE8A04C),
              ),
            ),
            const SizedBox(height: 8),
            state.when(
              data: (s) {
                switch (s.status) {
                  case ExecutorTimelineStatus.notGenerated:
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Generate an LLM-narrated build order from your spec.',
                          style: TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref
                              .read(executorTimelineProvider(project.path).notifier)
                              .generate(project.name, sv),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE8A04C),
                            foregroundColor: const Color(0xFF0F0F10),
                          ),
                          child: const Text(
                            'Generate Build Sequence',
                            style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Menlo'),
                          ),
                        ),
                      ],
                    );
                  case ExecutorTimelineStatus.generating:
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFE8A04C),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Generating...',
                              style: TextStyle(
                                fontFamily: 'Menlo',
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  case ExecutorTimelineStatus.done:
                    return Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: Text(
                          s.content ?? '',
                          style: const TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 12,
                            height: 1.5,
                            color: Color(0xFFD1D5DB),
                          ),
                        ),
                      ),
                    );
                  case ExecutorTimelineStatus.error:
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.error ?? 'An unknown error occurred',
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontFamily: 'Menlo',
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref
                              .read(executorTimelineProvider(project.path).notifier)
                              .generate(project.name, sv),
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: Color(0xFFE8A04C), fontFamily: 'Menlo'),
                          ),
                        ),
                      ],
                    );
                }
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFE8A04C),
                  ),
                ),
              ),
              error: (e, s) => Text(
                'Error loading timeline: $e',
                style: const TextStyle(color: Color(0xFFEF4444), fontFamily: 'Menlo', fontSize: 12),
              ),
            ),
          ],
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

    final done = _extractSection(raw!, "## What's Done");
    final next = _extractSection(raw!, "## What's Next");
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
