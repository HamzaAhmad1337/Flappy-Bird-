import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/flappy_game.dart';
import 'glow_sprite.dart';

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

  // Baked glow textures. Every mote and mist puff is a quad sampling one of
  // these instead of its own blur pass — motes are further batched into a
  // single drawAtlas call.
  GlowSprite? _glow;
  GlowSprite? _puff;
  Float32List? _atlasXf;
  Float32List? _atlasRects;
  Int32List? _atlasColors;

  static const double _w = GameConfig.width;
  static const double _h = GameConfig.height;
  static const double _groundY = _h - GameConfig.groundHeight;

  @override
  Future<void> onLoad() async {
    size = Vector2(_w, _h);
    _glow = await GlowSprite.create(size: 48, softness: 0.7);
    _puff = await GlowSprite.create(size: 96, softness: 1.6);
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
    // Pre-size the atlas buffers: 4 floats per transform (scale, rot, tx, ty),
    // 4 per source rect, 1 colour.
    _atlasXf = Float32List(_motes.length * 4);
    _atlasRects = Float32List(_motes.length * 4);
    _atlasColors = Int32List(_motes.length);

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
    final scroll =
        (game.state == GameState.playing ? game.scrollSpeed : 26.0) * 0.18;
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
    final glow = _glow;
    final xf = _atlasXf;
    final rects = _atlasRects;
    final colors = _atlasColors;
    if (glow == null || xf == null || rects == null || colors == null) return;

    // Night: warm fireflies that pulse. Day: cool dust catching the light.
    const firefly = Color(0xFFFFE9A8);
    const dust = Color(0xFFFFFFFF);
    final src = Rect.fromLTWH(
        0, 0, glow.image.width.toDouble(), glow.image.height.toDouble());
    final texR = glow.radius;

    var n = 0;
    for (final m in _motes) {
      final y = m.y + sin(_t * m.bobSpeed + m.phase) * m.bobAmp;
      final pulse = 0.5 + 0.5 * sin(_t * 2.2 + m.phase * 2.0);

      final double alpha;
      final Color tint;
      final double drawR;
      if (night > 0.05) {
        alpha = night * (0.25 + 0.75 * pulse);
        tint = firefly;
        drawR = m.size * 3.6;
      } else if (dayness > 0.05) {
        alpha = dayness * 0.20 * (0.5 + pulse * 0.5);
        tint = dust;
        drawR = m.size * 1.8;
      } else {
        continue;
      }

      // RSTransform laid out by hand: (scos, ssin, tx, ty) with the sprite's
      // centre as the anchor.
      final scale = drawR / texR;
      final i = n * 4;
      xf[i] = scale;
      xf[i + 1] = 0;
      xf[i + 2] = m.x - drawR;
      xf[i + 3] = y - drawR;
      rects[i] = src.left;
      rects[i + 1] = src.top;
      rects[i + 2] = src.right;
      rects[i + 3] = src.bottom;
      colors[n] = tint.withValues(alpha: alpha.clamp(0.0, 1.0)).toARGB32();
      n++;
    }
    if (n == 0) return;

    // One draw call for every mote on screen.
    canvas.drawRawAtlas(
      glow.image,
      Float32List.sublistView(xf, 0, n * 4),
      Float32List.sublistView(rects, 0, n * 4),
      Int32List.sublistView(colors, 0, n),
      ui.BlendMode.modulate,
      null,
      Paint(),
    );
  }

  void _paintMist(Canvas canvas, double dayness) {
    final puff = _puff;
    if (puff == null) return;
    final src = Rect.fromLTWH(
        0, 0, puff.image.width.toDouble(), puff.image.height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.low;
    final tint =
        Color.lerp(const Color(0xFFBFD8E8), const Color(0xFFFFF1D6), dayness)!;

    for (final m in _mist) {
      final wobble = sin(_t * 0.6 + m.phase) * 4;
      paint.color =
          tint.withValues(alpha: 0.10 + 0.05 * sin(_t * 0.9 + m.phase).abs());
      canvas.drawImageRect(
        puff.image,
        src,
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
