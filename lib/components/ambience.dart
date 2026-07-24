import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/flappy_game.dart';

/// Ambient life that reacts to the time of day: fireflies drifting and pulsing
/// at night, sunlit motes floating by day, and a low band of mist rolling over
/// the ground. Purely decorative, but it stops the scene feeling static
/// between pipes.
class Ambience extends PositionComponent with HasGameReference<FlappyGame> {
  Ambience() : super(priority: 15);

  final Random _rng = Random(11);
  final List<_Mote> _motes = [];
  final List<_Mist> _mist = [];
  double _t = 0;

  static const double _w = GameConfig.width;
  static const double _h = GameConfig.height;
  static const double _groundY = _h - GameConfig.groundHeight;

  @override
  Future<void> onLoad() async {
    size = Vector2(_w, _h);
    for (int i = 0; i < 34; i++) {
      _motes.add(_Mote(
        x: _rng.nextDouble() * _w,
        y: 90 + _rng.nextDouble() * (_groundY - 110),
        drift: 5 + _rng.nextDouble() * 14,
        bobAmp: 6 + _rng.nextDouble() * 16,
        bobSpeed: 0.5 + _rng.nextDouble() * 1.3,
        phase: _rng.nextDouble() * pi * 2,
        size: 1.2 + _rng.nextDouble() * 2.2,
      ));
    }
    for (int i = 0; i < 7; i++) {
      _mist.add(_Mist(
        x: _rng.nextDouble() * _w,
        y: _groundY - 26 - _rng.nextDouble() * 34,
        w: 120 + _rng.nextDouble() * 200,
        h: 18 + _rng.nextDouble() * 26,
        speed: 4 + _rng.nextDouble() * 12,
        phase: _rng.nextDouble() * pi * 2,
      ));
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    // Ambient life drifts against the scroll, a touch slower than the world.
    final scroll = (game.state == GameState.playing ? game.scrollSpeed : 26.0) * 0.18;
    for (final m in _motes) {
      m.x -= (m.drift + scroll) * dt;
      if (m.x < -12) {
        m.x = _w + 12;
        m.y = 90 + _rng.nextDouble() * (_groundY - 110);
      }
    }
    for (final m in _mist) {
      m.x -= (m.speed + scroll * 1.4) * dt;
      if (m.x + m.w < -20) {
        m.x = _w + 40;
        m.y = _groundY - 26 - _rng.nextDouble() * 34;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (game.reducedMotion) return;

    final phase = game.skyPhase;
    final dayness = (0.5 + 0.5 * cos((phase - 0.25) * 2 * pi)).clamp(0.0, 1.0);
    final night = 1 - dayness;

    _paintMist(canvas, dayness);
    _paintMotes(canvas, dayness, night);
  }

  void _paintMotes(Canvas canvas, double dayness, double night) {
    // Night: warm fireflies that pulse. Day: cool dust catching the light.
    const fireflyColor = Color(0xFFFFE9A8);
    const dustColor = Color(0xFFFFFFFF);
    final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final core = Paint();

    for (final m in _motes) {
      final y = m.y + sin(_t * m.bobSpeed + m.phase) * m.bobAmp;
      final pulse = 0.5 + 0.5 * sin(_t * 2.2 + m.phase * 2.0);

      if (night > 0.05) {
        final a = night * (0.25 + 0.75 * pulse);
        glow.color = fireflyColor.withValues(alpha: a * 0.5);
        canvas.drawCircle(Offset(m.x, y), m.size * 3.4, glow);
        core.color = fireflyColor.withValues(alpha: a);
        canvas.drawCircle(Offset(m.x, y), m.size, core);
      }
      if (dayness > 0.05) {
        core.color = dustColor.withValues(alpha: dayness * 0.16 * (0.5 + pulse * 0.5));
        canvas.drawCircle(Offset(m.x, y), m.size * 0.9, core);
      }
    }
  }

  void _paintMist(Canvas canvas, double dayness) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    for (final m in _mist) {
      final wobble = sin(_t * 0.6 + m.phase) * 4;
      paint.color = Color.lerp(
        const Color(0xFFBFD8E8),
        const Color(0xFFFFF1D6),
        dayness,
      )!
          .withValues(alpha: 0.10 + 0.05 * sin(_t * 0.9 + m.phase).abs());
      canvas.drawOval(
        Rect.fromLTWH(m.x, m.y + wobble, m.w, m.h),
        paint,
      );
    }
  }
}

class _Mote {
  _Mote({
    required this.x,
    required this.y,
    required this.drift,
    required this.bobAmp,
    required this.bobSpeed,
    required this.phase,
    required this.size,
  });
  double x;
  double y;
  final double drift, bobAmp, bobSpeed, phase, size;
}

class _Mist {
  _Mist({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.speed,
    required this.phase,
  });
  double x;
  double y;
  final double w, h, speed, phase;
}
