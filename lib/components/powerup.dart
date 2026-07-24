import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/flappy_game.dart';
import '../services/assets.dart';

/// A floating power-up capsule. Bobs and glows in its type color, scrolls with
/// the world, and grants its effect when the bird touches it.
class PowerUp extends PositionComponent with HasGameReference<FlappyGame> {
  PowerUp(Vector2 pos, this.type)
      : _baseY = pos.y,
        super(position: pos, priority: 6, anchor: Anchor.center);

  final PowerType type;
  final double _baseY;
  bool collected = false;
  double _t = 0;

  static const double r = GameConfig.powerupRadius;

  @override
  Future<void> onLoad() async {
    size = Vector2.all(r * 2);
  }

  @override
  void update(double dt) {
    if (game.state != GameState.playing) return;
    _t += dt;
    position.x -= game.scrollSpeed * dt;
    position.y = _baseY + sin(_t * 3) * 8; // gentle bob
    if (position.x < -50) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    final pulse = 0.85 + sin(_t * 6) * 0.15;

    // Aura.
    canvas.drawCircle(
      Offset.zero, r * 1.5 * pulse,
      Paint()
        ..color = type.color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // Body: the offline-rendered glass orb, modulated to the type colour.
    final orb = GameAssets.image('orb');
    if (orb != null) {
      canvas.drawImageRect(
        orb,
        Rect.fromLTWH(0, 0, orb.width.toDouble(), orb.height.toDouble()),
        Rect.fromCenter(center: Offset.zero, width: r * 2.3, height: r * 2.3),
        Paint()
          ..filterQuality = FilterQuality.high
          ..colorFilter = ColorFilter.mode(type.color, BlendMode.modulate),
      );
    } else {
      final body = Paint()
        ..shader = ui.Gradient.radial(
          const Offset(-5, -5), r * 1.8,
          [Color.lerp(type.color, Colors.white, 0.5)!, type.color],
        );
      canvas.drawCircle(Offset.zero, r, body);
    }
    canvas.drawCircle(
      Offset.zero, r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    _drawIcon(canvas);
    canvas.restore();
  }

  void _drawIcon(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (type) {
      case PowerType.shield:
        final p = Path()
          ..moveTo(0, -r * 0.55)
          ..lineTo(r * 0.5, -r * 0.28)
          ..lineTo(r * 0.5, r * 0.12)
          ..quadraticBezierTo(r * 0.5, r * 0.55, 0, r * 0.62)
          ..quadraticBezierTo(-r * 0.5, r * 0.55, -r * 0.5, r * 0.12)
          ..lineTo(-r * 0.5, -r * 0.28)
          ..close();
        canvas.drawPath(p, paint..style = PaintingStyle.fill);
        break;
      case PowerType.slowmo:
        // clock
        canvas.drawCircle(Offset.zero, r * 0.5, paint..style = PaintingStyle.stroke);
        canvas.drawLine(Offset.zero, const Offset(0, -r * 0.34), paint);
        canvas.drawLine(Offset.zero, const Offset(r * 0.24, 0), paint);
        break;
      case PowerType.magnet:
        final rect = Rect.fromCircle(center: const Offset(0, r * 0.1), radius: r * 0.42);
        canvas.drawArc(rect, pi, pi, false, paint..style = PaintingStyle.stroke..strokeWidth = 4);
        canvas.drawLine(const Offset(-r * 0.42, r * 0.1), const Offset(-r * 0.42, r * 0.5), paint..strokeWidth = 4);
        canvas.drawLine(const Offset(r * 0.42, r * 0.1), const Offset(r * 0.42, r * 0.5), paint);
        break;
    }
  }
}
