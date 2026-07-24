import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A lightweight, allocation-friendly particle field. One instance lives in
/// the world and everything (feather puffs on flap, coin sparkles, death
/// bursts, flight trails) is emitted through it.
class ParticleField extends PositionComponent {
  ParticleField() : super(priority: 30);

  final List<_P> _parts = [];
  final Random _rng = Random();

  @override
  void update(double dt) {
    for (final p in _parts) {
      p.vx *= p.drag;
      p.vy = p.vy * p.drag + p.gravity * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      p.rot += p.spin * dt;
    }
    _parts.removeWhere((p) => p.life <= 0);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint();
    for (final p in _parts) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: a * p.alpha);
      if (p.kind == _Kind.circle) {
        canvas.drawCircle(Offset(p.x, p.y), p.size * a, paint);
      } else if (p.kind == _Kind.spark) {
        canvas.save();
        canvas.translate(p.x, p.y);
        canvas.rotate(p.rot);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size * 2.2 * a, height: p.size * 0.5),
          paint,
        );
        canvas.restore();
      } else {
        // feather: little rounded oval
        canvas.save();
        canvas.translate(p.x, p.y);
        canvas.rotate(p.rot);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: p.size * 1.8, height: p.size * a),
          paint,
        );
        canvas.restore();
      }
    }
  }

  // ---- Emitters ------------------------------------------------------------

  void trail(double x, double y, Color color) {
    _parts.add(_P(
      x: x, y: y,
      vx: -40 - _rng.nextDouble() * 30, vy: _rng.nextDouble() * 20 - 10,
      gravity: 0, drag: 0.94, life: 0.5, maxLife: 0.5,
      size: 3 + _rng.nextDouble() * 2, color: color, alpha: 0.5,
      kind: _Kind.circle,
    ));
  }

  void feathers(double x, double y, Color color, {int count = 5}) {
    for (int i = 0; i < count; i++) {
      final ang = _rng.nextDouble() * pi * 2;
      final sp = 60 + _rng.nextDouble() * 120;
      _parts.add(_P(
        x: x, y: y,
        vx: cos(ang) * sp - 40, vy: sin(ang) * sp,
        gravity: 260, drag: 0.96, life: 0.6 + _rng.nextDouble() * 0.4,
        maxLife: 1.0, size: 3 + _rng.nextDouble() * 3, color: color, alpha: 0.9,
        rot: _rng.nextDouble() * pi, spin: (_rng.nextDouble() - 0.5) * 8,
        kind: _Kind.feather,
      ));
    }
  }

  void sparkle(double x, double y, Color color, {int count = 10}) {
    for (int i = 0; i < count; i++) {
      final ang = _rng.nextDouble() * pi * 2;
      final sp = 80 + _rng.nextDouble() * 160;
      _parts.add(_P(
        x: x, y: y,
        vx: cos(ang) * sp, vy: sin(ang) * sp,
        gravity: 40, drag: 0.90, life: 0.4 + _rng.nextDouble() * 0.4,
        maxLife: 0.8, size: 2 + _rng.nextDouble() * 3, color: color, alpha: 1.0,
        rot: ang, spin: (_rng.nextDouble() - 0.5) * 12,
        kind: _Kind.spark,
      ));
    }
  }

  void burst(double x, double y, Color color, {int count = 26}) {
    for (int i = 0; i < count; i++) {
      final ang = _rng.nextDouble() * pi * 2;
      final sp = 120 + _rng.nextDouble() * 260;
      _parts.add(_P(
        x: x, y: y,
        vx: cos(ang) * sp, vy: sin(ang) * sp - 60,
        gravity: 420, drag: 0.95, life: 0.6 + _rng.nextDouble() * 0.6,
        maxLife: 1.2, size: 3 + _rng.nextDouble() * 4, color: color, alpha: 1.0,
        rot: ang, spin: (_rng.nextDouble() - 0.5) * 14,
        kind: i.isEven ? _Kind.feather : _Kind.spark,
      ));
    }
  }

  /// A celebratory shower of coloured ribbons that flutter as they fall.
  void confetti(double x, double y, {int count = 30}) {
    const palette = [
      Color(0xFFFFD447), Color(0xFF7FC4FF), Color(0xFFFF7A9C),
      Color(0xFF9BF6D8), Color(0xFFE5B3FF), Color(0xFFFFFFFF),
    ];
    for (int i = 0; i < count; i++) {
      final ang = -pi / 2 + (_rng.nextDouble() - 0.5) * 2.4;
      final sp = 160 + _rng.nextDouble() * 260;
      _parts.add(_P(
        x: x, y: y,
        vx: cos(ang) * sp, vy: sin(ang) * sp,
        gravity: 520, drag: 0.985,
        life: 0.9 + _rng.nextDouble() * 0.7, maxLife: 1.6,
        size: 3 + _rng.nextDouble() * 3.5,
        color: palette[_rng.nextInt(palette.length)], alpha: 1.0,
        rot: _rng.nextDouble() * pi, spin: (_rng.nextDouble() - 0.5) * 18,
        kind: _Kind.spark,
      ));
    }
  }

  void clear() => _parts.clear();
}

enum _Kind { circle, feather, spark }

class _P {
  _P({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.gravity, required this.drag,
    required this.life, required this.maxLife,
    required this.size, required this.color, required this.alpha,
    required this.kind,
    this.rot = 0, this.spin = 0,
  });

  double x, y, vx, vy, gravity, drag, life, rot, spin;
  final double maxLife, size, alpha;
  final Color color;
  final _Kind kind;
}
