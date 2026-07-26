import 'dart:math';

import 'config.dart';

/// Decides where pipes go.
///
/// Pulled out of the game loop so the level design is a pure function of
/// (score, rng) and can be simulated and tested without a running engine —
/// see test/difficulty_test.dart, which flies an autopilot through thousands
/// of generated pipes to check the curve stays fair.
class LevelGenerator {
  LevelGenerator({Random? rng, double? startCenter})
      : _rng = rng ?? Random(),
        _lastCenter = startCenter ?? GameConfig.birdStartY;

  final Random _rng;
  double _lastCenter;

  double get lastCenter => _lastCenter;

  void reset({double? startCenter}) {
    _lastCenter = startCenter ?? GameConfig.birdStartY;
  }

  /// The vertical opening at a given score. Shrinks with score, floored so it
  /// always stays comfortably flyable.
  static double gapFor(int score) => max(
        GameConfig.minGap,
        GameConfig.pipeGap - score * GameConfig.gapShrinkPerPoint,
      );

  /// Scroll speed at a given score.
  static double speedFor(int score) =>
      GameConfig.pipeSpeed +
      min(score * GameConfig.speedPerPoint, GameConfig.maxSpeedBonus);

  /// Seconds the player gets between one pipe and the next. Because pipes are
  /// spaced by *distance*, going faster genuinely means less reaction time —
  /// which is what makes the speed ramp a difficulty ramp at all.
  static double intervalFor(int score) =>
      GameConfig.pipeSpacing / speedFor(score);

  /// Lowest / highest legal gap centre for a given gap size.
  static ({double lo, double hi}) centerRangeFor(double gap) {
    const groundY = GameConfig.height - GameConfig.groundHeight;
    return (
      lo: GameConfig.pipeMinMargin + gap / 2,
      hi: groundY - GameConfig.pipeMinMargin - gap / 2,
    );
  }

  /// Next pipe. The centre is a bounded random walk rather than uniform noise:
  /// consecutive gaps stay within [GameConfig.maxGapCenterShift] of the span,
  /// so the course flows instead of yanking the player corner to corner — and
  /// the first pipe opens near where the bird starts, which stops a new
  /// player's very first life being a coin flip.
  ({double gapCenter, double gap}) next(int score) {
    final gap = gapFor(score);
    final range = centerRangeFor(gap);
    final span = range.hi - range.lo;
    final maxShift = span * GameConfig.maxGapCenterShift;

    final lo = max(range.lo, _lastCenter - maxShift);
    final hi = min(range.hi, _lastCenter + maxShift);
    final center = lo + _rng.nextDouble() * (hi - lo);

    _lastCenter = center;
    return (gapCenter: center, gap: gap);
  }
}
