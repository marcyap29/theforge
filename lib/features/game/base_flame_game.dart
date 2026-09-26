import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../data/local_db/forge_database.dart';
import '../implementation/models/run_session.dart';
import '../tracker/models/tracker_enums.dart';
import 'hex_grid.dart';

/// The Base View **v2** world (Flame). See `DOCS/forge/base_view_v2_plan.md`.
///
/// - **A2** — an isometric hex grid (one hex per feature, spiralling from the
///   hub) with camera pan/zoom.
/// - **A3** — [syncWorld] is the Riverpod→Flame bridge: the Flutter layer
///   watches the providers and pushes snapshots in here; this diffs them into
///   hex/robot components so the world tracks reality without being rebuilt.
///
/// Robots (B) and Rive faces/art (C) build on these placeholder components.
class BaseFlameGame extends FlameGame {
  BaseFlameGame();

  static const double _tileSize = 52;

  final Map<String, _HexTile> _tiles = {};
  final Map<String, _Robot> _bots = {};

  bool _ready = false;
  bool _centered = false;
  List<Feature>? _pendingFeatures;
  Map<String, RunPhase>? _pendingRuns;

  // Gesture state (driven from the Flutter layer — see BaseViewScreen).
  double _zoomAtScaleStart = 1;

  @override
  Color backgroundColor() => const Color(0xFF0C1016);

  @override
  Future<void> onLoad() async {
    _ready = true;
    if (_pendingFeatures != null) {
      _apply(_pendingFeatures!, _pendingRuns ?? const {});
    }
  }

  /// Push the latest project snapshot into the world (A3). Safe to call before
  /// the game finishes loading — the last snapshot is applied in [onLoad].
  void syncWorld(List<Feature> features, Map<String, RunPhase> activeRuns) {
    if (!_ready) {
      _pendingFeatures = features;
      _pendingRuns = activeRuns;
      return;
    }
    _apply(features, activeRuns);
  }

  void _apply(List<Feature> features, Map<String, RunPhase> activeRuns) {
    final cells = HexGrid.spiral(features.length);
    final present = <String>{};

    // Buildings: one hex per feature, positioned on its spiral cell.
    for (var i = 0; i < features.length; i++) {
      final f = features[i];
      present.add(f.id);
      final centre = HexGrid.toIso(cells[i], _tileSize);
      final status = FeatureStatus.fromWire(f.status);
      final kind = BuildKind.fromWire(f.buildKind);
      final tile = _tiles[f.id];
      if (tile == null) {
        final t = _HexTile(
          size: _tileSize,
          title: f.title,
          statusColor: status.color,
          isEpic: kind == BuildKind.epic,
        )..position = Vector2(centre.dx, centre.dy);
        _tiles[f.id] = t;
        world.add(t);
      } else {
        tile
          ..position = Vector2(centre.dx, centre.dy)
          ..title = f.title
          ..statusColor = status.color
          ..isEpic = kind == BuildKind.epic;
      }
    }
    // Remove tiles for features that are gone.
    _tiles.keys.where((id) => !present.contains(id)).toList().forEach((id) {
      _tiles.remove(id)?.removeFromParent();
    });

    // Robots: one per active run, parked at its building.
    for (final entry in activeRuns.entries) {
      final tile = _tiles[entry.key];
      if (tile == null) continue; // run for a feature not shown
      final pos = tile.position + Vector2(0, _tileSize * 0.35);
      final bot = _bots[entry.key];
      if (bot == null) {
        final b = _Robot(phaseColor: entry.value.dotColor)..position = pos;
        _bots[entry.key] = b;
        world.add(b);
      } else {
        bot
          ..position = pos
          ..phaseColor = entry.value.dotColor;
      }
    }
    _bots.keys.where((id) => !activeRuns.containsKey(id)).toList().forEach((id) {
      _bots.remove(id)?.removeFromParent();
    });

    // Frame the base once, centred on the hub.
    if (!_centered && _tiles.isNotEmpty) {
      camera.viewfinder.position = Vector2.zero();
      camera.viewfinder.zoom = 1.0;
      _centered = true;
    }
  }

  // --- Camera control (input comes from Flutter gestures in BaseViewScreen) ---

  void panBy(Offset delta) {
    final z = camera.viewfinder.zoom;
    camera.viewfinder.position += Vector2(-delta.dx, -delta.dy) / z;
  }

  void onScaleStart() => _zoomAtScaleStart = camera.viewfinder.zoom;

  void onScaleUpdate(Offset focalDelta, double scale) {
    panBy(focalDelta);
    if (scale != 1.0) {
      camera.viewfinder.zoom = (_zoomAtScaleStart * scale).clamp(0.35, 3.0);
    }
  }

  void zoomBy(double scrollDy) {
    final z = camera.viewfinder.zoom * (1 - scrollDy * 0.0015);
    camera.viewfinder.zoom = z.clamp(0.35, 3.0);
  }
}

/// A feature rendered as a flat-top hex tile with a small building block and a
/// label. Placeholder art — Phase C swaps in real low-poly tiles/buildings.
class _HexTile extends PositionComponent {
  _HexTile({
    required double size,
    required this.title,
    required this.statusColor,
    required this.isEpic,
  }) : _size = size,
       super(anchor: Anchor.center);

  final double _size;
  String title;
  Color statusColor;
  bool isEpic;

  static final _label = TextPaint(
    style: const TextStyle(color: Color(0xFFD5D8DD), fontSize: 9),
  );

  Path _hexPath() {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = pi / 180 * (60 * i);
      final p = Offset(_size * cos(a), _size * 0.58 * sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void render(Canvas canvas) {
    final hex = _hexPath();
    canvas.drawPath(hex, Paint()..color = const Color(0xFF11161D));
    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = statusColor.withValues(alpha: 0.75),
    );
    // Building block, sized up a touch for epics.
    final w = _size * (isEpic ? 0.7 : 0.5);
    final h = _size * (isEpic ? 0.5 : 0.38);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -h * 0.4), width: w, height: h),
        const Radius.circular(3),
      ),
      Paint()..color = statusColor.withValues(alpha: 0.9),
    );
    _label.render(
      canvas,
      title.length > 16 ? '${title.substring(0, 15)}…' : title,
      Vector2(0, _size * 0.42),
      anchor: Anchor.topCenter,
    );
  }
}

/// A builder-bot: a placeholder body + face (two eyes), coloured by run phase.
/// Phase C1 replaces this with a Rive character with real expressions.
class _Robot extends PositionComponent {
  _Robot({required this.phaseColor}) : super(anchor: Anchor.center);

  Color phaseColor;

  @override
  void render(Canvas canvas) {
    // Body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 16, height: 14),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF2A2F38),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 16, height: 14),
        const Radius.circular(4),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = phaseColor,
    );
    // Face: two eyes.
    final eye = Paint()..color = phaseColor;
    canvas.drawCircle(const Offset(-3.5, -1), 1.6, eye);
    canvas.drawCircle(const Offset(3.5, -1), 1.6, eye);
  }
}
