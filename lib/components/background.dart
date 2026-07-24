import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/flappy_game.dart';
import 'sky_shader.dart';

/// A layered, parallax-scrolling storm sky with a full day → night cycle:
/// a shifting gradient, sun/moon crossfade, twinkling stars, mountains, a city
/// silhouette and drifting clouds. Everything is drawn on the canvas.
class Background extends PositionComponent with HasGameReference<FlappyGame> {
  Background() : super(priority: -100);

  final Random _rng = Random(42);

  double _farOffset = 0;
  double _nearOffset = 0;
  double _cityOffset = 0;
  final List<_Cloud> _clouds = [];
  final List<_Star> _stars = [];

  late final Path _farRange = _buildRange(seed: 7, amplitude: 70, step: 90);
  late final Path _nearRange = _buildRange(seed: 21, amplitude: 110, step: 70);
  late final Path _cityLine = _buildCity();

  static const double _w = GameConfig.width;
  static const double _h = GameConfig.height;

  // Sky keyframes: dawn, day, dusk, night. [top, mid, bottom].
  static const List<List<Color>> _skyKeys = [
    [Color(0xFF39456B), Color(0xFF7C6E97), Color(0xFFD98C6A)], // dawn
    [Color(0xFF13293D), Color(0xFF1B4965), Color(0xFF2C6E8F)], // day (stormy)
    [Color(0xFF2B1D3A), Color(0xFF7A3B5E), Color(0xFFD46A4A)], // dusk
    [Color(0xFF070C1C), Color(0xFF0E1D33), Color(0xFF16324A)], // night
  ];

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
    for (int i = 0; i < 70; i++) {
      _stars.add(_Star(
        x: _rng.nextDouble() * _w,
        y: _rng.nextDouble() * (_h * 0.6),
        size: 0.6 + _rng.nextDouble() * 1.6,
        phase: _rng.nextDouble() * pi * 2,
      ));
    }
  }

  @override
  void update(double dt) {
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
    for (final s in _stars) {
      s.phase += dt * 2.5;
    }
  }

  // Interpolate the sky palette for the current phase (0..1 around the clock).
  List<Color> _skyFor(double phase) {
    final scaled = (phase % 1.0) * 4.0; // 0..4 over dawn/day/dusk/night
    final i = scaled.floor() % 4;
    final j = (i + 1) % 4;
    final t = scaled - scaled.floor();
    return [
      Color.lerp(_skyKeys[i][0], _skyKeys[j][0], t)!,
      Color.lerp(_skyKeys[i][1], _skyKeys[j][1], t)!,
      Color.lerp(_skyKeys[i][2], _skyKeys[j][2], t)!,
    ];
  }

  @override
  void render(Canvas canvas) {
    final phase = game.skyPhase;
    // Dayness: 1 at midday (phase .25), 0 at midnight (phase .75).
    final dayness = (0.5 + 0.5 * cos((phase - 0.25) * 2 * pi)).clamp(0.0, 1.0);
    final nightAmount = 1 - dayness;

    // When the GPU sky is active it already renders the gradient, sun/moon,
    // stars and volumetric clouds — we only add the terrain silhouettes on top.
    if (!SkyShaderLayer.available) {
      _paintSky(canvas, phase);
      _paintStars(canvas, nightAmount);
      _paintCelestial(canvas, dayness, nightAmount, phase);
      _paintClouds(canvas, dayness);
    }
    _paintRange(canvas, _farRange, _farOffset, GameConfig.mountainFar, 360, nightAmount);
    _paintRange(canvas, _nearRange, _nearOffset, GameConfig.mountainNear, 300, nightAmount);
    _paintCity(canvas, nightAmount);
    _paintHaze(canvas);
  }

  void _paintSky(Canvas canvas, double phase) {
    final colors = _skyFor(phase);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(0, _h),
        colors,
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, _w, _h), paint);
  }

  void _paintStars(Canvas canvas, double nightAmount) {
    if (nightAmount <= 0.02) return;
    final paint = Paint();
    for (final s in _stars) {
      final twinkle = 0.5 + 0.5 * sin(s.phase);
      paint.color = Colors.white.withValues(alpha: nightAmount * twinkle * 0.9);
      canvas.drawCircle(Offset(s.x, s.y), s.size, paint);
    }
  }

  void _paintCelestial(Canvas canvas, double dayness, double nightAmount, double phase) {
    // Sun and moon share an arc; each fades with time of day.
    const arcX = _w * 0.72;
    final arcY = 120 + sin(phase * 2 * pi) * 30;

    if (dayness > 0.02) {
      canvas.drawCircle(
        Offset(arcX, arcY), 60,
        Paint()
          ..color = const Color(0xFFFFE9A8).withValues(alpha: dayness * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
      canvas.drawCircle(
        Offset(arcX, arcY), 30,
        Paint()..color = const Color(0xFFFFF2C4).withValues(alpha: dayness),
      );
    }
    if (nightAmount > 0.02) {
      canvas.drawCircle(
        Offset(arcX, arcY), 50,
        Paint()
          ..color = const Color(0xFFDDE8FF).withValues(alpha: nightAmount * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      );
      final moon = Paint()..color = const Color(0xFFEAF0FF).withValues(alpha: nightAmount);
      canvas.drawCircle(Offset(arcX, arcY), 26, moon);
      // Crater shadow to give the moon a crescent-ish read.
      canvas.drawCircle(
        Offset(arcX + 12, arcY - 6), 24,
        Paint()..color = _skyFor(phase)[0].withValues(alpha: nightAmount),
      );
    }
  }

  void _paintClouds(Canvas canvas, double dayness) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05 + dayness * 0.03);
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

  Path _buildRange({required int seed, required double amplitude, required double step}) {
    final rng = Random(seed);
    final path = Path()..moveTo(0, _h);
    double x = 0;
    double y = _h - 200 - rng.nextDouble() * amplitude;
    path.lineTo(0, y);
    const double totalWidth = _w * 2;
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

  void _paintRange(Canvas canvas, Path range, double offset, Color color, double topY, double nightAmount) {
    final c = Color.lerp(color, const Color(0xFF0A1526), nightAmount * 0.6)!;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, topY),
        const Offset(0, _h),
        [c, c.withValues(alpha: 0.75)],
      );
    for (final dx in [-offset, _w - offset]) {
      canvas.save();
      canvas.translate(dx, 0);
      canvas.drawPath(range, paint);
      canvas.restore();
    }
  }

  Path _buildCity() {
    final rng = Random(99);
    final path = Path()..moveTo(0, _h);
    double x = 0;
    const double baseY = _h - GameConfig.groundHeight - 6;
    const double totalWidth = _w * 2;
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

  void _paintCity(Canvas canvas, double nightAmount) {
    final paint = Paint()..color = GameConfig.cityColor.withValues(alpha: 0.9);
    for (final dx in [-_cityOffset, _w - _cityOffset]) {
      canvas.save();
      canvas.translate(dx, 0);
      canvas.drawPath(_cityLine, paint);
      canvas.restore();
    }
    // Window lights glow brighter at night.
    final light = Paint()
      ..color = const Color(0xFFFFCB6B).withValues(alpha: 0.08 + nightAmount * 0.35);
    final rng = Random(3);
    for (int i = 0; i < 60; i++) {
      final wx = rng.nextDouble() * _w;
      final wy = _h - GameConfig.groundHeight - 20 - rng.nextDouble() * 150;
      canvas.drawRect(Rect.fromLTWH(wx, wy, 2.5, 2.5), light);
    }
  }

  void _paintHaze(Canvas canvas) {
    const r = Rect.fromLTWH(0, _h - GameConfig.groundHeight - 150, _w, 150);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        r.topLeft,
        r.bottomLeft,
        [
          GameConfig.skyBottom.withValues(alpha: 0.0),
          GameConfig.skyBottom.withValues(alpha: 0.30),
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

class _Star {
  _Star({required this.x, required this.y, required this.size, required this.phase});
  final double x;
  final double y;
  final double size;
  double phase;
}
