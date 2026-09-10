import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/forge_theme.dart'; // adjust path to wherever you put ForgeColors

/// The Hearth Dial, drawn to the geometry in `The-Forge_Design-Language_v1.md`.
///
/// Same construction as the app icon: a 320-degree instrument bezel with the
/// opening at six o'clock, a brass progress arc, an ivory position marker where
/// brass meets steel, and the ember at the centre.
///
/// [progress] is the real thing being measured. At 0 the dial is all steel and
/// the ember is a hollow outline: nothing forged yet. Use that on first run.
class HearthDial extends StatelessWidget {
  const HearthDial({
    super.key,
    this.size = 96,
    this.progress = 0.72,
    this.showTicks = true,
    this.showMarker = true,
    this.showBloom = true,
  });

  /// The icon's own resting value. Use this when the dial is pure branding.
  static const double restingProgress = 0.72;

  final double size;
  final double progress;
  final bool showTicks;
  final bool showMarker;
  final bool showBloom;

  @override
  Widget build(BuildContext context) {
    // Below ~48px the ticks and marker turn to mush, same rule as the icon's
    // size variants. Drop them automatically rather than trusting call sites.
    final dense = size >= 48;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HearthDialPainter(
          progress: progress.clamp(0.0, 1.0),
          showTicks: showTicks && dense,
          showMarker: showMarker && dense && progress > 0.02,
          showBloom: showBloom && size >= 64,
        ),
      ),
    );
  }
}

/// Launch-screen version: the arc sweeps up to [progress] and the ember lights
/// last. Drive [controller] from real boot work, not a fixed timer, so a slow
/// start visibly stalls instead of lying.
class AnimatedHearthDial extends StatelessWidget {
  const AnimatedHearthDial({
    super.key,
    required this.controller,
    this.size = 118,
    this.progress = HearthDial.restingProgress,
  });

  final Animation<double> controller;
  final double size;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        // Arc leads, ember follows. Cold instrument first, heat second.
        final arcT = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
        final emberT = Curves.easeOut.transform(
          ((t - 0.35) / 0.55).clamp(0.0, 1.0),
        );
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _HearthDialPainter(
              progress: progress * arcT,
              showTicks: true,
              showMarker: arcT > 0.98,
              showBloom: true,
              emberOpacity: emberT,
              emberScale: 0.72 + 0.28 * emberT,
              tickOpacity: Curves.easeOut.transform((t / 0.3).clamp(0.0, 1.0)),
            ),
          ),
        );
      },
    );
  }
}

class _HearthDialPainter extends CustomPainter {
  _HearthDialPainter({
    required this.progress,
    required this.showTicks,
    required this.showMarker,
    required this.showBloom,
    this.emberOpacity = 1.0,
    this.emberScale = 1.0,
    this.tickOpacity = 1.0,
  });

  final double progress;
  final bool showTicks;
  final bool showMarker;
  final bool showBloom;
  final double emberOpacity;
  final double emberScale;
  final double tickOpacity;

  // Design-language geometry, expressed against a 1024 reference box.
  static const double _ref = 1024;
  static const double _gapStart = 200; // degrees clockwise from 12 o'clock
  static const double _liveSweep = 320;
  static const double _arcR = 300;
  static const double _arcW = 20;
  static const double _tickIn = 330;
  static const double _tickInMinor = 340;
  static const double _tickOut = 356;
  static const double _starRx = 216;
  static const double _starRy = 130;
  static const double _starK = 0.13;

  /// Degrees clockwise from 12 o'clock -> radians in Flutter's canvas space
  /// (which starts at 3 o'clock and runs clockwise).
  double _rad(double deg) => (deg - 90) * math.pi / 180;

  Offset _pt(Offset c, double deg, double r) {
    final a = _rad(deg);
    return Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _ref;
    canvas.save();
    canvas.scale(k);

    const c = Offset(_ref / 2, _ref / 2);
    final rect = Rect.fromCircle(center: c, radius: _arcR);
    final markDeg = _gapStart + _liveSweep * progress;

    // --- ticks -------------------------------------------------------------
    if (showTicks && tickOpacity > 0.01) {
      for (var i = 0; i < 60; i++) {
        final deg = i * 6.0;
        final rel = (deg - _gapStart) % 360;
        if (rel > _liveSweep) continue; // the opening at six o'clock
        final major = i % 5 == 0;
        final p = Paint()
          ..color = (major ? ForgeColors.brass : ForgeColors.steel)
              .withValues(alpha: (major ? 0.85 : 0.35) * tickOpacity)
          ..strokeWidth = major ? 7 : 4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          _pt(c, deg, major ? _tickIn : _tickInMinor),
          _pt(c, deg, _tickOut),
          p,
        );
      }
    }

    // --- unbuilt remainder, in steel ---------------------------------------
    final restStart = _rad(markDeg);
    final restSweep = (_liveSweep * (1 - progress)) * math.pi / 180;
    if (restSweep > 0.001) {
      canvas.drawArc(
        rect,
        restStart,
        restSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _arcW
          ..strokeCap = StrokeCap.round
          ..color = ForgeColors.steel.withValues(alpha: progress == 0 ? 0.42 : 0.30),
      );
    }

    // --- progress arc, in brass --------------------------------------------
    final doneSweep = (_liveSweep * progress) * math.pi / 180;
    if (doneSweep > 0.001) {
      canvas.drawArc(
        rect,
        _rad(_gapStart),
        doneSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _arcW
          ..strokeCap = StrokeCap.round
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ForgeColors.brass, ForgeColors.brassLo],
          ).createShader(rect),
      );
    }

    // --- position marker ----------------------------------------------------
    if (showMarker) {
      canvas.drawLine(
        _pt(c, markDeg, _arcR - 34),
        _pt(c, markDeg, _arcR + 34),
        Paint()
          ..color = ForgeColors.ivory.withValues(alpha: 0.92)
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
    }

    // --- heat bloom ---------------------------------------------------------
    if (showBloom && progress > 0 && emberOpacity > 0.01) {
      canvas.drawCircle(
        c,
        300,
        Paint()
          ..shader = RadialGradient(
            colors: [
              ForgeColors.ember.withValues(alpha: 0.32 * emberOpacity),
              ForgeColors.rust.withValues(alpha: 0.13 * emberOpacity),
              ForgeColors.rust.withValues(alpha: 0),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(Rect.fromCircle(center: c, radius: 300)),
      );
    }

    // --- ember --------------------------------------------------------------
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(emberScale);
    canvas.translate(-c.dx, -c.dy);

    final star = _starPath(c);
    if (progress == 0) {
      // Nothing forged yet: the ember is a cold outline.
      canvas.drawPath(
        star,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..color = ForgeColors.steel.withValues(alpha: 0.5),
      );
    } else if (emberOpacity > 0.01) {
      // Alpha is baked into the gradient stops: a Paint's `color` is ignored
      // once a shader is set, so fading via `..color` would silently do nothing.
      canvas.drawPath(
        star,
        Paint()
          ..shader = LinearGradient(
            begin: const Alignment(-0.5, -1),
            end: const Alignment(0.5, 1),
            colors: [
              ForgeColors.emberHi.withValues(alpha: emberOpacity),
              ForgeColors.ember.withValues(alpha: emberOpacity),
              ForgeColors.emberLo.withValues(alpha: emberOpacity),
            ],
            stops: const [0, 0.48, 1],
          ).createShader(star.getBounds()),
      );
      // White-hot core.
      canvas.drawCircle(
        c,
        62,
        Paint()
          ..shader = RadialGradient(
            colors: [
              ForgeColors.ivory.withValues(alpha: 0.95 * emberOpacity),
              ForgeColors.emberHi.withValues(alpha: 0.55 * emberOpacity),
              ForgeColors.emberHi.withValues(alpha: 0),
            ],
            stops: const [0, 0.35, 1],
          ).createShader(Rect.fromCircle(center: c, radius: 62)),
      );
      canvas.drawCircle(
        c,
        13,
        Paint()..color = ForgeColors.ivory.withValues(alpha: emberOpacity),
      );
    }
    canvas.restore();
    canvas.restore();
  }

  /// Four-arm concave star, horizontally dominant. Wide and low reads as a
  /// spark struck off metal; tall and narrow would read as TALA's star.
  Path _starPath(Offset c) {
    const rx = _starRx, ry = _starRy;
    const kx = _starK * rx, ky = _starK * ry;
    return Path()
      ..moveTo(c.dx, c.dy - ry)
      ..quadraticBezierTo(c.dx + kx, c.dy - ky, c.dx + rx, c.dy)
      ..quadraticBezierTo(c.dx + kx, c.dy + ky, c.dx, c.dy + ry)
      ..quadraticBezierTo(c.dx - kx, c.dy + ky, c.dx - rx, c.dy)
      ..quadraticBezierTo(c.dx - kx, c.dy - ky, c.dx, c.dy - ry)
      ..close();
  }

  @override
  bool shouldRepaint(_HearthDialPainter old) =>
      old.progress != progress ||
      old.emberOpacity != emberOpacity ||
      old.emberScale != emberScale ||
      old.tickOpacity != tickOpacity ||
      old.showTicks != showTicks ||
      old.showMarker != showMarker ||
      old.showBloom != showBloom;
}
