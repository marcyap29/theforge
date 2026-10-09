import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../lib/core/theme/forge_theme.dart';

/// The Forge's signature mark: a ring that fills as work lands.
///
/// `progress` is 0..1. At 0 the ring is all steel and the ember core is hollow
/// — nothing forged yet. As work lands the ember arc grows clockwise from the
/// top and the core lights up. This is the same mark as the app icon, so the
/// icon reads as a legend for the UI.
class HearthDial extends StatelessWidget {
  const HearthDial({
    super.key,
    this.size = 64,
    this.progress = 0,
    this.strokeWidth,
  });

  final double size;
  final double progress;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final sw = strokeWidth ?? math.max(2.0, size * 0.09);
    final p = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HearthDialPainter(progress: p, strokeWidth: sw),
      ),
    );
  }
}

class _HearthDialPainter extends CustomPainter {
  _HearthDialPainter({required this.progress, required this.strokeWidth});

  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Steel track — the "not yet" ring.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = ForgeColors.steelDim;
    canvas.drawCircle(center, radius, track);

    // Ember arc — the "happening now" progress, clockwise from top.
    if (progress > 0) {
      final ember = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 3 / 2,
          colors: [ForgeColors.emberLo, ForgeColors.ember, ForgeColors.emberHi],
        ).createShader(rect);
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, ember);
    }

    // Core — hollow at 0, lit as work lands.
    final coreRadius = radius * 0.42;
    if (progress <= 0) {
      final hollow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.6
        ..color = ForgeColors.steelDim;
      canvas.drawCircle(center, coreRadius, hollow);
    } else {
      final core = Paint()
        ..shader = const RadialGradient(
          colors: [ForgeColors.emberHi, ForgeColors.ember, ForgeColors.emberLo],
        ).createShader(Rect.fromCircle(center: center, radius: coreRadius));
      canvas.drawCircle(center, coreRadius, core);
    }
  }

  @override
  bool shouldRepaint(_HearthDialPainter old) =>
      old.progress != progress || old.strokeWidth != strokeWidth;
}
