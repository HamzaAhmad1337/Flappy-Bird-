import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';

/// Occasional lightning: a bright full-screen flash paired with a jagged bolt
/// that forks down the sky. Timed randomly for an unpredictable storm feel.
class Lightning extends PositionComponent {
  Lightning() : super(priority: 90);

  final Random _rng = Random();
  double _timer = 0;
  double _nextStrike = 4;

  // Flash envelope: 0 = dark, 1 = full white flash.
  double _flash = 0;
  Path? _bolt;
  double _boltLife = 0;

  static const double _w = GameConfig.width;
  static const double _h = GameConfig.height;

  @override
  Future<void> onLoad() async {
    size = Vector2(_w, _h);
    _scheduleNext();
  }

  void _scheduleNext() {
    _nextStrike = GameConfig.lightningMinDelay +
        _rng.nextDouble() * (GameConfig.lightningMaxDelay - GameConfig.lightningMinDelay);
    _timer = 0;
  }

  void _strike() {
    _flash = 1;
    _boltLife = 0.35;
    _bolt = _buildBolt();
  }

  Path _buildBolt() {
    final path = Path();
    double x = 40 + _rng.nextDouble() * (_w - 80);
    double y = 0;
    path.moveTo(x, y);
    final segments = 8 + _rng.nextInt(5);
    final segLen = (_h * 0.7) / segments;
    for (int i = 0; i < segments; i++) {
      x += (_rng.nextDouble() - 0.5) * 60;
      y += segLen;
      path.lineTo(x, y);
      // Occasional fork.
      if (_rng.nextDouble() < 0.25) {
        double fx = x, fy = y;
        for (int j = 0; j < 3; j++) {
          fx += (_rng.nextDouble() - 0.5) * 50;
          fy += segLen * 0.7;
          path.lineTo(fx, fy);
        }
        path.moveTo(x, y);
      }
    }
    return path;
  }

  @override
  void update(double dt) {
    _timer += dt;
    if (_timer >= _nextStrike) {
      _strike();
      _scheduleNext();
      // Occasional quick double-flash.
      if (_rng.nextDouble() < 0.4) _nextStrike = 0.18;
    }
    if (_flash > 0) {
      _flash = max(0, _flash - dt * 3.2);
    }
    if (_boltLife > 0) {
      _boltLife = max(0, _boltLife - dt);
    }
  }

  @override
  void render(Canvas canvas) {
    if (_flash > 0) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: _flash * 0.35);
      canvas.drawRect(Rect.fromLTWH(0, 0, _w, _h), paint);
    }
    if (_bolt != null && _boltLife > 0) {
      final a = (_boltLife / 0.35).clamp(0.0, 1.0);
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = const Color(0xFFBFE9FF).withValues(alpha: a * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      final core = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: a);
      canvas.drawPath(_bolt!, glow);
      canvas.drawPath(_bolt!, core);
    }
  }
}
