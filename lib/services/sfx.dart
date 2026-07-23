import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

import 'storage.dart';

/// Real sound effects (synthesized WAV files in assets/audio/) plus haptics.
/// Both channels honor the player's settings and fail silently if audio can't
/// initialize (e.g. some web/autoplay situations), so the game never crashes
/// over a sound.
class Sfx {
  Sfx._();

  static bool _ready = false;

  static const List<String> _clips = [
    'flap.wav',
    'score.wav',
    'coin.wav',
    'hit.wav',
    'powerup.wav',
    'shield.wav',
    'button.wav',
    'swoosh.wav',
  ];

  /// Preload clips into the audio cache. Safe to call once at startup.
  static Future<void> init() async {
    try {
      await FlameAudio.audioCache.loadAll(_clips);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static void _play(String clip, {double volume = 1.0}) {
    if (!_ready || !Storage.soundOn) return;
    try {
      FlameAudio.play(clip, volume: volume);
    } catch (_) {/* ignore */}
  }

  static void _haptic(void Function() fn) {
    if (!Storage.hapticsOn) return;
    fn();
  }

  static void flap() {
    _play('flap.wav', volume: 0.6);
    _haptic(HapticFeedback.selectionClick);
  }

  static void score() {
    _play('score.wav', volume: 0.7);
    _haptic(HapticFeedback.lightImpact);
  }

  static void coin() => _play('coin.wav', volume: 0.7);

  static void hit() {
    _play('hit.wav');
    _haptic(HapticFeedback.heavyImpact);
  }

  static void powerup() {
    _play('powerup.wav', volume: 0.8);
    _haptic(HapticFeedback.mediumImpact);
  }

  static void shield() {
    _play('shield.wav', volume: 0.8);
    _haptic(HapticFeedback.heavyImpact);
  }

  static void button() {
    _play('button.wav', volume: 0.6);
    _haptic(HapticFeedback.selectionClick);
  }

  static void swoosh() => _play('swoosh.wav', volume: 0.5);
}
