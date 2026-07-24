import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/flappy_game.dart';
import '../services/assets.dart';

/// Full-screen camera-lens pass (shaders/lens.frag): rain beading on the
/// glass, vignette, chromatic fringing, grain and lightning bloom.
///
/// Drawn above everything except the Flutter UI overlays. Skipped entirely
/// when reduced-motion is on or the shader failed to load.
class LensOverlay extends PositionComponent with HasGameReference<FlappyGame> {
  LensOverlay() : super(priority: 200);

  double _t = 0;

  @override
  Future<void> onLoad() async {
    size = Vector2(GameConfig.width, GameConfig.height);
  }

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final shader = GameAssets.lensShader;
    if (shader == null || game.reducedMotion) return;

    shader
      ..setFloat(0, GameConfig.width)
      ..setFloat(1, GameConfig.height)
      ..setFloat(2, _t)
      ..setFloat(3, GameConfig.lensWetness)
      ..setFloat(4, game.lightningFlash)
      ..setFloat(5, game.scrollSpeed);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, GameConfig.width, GameConfig.height),
      Paint()..shader = shader,
    );
  }
}
