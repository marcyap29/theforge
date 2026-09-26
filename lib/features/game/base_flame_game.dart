import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../data/local_db/forge_database.dart';
import '../implementation/models/run_session.dart';
import '../tracker/models/tracker_enums.dart';
import 'hex_grid.dart';

/// The Base View **v2** world (Flame). See `DOCS/forge/base_view_v2_plan.md`.
///
/// - **A2** — isometric hex grid (one hex per feature, spiralling from the hub)
///   with camera pan/zoom.
/// - **A3** — [syncWorld] is the Riverpod→Flame bridge: the Flutter layer pushes
///   snapshots here; this diffs them into hex/robot components.
/// - **B** — robots are parked at their building (B1) and **walk out of the hub**
///   when a run starts (B4); a **blocked/awaiting-approval** robot pulses with a
///   "!" bubble (B3); taps are hit-tested to fire [onTapFeatureId] / [onTapBotId]
///   so the Flutter layer can open the inspect sheets (B2).
///
/// Rive faces + low-poly art come in Phase C.
class BaseFlameGame extends FlameGame {
  BaseFlameGame();

  static const double _tileSize = 52;

  final Map<String, _HexTile> _tiles = {};
  final Map<String, _Robot> _bots = {};

  bool _ready = false;
  bool _centered = false;
  List<Feature>? _pendingFeatures;
  Map<String, RunPhase>? _pendingRuns;

  double _zoomAtScaleStart = 1;

  /// Fired (by feature id) when the user taps a building / a robot. The Flutter
  /// layer maps the id back to the feature and opens the inspect sheet.
  void Function(String featureId)? onTapFeatureId;
  void Function(String featureId)? onTapBotId;

  @override
  Color backgroundColor() => const Color(0xFF0C1016);

  @override
  Future<void> onLoad() async {
    _ready = true;
    if (_pendingFeatures != null) {
      _apply(_pendingFeatures!, _pendingRuns ?? const {});
    }
  }

  /// Push the latest project snapshot into the world (A3). Safe before load.
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

    for (var i = 0; i < features.length; i++) {
      final f = features[i];
      present.add(f.id);
      final centre = HexGrid.toIso(cells[i], _tileSize);
      final status = FeatureStatus.fromWire(f.status);
      final isEpic = BuildKind.fromWire(f.buildKind) == BuildKind.epic;
      final tile = _tiles[f.id];
      if (tile == null) {
        final t = _HexTile(
          size: _tileSize,
          title: f.title,
          statusColor: status.color,
          isEpic: isEpic,
        )..position = Vector2(centre.dx, centre.dy);
        _tiles[f.id] = t;
        world.add(t);
      } else {
        tile
          ..position = Vector2(centre.dx, centre.dy)
          ..title = f.title
          ..statusColor = status.color
          ..isEpic = isEpic;
      }
    }
    _tiles.keys.where((id) => !present.contains(id)).toList().forEach((id) {
      _tiles.remove(id)?.removeFromParent();
    });

    for (final entry in activeRuns.entries) {
      final tile = _tiles[entry.key];
      if (tile == null) continue;
      final target = tile.position + Vector2(0, _tileSize * 0.35);
      final attention = entry.value == RunPhase.awaitingApproval ||
          entry.value == RunPhase.failed;
      final bot = _bots[entry.key];
      if (bot == null) {
        // B4: spawn at the hub (0,0) and walk out to the building.
        final b = _Robot(phaseColor: entry.value.dotColor, attention: attention)
          ..position = Vector2.zero();
        _bots[entry.key] = b;
        world.add(b);
        b.add(MoveToEffect(
          target,
          EffectController(duration: 1.1, curve: Curves.easeInOut),
        ));
      } else {
        bot
          ..position = target
          ..phaseColor = entry.value.dotColor
          ..attention = attention;
      }
    }
    _bots.keys.where((id) => !activeRuns.containsKey(id)).toList().forEach((id) {
      _bots.remove(id)?.removeFromParent();
    });

    if (!_centered && _tiles.isNotEmpty) {
      camera.viewfinder.position = Vector2.zero();
      camera.viewfinder.zoom = 1.0;
      _centered = true;
    }
  }

  // --- Input (driven from Flutter gestures in BaseViewScreen) ------------------

  /// Hit-tests a tap at [localPx] (pane-local pixels) against robots (on top)
  /// then tiles, converting screen→world via the camera. Manual hit-testing
  /// (we own every component's position) avoids Flame gesture-arena conflicts
  /// with the pan/zoom recognizer.
  void handleTapAtScreen(Offset localPx) {
    final z = camera.viewfinder.zoom;
    final world = camera.viewfinder.position +
        Vector2(localPx.dx - size.x / 2, localPx.dy - size.y / 2) / z;
    for (final e in _bots.entries) {
      if ((world - e.value.position).length <= 14) {
        onTapBotId?.call(e.key);
        return;
      }
    }
    for (final e in _tiles.entries) {
      final d = world - e.value.position;
      if (d.x.abs() <= _tileSize && d.y.abs() <= _tileSize * 0.62) {
        onTapFeatureId?.call(e.key);
        return;
      }
    }
  }

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

/// A feature as a flat-top hex tile with a building block + label. Placeholder
/// art — Phase C swaps in real low-poly tiles/buildings.
class _HexTile extends PositionComponent {
  _HexTile({
    required double size,
    required this.title,
    required this.statusColor,
    required this.isEpic,
  })  : _size = size,
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

/// A builder-bot: body + two-eye face, coloured by run phase. When it needs the
/// user (awaiting approval / failed) it pulses with a "!" bubble (B3). Phase C1
/// replaces this with a Rive character with real expressions.
class _Robot extends PositionComponent {
  _Robot({required this.phaseColor, required this.attention})
      : super(anchor: Anchor.center);

  Color phaseColor;
  bool attention;
  double _t = 0;

  static final _bang = TextPaint(
    style: const TextStyle(
        color: Color(0xFF15161C), fontSize: 10, fontWeight: FontWeight.bold),
  );

  @override
  void update(double dt) {
    super.update(dt);
    if (attention) _t += dt;
  }

  @override
  void render(Canvas canvas) {
    if (attention) {
      final pulse = 0.5 + 0.5 * sin(_t * 4);
      canvas.drawCircle(
        Offset.zero,
        13 + pulse * 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = phaseColor.withValues(alpha: 0.25 + 0.45 * pulse),
      );
    }
    final body = Rect.fromCenter(center: Offset.zero, width: 16, height: 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(4)),
      Paint()..color = const Color(0xFF2A2F38),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = phaseColor,
    );
    final eye = Paint()..color = phaseColor;
    canvas.drawCircle(const Offset(-3.5, -1), 1.6, eye);
    canvas.drawCircle(const Offset(3.5, -1), 1.6, eye);

    if (attention) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(0, -16), width: 12, height: 12),
          const Radius.circular(3),
        ),
        Paint()..color = phaseColor,
      );
      _bang.render(canvas, '!', Vector2(0, -16), anchor: Anchor.center);
    }
  }
}
