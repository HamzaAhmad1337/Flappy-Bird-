import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/flappy_game.dart';
import '../game/skins.dart';
import '../services/assets.dart';

/// The player's bird. Handles gravity/velocity, tilts toward its direction of
/// travel, and draws a glossy bird using the currently selected skin — with an
/// optional aura for legendary skins and a shimmering shield ring when the
/// shield power-up is active.
class Bird extends PositionComponent with HasGameReference<FlappyGame> {
  Bird() : super(priority: 10, anchor: Anchor.center);

  double velocity = 0;
  double _wingPhase = 0;
  double _flapImpulse = 0;
  double _tilt = 0;
  double _trailTimer = 0;

  static const double r = GameConfig.birdRadius;

  BirdSkin get skin => game.skin;

  @override
  Future<void> onLoad() async {
    size = Vector2(r * 2.6, r * 2.2);
    reset();
  }

  void reset() {
    velocity = 0;
    _tilt = 0;
    position = Vector2(GameConfig.birdX, GameConfig.birdStartY);
  }

  void flap() {
    velocity = GameConfig.flapVelocity;
    _flapImpulse = 1;
    game.particles.feathers(position.x - 6, position.y + 4, skin.wing, count: 4);
  }

  void idleBob(double dt, double t) {
    position.y = GameConfig.birdStartY + sin(t * 3) * 8;
    _wingPhase += dt * 10;
    _tilt = sin(t * 3) * 0.12;
  }

  @override
  void update(double dt) {
    _wingPhase += dt * 16;
    _flapImpulse = max(0, _flapImpulse - dt * 4);

    if (game.state != GameState.playing) return;

    velocity = min(velocity + GameConfig.gravity * dt, GameConfig.maxFallSpeed);
    position.y += velocity * dt;

    final target = velocity < 0
        ? GameConfig.tiltUp
        : (GameConfig.tiltUp +
            (velocity / GameConfig.maxFallSpeed) *
                (GameConfig.tiltDown - GameConfig.tiltUp));
    _tilt += (target - _tilt) * min(1, dt * 10);

    // Flight trail.
    _trailTimer -= dt;
    if (_trailTimer <= 0 && !game.reducedMotion) {
      _trailTimer = 0.04;
      game.particles.trail(position.x - r, position.y + 3, skin.trail);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    if (skin.glow) {
      canvas.drawCircle(
        Offset.zero, r * 1.7,
        Paint()
          ..color = skin.trail.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    canvas.rotate(_tilt);

    // Preferred path: the offline-rendered 3D sprite sheet.
    final sheet = GameAssets.birdSheet(skin.id);
    if (sheet != null) {
      _drawSprite(canvas, sheet);
      canvas.restore();
      if (game.shieldActive) _drawShield(canvas);
      return;
    }

    _drawProcedural(canvas);
    canvas.restore();
    if (game.shieldActive) _drawShield(canvas);
  }

  /// Blits the current flap frame from the baked sheet.
  void _drawSprite(Canvas canvas, ui.Image sheet) {
    const frames = GameConfig.birdSheetFrames;
    final fw = sheet.width / frames;
    final fh = sheet.height.toDouble();
    final idx = ((_wingPhase / (2 * pi)) * frames).floor() % frames;
    final src = Rect.fromLTWH(idx.abs() * fw, 0, fw, fh);

    const w = r * GameConfig.birdSpriteScale;
    final h = w * fh / fw;
    canvas.drawImageRect(
      sheet,
      src,
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  /// Fallback: the original hand-drawn bird, used if the sheet failed to load.
  void _drawProcedural(Canvas canvas) {
    final glow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 3), width: r * 2.4, height: r * 1.9), glow);

    final bodyRect = Rect.fromCenter(center: Offset.zero, width: r * 2.3, height: r * 2.0);
    final body = Paint()
      ..shader = ui.Gradient.linear(
        bodyRect.topCenter,
        bodyRect.bottomCenter,
        [skin.hi, skin.body, skin.lo],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawOval(bodyRect, body);

    final belly = Paint()..color = skin.belly.withValues(alpha: 0.7);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-1, 5), width: r * 1.5, height: r * 1.1),
      belly,
    );

    _drawWing(canvas);
    _drawFace(canvas);
  }

  void _drawWing(Canvas canvas) {
    final flutter = sin(_wingPhase) * 0.35;
    final kick = _flapImpulse * -0.9;
    final angle = -0.15 + flutter + kick;

    canvas.save();
    canvas.translate(-2, -1);
    canvas.rotate(angle);
    final wingRect = Rect.fromCenter(center: const Offset(-4, 2), width: r * 1.7, height: r * 1.15);
    final wing = Paint()
      ..shader = ui.Gradient.linear(
        wingRect.topCenter,
        wingRect.bottomCenter,
        [Color.lerp(skin.wing, Colors.white, 0.25)!, skin.wing],
      );
    canvas.drawOval(wingRect, wing);
    canvas.drawOval(
      wingRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Color.lerp(skin.wing, Colors.black, 0.3)!.withValues(alpha: 0.6),
    );
    canvas.restore();
  }

  void _drawFace(Canvas canvas) {
    final beak = Paint()..color = skin.beak;
    final beakPath = Path()
      ..moveTo(r * 0.9, -2)
      ..lineTo(r * 1.9, 1)
      ..lineTo(r * 0.9, 5)
      ..close();
    canvas.drawPath(beakPath, beak);

    canvas.drawCircle(const Offset(6, -6), 6.2, Paint()..color = Colors.white);
    canvas.drawCircle(
      const Offset(6, -6),
      6.2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.12),
    );
    canvas.drawCircle(const Offset(7.6, -6), 2.8, Paint()..color = const Color(0xFF20303A));
    canvas.drawCircle(const Offset(8.6, -7.2), 1.0, Paint()..color = Colors.white);
  }

  void _drawShield(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    final t = game.shieldRemaining;
    // Blink faster as it's about to expire.
    final blink = t < 3 ? (sin(t * 18) * 0.5 + 0.5) : 1.0;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = PowerType.shield.color.withValues(alpha: 0.85 * blink);
    canvas.drawCircle(Offset.zero, r * 1.55, ring);
    canvas.drawCircle(
      Offset.zero, r * 1.55,
      Paint()
        ..color = PowerType.shield.color.withValues(alpha: 0.12 * blink)
        ..style = PaintingStyle.fill,
    );
    canvas.restore();
  }

  ({double x, double y, double r}) get bounds =>
      (x: position.x, y: position.y, r: r);
}
