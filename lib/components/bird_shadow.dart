import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/flappy_game.dart';

/// A soft contact shadow cast onto the wet ground beneath the bird.
///
/// Small, but it does more than its size suggests: without it the bird reads as
/// a sprite pasted over the scene, and with it the same sprite reads as an
/// object at a height *within* the scene. It tightens and darkens as the bird
/// drops, which is also a genuinely useful altitude cue in the moments when the
/// ground is about to become a problem.
class BirdShadow extends PositionComponent with HasGameReference<FlappyGame> {
  BirdShadow() : super(priority: 22); // above the ground and its reflections

  static const double _groundY = GameConfig.height - GameConfig.groundHeight;

  @override
  Future<void> onLoad() async {
    position = Vector2.zero();
    size = Vector2(GameConfig.width, GameConfig.height);
  }

  @override
  void render(Canvas canvas) {
    final bird = game.bird;
    // How far up the bird is, as a fraction of the playable column.
    final t = ((_groundY - bird.position.y) / _groundY).clamp(0.0, 1.0);

    // Directly beneath at ground level, drifting away as it climbs — the sky's
    // key light sits high and to the right, so the shadow falls left.
    final cx = bird.position.x - t * 26;
    final w = 52 - 18 * t;
    final h = w * 0.28;

    // Deliberately heavier than a shadow "should" be. Three translucent layers
    // are drawn over this one — ground mist, rain, and the lens overlay — and
    // measuring an opaque test fill through them showed they eat roughly half
    // of whatever lands here. At the physically tasteful alpha the shadow
    // survived only where the bird touched down, which is exactly where it is
    // least useful.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, _groundY + 7), width: w, height: h),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.52 * (1 - t) + 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 + 4 * t),
    );
  }
}
