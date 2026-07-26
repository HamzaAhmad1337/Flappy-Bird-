import 'dart:math';

import 'package:flappy_rain/game/config.dart';
import 'package:flappy_rain/game/flappy_game.dart';
import 'package:flappy_rain/game/level.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flies an autopilot through generated courses to check the difficulty curve
/// is actually fair, rather than trusting that the constants "feel right".
///
/// The simulation mirrors the game's physics exactly: same gravity, same flap
/// impulse, same terminal velocity, same clamped timestep, and pipes from the
/// real [LevelGenerator]. If someone retunes the constants into something
/// unflyable, these tests fail.
void main() {
  group('course fairness', () {
    test('consecutive gaps are always physically reachable', () {
      // Worst case at every score: the biggest legal jump between two gap
      // centres, against the least time the player gets to make it.
      for (var score = 0; score <= 200; score++) {
        final gap = LevelGenerator.gapFor(score);
        final range = LevelGenerator.centerRangeFor(gap);
        final maxShift = (range.hi - range.lo) * GameConfig.maxGapCenterShift;
        final seconds = LevelGenerator.intervalFor(score);

        final climb = _maxClimb(seconds);
        final drop = _maxDrop(seconds);

        expect(climb, greaterThan(maxShift),
            reason: 'at score $score the bird cannot climb $maxShift px '
                'in ${seconds.toStringAsFixed(2)}s (max ${climb.toStringAsFixed(0)})');
        expect(drop, greaterThan(maxShift),
            reason: 'at score $score the bird cannot fall $maxShift px in time');
      }
    });

    test('the gap always admits the bird with margin to spare', () {
      for (var score = 0; score <= 200; score++) {
        final gap = LevelGenerator.gapFor(score);
        // Diameter plus a little room; a gap barely wider than the bird would
        // be technically passable but miserable.
        expect(gap, greaterThan(GameConfig.birdRadius * 2 * 2.5),
            reason: 'gap $gap too tight at score $score');
      }
    });

    test('speed ramp really does shorten reaction time', () {
      // The whole point of distance-based spacing: going faster must mean less
      // time per pipe, otherwise the speed ramp cancels itself out.
      final early = LevelGenerator.intervalFor(0);
      final late = LevelGenerator.intervalFor(60);
      expect(late, lessThan(early));
      // …but never so little that it stops being playable.
      expect(late, greaterThan(0.75));
    });

    test('gap centres stay inside the playable band', () {
      final gen = LevelGenerator(rng: Random(1));
      for (var i = 0; i < 5000; i++) {
        final score = i ~/ 20;
        final p = gen.next(score);
        final range = LevelGenerator.centerRangeFor(p.gap);
        expect(p.gapCenter, greaterThanOrEqualTo(range.lo - 1e-6));
        expect(p.gapCenter, lessThanOrEqualTo(range.hi + 1e-6));
        // The opening must never overlap the ground or the ceiling.
        expect(p.gapCenter - p.gap / 2, greaterThan(0));
        expect(p.gapCenter + p.gap / 2,
            lessThan(GameConfig.height - GameConfig.groundHeight));
      }
    });

    test('the first pipe opens near where the bird starts', () {
      // A new player's very first life shouldn't be a coin flip.
      for (var seed = 0; seed < 200; seed++) {
        final gen = LevelGenerator(rng: Random(seed));
        final first = gen.next(0);
        final reachable = _maxClimb(LevelGenerator.intervalFor(0));
        expect((first.gapCenter - GameConfig.birdStartY).abs(),
            lessThan(reachable));
      }
    });
  });

  group('autopilot', () {
    test('a competent player can post a good score', () {
      // A simple aim-for-the-gap policy should get a long way. If it cannot,
      // the course is unfair rather than merely hard.
      final scores = <int>[];
      for (var seed = 0; seed < 25; seed++) {
        scores.add(_simulate(seed: seed, cap: 120));
      }
      scores.sort();
      final median = scores[scores.length ~/ 2];
      // Thresholds encode "a competent policy can fly this course", not this
      // particular bot's exact skill — retuning should only trip them if the
      // course actually becomes unfair. Observed: median ~39, range ~19-68.
      expect(median, greaterThanOrEqualTo(20),
          reason: 'autopilot median only $median (scores: $scores)');
      expect(scores.first, greaterThan(5),
          reason: 'seed produced an almost unplayable course: $scores');
    });

    test('the course is not trivially survivable by mashing', () {
      // Flapping on a fixed rhythm, ignoring the pipes, should die quickly —
      // otherwise there is no skill in it.
      var total = 0;
      for (var seed = 0; seed < 20; seed++) {
        total += _simulate(seed: seed, cap: 60, mindless: true);
      }
      expect(total / 20, lessThan(5),
          reason: 'mashing averaged ${total / 20} points');
    });
  });
}

// ---------------------------------------------------------------------------
// Physics helpers — mirror Bird.update / FlappyGame.update exactly.
// ---------------------------------------------------------------------------

const double _step = 1 / 60;

/// Furthest the bird can climb in [seconds] by flapping as fast as possible.
double _maxClimb(double seconds) {
  var y = 0.0;
  var v = 0.0;
  for (var t = 0.0; t < seconds; t += _step) {
    v = GameConfig.flapVelocity; // flap every frame = fastest possible climb
    v = min(v + GameConfig.gravity * _step, GameConfig.maxFallSpeed);
    y += v * _step;
  }
  return -y; // upward is negative
}

/// Furthest the bird can fall in [seconds] without flapping.
double _maxDrop(double seconds) {
  var y = 0.0;
  var v = 0.0;
  for (var t = 0.0; t < seconds; t += _step) {
    v = min(v + GameConfig.gravity * _step, GameConfig.maxFallSpeed);
    y += v * _step;
  }
  return y;
}

/// One simulated pipe in flight.
class _Pipe {
  _Pipe(this.x, this.center, this.gap);
  double x;
  final double center;
  final double gap;
  bool scored = false;
}

/// Runs a whole simulated game and returns the score reached.
///
/// [mindless] ignores the pipes and flaps on a fixed rhythm, which is the
/// control case for "is there any skill here".
int _simulate({required int seed, required int cap, bool mindless = false}) {
  const groundY = GameConfig.height - GameConfig.groundHeight;
  final gen = LevelGenerator(rng: Random(seed));

  var y = GameConfig.birdStartY;
  var v = 0.0;
  var score = 0;
  var sinceSpawn = GameConfig.pipeSpacing * 0.35;
  final pipes = <_Pipe>[];
  var rhythm = 0.0;

  // Generous time budget; the caps below end the run.
  for (var frame = 0; frame < 60 * 600; frame++) {
    final speed = LevelGenerator.speedFor(score);

    sinceSpawn += speed * _step;
    if (sinceSpawn >= GameConfig.pipeSpacing) {
      sinceSpawn -= GameConfig.pipeSpacing;
      final p = gen.next(score);
      pipes.add(_Pipe(GameConfig.width + 20, p.gapCenter, p.gap));
    }

    // ---- policy ----
    var flap = false;
    if (mindless) {
      rhythm += _step;
      if (rhythm >= 0.30) {
        rhythm = 0;
        flap = true;
      }
    } else {
      // Aim at the gap the bird is heading for, and keep aiming at it until
      // the pipe is completely behind — switching while still between the
      // pipes drags the bird toward the next gap and clips the current one.
      var targetY = GameConfig.height / 2;
      for (final p in pipes) {
        if (p.x + GameConfig.pipeWidth > GameConfig.birdX - GameConfig.birdRadius) {
          targetY = p.center;
          break;
        }
      }
      // A flap climbs ~62px before gravity wins, so a hold-altitude policy
      // oscillates in a band *above* wherever it decides to flap. Aim below
      // the gap centre by half that band, with only a short lookahead, so the
      // oscillation straddles the centre instead of riding the top pipe.
      const lookahead = 0.05;
      const bandOffset = 30.0;
      flap = y + v * lookahead > targetY + bandOffset;
    }
    if (flap) v = GameConfig.flapVelocity;

    // ---- physics (identical to Bird.update) ----
    v = min(v + GameConfig.gravity * _step, GameConfig.maxFallSpeed);
    y += v * _step;

    for (final p in pipes) {
      p.x -= speed * _step;
    }
    pipes.removeWhere((p) => p.x + GameConfig.pipeWidth < -20);

    // ---- collisions (identical to FlappyGame._checkCollisions) ----
    const r = GameConfig.birdRadius;
    if (y + r >= groundY) return score;
    if (y - r <= 0) {
      y = r;
      v = 0;
    }
    for (final p in pipes) {
      final overlapsX =
          GameConfig.birdX + r > p.x && GameConfig.birdX - r < p.x + GameConfig.pipeWidth;
      if (!overlapsX) continue;
      if (y - r < p.center - p.gap / 2 || y + r > p.center + p.gap / 2) {
        return score;
      }
    }

    // ---- scoring ----
    for (final p in pipes) {
      if (!p.scored && p.x + GameConfig.pipeWidth < GameConfig.birdX) {
        p.scored = true;
        score++;
        if (score >= cap) return score;
      }
    }
  }
  return score;
}

/// Referenced so the timestep clamp stays visible next to the simulation.
// ignore: unused_element
const double _engineClamp = FlappyGame.maxTimeStep;
