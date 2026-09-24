import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../data/local_db/forge_database.dart';

/// One feature's placement on the base: its grid cell and pixel rectangle.
/// The game screen draws a "building" at [rect] and parks that feature's
/// builder-bot near it.
@immutable
class BuildingSlot {
  const BuildingSlot({
    required this.feature,
    required this.col,
    required this.row,
    required this.center,
    required this.size,
  });

  final Feature feature;
  final int col;
  final int row;
  final Offset center;
  final Size size;

  Rect get rect => Rect.fromCenter(
      center: center, width: size.width, height: size.height);
}

/// Pure layout math for the Base View — grid placement of feature "buildings"
/// on a base. No Flutter widgets, no I/O: deterministic in feature order so it
/// can be unit-tested and so the scene doesn't jump around between rebuilds.
class BaseLayout {
  const BaseLayout._();

  /// Columns for [count] buildings — a squarish grid, clamped to [1, 6] so a
  /// big project stays readable (it grows in rows, then the view scrolls).
  static int columnsFor(int count) {
    if (count <= 1) return 1;
    return sqrt(count).ceil().clamp(1, 6);
  }

  /// Places [features] left-to-right, top-to-bottom on a grid, returning a slot
  /// (grid cell + pixel center) for each, in the same order.
  static List<BuildingSlot> place(
    List<Feature> features, {
    int? columns,
    Size cell = const Size(128, 104),
    double gap = 32,
    double padding = 48,
  }) {
    if (features.isEmpty) return const [];
    final cols = columns ?? columnsFor(features.length);
    final slots = <BuildingSlot>[];
    for (var i = 0; i < features.length; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final cx = padding + cell.width / 2 + col * (cell.width + gap);
      final cy = padding + cell.height / 2 + row * (cell.height + gap);
      slots.add(BuildingSlot(
        feature: features[i],
        col: col,
        row: row,
        center: Offset(cx, cy),
        size: cell,
      ));
    }
    return slots;
  }

  /// The canvas size needed to hold [count] buildings — the scene's scrollable
  /// extent (so the base can be bigger than the viewport and pan/zoom inside it).
  static Size canvasSize(
    int count, {
    int? columns,
    Size cell = const Size(128, 104),
    double gap = 32,
    double padding = 48,
  }) {
    final cols = count <= 0 ? 1 : (columns ?? columnsFor(count));
    final rows = count <= 0 ? 1 : (count / cols).ceil();
    final w = padding * 2 + cols * cell.width + (cols - 1) * gap;
    final h = padding * 2 + rows * cell.height + (rows - 1) * gap;
    return Size(w, h);
  }
}
