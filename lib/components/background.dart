import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/flappy_game.dart';

/// A layered, parallax-scrolling storm sky: gradient sky, two mountain ranges,
/// a distant city silhouette and drifting clouds. Everything is drawn on the
/// canvas — no image assets required.
class Background extends PositionComponent with HasGameReference<FlappyGame> {
  Background() : super(priority: -100);

  final Random _rng = Random(42);

  // Parallax offsets (px). Each layer scrolls at a fraction of the world speed.
  double _farOffset = 0;
  double _nearOffset = 0;
  double _cityOffset = 0;
  final List<_Cloud> _clouds = [];

  // Cached mountain silhouettes so we don't rebuild the paths every frame.
  late final Path _farRange = _buildRange(seed: 7, amplitude: 70, step: 90);
  late final Path _nearRange = _buildRange(seed: 21, amplitude: 110, step: 70);
  late final Path _cityLine = _buildCity();

  static const double _w = GameConfig.width;
  static const double _h = GameConfig.height;

  @override
  Future<void> onLoad() async {
    size = Vector2(_w, _h);
    for (int i = 0; i < 5; i++) {
      _clouds.add(_Cloud(
        x: _rng.nextDouble() * _w,
        y: 40 + _rng.nextDouble() * 220,
        scale: 0.6 + _rng.nextDouble() * 0.9,
        speed: 6 + _rng.nextDouble() * 10,
      ));
    }
  }

  @override
  void update(double dt) {
    // Distant things scroll slower, creating depth. Always drift a little,
    // even on the menu, so the scene feels alive.
    final base = game.state == GameState.playing ? game.scrollSpeed : 26.0;
    _farOffset = (_farOffset + base * 0.08 * dt) % _w;
    _nearOffset = (_nearOffset + base * 0.16 * dt) % _w;
    _cityOffset = (_cityOffset + base * 0.28 * dt) % _w;
    for (final c in _clouds) {
      c.x -= c.speed * dt;
      if (c.x < -120) {
        c.x = _w + 60;
        c.y = 40 + _rng.nextDouble() * 220;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    _paintSky(canvas);
    _paintClouds(canvas);
    _paintRange(canvas, _farRange, _farOffset, GameConfig.mountainFar, 360);
    _paintRange(canvas, _nearRange, _nearOffset, GameConfig.mountainNear, 300);
    _paintCity(canvas);
    _paintHaze(canvas);
  }

  // ---- Sky -----------------------------------------------------------------
  void _paintSky(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, _w, _h);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(0, _h),
        const [
          GameConfig.skyTop,
          GameConfig.skyMid,
          GameConfig.skyBottom,
        ],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(rect, paint);
  }

  void _paintClouds(Canvas canvas) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (final c in _clouds) {
      canvas.save();
      canvas.translate(c.x, c.y);
      canvas.scale(c.scale);
      for (final b in const [
        Offset(0, 0),
        Offset(34, -12),
        Offset(70, 4),
        Offset(104, -6),
        Offset(48, 14),
      ]) {
        canvas.drawCircle(b, 30, paint);
      }
      canvas.restore();
    }
  }

  // ---- Mountains -----------------------------------------------------------
  Path _buildRange({required int seed, required double amplitude, required double step}) {
    final rng = Random(seed);
    // Build a range wider than the screen so it can wrap seamlessly.
    final path = Path()..moveTo(0, _h);
    double x = 0;
    double y = _h - 200 - rng.nextDouble() * amplitude;
    path.lineTo(0, y);
    final double totalWidth = _w * 2;
    while (x < totalWidth) {
      final nx = x + step;
      final ny = _h - 180 - rng.nextDouble() * amplitude;
      final cx = (x + nx) / 2;
      path.quadraticBezierTo(cx, min(y, ny) - 20, nx, ny);
      x = nx;
      y = ny;
    }
    path
      ..lineTo(totalWidth, _h)
      ..close();
    return path;
  }

  void _paintRange(Canvas canvas, Path range, double offset, Color color, double topY) {
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, topY),
        const Offset(0, _h),
        [color, color.withValues(alpha: 0.75)],
      );
    // Draw twice, offset by _w, for a seamless scroll.
    for (final dx in [-offset, _w - offset]) {
      canvas.save();
      canvas.translate(dx, 0);
      canvas.drawPath(range, paint);
      canvas.restore();
    }
  }

  // ---- City ----------------------------------------------------------------
  Path _buildCity() {
    final rng = Random(99);
    final path = Path()..moveTo(0, _h);
    double x = 0;
    final double baseY = _h - GameConfig.groundHeight - 6;
    final double totalWidth = _w * 2;
    while (x < totalWidth) {
      final bw = 26 + rng.nextDouble() * 34;
      final bh = 60 + rng.nextDouble() * 150;
      path
        ..lineTo(x, baseY - bh)
        ..lineTo(x + bw, baseY - bh)
        ..lineTo(x + bw, baseY);
      x += bw + rng.nextDouble() * 10;
    }
    path
      ..lineTo(totalWidth, _h)
      ..close();
    return path;
  }

  void _paintCity(Canvas canvas) {
    final paint = Paint()..color = GameConfig.cityColor.withValues(alpha: 0.9);
    for (final dx in [-_cityOffset, _w - _cityOffset]) {
      canvas.save();
      canvas.translate(dx, 0);
      canvas.drawPath(_cityLine, paint);
      canvas.restore();
    }
    // Warm window lights flicker faintly in the towers.
    final light = Paint()..color = const Color(0xFFFFCB6B).withValues(alpha: 0.10);
    final rng = Random(3);
    for (int i = 0; i < 60; i++) {
      final wx = rng.nextDouble() * _w;
      final wy = _h - GameConfig.groundHeight - 20 - rng.nextDouble() * 150;
      canvas.drawRect(Rect.fromLTWH(wx, wy, 2.5, 2.5), light);
    }
  }

  // A soft haze near the horizon adds atmospheric depth.
  void _paintHaze(Canvas canvas) {
    final r = Rect.fromLTWH(0, _h - GameConfig.groundHeight - 150, _w, 150);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        r.topLeft,
        r.bottomLeft,
        [
          GameConfig.skyBottom.withValues(alpha: 0.0),
          GameConfig.skyBottom.withValues(alpha: 0.35),
        ],
      );
    canvas.drawRect(r, paint);
  }
}

class _Cloud {
  _Cloud({required this.x, required this.y, required this.scale, required this.speed});
  double x;
  double y;
  final double scale;
  final double speed;
}
