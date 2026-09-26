import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/filesystem/project_file_repository.dart';
import '../../data/local_db/forge_database.dart';
import '../implementation/models/run_session.dart';
import '../implementation/providers/implementation_notifier.dart';
import '../implementation/providers/implementation_providers.dart';
import '../tracker/models/tracker_enums.dart';
import '../tracker/providers/tracker_providers.dart';
import '../tracker/scan/feature_scan.dart';
import 'base_flame_game.dart';
import 'base_layout.dart';

/// The Base View — a StarCraft-style visualization of a project as a *base*:
/// each feature is a **building**, each active Build-with-AI run is a
/// **builder-bot** working at its building, and the project's "one key thing"
/// is distilled into a **metaphor** that themes the base. v1 (points 1–4):
/// display + tap-to-inspect. No Flame yet — Flutter widgets over an
/// [InteractiveViewer] for free pan/zoom.
class BaseViewScreen extends ConsumerStatefulWidget {
  const BaseViewScreen({super.key, required this.project, this.repoPath});

  final Project project;
  final String? repoPath;

  @override
  ConsumerState<BaseViewScreen> createState() => _BaseViewScreenState();
}

class _BaseViewScreenState extends ConsumerState<BaseViewScreen> {
  Project get project => widget.project;

  ProjectMetaphor? _metaphor;
  bool _loadingMetaphor = true;

  /// v2: switch between the v1 widget scene and the Flame world (WIP). The game
  /// is created once and reused so the world isn't rebuilt on every setState.
  bool _flameView = false;
  BaseFlameGame? _flameGame;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadMetaphor);
  }

  /// Metaphor is distilled once and cached under `.forge/` — it rarely changes.
  /// Read the cache first; only call the LLM on a miss. Degrades silently: a
  /// failure just leaves the default 🏗️ base.
  Future<void> _loadMetaphor() async {
    final cached =
        await ProjectFileRepository.readProjectMetaphor(project.path);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _metaphor = ProjectMetaphor.fromMap(cached);
          _loadingMetaphor = false;
        });
      }
      return;
    }
    try {
      final features =
          ref.read(featureListProvider(project.id)).valueOrNull ?? const [];
      final m = await ref.read(featureScannerProvider).distillMetaphor(
            projectPath: project.path,
            repoPath: widget.repoPath,
            projectName: project.name,
            features: features,
          );
      await ProjectFileRepository.writeProjectMetaphor(project.path,
          noun: m.noun, emoji: m.emoji, tagline: m.tagline);
      if (mounted) setState(() => _metaphor = m);
    } catch (_) {
      // Leave the default base; the metaphor is flavor, not function.
    } finally {
      if (mounted) setState(() => _loadingMetaphor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final featuresAsync = ref.watch(featureListProvider(project.id));
    final activeRuns = ref.watch(implActiveRunsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0C1016),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161C),
        title: _title(),
        actions: [
          IconButton(
            icon: Icon(_flameView
                ? Icons.grid_view_outlined
                : Icons.videogame_asset_outlined),
            tooltip: _flameView ? 'Classic view' : 'Flame world (v2, WIP)',
            onPressed: () => setState(() => _flameView = !_flameView),
          ),
        ],
      ),
      body: featuresAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Could not load the base: $e',
                style: const TextStyle(color: Color(0xFFE57373)))),
        data: (all) {
          final features = all
              .where((f) =>
                  FeatureStatus.fromWire(f.status) != FeatureStatus.archived)
              .toList();
          if (_flameView) return _flameBody(features, activeRuns);
          if (features.isEmpty) {
            return const Center(
              child: Text(
                'No features yet — this base has no buildings.\n'
                'Add features on the board, then come back.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8A8A8E), fontSize: 14),
              ),
            );
          }
          return _scene(features, activeRuns);
        },
      ),
    );
  }

  Widget _title() {
    final emoji = _metaphor?.emoji ?? '🏗️';
    final tagline = _loadingMetaphor
        ? 'distilling this base…'
        : (_metaphor?.tagline.isNotEmpty ?? false)
            ? _metaphor!.tagline
            : (_metaphor != null ? 'a ${_metaphor!.noun}' : 'your base');
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(project.name,
                style: const TextStyle(fontSize: 16, color: Color(0xFFE5E5E7))),
            Text(tagline,
                style:
                    const TextStyle(fontSize: 11, color: Color(0xFF8A8A8E))),
          ],
        ),
      ],
    );
  }

  /// The Flame world (v2, WIP). Created lazily and reused. Pushes the live
  /// feature/run snapshot into the game (the Riverpod→Flame bridge, A3) and
  /// drives camera pan/zoom from Flutter gestures. A2 = iso hex grid + camera;
  /// A3 = data sync; robots + art follow in B/C.
  Widget _flameBody(List<Feature> features, Map<String, RunPhase> activeRuns) {
    final game = _flameGame ??= BaseFlameGame();
    game.syncWorld(features, activeRuns);
    return Listener(
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) game.zoomBy(e.scrollDelta.dy);
      },
      child: GestureDetector(
        onScaleStart: (_) => game.onScaleStart(),
        onScaleUpdate: (d) => game.onScaleUpdate(d.focalPointDelta, d.scale),
        child: GameWidget(game: game),
      ),
    );
  }

  Widget _scene(List<Feature> features, Map<String, RunPhase> activeRuns) {
    final scene = BaseLayout.scene(features);
    final byId = {for (final b in scene.buildings) b.feature.id: b};

    return InteractiveViewer(
      constrained: false,
      minScale: 0.4,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(600),
      child: SizedBox(
        width: scene.canvas.width,
        height: scene.canvas.height,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _GroundPainter(scene))),
            // The hub — command center, themed by the project metaphor.
            Positioned(
              left: scene.hub.dx - scene.hubRadius,
              top: scene.hub.dy - scene.hubRadius,
              width: scene.hubRadius * 2,
              height: scene.hubRadius * 2,
              child: _Hub(name: project.name, emoji: _metaphor?.emoji ?? '🏗️'),
            ),
            // Buildings (one per feature), clustered on rings around the hub.
            for (final b in scene.buildings)
              Positioned(
                left: b.rect.left,
                top: b.rect.top,
                width: b.size.width,
                height: b.size.height,
                child: _Building(
                  feature: b.feature,
                  onTap: () => _showBuilding(b.feature),
                ),
              ),
            // Builder-bots (one per active run), parked at their building.
            for (final entry in activeRuns.entries)
              if (byId[entry.key] != null)
                Positioned(
                  left: byId[entry.key]!.center.dx - 22,
                  top: byId[entry.key]!.rect.bottom - 6,
                  width: 44,
                  height: 52,
                  child: _Bot(
                    phase: entry.value,
                    onTap: () =>
                        _showBot(byId[entry.key]!.feature, entry.value),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _showBuilding(Feature feature) {
    final status = FeatureStatus.fromWire(feature.status);
    final kind = BuildKind.fromWire(feature.buildKind);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15161C),
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.home_work_outlined, color: status.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(feature.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _pill(status.label, status.color),
              if (kind != BuildKind.standard) ...[
                const SizedBox(width: 8),
                _pill(kind.label, kind.color),
              ],
            ]),
            if ((feature.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(feature.description!.trim(),
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.45, color: Color(0xFFB0B0B4))),
            ],
          ],
        ),
      ),
    );
  }

  void _showBot(Feature feature, RunPhase phase) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15161C),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Consumer(
        builder: (ctx, ref, _) {
          final run = ref.watch(implRunProvider(feature.id));
          final tail = run.console.length > 14
              ? run.console.sublist(run.console.length - 14)
              : run.console;
          final elapsed = run.elapsed(DateTime.now());
          String two(int n) => n.toString().padLeft(2, '0');
          final clock =
              '${two(elapsed.inMinutes)}:${two(elapsed.inSeconds % 60)}';
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: run.phase.dotColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Bot · ${feature.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    Text('${run.phase.label} · $clock',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF8A8A8E))),
                  ]),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C0D12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: tail.isEmpty
                          ? const Center(
                              child: Text('Warming up…',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280), fontSize: 12)))
                          : ListView(
                              children: [
                                for (final line in tail)
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 1),
                                    child: Text(line.text,
                                        style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11.5,
                                            color: line.color)),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: color)),
      );
}

/// Draws the base ground: a rounded "creep" pad + concentric rings under the
/// hub, supply lines from the hub out to every building, and a platform pad
/// under each building — so it reads as a base radiating from a command center,
/// not a grid of rows.
class _GroundPainter extends CustomPainter {
  _GroundPainter(this.scene);
  final BaseScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    final hub = scene.hub;
    final maxR = scene.buildings.isEmpty
        ? scene.hubRadius
        : scene.buildings
                .map((b) => (b.center - hub).distance)
                .reduce((a, b) => a > b ? a : b) +
            56;

    // Base platform ("creep"): a filled disc + faint radial glow at the hub.
    canvas.drawCircle(hub, maxR, Paint()..color = const Color(0x120E1826));
    canvas.drawCircle(
        hub,
        scene.hubRadius + 40,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0x22E8A04C), Color(0x00E8A04C)],
          ).createShader(
              Rect.fromCircle(center: hub, radius: scene.hubRadius + 40)));

    // Concentric rings.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF1A2532);
    for (var rr = scene.hubRadius + 34.0; rr < maxR; rr += 46) {
      canvas.drawCircle(hub, rr, ring);
    }

    // Supply lines: hub → each building.
    final line = Paint()
      ..strokeWidth = 1.5
      ..color = const Color(0x1FE8A04C);
    for (final b in scene.buildings) {
      canvas.drawLine(hub, b.center, line);
    }

    // Platform pad under each building.
    final pad = Paint()..color = const Color(0xFF11161D);
    for (final b in scene.buildings) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(b.rect.inflate(9), const Radius.circular(14)),
        pad,
      );
    }
  }

  @override
  bool shouldRepaint(_GroundPainter old) => old.scene != scene;
}

/// The command center at the heart of the base — a glowing hub themed by the
/// project's metaphor emoji, with the project name.
class _Hub extends StatelessWidget {
  const _Hub({required this.name, required this.emoji});
  final String name;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF201A12),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE8A04C), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x33E8A04C), blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFFE8A04C),
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// A feature rendered as a building: roof + body, colored by status, with an
/// "epic" flag when it's a subsystem.
class _Building extends StatelessWidget {
  const _Building({required this.feature, required this.onTap});
  final Feature feature;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = FeatureStatus.fromWire(feature.status);
    final kind = BuildKind.fromWire(feature.buildKind);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // Roof.
          Container(
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.85),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
          ),
          // Body.
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2028),
                border: Border.all(color: status.color.withValues(alpha: 0.5)),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(6)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFD5D8DD), height: 1.2),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (kind == BuildKind.epic)
                        Icon(Icons.account_tree_outlined,
                            size: 12, color: kind.color)
                      else if (kind == BuildKind.manual)
                        Icon(Icons.pan_tool_outlined,
                            size: 12, color: kind.color)
                      else
                        const SizedBox.shrink(),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: status.color, shape: BoxShape.circle),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A builder-bot: a little robot colored by the run phase (amber = working,
/// blue = awaiting approval, green = done, red = failed). Tap for live status.
class _Bot extends StatelessWidget {
  const _Bot({required this.phase, required this.onTap});
  final RunPhase phase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = phase.dotColor;
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: phase.label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Antenna.
            Container(width: 2, height: 6, color: const Color(0xFF6B7280)),
            // Head.
            Container(
              width: 26,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2F38),
                border: Border.all(color: color, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Container(
                  width: 12,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            // Body.
            Container(
              width: 22,
              height: 16,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF232830),
                border: Border.all(color: color.withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
