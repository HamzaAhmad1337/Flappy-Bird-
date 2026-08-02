import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/flappy_game.dart';
import '../services/assets.dart';

/// A seamless, scrolling ground strip: a grassy top edge over wet dirt with
/// texture flecks. Scrolls at the game speed and loops forever.
class Ground extends PositionComponent with HasGameReference<FlappyGame> {
  Ground() : super(priority: 20);

  double _offset = 0;
  final Random _rng = Random(5);
  late final List<Offset> _flecks;

  static const double _w = GameConfig.width;
  static const double _h = GameConfig.groundHeight;

  @override
  Future<void> onLoad() async {
    position = Vector2(0, GameConfig.height - _h);
    size = Vector2(_w, _h);
    // Pre-generate dirt flecks across a double-width tile for seamless scroll.
    _flecks = List.generate(120, (_) {
      return Offset(
          _rng.nextDouble() * _w * 2, 18 + _rng.nextDouble() * (_h - 24));
    });
  }

  @override
  void update(double dt) {
    final speed = game.state == GameState.playing ? game.scrollSpeed : 26.0;
    _offset = (_offset + speed * dt) % _w;
  }

  @override
  void render(Canvas canvas) {
    // Preferred path: the offline-rendered wet embankment.
    //
    // Drawn with a repeating ImageShader rather than tile-by-tile blits: manual
    // tiling clamps at the texture edges and leaves a visible seam at every
    // repeat, whereas TileMode.repeated wraps correctly on the GPU (and is a
    // single draw call).
    final tex = GameAssets.image('ground');
    if (tex != null) {
      const tile = 192.0; // logical px per texture repeat
      // Column-major 4x4: scale texture -> tile size, then translate by the
      // scroll offset. (Built by hand because `Matrix4` is ambiguous here:
      // Flame exports vector_math while Flutter exports vector_math_64.)
      final sx = tile / tex.width;
      final sy = _h / tex.height;
      final tx = -(_offset % tile);
      final m = Float64List.fromList([
        sx,
        0,
        0,
        0,
        0,
        sy,
        0,
        0,
        0,
        0,
        1,
        0,
        tx,
        0,
        0,
        1,
      ]);
      final paint = Paint()
        ..filterQuality = FilterQuality.medium
        // Track the sky, or the ground stays daylit under a midnight storm.
        ..colorFilter = ColorFilter.mode(game.worldTint, BlendMode.modulate)
        ..shader = ImageShader(
          tex,
          TileMode.repeated,
          TileMode.clamp,
          m,
          filterQuality: FilterQuality.medium,
        );
      canvas.drawRect(const Rect.fromLTWH(0, 0, _w, _h), paint);
      return;
    }

    // Dirt base.
    const dirtRect = Rect.fromLTWH(0, 0, _w, _h);
    final dirt = Paint()
      ..shader = ui.Gradient.linear(
        dirtRect.topLeft,
        dirtRect.bottomLeft,
        const [Color(0xFF7A5433), GameConfig.groundDirt, Color(0xFF4E3620)],
      );
    canvas.drawRect(dirtRect, dirt);

    // Scrolling dirt flecks.
    final fleck = Paint()..color = Colors.black.withValues(alpha: 0.14);
    for (final f in _flecks) {
      double fx = (f.dx - _offset) % (_w);
      if (fx < 0) fx += _w;
      canvas.drawCircle(Offset(fx, f.dy), 1.6, fleck);
    }

    // Grass strip along the top with a scalloped lower edge.
    const grassH = 26.0;
    const grassRect = Rect.fromLTWH(0, 0, _w, grassH);
    final grass = Paint()
      ..shader = ui.Gradient.linear(
        grassRect.topLeft,
        grassRect.bottomLeft,
        const [Color(0xFF8FD65B), GameConfig.groundGrass, Color(0xFF4E9A34)],
      );
    canvas.drawRect(grassRect, grass);

    // Scalloped grass blades hanging into the dirt, scrolling.
    final blade = Paint()..color = GameConfig.groundGrass;
    const bladeW = 16.0;
    for (double x = -((_offset) % bladeW) - bladeW;
        x < _w + bladeW;
        x += bladeW) {
      final path = Path()
        ..moveTo(x, grassH - 2)
        ..quadraticBezierTo(x + bladeW / 2, grassH + 8, x + bladeW, grassH - 2)
        ..close();
      canvas.drawPath(path, blade);
    }

    // A darker line where grass meets dirt.
    canvas.drawRect(
      const Rect.fromLTWH(0, grassH + 4, _w, 2),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    // Wet sheen highlight near the top (it's raining).
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _w, 3),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }
}
