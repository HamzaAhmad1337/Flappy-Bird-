import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A short-lived piece of text that floats upward and fades — used for score
/// pops, combo call-outs and "+1" coin feedback.
class FloatingText extends PositionComponent {
  FloatingText({
    required Vector2 start,
    required this.text,
    required this.color,
    this.fontSize = 26,
    this.rise = 46,
    this.life = 0.9,
  }) : super(position: start.clone(), priority: 40);

  final String text;
  final Color color;
  final double fontSize;
  final double rise;
  final double life;

  double _t = 0;
  late final TextPainter _painter;

  @override
  Future<void> onLoad() async {
    _painter = TextPainter(textDirection: TextDirection.ltr);
  }

  @override
  void update(double dt) {
    _t += dt;
    position.y -= rise * dt;
    if (_t >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / life).clamp(0.0, 1.0);
    final alpha = (1 - p * p); // ease-out fade
    final scale = 0.7 + (1 - (1 - p) * (1 - p)) * 0.3; // pop-in
    _painter
      ..text = TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: color.withValues(alpha: alpha),
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: alpha * 0.6), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
      )
      ..layout();
    canvas.save();
    canvas.translate(-_painter.width / 2 * scale, 0);
    canvas.scale(scale);
    _painter.paint(canvas, Offset.zero);
    canvas.restore();
  }
}
