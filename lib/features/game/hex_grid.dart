import 'dart:math';

import 'package:flutter/widgets.dart';

/// An axial hex coordinate (q, r). The Base View v2 world places one hex per
/// feature, spiralling out from the hub at (0, 0).
@immutable
class HexCell {
  const HexCell(this.q, this.r);
  final int q;
  final int r;

  @override
  bool operator ==(Object other) =>
      other is HexCell && other.q == q && other.r == r;

  @override
  int get hashCode => Object.hash(q, r);
}

/// Pure hex-grid math for the Flame world — a deterministic spiral of cells and
/// an isometric (flat-top, vertically-squashed) axial→pixel projection. No
/// Flame/engine types, so it's unit-tested independently of rendering.
class HexGrid {
  const HexGrid._();

  /// Axial neighbour directions (flat-top), used to walk each ring.
  static const _dirs = [
    [1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1],
  ];

  /// A spiral of [count] cells: the hub at (0,0), then ring 1, ring 2, … Each
  /// ring is walked in a stable order so the layout never jumps between builds.
  static List<HexCell> spiral(int count) {
    if (count <= 0) return const [];
    final out = <HexCell>[const HexCell(0, 0)];
    var radius = 1;
    while (out.length < count) {
      // Start at a fixed corner of this ring, then walk its six sides.
      var q = _dirs[4][0] * radius;
      var r = _dirs[4][1] * radius;
      for (var side = 0; side < 6; side++) {
        for (var step = 0; step < radius; step++) {
          if (out.length >= count) return out;
          out.add(HexCell(q, r));
          q += _dirs[side][0];
          r += _dirs[side][1];
        }
      }
      radius++;
    }
    return out;
  }

  /// Flat-top axial (q,r) → isometric pixel centre. [size] is the hex radius;
  /// [squash] flattens the vertical axis so the plane reads as tilted-away.
  static Offset toIso(HexCell c, double size, {double squash = 0.58}) {
    final x = size * 1.5 * c.q;
    final y = size * sqrt(3) * (c.r + c.q / 2);
    return Offset(x, y * squash);
  }
}
