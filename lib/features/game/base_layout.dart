import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../data/local_db/forge_database.dart';
import '../tracker/models/tracker_enums.dart';

/// One feature's placement on the base: its pixel center + footprint. The game
/// screen draws a "building" at [rect] and parks that feature's builder-bot
/// near it. [ring] is which concentric ring out from the hub it sits on.
@immutable
class BuildingSlot {
  const BuildingSlot({
    required this.feature,
    required this.center,
    required this.size,
    required this.ring,
  });

  final Feature feature;
  final Offset center;
  final Size size;
  final int ring;

  Rect get rect =>
      Rect.fromCenter(center: center, width: size.width, height: size.height);
}

/// A laid-out base: a central hub (the Command Center / metaphor) with feature
/// buildings arranged on concentric rings around it, plus the canvas extent.
@immutable
class BaseScene {
  const BaseScene({
    required this.hub,
    required this.hubRadius,
    required this.buildings,
    required this.canvas,
  });

  final Offset hub;
  final double hubRadius;
  final List<BuildingSlot> buildings;
  final Size canvas;
}

/// Pure layout math for the Base View — a StarCraft-style *base*, not a grid:
/// a command-center hub at the middle with buildings clustered on rings around
/// it. No Flutter widgets, no I/O; deterministic in feature order so the scene
/// is testable and doesn't jump around between rebuilds.
class BaseLayout {
  const BaseLayout._();

  static const _baseCell = Size(112, 92);
  static const _epicCell = Size(150, 122);
  static const _manualCell = Size(94, 78);
  static const hubRadius = 64.0;

  /// Hub edge → first ring, and between successive ring centers.
  static const _firstRingGap = 84.0;
  static const _ringGap = 48.0;

  /// Minimum arc (px) each building claims on its ring — sets ring capacity.
  static const _angularGap = 40.0;
  static const _pad = 96.0;

  static Size cellFor(String buildKind) => switch (BuildKind.fromWire(buildKind)) {
        BuildKind.epic => _epicCell,
        BuildKind.manual => _manualCell,
        BuildKind.standard => _baseCell,
      };

  /// Hub-center → building-center distance for ring [r] (0 = innermost).
  static double ringRadius(int r) =>
      hubRadius + _firstRingGap + r * (_baseCell.height + _ringGap);

  /// How many buildings fit on ring [r] before it should spill to the next.
  static int ringCapacity(int r) {
    final circumference = 2 * pi * ringRadius(r);
    return max(1, (circumference / (_baseCell.width + _angularGap)).floor());
  }

  /// Lays [features] out around a central hub. Fills the inner ring first, then
  /// spills outward. Buildings are evenly spaced around each ring (alternate
  /// rings staggered by half a slot so they don't line up spoke-like), sized by
  /// build kind (epics larger, manual smaller).
  static BaseScene scene(List<Feature> features) {
    // 1. Assign features to rings, inner-first.
    final rings = <List<Feature>>[];
    var i = 0;
    var r = 0;
    while (i < features.length) {
      final take = min(ringCapacity(r), features.length - i);
      rings.add(features.sublist(i, i + take));
      i += take;
      r++;
    }

    // 2. Canvas: square, big enough for the outermost ring + a large cell + pad.
    final outerR = rings.isEmpty ? 0.0 : ringRadius(rings.length - 1);
    final extent = outerR + _epicCell.height / 2 + _pad;
    final canvas = Size(extent * 2, extent * 2);
    final hub = Offset(extent, extent);

    // 3. Place each building around its ring, starting at the top (-90°).
    final buildings = <BuildingSlot>[];
    for (var ri = 0; ri < rings.length; ri++) {
      final ring = rings[ri];
      final radius = ringRadius(ri);
      final n = ring.length;
      final start = -pi / 2 + (ri.isOdd ? pi / n : 0.0);
      for (var k = 0; k < n; k++) {
        final angle = start + 2 * pi * k / n;
        final center = hub + Offset(cos(angle), sin(angle)) * radius;
        buildings.add(BuildingSlot(
          feature: ring[k],
          center: center,
          size: cellFor(ring[k].buildKind),
          ring: ri,
        ));
      }
    }
    return BaseScene(
        hub: hub, hubRadius: hubRadius, buildings: buildings, canvas: canvas);
  }
}
