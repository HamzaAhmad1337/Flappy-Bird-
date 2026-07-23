import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/flappy_game.dart';

/// A top + bottom pipe with a gap between them. Scrolls left at the game's
/// current speed and reports when the bird has passed it (for scoring).
class PipePair extends PositionComponent with HasGameReference<FlappyGame> {
  PipePair({required this.gapCenter, required this.gap})
      : super(priority: 5, anchor: Anchor.topLeft);

  final double gapCenter; // y of the middle of the opening
  final double gap; // vertical opening height
  bool scored = false;
  bool nearMissed = false;

  static const double _w = GameConfig.pipeWidth;
  static const double _cap = GameConfig.pipeCapHeight;

  double get topPipeBottom => gapCenter - gap / 2;
  double get bottomPipeTop => gapCenter + gap / 2;
  double get right => position.x + _w;

  @override
  Future<void> onLoad() async {
    size = Vector2(_w, GameConfig.height);
  }

  @override
  void update(double dt) {
    if (game.state != GameState.playing) return;
    position.x -= game.scrollSpeed * dt;
  }

  @override
  void render(Canvas canvas) {
    const groundY = GameConfig.height - GameConfig.groundHeight;
    _drawPipe(canvas, top: 0, bottom: topPipeBottom, capAtBottom: true);
    _drawPipe(canvas, top: bottomPipeTop, bottom: groundY, capAtBottom: false);
  }

  void _drawPipe(Canvas canvas, {required double top, required double bottom, required bool capAtBottom}) {
    final bodyRect = Rect.fromLTWH(0, top, _w, bottom - top);

    // Rounded body with a left-lit gradient for a tube-like sheen.
    final body = Paint()
      ..shader = ui.Gradient.linear(
        bodyRect.topLeft,
        bodyRect.topRight,
        const [
          GameConfig.pipeDark,
          GameConfig.pipeBase,
          GameConfig.pipeLight,
          GameConfig.pipeBase,
          GameConfig.pipeDark,
        ],
        const [0.0, 0.22, 0.42, 0.7, 1.0],
      );
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(6));
    canvas.drawRRect(bodyRRect, body);

    // Subtle vertical highlight streak (wet look in the rain).
    final streak = Paint()
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_w * 0.30, top, _w * 0.10, bottom - top),
        const Radius.circular(4),
      ),
      streak,
    );

    // The cap (lip) at the mouth of the pipe.
    final capY = capAtBottom ? bottom - _cap : top;
    final capRect = Rect.fromLTWH(-5, capY, _w + 10, _cap);
    final cap = Paint()
      ..shader = ui.Gradient.linear(
        capRect.topLeft,
        capRect.topRight,
        const [
          GameConfig.pipeDark,
          GameConfig.pipeLight,
          GameConfig.pipeBase,
          GameConfig.pipeDark,
        ],
        const [0.0, 0.4, 0.7, 1.0],
      );
    final capRRect = RRect.fromRectAndRadius(capRect, const Radius.circular(7));
    canvas.drawRRect(capRRect, cap);
    canvas.drawRRect(
      capRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = GameConfig.pipeDark.withValues(alpha: 0.7),
    );
    // Outline the body edges.
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = GameConfig.pipeDark.withValues(alpha: 0.45),
    );
  }

  /// Circle-vs-rect collision against either pipe. `b` is the bird's bounds.
  bool collidesWith(({double x, double y, double r}) b) {
    const groundY = GameConfig.height - GameConfig.groundHeight;
    final top = Rect.fromLTWH(position.x, 0, _w, topPipeBottom);
    final bottom = Rect.fromLTWH(position.x, bottomPipeTop, _w, groundY - bottomPipeTop);
    return _circleHitsRect(b, top) || _circleHitsRect(b, bottom);
  }

  bool _circleHitsRect(({double x, double y, double r}) c, Rect rect) {
    final nx = c.x.clamp(rect.left, rect.right);
    final ny = c.y.clamp(rect.top, rect.bottom);
    final dx = c.x - nx;
    final dy = c.y - ny;
    return dx * dx + dy * dy <= c.r * c.r;
  }
}
