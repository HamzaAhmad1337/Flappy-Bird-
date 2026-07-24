import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/flappy_game.dart';
import '../services/assets.dart';

/// Draws the volumetric storm sky (shaders/sky.frag) across the whole screen.
///
/// Sits behind everything. When the shader is unavailable this component draws
/// nothing and [Background] falls back to painting its own gradient sky.
class SkyShaderLayer extends PositionComponent with HasGameReference<FlappyGame> {
  SkyShaderLayer() : super(priority: -120);

  double _t = 0;

  static bool get available => GameAssets.skyShader != null;

  @override
  Future<void> onLoad() async {
    size = Vector2(GameConfig.width, GameConfig.height);
  }

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final shader = GameAssets.skyShader;
    if (shader == null) return;

    // Uniform order must match the declaration order in sky.frag.
    shader
      ..setFloat(0, GameConfig.width)
      ..setFloat(1, GameConfig.height)
      ..setFloat(2, _t)
      ..setFloat(3, game.skyPhase)
      ..setFloat(4, game.worldScroll)
      ..setFloat(5, game.stormIntensity)
      ..setFloat(6, game.lightningFlash);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, GameConfig.width, GameConfig.height),
      Paint()..shader = shader,
    );
  }
}
