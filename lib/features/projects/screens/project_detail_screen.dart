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
        title: _AppBarTitle(
          projectName: live.name,
          projectPath: live.path,
          specVersion: live.specVersion,
        ),
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
                if (_stageOf(live.phase) == 'worksheet_complete')
                  _BuildSequenceSection(project: live),
                const SizedBox(height: 24),
                // Phase-aware CTA
                _SectionHeader(_ctaSectionLabel(live.phase)),
                SizedBox(
                  width: double.infinity,
                  child: _buildCta(context, live, mode, sv),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ctaSectionLabel(String phase) => switch (_stageOf(phase)) {
        'spec_locked' => 'NEXT STEP',
        'worksheet_complete' => 'STATUS',
        _ => 'INTERVIEW',
      };

  Widget _buildCta(
      BuildContext context, Project live, ProjectMode mode, String sv) {
    final stage = _stageOf(live.phase);
    final version = _versionOf(live.phase);

    return switch (stage) {
      'spec_locked' => FilledButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => WorksheetGenerationScreen(
              projectPath: live.path,
              projectName: live.name,
              specVersion: sv,
            ),
          )),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            backgroundColor: const Color(0xFFE8A04C),
            foregroundColor: const Color(0xFF0F0F10),
          ),
          child: const Text(
            'Generate Setup Worksheet →',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontFamily: 'Menlo'),
          ),
        ),
      'worksheet_complete' => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF22C55E)),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF22C55E), size: 14),
                    const SizedBox(width: 8),
                    Text(
                      '${version.toUpperCase()} ready for executor',
                      style: const TextStyle(
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
            if (mode == ProjectMode.build) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InterviewScreen(
                        args: InterviewArgs(
                          path: live.path,
                          name: live.name,
                          mode: ProjectMode.build,
                          priorSpecVersion: version,
                        ),
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE8A04C)),
                    foregroundColor: const Color(0xFFE8A04C),
                  ),
                  child: Text(
                    'Start ${_nextVersion(version).toUpperCase()} Interview →',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Menlo',
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      'interview_active' => FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => InterviewScreen(
                args: InterviewArgs(
                  path: live.path,
                  name: live.name,
                  mode: mode,
                  priorSpecVersion:
                      version != 'v1' ? _previousVersion(version) : null,
                ),
              ),
            ),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            backgroundColor: const Color(0xFFE8A04C),
            foregroundColor: const Color(0xFF0F0F10),
          ),
          child: Text(
            'Continue with ${version.toUpperCase()} Interview →',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontFamily: 'Menlo'),
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
            minimumSize: const Size.fromHeight(44),
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

// ── AppBar title with goal subtitle ──────────────────────────────────────────

class _AppBarTitle extends StatefulWidget {
  const _AppBarTitle({
    required this.projectName,
    required this.projectPath,
    required this.specVersion,
  });
  final String projectName;
  final String projectPath;
  final String? specVersion;

  @override
  State<_AppBarTitle> createState() => _AppBarTitleState();
}

class _AppBarTitleState extends State<_AppBarTitle> {
  String? _goal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sv = widget.specVersion ?? 'v1';
    try {
      final file = File(p.join(
        widget.projectPath, 'specs',
        '${widget.projectName}_LockedSpec_$sv.md',
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.projectName),
        if (_goal != null)
          Text(
            _goal!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'Menlo',
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B7280),
            ),
          ),
      ],
    );
  }
}

// ── Version history lane ──────────────────────────────────────────────────────

typedef _SpecSummary = ({String? goal, List<String> components});

class _VersionHistoryLane extends StatefulWidget {
  const _VersionHistoryLane({
    required this.phase,
    required this.projectPath,
    required this.projectName,
  });
  final String phase;
  final String projectPath;
  final String projectName;

  @override
  State<_VersionHistoryLane> createState() => _VersionHistoryLaneState();
}

class _VersionHistoryLaneState extends State<_VersionHistoryLane> {
  final Map<String, _SpecSummary> _specData = {};

  /// Versions that are fully complete (worksheet_complete for that version).
  List<String> _completedVersions() {
    final version = _versionOf(widget.phase);
    final stage = _stageOf(widget.phase);
    final n = int.tryParse(version.substring(1)) ?? 1;
    // If current stage is worksheet_complete, current version is also done.
    final completedCount = (stage == 'worksheet_complete') ? n : n - 1;
    if (completedCount <= 0) return const [];
    return List.generate(completedCount, (i) => 'v${i + 1}');
  }

  @override
  void initState() {
    super.initState();
    _loadSpecs();
  }

  Future<void> _loadSpecs() async {
    for (final v in _completedVersions()) {
      final summary = await _loadSpec(v);
      if (mounted) setState(() => _specData[v] = summary);
    }
  }

  Future<_SpecSummary> _loadSpec(String version) async {
    try {
      final file = File(p.join(
        widget.projectPath, 'specs',
        '${widget.projectName}_LockedSpec_$version.md',
      ));
      if (!file.existsSync()) return (goal: null, components: <String>[]);
      final content = await file.readAsString();
      return (goal: _parseGoal(content), components: _parseComponents(content));
    } catch (_) {
      return (goal: null, components: <String>[]);
    }
  }

  String? _parseGoal(String spec) {
    final lines = spec.split('\n');
    bool inSection = false;
    for (final line in lines) {
      if (RegExp(r'##\s+\d*\.?\s*(Immutable )?Goal Statement', caseSensitive: false)
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

  List<String> _parseComponents(String spec) {
    final lines = spec.split('\n');
    bool inSection = false;
    bool pastHeader = false;
    final result = <String>[];
    for (final line in lines) {
      if (RegExp(r'##\s+\d*\.?\s*Component\s+(Map|List)', caseSensitive: false)
          .hasMatch(line)) {
        inSection = true;
        pastHeader = false;
        continue;
      }
      if (inSection) {
        if (line.trim().startsWith('#')) break;
        if (!line.trim().startsWith('|')) continue;
        if (!pastHeader) {
          if (line.contains('---')) pastHeader = true;
          continue;
        }
        final cols = line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        if (cols.isNotEmpty) {
          final name = cols[0].replaceAll(RegExp(r'[`*_]'), '').trim();
          if (name.isNotEmpty) result.add(name);
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final completed = _completedVersions();
    if (completed.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final v in completed) _buildShippedPanel(v),
          // Show "V2 — IN PROGRESS" label only when there are prior completed versions
          // and current version is not itself complete (i.e., v2 spec locked but not yet worksheeted)
          if (_stageOf(widget.phase) != 'worksheet_complete')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${_versionOf(widget.phase).toUpperCase()} — IN PROGRESS',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  fontFamily: 'Menlo',
                  color: Color(0xFFE8A04C),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShippedPanel(String version) {
    final data = _specData[version];
    final components = data?.components ?? [];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A0E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1A3324)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 12),
              const SizedBox(width: 6),
              Text(
                '${version.toUpperCase()} SHIPPED',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  fontFamily: 'Menlo',
                  color: Color(0xFF22C55E),
                ),
              ),
            ],
          ),
          if (components.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                for (final c in components)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2318),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF1A3324)),
                    ),
                    child: Text(
                      c,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'Menlo',
                        color: Color(0xFF4ADE80),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Phase helpers ─────────────────────────────────────────────────────────────

String _versionOf(String phase) {
  final idx = phase.indexOf('_');
  return idx > 0 ? phase.substring(0, idx) : 'v1';
}

String _stageOf(String phase) {
  final idx = phase.indexOf('_');
  return idx > 0 ? phase.substring(idx + 1) : phase;
}

String _nextVersion(String current) {
  if (current.startsWith('v')) {
    final n = int.tryParse(current.substring(1));
    if (n != null) return 'v${n + 1}';
  }
  return 'v2';
}

String _previousVersion(String current) {
  if (current.startsWith('v')) {
    final n = int.tryParse(current.substring(1));
    if (n != null && n > 1) return 'v${n - 1}';
  }
  return 'v1';
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
  // version → component names; loaded for all completed versions
  final Map<String, List<String>> _allComponents = {};

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
    _loadComponents();
  }

  Future<void> _loadComponents() async {
    final pj = widget.project;
    final stage = _stageOf(pj.phase);
    final currentVersion = _versionOf(pj.phase);
    final n = int.tryParse(currentVersion.substring(1)) ?? 1;
    final completedCount = stage == 'worksheet_complete' ? n : n - 1;
    for (int i = 1; i <= completedCount; i++) {
      await _loadVersionComponents(pj, 'v$i');
    }
  }

  Future<void> _loadVersionComponents(Project pj, String version) async {
    try {
      final file = File(p.join(
          pj.path, 'specs', '${pj.name}_LockedSpec_$version.md'));
      if (!file.existsSync()) return;
      final content = await file.readAsString();
      final result = <String>[];
      final lines = content.split('\n');
      bool inSection = false;
      bool pastHeader = false;
      for (final line in lines) {
        if (RegExp(r'##\s+\d*\.?\s*Component\s+(Map|List)',
                caseSensitive: false)
            .hasMatch(line)) {
          inSection = true;
          pastHeader = false;
          continue;
        }
        if (inSection) {
          if (line.trim().startsWith('#')) break;
          if (!line.trim().startsWith('|')) continue;
          if (!pastHeader) {
            if (line.contains('---')) pastHeader = true;
            continue;
          }
          final cols = line
              .split('|')
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .toList();
          if (cols.isNotEmpty) {
            final name = cols[0].replaceAll(RegExp(r'[`*_]'), '').trim();
            if (name.isNotEmpty) result.add(name);
          }
        }
      }
      if (mounted) setState(() => _allComponents[version] = result);
    } catch (_) {}
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

    final stage = _stageOf(pj.phase);
    final interviewDone = stage != 'interview';
    final worksheetDone = stage == 'worksheet_complete';
    final worksheetCurrent = stage == 'spec_locked';

    final latestVersion = _versionOf(pj.phase);
    final latestN = int.tryParse(latestVersion.substring(1)) ?? 1;
    final priorVersions = worksheetDone
        ? List.generate(latestN - 1, (i) => 'v${i + 1}')
        : <String>[];
    final latestChips = _allComponents[latestVersion] ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main timeline row: compact dots + connectors ──────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Interview dot — compact, never widens the row
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (worksheetDone)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _openArtifact(
                            context, 'specs',
                            '${pj.name}_LockedSpec_$sv.md',
                            ArtifactViewMode.spec),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle,
                                color: Color(0xFF22C55E), size: 20),
                            const SizedBox(height: 5),
                            Text(
                              '${latestVersion.toUpperCase()} SHIPPED',
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'Menlo',
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: Color(0xFF22C55E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    _TimelineStep(
                      label: 'Interview',
                      isDone: interviewDone,
                      isCurrent: !interviewDone,
                      pulseOpacity: _pulseOpacity,
                      onTap: interviewDone
                          ? () => _openArtifact(
                              context, 'specs',
                              '${pj.name}_LockedSpec_$sv.md',
                              ArtifactViewMode.spec)
                          : () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => InterviewScreen(
                                  args: InterviewArgs(
                                    path: pj.path,
                                    name: pj.name,
                                    mode: mode,
                                  ),
                                ),
                              )),
                    ),
                    if (mode == ProjectMode.build &&
                        (!interviewDone || _progress != null))
                      _LayerSubRow(
                        progress: _progress,
                        interviewDone: interviewDone,
                        pulseOpacity: _pulseOpacity,
                      ),
                  ],
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
      // ── Below timeline: version detail (worksheetDone, Build mode only) ──
      if (worksheetDone && mode == ProjectMode.build) ...[
        // Latest version component chips
        if (latestChips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 4,
              runSpacing: 3,
              children: [
                for (final c in latestChips)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2318),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF1A3324)),
                    ),
                    child: Text(c,
                        style: const TextStyle(
                          fontSize: 9,
                          fontFamily: 'Menlo',
                          color: Color(0xFF4ADE80),
                        )),
                  ),
              ],
            ),
          ),
        // Prior versions: collapsed pills (only shown when v2+)
        if (priorVersions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final v in priorVersions) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1A0E),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF1A3324)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle,
                            color: Color(0xFF22C55E), size: 9),
                        const SizedBox(width: 3),
                        Text(v.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontFamily: 'Menlo',
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF22C55E),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        // "Interview" label + L1–L4 on the same row
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Interview',
                style: TextStyle(
                  fontSize: 9,
                  fontFamily: 'Menlo',
                  letterSpacing: 0.3,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(width: 8),
              _LayerSubRow(
                progress: _progress,
                interviewDone: true,
                pulseOpacity: _pulseOpacity,
              ),
            ],
          ),
        ),
      ],
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
