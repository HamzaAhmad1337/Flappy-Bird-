import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';

/// A full-screen rain system: hundreds of slanted streaks driven by wind,
/// plus little splashes when a drop hits the ground line. Drawn as batched
/// lines for performance.
class Rain extends PositionComponent {
  Rain() : super(priority: 100);

  final Random _rng = Random();
  final List<_Drop> _drops = [];
  final List<_Splash> _splashes = [];

  /// Endpoint buffer reused every frame so the whole downpour is a single
  /// drawRawPoints call instead of one drawLine per drop.
  late final Float32List _segments = Float32List(GameConfig.rainCount * 4);

  static const double _w = GameConfig.width;
  static const double _h = GameConfig.height;
  double get _groundY => _h - GameConfig.groundHeight + 8;

  @override
  Future<void> onLoad() async {
    size = Vector2(_w, _h);
    for (int i = 0; i < GameConfig.rainCount; i++) {
      _drops.add(_spawnDrop(initial: true));
    }
  }

  _Drop _spawnDrop({bool initial = false}) {
    return _Drop(
      x: _rng.nextDouble() * (_w + 160) - 80,
      y: initial ? _rng.nextDouble() * _h : -20 - _rng.nextDouble() * 60,
      speed: GameConfig.rainMinSpeed +
          _rng.nextDouble() * (GameConfig.rainMaxSpeed - GameConfig.rainMinSpeed),
      length: GameConfig.rainLengthMin +
          _rng.nextDouble() * (GameConfig.rainLengthMax - GameConfig.rainLengthMin),
      alpha: 0.35 + _rng.nextDouble() * 0.55,
    );
  }

  @override
  void update(double dt) {
    for (final d in _drops) {
      d.y += d.speed * dt;
      d.x += GameConfig.rainWindX * dt;
      if (d.y >= _groundY) {
        if (_splashes.length < 90 && _rng.nextDouble() < 0.5) {
          _splashes.add(_Splash(x: d.x, y: _groundY));
        }
        final nd = _spawnDrop();
        d
          ..x = nd.x
          ..y = nd.y
          ..speed = nd.speed
          ..length = nd.length
          ..alpha = nd.alpha;
      }
    }
    for (final s in _splashes) {
      s.t += dt;
    }
    _splashes.removeWhere((s) => s.t > s.life);
  }

  @override
  void render(Canvas canvas) {
    // Slant direction from wind + gravity.
    const slant = Offset(GameConfig.rainWindX, GameConfig.rainMaxSpeed);
    final norm = slant / slant.distance;

    // All drops share one colour so they can go out in a single batched call;
    // per-drop alpha is folded into the drop's length/brightness instead.
    var n = 0;
    for (final d in _drops) {
      final i = n * 4;
      final len = d.length * (0.55 + d.alpha * 0.45);
      _segments[i] = d.x;
      _segments[i + 1] = d.y;
      _segments[i + 2] = d.x - norm.dx * len;
      _segments[i + 3] = d.y - norm.dy * len;
      n++;
    }
    if (n > 0) {
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.sublistView(_segments, 0, n * 4),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.6
          ..color = GameConfig.rainColor.withValues(alpha: 0.62),
      );
    }
    // Splashes: expanding faint arcs on the ground.
    final splashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final s in _splashes) {
      final p = s.t / s.life;
      final r = 2 + p * 8;
      splashPaint.color = GameConfig.rainColor.withValues(alpha: (1 - p) * 0.5);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(s.x, s.y), radius: r),
        pi, // top half only
        pi,
        false,
        splashPaint,
      );
    }
  }
}

class _Drop {
  _Drop({
    required this.x,
    required this.y,
    required this.speed,
    required this.length,
    required this.alpha,
  });
  double x;
  double y;
  double speed;
  double length;
  double alpha;
}

class _Splash {
  _Splash({required this.x, required this.y});
  final double x;
  final double y;
  double t = 0;
  final double life = 0.4;
}
