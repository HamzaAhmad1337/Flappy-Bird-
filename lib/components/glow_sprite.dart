import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A pre-rendered soft radial glow.
///
/// Drawing a blurred circle per particle means one `MaskFilter.blur` pass per
/// particle per frame, which is one of the most expensive things you can ask a
/// mobile GPU to do. Baking the falloff into a small texture once at startup
/// turns each particle into an ordinary textured quad — and lets many of them
/// be batched into a single `drawAtlas` call.
class GlowSprite {
  GlowSprite._(this.image);

  final ui.Image image;

  double get radius => image.width / 2;

  /// Renders a white radial falloff of the given pixel size.
  static Future<GlowSprite> create(
      {int size = 64, double softness = 1.0}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = size / 2.0;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: [0.0, 0.30 * softness, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(r, r), radius: r));
    canvas.drawCircle(Offset(r, r), r, paint);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    picture.dispose();
    return GlowSprite._(image);
  }
}
