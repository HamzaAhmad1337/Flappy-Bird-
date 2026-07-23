import 'package:flutter/services.dart';

/// Sound / feedback helper.
///
/// The game ships with no binary audio assets so it stays lightweight and
/// buildable from source. We use the platform's haptic engine for tactile
/// feedback, which feels great on a phone and needs no assets.
///
/// To add real sound effects later:
///   1. Add `flame_audio: ^2.x` to pubspec.yaml.
///   2. Drop wav/mp3 files in assets/audio/ and declare them under `flutter:`.
///   3. Preload them and replace the haptic calls below with
///      `FlameAudio.play('flap.wav')`, etc.
class Sfx {
  Sfx._();

  static bool enabled = true;

  static void flap() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }

  static void score() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
  }

  static void hit() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }
}
