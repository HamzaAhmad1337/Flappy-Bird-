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
    'ambience_rain.wav',
    'music_loop.wav',
  ];

  /// Continuous beds: rainfall, and the pad that sits under it.
  static AudioPlayer? _ambience;
  static AudioPlayer? _music;

  /// Preload clips into the audio cache. Safe to call once at startup.
  static Future<void> init() async {
    try {
      await FlameAudio.audioCache.loadAll(_clips);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  // ---- Looping beds --------------------------------------------------------

  /// Starts (or restarts) the rain and music loops according to the player's
  /// settings. Called after the first interaction, because browsers — and iOS
  /// in some states — refuse to start audio before the user has touched
  /// something.
  static Future<void> startBeds() async {
    await _syncAmbience();
    await _syncMusic();
  }

  static Future<void> _syncAmbience() async {
    try {
      if (Storage.soundOn && _ambience == null) {
        _ambience = await FlameAudio.loop('ambience_rain.wav', volume: 0.34);
      } else if (!Storage.soundOn && _ambience != null) {
        await _ambience?.stop();
        _ambience = null;
      }
    } catch (_) {
      _ambience = null;
    }
  }

  static Future<void> _syncMusic() async {
    try {
      if (Storage.musicOn && _music == null) {
        _music = await FlameAudio.loop('music_loop.wav', volume: 0.22);
      } else if (!Storage.musicOn && _music != null) {
        await _music?.stop();
        _music = null;
      }
    } catch (_) {
      _music = null;
    }
  }

  /// Re-reads the settings and starts/stops the beds to match.
  static Future<void> settingsChanged() => startBeds();

  /// Suspends the beds while the app is backgrounded, and brings them back.
  static Future<void> setPaused(bool paused) async {
    try {
      if (paused) {
        await _ambience?.pause();
        await _music?.pause();
      } else {
        await _ambience?.resume();
        await _music?.resume();
      }
    } catch (_) {/* ignore */}
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
