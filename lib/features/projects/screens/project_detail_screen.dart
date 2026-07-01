import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/app.dart';
import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../../artifacts/artifact_viewer_screen.dart';
import '../../interview/providers/interview_providers.dart';
import '../../interview/ui/interview_screen.dart';
import '../../pull_interview/state/pull_interview_state.dart';
import '../../pull_interview/ui/pull_interview_screen.dart';
import '../../spec_generation/compliance/spec_compliance_screen.dart';
import '../../spec_generation/executor_timeline_notifier.dart';
import '../../spec_generation/worksheet_generation_screen.dart';
import '../ingestion/ingestion_notifier.dart';
import '../ingestion/pull_ingestion_notifier.dart';
import '../ingestion/reference_docs_screen.dart';
import '../models/pull_ingestion_summary.dart' as rev_ingest;
import '../providers/providers.dart';
import 'pull_ingestion_progress_screen.dart';
import 'pull_ingestion_summary_screen.dart';
import '../../addendum_interview/state/addendum_interview_notifier.dart';
import '../../addendum_interview/ui/addendum_interview_screen.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({super.key, required this.project});
  final Project project;
  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  double _sidebarWidth = 220;
  bool _sidebarCollapsed = false;
  double _contextPanelHeight = 200;
  String? _selectedVersion;

  int _bannerIndex = 0;
  Timer? _bannerTimer;

  static const _bannerMessages = [
    'Ready for {next}?',
    'What\'s the next feature?',
    '{next} is up — what are we building?',
    'Time to scope {next}.',
    'Momentum is yours — what\'s next?',
    'What should we work on next?',
  ];

  @override
  void initState() {
    super.initState();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() {
        _bannerIndex = (_bannerIndex + 1) % _bannerMessages.length;
      });
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch project list to get live phase/specVersion after generation
    final projects = ref.watch(projectListProvider).valueOrNull ?? [];
    final live = projects.firstWhere(
      (p) => p.id == widget.project.id,
      orElse: () => widget.project,
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
          // Collapsible sidebar — Files (top) + Context (bottom)
          if (!_sidebarCollapsed)
            SizedBox(
              width: _sidebarWidth,
              child: Column(
                children: [
                  Expanded(
                    child: _FilesSidebar(projectPath: live.path),
                  ),
                  GestureDetector(
                    onVerticalDragUpdate: (details) => setState(() {
                      _contextPanelHeight =
                          (_contextPanelHeight - details.delta.dy)
                              .clamp(80.0, MediaQuery.of(context).size.height - 160.0);
                    }),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeRow,
                      child: Container(
                        height: 8,
                        color: const Color(0xFF1C1C1E),
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 2,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3C3C3E),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: _contextPanelHeight,
                    child: _ContextPanel(
                      projectPath: live.path,
                      projectName: live.name,
                    ),
                  ),
                ],
              ),
            ),
          // Drag-to-resize handle + collapse toggle
          _SidebarDivider(
            collapsed: _sidebarCollapsed,
            onToggle: () => setState(() {
              _sidebarCollapsed = !_sidebarCollapsed;
            }),
            onDrag: (dx) => setState(() {
              _sidebarWidth =
                  (_sidebarWidth + dx).clamp(140.0, 420.0);
            }),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _FixStructureBanner(projectPath: live.path),
                _PhaseTimeline(
                  project: live,
                  selectedVersion: _selectedVersion ?? _versionOf(live.phase),
                  onVersionTap: (v) => setState(() => _selectedVersion = v),
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
                const _SectionHeader('Reference Documents'),
                _ReferenceDocsRow(projectPath: widget.project.path),
                const SizedBox(height: 24),
                if (mode == ProjectMode.pull) ...[
                  _RepoIngestRow(projectPath: widget.project.path, projectName: widget.project.name),
                  const SizedBox(height: 24),
                ],
                _RepoPathRow(projectPath: widget.project.path, projectName: widget.project.name),
                if (_stageOf(live.phase) == 'worksheet_complete') ...[
                  _BuildSequenceSection(project: live),
                  const SizedBox(height: 8),
                  _CopyWorksheetButton(
                    projectPath: live.path,
                    projectName: live.name,
                    specVersion: sv,
                  ),
                ],
                _CoderPackageSection(
                  projectPath: live.path,
                  projectName: live.name,
                  targetVersion: _selectedVersion ?? _versionOf(live.phase),
                ),
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
      'worksheet_complete' => FutureBuilder<_DiskNextInfo>(
          future: _diskNextVersionState(live.path, version),
          builder: (context, snap) {
            // info.nextVersion is the first unstarted/in-progress version,
            // so the latest completed is one step before it.
            final info = snap.data;
            final latestCompletedV = info != null
                ? _previousVersion(info.nextVersion)
                : version;
            Widget? actionButton;
            if (mode == ProjectMode.build &&
                snap.connectionState != ConnectionState.waiting &&
                info != null) {
              if (info.state == _DiskNextState.specLocked) {
                actionButton = SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => WorksheetGenerationScreen(
                        projectPath: live.path,
                        projectName: live.name,
                        specVersion: info.nextVersion,
                      ),
                    )),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: const Color(0xFFE8A04C),
                      foregroundColor: const Color(0xFF0F0F10),
                    ),
                    child: Text(
                      'Generate ${info.nextVersion.toUpperCase()} Setup Worksheet →',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontFamily: 'Menlo'),
                    ),
                  ),
                );
              } else {
                final priorV = _previousVersion(info.nextVersion);
                actionButton = SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SpecComplianceScreen(
                        projectPath: live.path,
                        projectName: live.name,
                        priorSpecVersion: priorV,
                        nextVersion: info.nextVersion,
                        mode: mode,
                      ),
                    )),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE8A04C)),
                      foregroundColor: const Color(0xFFE8A04C),
                    ),
                    child: Text(
                      'Start ${info.nextVersion.toUpperCase()} Interview →',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Menlo',
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }
            }
            return FutureBuilder<List<String>>(
              future: ProjectFileRepository.readValidatedVersions(live.path),
              builder: (context, validSnap) {
                final validatedVersions = validSnap.data ?? [];
                final isValidated =
                    validatedVersions.contains(latestCompletedV);

                final badge = Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isValidated
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFE8A04C),
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isValidated
                              ? Icons.check_circle
                              : Icons.schedule,
                          color: isValidated
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFE8A04C),
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isValidated
                              ? '${latestCompletedV.toUpperCase()} validated ✓'
                              : '${latestCompletedV.toUpperCase()} awaiting validation',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Menlo',
                            color: isValidated
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFE8A04C),
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                if (!isValidated) {
                  return badge;
                }

                final bannerText = _bannerMessages[_bannerIndex]
                    .replaceAll('{next}', info!.nextVersion.toUpperCase());

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    badge,
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2C2C2E)),
                      ),
                      child: Text(
                        bannerText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    if (actionButton != null) ...[
                      const SizedBox(height: 10),
                      actionButton,
                    ],
                  ],
                );
              },
            );
          },
        ),
       'interview_active' => mode == ProjectMode.pull
            ? _ReverseModeCta(projectPath: live.path, projectName: live.name)
           : FilledButton(
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
        'as_built' => FilledButton(
            onPressed: () {/* view as-built spec — artifact viewer */},
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: const Color(0xFF0F0F10),
            ),
            child: const Text(
              'View As-Built Spec →',
              style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Menlo'),
            ),
          ),
        _ => mode == ProjectMode.pull
            ? _ReverseModeCta(projectPath: live.path, projectName: live.name)
           : FilledButton(
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
      // Check versioned subfolder first, fall back to flat for older projects.
      File file = File(p.join(widget.projectPath, 'specs', sv,
          '${widget.projectName}_LockedSpec_$sv.md'));
      if (!file.existsSync()) {
        file = File(p.join(
            widget.projectPath, 'specs', '${widget.projectName}_LockedSpec_$sv.md'));
      }
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
      File file = File(p.join(
          widget.projectPath, 'specs', version,
          '${widget.projectName}_LockedSpec_$version.md'));
      if (!file.existsSync()) {
        file = File(p.join(widget.projectPath, 'specs',
            '${widget.projectName}_LockedSpec_$version.md'));
      }
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

/// Scans specs/ for any *_LockedSpec_{version}.md file — works even when the
/// project display name differs from the original folder/file prefix (rename case).
File? _findSpecFile(String projectPath, String version) {
  final suffix = '_LockedSpec_$version.md';
  final nestedDir = Directory(p.join(projectPath, 'specs', version));
  if (nestedDir.existsSync()) {
    final hit = nestedDir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).endsWith(suffix))
        .firstOrNull;
    if (hit != null) return hit;
  }
  final flatDir = Directory(p.join(projectPath, 'specs'));
  if (flatDir.existsSync()) {
    final hit = flatDir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).endsWith(suffix))
        .firstOrNull;
    if (hit != null) return hit;
  }
  if (nestedDir.existsSync()) {
    return nestedDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .firstOrNull;
  }
  return null;
}

bool _specFileExistsOnDisk(String projectPath, String version) =>
    _findSpecFile(projectPath, version) != null;

/// Like _findSpecFile but for setup worksheets (*_SetupWorksheet_{version}.md).
File? _findWorksheetFile(String projectPath, String version) {
  final suffix = '_SetupWorksheet_$version.md';
  final nestedDir = Directory(p.join(projectPath, 'worksheets', version));
  if (nestedDir.existsSync()) {
    final hit = nestedDir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).endsWith(suffix))
        .firstOrNull;
    if (hit != null) return hit;
  }
  final flatDir = Directory(p.join(projectPath, 'worksheets'));
  if (flatDir.existsSync()) {
    return flatDir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).endsWith(suffix))
        .firstOrNull;
  }
  return null;
}

bool _worksheetFileExistsOnDisk(String projectPath, String version) =>
    _findWorksheetFile(projectPath, version) != null;

bool _handoffDirHasFiles(String projectPath, String version) {
  final dir = Directory(p.join(projectPath, 'handoffs', version));
  if (!dir.existsSync()) return false;
  return dir.listSync().whereType<File>().any(
      (f) => f.path.endsWith('.md'));
}

enum _DiskNextState { none, specLocked }

/// Record returned by _diskNextVersionState: the state and the version it applies to.
typedef _DiskNextInfo = ({_DiskNextState state, String nextVersion});

/// Scans forward from [currentVersion], skipping versions that are fully done
/// (spec + worksheet on disk), until it finds the first gap. Returns:
///   state=none      → nextVersion has no spec yet  (show "Start V{n} Interview")
///   state=specLocked → nextVersion has spec but no worksheet (show "Generate Worksheet")
Future<_DiskNextInfo> _diskNextVersionState(
    String projectPath, String currentVersion) async {
  String v = currentVersion;
  while (true) {
    final nextV = _nextVersion(v);
    if (!_specFileExistsOnDisk(projectPath, nextV)) {
      return (state: _DiskNextState.none, nextVersion: nextV);
    }
    if (!_worksheetFileExistsOnDisk(projectPath, nextV)) {
      return (state: _DiskNextState.specLocked, nextVersion: nextV);
    }
    // nextV is fully shipped — advance one more
    v = nextV;
  }
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
  const _PhaseTimeline({
    required this.project,
    required this.selectedVersion,
    required this.onVersionTap,
  });
  final Project project;
  final String selectedVersion;
  final void Function(String version) onVersionTap;

  @override
  State<_PhaseTimeline> createState() => _PhaseTimelineState();
}

class _PhaseTimelineState extends State<_PhaseTimeline>
    with SingleTickerProviderStateMixin, RouteAware {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseOpacity;
  Map<String, dynamic>? _progress;
  final Map<String, List<String>> _allComponents = {};
  final Map<String, String?> _versionGoals = {};
  // true = expanded; shipped versions default false, active version defaults true
  final Map<String, bool> _expanded = {};
  // disk-discovered max version (may exceed DB-declared phase when DB drifts)
  int _diskLatestN = 1;
  // stage ('spec_locked' | 'worksheet_complete') for disk-extra versions
  final Map<String, String> _diskExtraStages = {};
  final Set<String> _validatedVersions = {};

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
    _loadValidatedVersions();
  }

  Future<void> _loadComponents() async {
    final pj = widget.project;
    final stage = _stageOf(pj.phase);
    final currentVersion = _versionOf(pj.phase);
    int n = int.tryParse(currentVersion.substring(1)) ?? 1;
    // Load all versions that have a locked spec (prior completed + current if spec exists).
    for (int i = 1; i <= n; i++) {
      await _loadVersionComponents(pj, 'v$i');
    }
    // Scan beyond DB-declared n: if a spec exists for v{n+1}, the DB phase drifted.
    // Track each extra version's actual disk stage (spec_locked vs worksheet_complete).
    final extraStages = <String, String>{};
    while (true) {
      final vNext = 'v${n + 1}';
      if (!_specFileExistsOnDisk(pj.path, vNext)) break;
      await _loadVersionComponents(pj, vNext);
      extraStages[vNext] =
          (_worksheetFileExistsOnDisk(pj.path, vNext) ||
                  _handoffDirHasFiles(pj.path, vNext))
              ? 'worksheet_complete'
              : 'spec_locked';
      n++;
    }
    // Default expansion: active version expanded, shipped ones collapsed.
    if (mounted) {
      setState(() {
        _diskLatestN = n;
        _diskExtraStages.addAll(extraStages);
        for (int i = 1; i <= n; i++) {
          final v = 'v$i';
          if (!_expanded.containsKey(v)) {
            _expanded[v] = (v == currentVersion) && (stage != 'worksheet_complete' || n == 1);
          }
        }
      });
    }
  }

  Future<void> _loadVersionComponents(Project pj, String version) async {
    try {
      // Find spec by suffix in case the project was renamed after creation.
      final File? file = _findSpecFile(pj.path, version);
      if (file == null) return;
      final content = await file.readAsString();
      final result = <String>[];
      final lines = content.split('\n');

      // Extract goal
      bool inGoal = false;
      String? goal;
      for (final line in lines) {
        if (RegExp(r'##\s+\d*\.?\s*(Immutable )?Goal Statement', caseSensitive: false).hasMatch(line)) {
          inGoal = true;
          continue;
        }
        if (inGoal) {
          final t = line.trim();
          if (t.isEmpty) continue;
          if (t.startsWith('#')) break;
          goal = t.replaceAll(RegExp(r'^\*+|\*+$'), '').trim();
          break;
        }
      }

      // Extract components
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
      if (mounted) setState(() {
        _allComponents[version] = result;
        _versionGoals[version] = goal;
      });
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
  void didPopNext() {
    _loadProgress();
    _loadComponents();
    _loadValidatedVersions();
  }

  void _loadProgress() {
    final repo = ProjectFileRepository();
    repo
        .readInterviewProgress(widget.project.path, widget.project.name)
        .then((data) {
      if (mounted) setState(() => _progress = data);
    });
  }

  Future<void> _loadValidatedVersions() async {
    final validated =
        await ProjectFileRepository.readValidatedVersions(widget.project.path);
    if (mounted) {
      setState(() {
        _validatedVersions
          ..clear()
          ..addAll(validated);
      });
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _openArtifact(
      BuildContext context, String folder, String filename, ArtifactViewMode mode,
      {String? specVersion}) {
    final file = specVersion != null
        ? File(p.join(widget.project.path, folder, specVersion, filename))
        : File(p.join(widget.project.path, folder, filename));
    // Fall back to flat path for existing projects.
    final resolvedFile = file.existsSync()
        ? file
        : File(p.join(widget.project.path, folder, filename));
    if (!resolvedFile.existsSync()) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ArtifactViewerScreen(
        args: ArtifactViewArgs(
          projectPath: widget.project.path,
          projectName: widget.project.name,
          filename: filename,
          mode: mode,
          specVersion: specVersion,
        ),
      ),
    ));
  }

  Widget _buildChips(List<String> chips) {
    return Wrap(
      spacing: 4,
      runSpacing: 3,
      children: [
        for (final c in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0F2318),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF1A3324)),
            ),
            child: Text(c,
                style: const TextStyle(
                    fontSize: 9, fontFamily: 'Menlo', color: Color(0xFF4ADE80))),
          ),
      ],
    );
  }

  Widget _buildTimelineRow(BuildContext context, Project pj, String sv,
      ProjectMode mode, String stage) {
    final interviewDone = stage != 'interview';
    final worksheetDone = stage == 'worksheet_complete';
    final worksheetCurrent = stage == 'spec_locked';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  ? () => _openArtifact(context, 'specs',
                      '${pj.name}_LockedSpec_$sv.md', ArtifactViewMode.spec,
                      specVersion: sv)
                  : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => InterviewScreen(
                          args: InterviewArgs(
                            path: pj.path,
                            name: pj.name,
                            mode: mode,
                            priorSpecVersion: sv != 'v1' ? _previousVersion(sv) : null,
                          ),
                        ),
                      )),
            ),
            if (mode == ProjectMode.build)
              _LayerSubRow(
                progress: _progress,
                interviewDone: interviewDone,
                pulseOpacity: _pulseOpacity,
              ),
          ],
        ),
        Expanded(child: _TimelineConnector(done: interviewDone)),
        _TimelineStep(
          label: 'Worksheet',
          isDone: worksheetDone,
          isCurrent: worksheetCurrent,
          pulseOpacity: _pulseOpacity,
          onTap: worksheetDone
              ? () => _openArtifact(context, 'worksheets',
                  '${pj.name}_SetupWorksheet_$sv.md', ArtifactViewMode.worksheet,
                  specVersion: sv)
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
        _TimelineStep(
          label: 'Ready',
          isDone: worksheetDone,
          isCurrent: false,
          pulseOpacity: _pulseOpacity,
          onTap: worksheetDone
              ? () => _openArtifact(context, 'handoffs',
                  '${pj.name}_BulletHandoff_${sv}_Interview.md',
                  ArtifactViewMode.handoff,
                  specVersion: sv)
              : null,
        ),
      ],
    );
  }

  Widget _buildVersionPanel(
    BuildContext context, {
    required String version,
    required bool isShipped,
    required bool isValidated,
    required Widget expandedContent,
    Widget? collapsedTrailing,
  }) {
    final isExpanded = _expanded[version] ?? (!isShipped || !isValidated);
    final color = isShipped
        ? (isValidated
            ? const Color(0xFF22C55E)
            : const Color(0xFFE8A04C))
        : const Color(0xFF4B5563);
    final label = isShipped
        ? (isValidated
            ? '${version.toUpperCase()} VALIDATED'
            : '${version.toUpperCase()} SHIPPED')
        : '${version.toUpperCase()} IN PROGRESS';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Chevron header ──────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _expanded[version] = !isExpanded),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExpanded ? Icons.expand_more : Icons.chevron_right,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      if (isShipped) ...[
                        Icon(Icons.check_circle,
                            size: 11,
                            color: isValidated
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFE8A04C)),
                        const SizedBox(width: 4),
                      ],
                      GestureDetector(
                        onTap: () => widget.onVersionTap(version),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: widget.selectedVersion == version
                              ? const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Color(0xFFE8A04C),
                                      width: 1.5,
                                    ),
                                  ),
                                )
                              : null,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Menlo',
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: widget.selectedVersion == version
                                  ? const Color(0xFFE8A04C)
                                  : color,
                            ),
                          ),
                        ),
                      ),
                      // In-progress: show mini L-dots inline when collapsed
                      if (!isShipped && !isExpanded && collapsedTrailing != null) ...[
                        const SizedBox(width: 10),
                        collapsedTrailing,
                      ],
                    ],
                  ),
                ),
              ),
              if (isShipped) ...[
                const Spacer(),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => WorksheetGenerationScreen(
                        projectPath: widget.project.path,
                        projectName: widget.project.name,
                        specVersion: version,
                      ),
                    )),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh,
                            size: 11, color: Color(0xFF6B7280)),
                        SizedBox(width: 4),
                        Text(
                          '↻ Regenerate',
                          style: TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          // ── Expanded body ───────────────────────────────────
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 18),
              child: expandedContent,
            ),
        ],
      ),
    );
  }

  Widget _buildVersionEntry(
    BuildContext context,
    String v, {
    required String sv,
    required ProjectMode mode,
    required String stage,
    required bool worksheetDone,
    required String latestVersion,
    required Project pj,
  }) {
    // Disk-extra versions carry their own stage determined from the filesystem.
    final diskStage = _diskExtraStages[v];
    final effectiveStage = diskStage ?? stage;
    final vIsShipped = diskStage != null
        ? diskStage == 'worksheet_complete'
        : (v != latestVersion) || worksheetDone;

    final chips = _allComponents[v] ?? [];
    final goal = _versionGoals[v];

    // For a disk-extra version that isn't shipped yet, use `v` as the spec version
    // so artifact links and worksheet navigation point to the correct version.
    final effectiveSv = (diskStage != null && !vIsShipped) ? v : sv;

    return _buildVersionPanel(
      context,
      version: v,
      isShipped: vIsShipped,
      isValidated: _validatedVersions.contains(v),
      collapsedTrailing: !vIsShipped && mode == ProjectMode.build
          ? _LayerSubRow(
              progress: _progress,
              interviewDone: diskStage != null,
              pulseOpacity: _pulseOpacity,
            )
          : null,
      expandedContent: vIsShipped
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTimelineRow(context, pj, v, mode, 'worksheet_complete'),
                if (goal != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    goal,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'Menlo',
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildChips(chips),
                ],
                if (vIsShipped && !_validatedVersions.contains(v)) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ProjectFileRepository.markVersionValidated(
                          pj.path, v);
                      await _loadValidatedVersions();
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: Text(
                      'Mark ${v.toUpperCase()} as Executed & Validated',
                      style: const TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE8A04C)),
                      foregroundColor: const Color(0xFFE8A04C),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ],
            )
          : _buildTimelineRow(context, pj, effectiveSv, mode, effectiveStage),
    );
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
    final worksheetDone = stage == 'worksheet_complete';
    final latestVersion = _versionOf(pj.phase);
    // Use _diskLatestN so versions found on disk (but not yet in DB) appear in timeline.
    final allVersions = List.generate(_diskLatestN, (i) => 'v${i + 1}');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in allVersions)
            _buildVersionEntry(context, v,
                sv: sv,
                mode: mode,
                stage: stage,
                worksheetDone: worksheetDone,
                latestVersion: latestVersion,
                pj: pj),
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

class _SidebarDivider extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onToggle;
  final void Function(double dx) onDrag;

  const _SidebarDivider({
    required this.collapsed,
    required this.onToggle,
    required this.onDrag,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: SizedBox(
          width: 12,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(width: 1, color: const Color(0xFF2C2C2E)),
              Positioned(
                top: 40,
                child: GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 16,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      border: Border.all(color: const Color(0xFF3C3C3E)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      collapsed
                          ? Icons.chevron_right
                          : Icons.chevron_left,
                      size: 12,
                      color: const Color(0xFF6B7280),
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
}

class _FilesSidebar extends ConsumerStatefulWidget {
  const _FilesSidebar({required this.projectPath});
  final String projectPath;

  @override
  ConsumerState<_FilesSidebar> createState() => _FilesSidebarState();
}

class _FilesSidebarState extends ConsumerState<_FilesSidebar> with RouteAware {
  String? _selected;
  // folder → version ('' for flat files) → filenames
  Future<Map<String, Map<String, List<String>>>>? _scanFuture;
  // null key → defaults to expanded (true)
  final Map<String, bool> _folderExpanded = {};

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
    setState(() { _scanFuture = _scan(); });
  }

  void _open(BuildContext context, String folder, String version, String filename) {
    setState(() => _selected = '$folder/$version/$filename');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtifactViewerScreen(
          args: ArtifactViewArgs(
            projectPath: widget.projectPath,
            projectName: p.basename(widget.projectPath),
            filename: filename,
            specVersion: version.isEmpty ? null : version,
            mode: _modeForFolder(folder),
          ),
        ),
      ),
    );
  }

  /// Scans each folder. Version subfolders (v1, v2, …) are grouped by name;
  /// flat files (audit, ingested, legacy) land under the '' key.
  Future<Map<String, Map<String, List<String>>>> _scan() async {
    final result = <String, Map<String, List<String>>>{};
    for (final f in _folders) {
      final dir = Directory(p.join(widget.projectPath, f.id));
      if (!dir.existsSync()) continue;
      final versions = <String, List<String>>{};
      for (final entry in dir.listSync()) {
        if (entry is Directory) {
          final vName = p.basename(entry.path);
          if (RegExp(r'^v(\d+(?:\.\d+)?)$').hasMatch(vName)) {
            final vFiles = entry.listSync()
                .whereType<File>()
                .map((e) => p.basename(e.path))
                .toList()..sort();
            if (vFiles.isNotEmpty) versions[vName] = vFiles;
          }
        } else if (entry is File) {
          (versions[''] ??= []).add(p.basename(entry.path));
        }
      }
      versions['']?.sort();
      if (versions.isNotEmpty) result[f.id] = versions;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Project>>>(projectListProvider, (_, __) {
      setState(() { _scanFuture = _scan(); });
    });
    return SizedBox(
      width: 220,
      child: Container(
        color: const Color(0xFF141414),
        child: FutureBuilder<Map<String, Map<String, List<String>>>>(
          future: _scanFuture,
          builder: (context, snapshot) {
            final files = snapshot.data ?? {};
            final hasAny = files.values
                .any((vMap) => vMap.values.any((l) => l.isNotEmpty));

            // Find latest version across all folders
            String? latestV;
            for (final vMap in files.values) {
              for (final v in vMap.keys) {
                if (v.isEmpty) continue;
                if (latestV == null || v.compareTo(latestV) > 0) latestV = v;
              }
            }
            // Files that should go to the coder for the latest version
            final coderFiles = <String>{};
            if (latestV != null) {
              for (final folderId in files.keys) {
                for (final filename in files[folderId]![latestV] ?? []) {
                  if (filename.contains('_LockedSpec_') ||
                      filename.contains('_HandoffPackage_') ||
                      filename.contains('_BulletHandoff_') ||
                      filename.contains('_SetupWorksheet_')) {
                    coderFiles.add('$folderId/$latestV/$filename');
                  }
                }
              }
            }

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
                                // ── Collapsible folder header ──────────────
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _folderExpanded[folder.id] =
                                          !(_folderExpanded[folder.id] ?? true);
                                    }),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(8, 12, 12, 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            (_folderExpanded[folder.id] ?? true)
                                                ? Icons.expand_more
                                                : Icons.chevron_right,
                                            size: 13,
                                            color: const Color(0xFF6B7280),
                                          ),
                                          const SizedBox(width: 3),
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
                                          if (!(_folderExpanded[folder.id] ?? true)) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              '${files[folder.id]!.values.fold(0, (s, l) => s + l.length)}',
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontFamily: 'Menlo',
                                                color: Color(0xFF4B5563),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // ── Files (only when expanded) ─────────────
                                if (_folderExpanded[folder.id] ?? true)
                                  // Sort versions: flat ('') first, then v1, v2...
                                  for (final version in (files[folder.id]!.keys.toList()
                                        ..sort((a, b) => a.isEmpty ? -1 : b.isEmpty ? 1 : a.compareTo(b)))) ...[
                                    if (version.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(24, 8, 12, 2),
                                        child: Text(
                                          version.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                            fontFamily: 'Menlo',
                                            color: Color(0xFF4B5563),
                                          ),
                                        ),
                                      ),
                                    for (final filename in files[folder.id]![version]!)
                                      _FileRow(
                                        filename: filename,
                                        selected: _selected == '${folder.id}/$version/$filename',
                                        highlighted: coderFiles.contains('${folder.id}/$version/$filename'),
                                        onTap: () => _open(context, folder.id, version, filename),
                                        filePath: version.isEmpty
                                            ? p.join(widget.projectPath, folder.id, filename)
                                            : p.join(widget.projectPath, folder.id, version, filename),
                                      ),
                                  ],
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
    required this.filePath,
    this.highlighted = false,
  });

  final String filename;
  final bool selected;
  final VoidCallback onTap;
  final String filePath;
  final bool highlighted;

  void _showInFinder() {
    Process.run('open', ['-R', filePath]);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) async {
        final overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        await showMenu(
          context: context,
          position: RelativeRect.fromRect(
            details.globalPosition & Size.zero,
            Offset.zero & overlay.size,
          ),
          color: const Color(0xFF1C1C1E),
          items: [
            PopupMenuItem(
              onTap: _showInFinder,
              child: const Text(
                'Show in Finder',
                style: TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 12,
                  color: Color(0xFFD1D5DB),
                ),
              ),
            ),
          ],
        );
      },
      child: Material(
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
          child: Row(
            children: [
              if (highlighted && !selected)
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8A04C),
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: Text(
                  filename,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 11,
                    color: selected
                        ? const Color(0xFFE8A04C)
                        : highlighted
                            ? const Color(0xFFE5E5E7)
                            : const Color(0xFFD1D5DB),
                  ),
                ),
              ),
            ],
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

class _RepoPathRow extends StatefulWidget {
  const _RepoPathRow({required this.projectPath, required this.projectName});
  final String projectPath;
  final String projectName;

  @override
  State<_RepoPathRow> createState() => _RepoPathRowState();
}

class _RepoPathRowState extends State<_RepoPathRow> {
  String? _repoPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await ProjectFileRepository.readProjectConfig(widget.projectPath);
    if (mounted) setState(() => _repoPath = config['repoPath'] as String?);
  }

  Future<void> _pick() async {
    final picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select implementation repo for ${widget.projectName}',
    );
    if (picked == null) return;
    await ProjectFileRepository.writeProjectConfig(widget.projectPath, {'repoPath': picked});
    if (mounted) setState(() => _repoPath = picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = _repoPath == null ? 'No repo linked' : _repoPath!.split('/').last;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _pick,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F10),
            border: Border.all(color: const Color(0xFF2C2C2E)),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.code_outlined, size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 12,
                    color: Color(0xFFE5E5E7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _repoPath == null ? 'Link Repo →' : 'Change →',
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

class _RepoIngestRow extends ConsumerStatefulWidget {
  final String projectPath;
  final String projectName;

  const _RepoIngestRow({
    required this.projectPath,
    required this.projectName,
  });

  @override
  ConsumerState<_RepoIngestRow> createState() => _RepoIngestRowState();
}

class _RepoIngestRowState extends ConsumerState<_RepoIngestRow> {
  String? _repoPath;

  @override
  void initState() {
    super.initState();
    _loadRepoPath();
  }

  Future<void> _loadRepoPath() async {
    final config = await ProjectFileRepository.readProjectConfig(widget.projectPath);
    if (mounted) setState(() => _repoPath = config['repoPath'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          if (_repoPath == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Link a repo first using the Repo Path row below.'),
              ),
            );
            return;
          }

          await ref
              .read(pullIngestionNotifierProvider.notifier)
              .startIngestion(_repoPath!);

          if (!mounted) return;
          final ingestionState = ref.read(pullIngestionNotifierProvider);
          if (ingestionState.state == rev_ingest.IngestionState.done) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PullIngestionSummaryScreen(
                  projectPath: widget.projectPath,
                  projectName: widget.projectName,
                ),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PullIngestionProgressScreen(
                  projectPath: widget.projectPath,
                ),
              ),
            );
          }
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
              const Icon(Icons.code_outlined,
                  size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _repoPath == null
                      ? 'No repo linked — use Repo Path row below'
                      : 'Ready to ingest: ${_repoPath!.split('/').last}',
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 12,
                    color: Color(0xFFE5E5E7),
                  ),
                ),
              ),
              const Text(
                'Ingest Repo →',
                style: TextStyle(
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
    int _latestSpecN = 1;
    while (_specFileExistsOnDisk(project.path, 'v${_latestSpecN + 1}')) {
      _latestSpecN++;
    }
    final sv = 'v$_latestSpecN';

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
            Text(
              'BUILD SEQUENCE — ${sv.toUpperCase()}',
              style: const TextStyle(
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
                        Text(
                          'Generate an LLM-narrated build order from your ${sv.toUpperCase()} spec.',
                          style: const TextStyle(
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

class _CopyWorksheetButton extends StatelessWidget {
  const _CopyWorksheetButton({
    required this.projectPath,
    required this.projectName,
    required this.specVersion,
  });

  final String projectPath;
  final String projectName;
  final String specVersion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          // Check versioned subfolder first, fall back to flat.
          File _resolve(String folder, String filename) {
            final v = File(p.join(projectPath, folder, specVersion, filename));
            return v.existsSync() ? v : File(p.join(projectPath, folder, filename));
          }
          final goalFile = _resolve('handoffs', '${projectName}_goal_$specVersion.md');
          final worksheetFile = _resolve('worksheets', '${projectName}_SetupWorksheet_$specVersion.md');

          final goalExists = await goalFile.exists();
          final worksheetExists = await worksheetFile.exists();

          if (!goalExists && !worksheetExists) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No files found to copy')),
              );
            }
            return;
          }

          final parts = <String>[];
          if (goalExists) parts.add(await goalFile.readAsString());
          if (worksheetExists) parts.add(await worksheetFile.readAsString());

          await Clipboard.setData(ClipboardData(text: parts.join('\n\n---\n\n')));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Handoff copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        icon: const Icon(Icons.copy_outlined, size: 14),
        label: const Text(
          'Copy Handoff to Clipboard',
          style: TextStyle(fontFamily: 'Menlo', fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(40),
          foregroundColor: const Color(0xFFE8A04C),
          side: const BorderSide(color: Color(0xFFE8A04C)),
        ),
      ),
    );
  }
}

// ── Fix File Structure Banner ─────────────────────────────────────────────────

class _FixStructureBanner extends StatefulWidget {
  const _FixStructureBanner({required this.projectPath});
  final String projectPath;

  @override
  State<_FixStructureBanner> createState() => _FixStructureBannerState();
}

class _FixStructureBannerState extends State<_FixStructureBanner> {
  bool _hasFlatFiles = false;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final has = await ProjectFileRepository().hasFlatVersionedFiles(widget.projectPath);
    if (mounted) setState(() => _hasFlatFiles = has);
  }

  Future<void> _fix(BuildContext context) async {
    setState(() => _running = true);
    try {
      final count = await ProjectFileRepository().migrateToVersionFolders(widget.projectPath);
      if (mounted) {
        setState(() { _hasFlatFiles = false; _running = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Reorganized $count file${count == 1 ? '' : 's'} into version folders.'),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _running = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasFlatFiles) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1200),
          border: Border.all(color: const Color(0xFFE8A04C)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_open_outlined,
                size: 14, color: Color(0xFFE8A04C)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Files from before version folders were added are still in the flat layout. Fix to keep versions clean.',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Menlo',
                  color: Color(0xFFE8A04C),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _running
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFFE8A04C)),
                  )
                : TextButton(
                    onPressed: () => _fix(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Fix Structure →',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Menlo',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE8A04C),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ── Context Panel (bottom sidebar) ───────────────────────────────────────────

class _ContextPanel extends StatefulWidget {
  const _ContextPanel({required this.projectPath, required this.projectName});
  final String projectPath;
  final String projectName;

  @override
  State<_ContextPanel> createState() => _ContextPanelState();
}

class _ContextPanelState extends State<_ContextPanel> {
  int _tab = 0; // 0 = Notes, 1 = Backlog

  late final TextEditingController _notesCtrl;
  bool _notesDirty = false;

  List<String> _backlogItems = [];
  final TextEditingController _addCtrl = TextEditingController();

  final Map<String, List<String>> _seedsByVersion = {};
  bool _seedsLoaded = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController();
    _loadAll();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadNotes(), _loadBacklog(), _loadSeeds()]);
  }

  Future<void> _loadNotes() async {
    final file = File(p.join(widget.projectPath, 'user_notes.md'));
    if (!file.existsSync()) return;
    final text = await file.readAsString();
    if (mounted) setState(() => _notesCtrl.text = text);
  }

  Future<void> _loadBacklog() async {
    final file = File(p.join(widget.projectPath, 'user_backlog.md'));
    if (!file.existsSync()) return;
    final items = (await file.readAsString())
        .split('\n')
        .map((l) => l.startsWith('- ') ? l.substring(2).trim() : l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (mounted) setState(() => _backlogItems = items);
  }

  Future<void> _loadSeeds() async {
    final handoffsDir =
        Directory(p.join(widget.projectPath, 'handoffs'));
    if (!handoffsDir.existsSync()) {
      if (mounted) setState(() => _seedsLoaded = true);
      return;
    }
    final result = <String, List<String>>{};
    for (final entry in handoffsDir.listSync()) {
      if (entry is! Directory) continue;
      final vName = p.basename(entry.path);
      if (!RegExp(r'^v\d+$').hasMatch(vName)) continue;
      for (final file in entry.listSync().whereType<File>()) {
        if (!p.basename(file.path).contains('_HandoffPackage_')) continue;
        try {
          final data =
              jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          final seeds =
              (data['v2SeedItems'] as List<dynamic>?)?.cast<String>() ?? [];
          if (seeds.isNotEmpty) result[vName] = seeds;
        } catch (_) {}
      }
    }
    if (mounted) {
      setState(() {
        _seedsByVersion.addAll(result);
        _seedsLoaded = true;
      });
    }
  }

  Future<void> _saveNotes() async {
    await File(p.join(widget.projectPath, 'user_notes.md'))
        .writeAsString(_notesCtrl.text);
    if (mounted) setState(() => _notesDirty = false);
  }

  Future<void> _addBacklogItem() async {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    _addCtrl.clear();
    final updated = [..._backlogItems, text];
    if (mounted) setState(() => _backlogItems = updated);
    await File(p.join(widget.projectPath, 'user_backlog.md'))
        .writeAsString(updated.map((i) => '- $i').join('\n'));
  }

  Future<void> _removeBacklogItem(int index) async {
    final updated = [..._backlogItems]..removeAt(index);
    if (mounted) setState(() => _backlogItems = updated);
    await File(p.join(widget.projectPath, 'user_backlog.md'))
        .writeAsString(updated.map((i) => '- $i').join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2C2C2E))),
        color: Color(0xFF0F0F10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _tabChip(0, 'NOTES'),
              _tabChip(1, 'BACKLOG'),
            ],
          ),
          const Divider(height: 1, color: Color(0xFF2C2C2E)),
          Expanded(
            child: _tab == 0 ? _buildNotesTab() : _buildBacklogTab(),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(int index, String label) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFFE8A04C) : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Menlo',
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: active ? const Color(0xFFE8A04C) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesTab() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: _notesCtrl,
              maxLines: null,
              expands: true,
              onChanged: (_) {
                if (!_notesDirty) setState(() => _notesDirty = true);
              },
              style: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 11,
                color: Color(0xFFE5E5E7),
                height: 1.5,
              ),
              decoration: const InputDecoration(
                hintText: 'Add notes for the AI…',
                hintStyle: TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 11,
                    color: Color(0xFF6B7280)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_notesDirty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _saveNotes,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 10,
                      color: Color(0xFFE8A04C)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBacklogTab() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addCtrl,
                style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 11,
                    color: Color(0xFFE5E5E7)),
                decoration: const InputDecoration(
                  hintText: 'Add item…',
                  hintStyle: TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 11,
                      color: Color(0xFF6B7280)),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (_) => _addBacklogItem(),
              ),
            ),
            GestureDetector(
              onTap: _addBacklogItem,
              child: const Icon(Icons.add, size: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        if (_backlogItems.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Divider(height: 1, color: Color(0xFF2C2C2E)),
          const SizedBox(height: 4),
          for (int i = 0; i < _backlogItems.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('·',
                      style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontFamily: 'Menlo',
                          fontSize: 11)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _backlogItems[i],
                      style: const TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 11,
                          color: Color(0xFFE5E5E7),
                          height: 1.4),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _removeBacklogItem(i),
                    child: const Icon(Icons.close,
                        size: 10, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
        ],
        if (_seedsLoaded && _seedsByVersion.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'AI DEFERRED',
            style: TextStyle(
              fontFamily: 'Menlo',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          for (final version in (_seedsByVersion.keys.toList()..sort()))
            for (final item in _seedsByVersion[version]!)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$version ·',
                      style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontFamily: 'Menlo',
                          fontSize: 10),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 10,
                            color: Color(0xFF9CA3AF),
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ],
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


class _ReverseModeCta extends ConsumerWidget {
  final String projectPath;
  final String projectName;

  const _ReverseModeCta({
    required this.projectPath,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingestionState = ref.watch(pullIngestionNotifierProvider);
    final ingestionDone =
        ingestionState.state == rev_ingest.IngestionState.done;

    return FilledButton(
      onPressed: ingestionDone
          ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => PullInterviewScreen(
                  args: PullInterviewArgs(
                    projectPath: projectPath,
                    projectName: projectName,
                  ),
                ),
              ))
          : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        backgroundColor:
            ingestionDone ? const Color(0xFFE8A04C) : const Color(0xFF2C2C2E),
        foregroundColor:
            ingestionDone ? const Color(0xFF0F0F10) : const Color(0xFF6B7280),
      ),
      child: Text(
        ingestionDone
            ? 'Start Pull Interview →'
            : 'Ingest Repo First',
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontFamily: 'Menlo'),
      ),
    );
  }
}

// ── Coder Package ─────────────────────────────────────────────────────────────

class _CoderItem {
  const _CoderItem(this.label, this.file);
  final String label;
  final File file;
}

class _CoderPackageSection extends StatefulWidget {
  const _CoderPackageSection({
    required this.projectPath,
    required this.projectName,
    required this.targetVersion,
  });
  final String projectPath;
  final String projectName;
  final String targetVersion;

  @override
  State<_CoderPackageSection> createState() => _CoderPackageSectionState();
}

class _CoderPackageSectionState extends State<_CoderPackageSection> {
  bool _working = false;
  late Future<({String? version, List<_CoderItem> items})> _discovery;

  @override
  void initState() {
    super.initState();
    _discovery = _discover();
  }

  @override
  void didUpdateWidget(_CoderPackageSection old) {
    super.didUpdateWidget(old);
    if (old.targetVersion != widget.targetVersion) {
      setState(() => _discovery = _discover());
    }
  }

  Future<({String? version, List<_CoderItem> items})> _discover() async {
    final v = widget.targetVersion;
    final items = <_CoderItem>[];

    final readme = File(p.join(widget.projectPath, 'README.md'));
    if (readme.existsSync()) items.add(_CoderItem('README — Project State', readme));

    for (final folder in ['specs', 'handoffs', 'worksheets']) {
      final vDir = Directory(p.join(widget.projectPath, folder, v));
      final scanDir = vDir.existsSync()
          ? vDir
          : Directory(p.join(widget.projectPath, folder));
      if (!scanDir.existsSync()) continue;
      for (final f in scanDir.listSync().whereType<File>()) {
        final label = _label(p.basename(f.path));
        if (label != null) items.add(_CoderItem(label, f));
      }
    }

    return (version: v, items: items);
  }

  String? _label(String name) {
    if (name.contains('_LockedSpec_')) return 'Locked Spec';
    if (name.contains('_HandoffPackage_') || name.contains('_BulletHandoff_')) return 'Handoff Package';
    if (name.contains('_SetupWorksheet_')) return 'Setup Worksheet';
    return null;
  }

  Future<String> _bundle(String version, List<_CoderItem> items) async {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final buf = StringBuffer(
      '# ${widget.projectName} — Coder Package $version\n'
      'Generated: $date\n\n'
      'Everything the coder LLM needs to implement ${widget.projectName}.\n',
    );
    for (final item in items) {
      buf.writeln('\n---\n');
      buf.writeln('## ${item.label}');
      buf.writeln();
      buf.write(await item.file.readAsString());
    }
    return buf.toString();
  }

  Future<void> _copy() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final d = await _discovery;
      if (d.items.isEmpty || d.version == null) {
        _snack('No coder files found yet.');
        return;
      }
      final text = await _bundle(d.version!, d.items);
      await Clipboard.setData(ClipboardData(text: text));
      _snack('Copied ${d.items.length} files to clipboard.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _export() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final d = await _discovery;
      if (d.items.isEmpty || d.version == null) {
        _snack('No coder files found yet.');
        return;
      }
      final text = await _bundle(d.version!, d.items);
      final exportsDir = Directory(p.join(widget.projectPath, 'exports'));
      await exportsDir.create(recursive: true);
      final out = File(p.join(
        exportsDir.path,
        '${widget.projectName}_CoderPack-${d.version}.md',
      ));
      await out.writeAsString(text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Saved → ${out.path}',
            style: const TextStyle(fontFamily: 'Menlo', fontSize: 11),
          ),
          backgroundColor: const Color(0xFF1C1C1E),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Show in Finder',
            textColor: const Color(0xFFE8A04C),
            onPressed: () => Process.run('open', ['-R', out.path]),
          ),
        ));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(msg, style: const TextStyle(fontFamily: 'Menlo', fontSize: 12)),
      backgroundColor: const Color(0xFF1C1C1E),
      duration: const Duration(seconds: 3),
    ));
  }

  String? _latestVersionOnDisk() {
    final specsDir = Directory(p.join(widget.projectPath, 'specs'));
    if (!specsDir.existsSync()) return null;
    String? latest;
    for (final entry in specsDir.listSync()) {
      if (entry is Directory) {
        final vName = p.basename(entry.path);
        if (RegExp(r'^v(\d+(?:\.\d+)?)$').hasMatch(vName)) {
          if (latest == null || vName.compareTo(latest) > 0) latest = vName;
        }
      }
    }
    return latest;
  }

  Widget _buildUpdateCta(BuildContext context, String version) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF1C1C1E),
                title: Text(
                  'Create update for $version?',
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 13,
                    color: Color(0xFFE5E5E7),
                  ),
                ),
                content: Text(
                  'This will open an addendum interview to produce a '
                  '${version.replaceFirst('v', 'v')}.1 spec. Continue?',
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontFamily: 'Menlo',
                            color: Color(0xFF6B7280))),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE8A04C),
                      foregroundColor: const Color(0xFF0F0F10),
                    ),
                    child: const Text('Start',
                        style: TextStyle(
                            fontFamily: 'Menlo',
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AddendumInterviewScreen(
                  args: AddendumInterviewArgs(
                    projectPath: widget.projectPath,
                    projectName: widget.projectName,
                    baseVersion: version,
                  ),
                ),
              ));
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE8A04C),
            side: const BorderSide(color: Color(0xFFE8A04C)),
          ),
          child: Text(
            'Update $version',
            style: const TextStyle(
                fontFamily: 'Menlo', fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String? version, List<_CoderItem> items})>(
      future: _discovery,
      builder: (context, snap) {
        final items = snap.data?.items ?? [];
        if (items.isEmpty) return const SizedBox.shrink();
        final latestVersion = _latestVersionOnDisk();
        final isLatest = latestVersion == null || widget.targetVersion == latestVersion;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader('Coder Package'),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8A04C),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          p.basename(item.file.path),
                          style: const TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 11,
                            color: Color(0xFFD1D5DB),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            Row(
              children: [
                _PackBtn(
                  label: 'Copy ${widget.targetVersion.toUpperCase()} Bundle',
                  icon: Icons.copy,
                  onTap: _working ? null : _copy,
                ),
                const SizedBox(width: 8),
                _PackBtn(
                  label: 'Export ${widget.targetVersion.toUpperCase()} Pack',
                  icon: Icons.download,
                  onTap: _working ? null : _export,
                ),
              ],
            ),
            if (!isLatest) _buildUpdateCta(context, widget.targetVersion),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _PackBtn extends StatelessWidget {
  const _PackBtn({required this.label, required this.icon, this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF1C1C1E) : const Color(0xFF141414),
          border: Border.all(color: const Color(0xFF3C3C3E)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12,
                color: enabled
                    ? const Color(0xFFE8A04C)
                    : const Color(0xFF4B5563)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Menlo',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: enabled
                    ? const Color(0xFFE8A04C)
                    : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
