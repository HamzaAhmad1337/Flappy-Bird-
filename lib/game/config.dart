import 'package:flutter/material.dart';

/// Logical design resolution. The camera uses a fixed resolution so the game
/// looks and plays identically on every device, letterboxing as needed.
class GameConfig {
  GameConfig._();

  static const double width = 480;
  static const double height = 720;

  // ---- Physics -------------------------------------------------------------
  static const double gravity = 1500; // px / s^2
  static const double flapVelocity = -430; // px / s (instant impulse)
  static const double maxFallSpeed = 700; // px / s terminal velocity
  static const double tiltUp = -0.5; // radians, tilt while rising
  static const double tiltDown = 1.35; // radians, tilt while diving

  // ---- Bird ----------------------------------------------------------------
  static const double birdX = 132; // fixed horizontal position
  static const double birdRadius = 16; // collision radius
  static const double birdStartY = 300;

  // ---- Pipes ---------------------------------------------------------------
  static const double pipeWidth = 80;
  static const double pipeGap = 194; // vertical opening
  static const double pipeSpeed = 178; // px / s base scroll speed

  /// Pipes are spaced by *distance*, not time. With time-based spawning a
  /// faster scroll pushed the pipes further apart, so getting better made the
  /// course roomier — the speed ramp partly cancelled itself out. Fixed
  /// spacing means more speed really does mean less reaction time.
  static const double pipeSpacing = 258; // px between pipes

  /// How far a gap centre may move between consecutive pipes, as a fraction of
  /// the legal span. Keeps the course flowing instead of yanking the player
  /// from top to bottom at random.
  static const double maxGapCenterShift = 0.60;
  static const double pipeMinMargin = 78; // gap distance from top/bottom
  static const double pipeCapHeight = 34;

  // ---- Ground --------------------------------------------------------------
  static const double groundHeight = 100;

  // ---- Weather -------------------------------------------------------------
  static const int rainCount = 230;
  static const double rainMinSpeed = 620;
  static const double rainMaxSpeed = 920;
  static const double rainLengthMin = 12;
  static const double rainLengthMax = 22;
  static const double rainWindX = -140; // horizontal drift (slant)

  static const double lightningMinDelay = 6;
  static const double lightningMaxDelay = 16;

  // ---- Difficulty (gentle ramp) --------------------------------------------
  static const double speedPerPoint = 2.2;
  static const double maxSpeedBonus = 95;
  static const double gapShrinkPerPoint = 1.1;
  static const double minGap = 152;

  // ---- Collectibles --------------------------------------------------------
  static const double coinRadius = 15;
  static const double coinSpawnChance = 0.7; // per pipe
  static const double powerupRadius = 20;
  static const double powerupSpawnChance = 0.16; // per pipe
  static const double magnetRadius = 150; // pull range when magnet active

  // ---- Power-up durations (seconds) ----------------------------------------
  static const double shieldDuration = 12;
  static const double slowmoDuration = 6;
  static const double magnetDuration = 9;
  static const double slowmoFactor = 0.45; // time scale while slow-mo active

  // ---- Juice ---------------------------------------------------------------
  static const double nearMissDist = 26; // proximity for a "close call"
  static const double nearMissSlowmo = 0.35; // brief bullet-time on near miss
  static const double shakeOnHit = 16;
  static const double shakeOnShield = 9;

  // ---- Day / night cycle ---------------------------------------------------
  static const double dayCycleSeconds = 75; // full dawn→day→dusk→night loop

  // ---- Rendering -----------------------------------------------------------
  static const double lensWetness = 0.85; // rain-on-lens strength (0..1)
  static const double stormIntensity = 0.72; // cloud density / sky darkening
  static const int birdSheetFrames = 8;
  static const int coinSheetFrames = 8;
  static const double birdSpriteScale = 3.5; // sprite width = radius * this

  static const String highScoreKey = 'flappy_rain_highscore_v1';

  // ---- Palette -------------------------------------------------------------
  static const Color skyTop = Color(0xFF13293D);
  static const Color skyMid = Color(0xFF1B4965);
  static const Color skyBottom = Color(0xFF2C6E8F);
  static const Color mountainFar = Color(0xFF244B63);
  static const Color mountainNear = Color(0xFF1A3A4E);
  static const Color cityColor = Color(0xFF10222E);
  static const Color pipeBase = Color(0xFF4CA64C);
  static const Color pipeLight = Color(0xFF8FE388);
  static const Color pipeDark = Color(0xFF2E7031);
  static const Color groundGrass = Color(0xFF6DBB47);
  static const Color groundDirt = Color(0xFF6B4A2B);
  static const Color rainColor = Color(0xB0BFE7F5);
  static const Color birdBody = Color(0xFFFFD447);
  static const Color birdBelly = Color(0xFFFFE9A8);
  static const Color birdWing = Color(0xFFF2A93B);
}

enum GameState { menu, playing, paused, gameOver }

enum PowerType { shield, slowmo, magnet }

extension PowerTypeInfo on PowerType {
  String get label => switch (this) {
        PowerType.shield => 'Shield',
        PowerType.slowmo => 'Slow-Mo',
        PowerType.magnet => 'Magnet',
      };

  Color get color => switch (this) {
        PowerType.shield => const Color(0xFF4FC3F7),
        PowerType.slowmo => const Color(0xFFBA68C8),
        PowerType.magnet => const Color(0xFFFF7043),
      };

  double get duration => switch (this) {
        PowerType.shield => GameConfig.shieldDuration,
        PowerType.slowmo => GameConfig.slowmoDuration,
        PowerType.magnet => GameConfig.magnetDuration,
      };
}
