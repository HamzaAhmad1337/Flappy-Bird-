import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/flappy_game.dart';
import '../services/assets.dart';

/// Wet-ground reflections.
///
/// Mirrors the pipes and the bird into the top of the ground strip, faded with
/// depth and rippled. It's a cheap trick — the reflected sprites are drawn
/// flipped into an offscreen layer and masked out with a gradient — but it does
/// more for the rain-soaked mood than almost anything else on screen.
class Reflections extends PositionComponent with HasGameReference<FlappyGame> {
  Reflections() : super(priority: 21); // just above the ground

  double _t = 0;

  static const double _w = GameConfig.width;
  static const double _groundY = GameConfig.height - GameConfig.groundHeight;

  /// Reflections only read on the wet strip just below the horizon.
  static const double _depth = 52;
  static const Rect _bounds = Rect.fromLTWH(0, 0, _w, _depth);

  /// Reflections are foreshortened; a 1:1 mirror would run off the strip.
  static const double _squash = 0.42;

  @override
  Future<void> onLoad() async {
    position = Vector2(0, _groundY);
    size = Vector2(_w, _depth);
  }

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    if (game.reducedMotion) return;

    // Own layer so the gradient mask below only eats the reflection.
    canvas.saveLayer(_bounds, Paint());

    canvas.save();
    // Flip about the horizon (local y == 0) and squash toward it: something at
    // world depth d above the line lands at local +d * _squash.
    canvas.scale(1, -_squash);
    _drawPipes(canvas);
    _drawBird(canvas);
    canvas.restore();

    // Fade out with depth so it reads as water, not a second copy of the scene.
    canvas.drawRect(
      _bounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.40),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(_bounds),
    );
    canvas.restore();

    // Ripple lines across the surface.
    final ripple = Paint()..strokeWidth = 1.0;
    for (int i = 0; i < 6; i++) {
      final y = 5.0 + i * 8.0;
      final phase = sin(_t * 1.6 + i * 1.3);
      ripple.color = Colors.white.withValues(alpha: 0.045 + 0.03 * phase.abs());
      canvas.drawLine(Offset(0, y), Offset(_w, y), ripple);
    }
  }

  void _drawPipes(Canvas canvas) {
    final bodyTex = GameAssets.image('pipe_body');
    for (final p in game.visiblePipes) {
      final x = p.position.x;
      if (x > _w || x + GameConfig.pipeWidth < 0) continue;
      // Only the lower pipe stands in the water: mirror from its mouth down.
      final mouth = p.bottomPipeTop;
      final len = _groundY - mouth;
      if (len <= 0) continue;

      // Wobble horizontally for a water-surface feel.
      final wob = sin(_t * 2.0 + x * 0.03) * 1.8;
      final top = mouth - _groundY; // negative -> mirrored below the line
      final rect = Rect.fromLTWH(x + wob, top, GameConfig.pipeWidth, len);
      if (bodyTex != null) {
        canvas.drawImageRect(
          bodyTex,
          Rect.fromLTWH(
              0, 0, bodyTex.width.toDouble(), bodyTex.height.toDouble()),
          rect,
          Paint()..filterQuality = FilterQuality.low,
        );
      } else {
        canvas.drawRect(rect, Paint()..color = GameConfig.pipeBase);
      }
    }
  }

  void _drawBird(Canvas canvas) {
    final sheet = GameAssets.birdSheet(game.skin.id);
    if (sheet == null) return;
    final b = game.bird;
    final height = _groundY - b.position.y;
    if (height <= 0) return;

    const frames = GameConfig.birdSheetFrames;
    final fw = sheet.width / frames;
    final fh = sheet.height.toDouble();
    const w = GameConfig.birdRadius * GameConfig.birdSpriteScale;
    final h = w * fh / fw;

    // Mirror the frame the bird is actually on; a fixed frame made the
    // reflection's wings sit still while the bird above them flapped.
    final frame = b.currentFrame.clamp(0, frames - 1);

    canvas.drawImageRect(
      sheet,
      Rect.fromLTWH(frame * fw, 0, fw, fh),
      Rect.fromCenter(
        center: Offset(b.position.x, -height),
        width: w,
        height: h,
      ),
      Paint()
        ..filterQuality = FilterQuality.low
        ..color = Colors.white.withValues(alpha: 0.8),
    );
  }
}
