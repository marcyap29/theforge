import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// The Base View **v2** world, rendered with Flame (see
/// `DOCS/forge/base_view_v2_plan.md`).
///
/// Phase A1: an empty world that just renders — this proves Flame is embedded
/// and coexists with the v1 widget scene behind a toggle. The isometric hex
/// grid (A2), the Riverpod→Flame sync bridge (A3), and robots (B) build on top
/// of this shell.
class BaseFlameGame extends FlameGame {
  BaseFlameGame();

  @override
  Color backgroundColor() => const Color(0xFF0C1016);

  @override
  Future<void> onLoad() async {
    // Placeholder marker so it's unmistakably the Flame world during build-out.
    add(
      TextComponent(
        text: 'Flame world — v2 (WIP)',
        position: Vector2(24, 24),
        textRenderer: TextPaint(
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
      ),
    );
  }
}
