import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/flappy_game.dart';

/// A collectible coin. Scrolls with the world and, when the magnet power-up is
/// active, is pulled toward the bird. Spins for a little shine.
class Coin extends PositionComponent with HasGameReference<FlappyGame> {
  Coin(Vector2 pos) : super(position: pos, priority: 6, anchor: Anchor.center);

  bool collected = false;
  double _spin = 0;

  static const double r = GameConfig.coinRadius;

  @override
  Future<void> onLoad() async {
    size = Vector2.all(r * 2);
  }

  @override
  void update(double dt) {
    if (game.state != GameState.playing) return;
    _spin += dt * 4;

    // Base leftward scroll.
    position.x -= game.scrollSpeed * dt;

    // Magnet attraction.
    if (game.magnetActive) {
      final bp = game.bird.position;
      final d = bp - position;
      final dist = d.length;
      if (dist > 0.01 && dist < GameConfig.magnetRadius) {
        final pull = (1 - dist / GameConfig.magnetRadius) * 620;
        position.add(d / dist * pull * dt);
      }
    }

    if (position.x < -40) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    // Squash horizontally to fake a spin.
    final sx = (cos(_spin)).abs().clamp(0.25, 1.0);
    canvas.scale(sx, 1.0);

    final face = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(-4, -4), r * 1.6,
        const [Color(0xFFFFF3B0), Color(0xFFFFC93C), Color(0xFFC8860B)],
        const [0.0, 0.6, 1.0],
      );
    canvas.drawCircle(Offset.zero, r, face);
    canvas.drawCircle(
      Offset.zero, r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFF8A5D00),
    );
    // Inner ring + star.
    canvas.drawCircle(
      Offset.zero, r * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFFFFF3B0).withValues(alpha: 0.8),
    );
    _drawStar(canvas, r * 0.5, const Color(0xFF8A5D00));
    // Glint.
    canvas.drawCircle(const Offset(-r * 0.4, -r * 0.4), r * 0.16, Paint()..color = Colors.white.withValues(alpha: 0.9));
    canvas.restore();
  }

  void _drawStar(Canvas canvas, double radius, Color color) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outer = -pi / 2 + i * 2 * pi / 5;
      final inner = outer + pi / 5;
      final ox = cos(outer) * radius, oy = sin(outer) * radius;
      final ix = cos(inner) * radius * 0.45, iy = sin(inner) * radius * 0.45;
      if (i == 0) {
        path.moveTo(ox, oy);
      } else {
        path.lineTo(ox, oy);
      }
      path.lineTo(ix, iy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }
}
