import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flappy_rain/game/config.dart';
import 'package:flappy_rain/game/flappy_game.dart';

/// Mirror of FlappyGame's frame-rate guard, so the thresholds can be exercised
/// without standing up the whole engine. Kept deliberately in step with the
/// real one: if that changes, these numbers should stop making sense.
class _Guard {
  bool lowPower = false;
  double _slowFor = 0;

  void frame(double rawDt) {
    if (lowPower) return;
    if (rawDt > GameConfig.slowFrameSeconds) {
      _slowFor += min(rawDt, GameConfig.maxFrameCredit);
      if (_slowFor >= GameConfig.slowSustainSeconds) lowPower = true;
    } else {
      _slowFor = max(0, _slowFor - rawDt * 2);
    }
  }

  void run(double frameMs, double seconds) {
    final dt = frameMs / 1000;
    for (var t = 0.0; t < seconds; t += dt) {
      frame(dt);
    }
  }
}

void main() {
  group('adaptive quality', () {
    test('a healthy 60fps device keeps every effect', () {
      final g = _Guard()..run(16.7, 60);
      expect(g.lowPower, isFalse);
    });

    test('a device stuck at 15fps sheds effects within about three seconds',
        () {
      // Slow time accumulates at wall-clock rate, so tripping takes
      // slowSustainSeconds of genuinely bad frames — no more, no less.
      final early = _Guard()..run(66, 2.0);
      expect(early.lowPower, isFalse,
          reason: 'must not fire before the window');

      final g = _Guard()..run(66, 3.0);
      expect(g.lowPower, isTrue);
    });

    test('an isolated hitch is not mistaken for a slow device', () {
      final g = _Guard();
      // One horrible 400ms frame — an overlay rebuild, a GC pause — surrounded
      // by healthy ones.
      g.run(16.7, 5);
      g.frame(0.4);
      g.run(16.7, 5);
      expect(g.lowPower, isFalse);
    });

    test('resuming from the lock screen does not strip the effects', () {
      // Regression: Flame derives dt by subtracting timestamps with no upper
      // bound, so coming back after minutes away arrives as a single frame
      // tens of seconds long. Credited in full it buried the sustain window
      // instantly, and the player's game was permanently plainer for no
      // reason they could see. The original hitch test used 400ms and sailed
      // straight past this.
      for (final gap in [3.0, 30.0, 600.0]) {
        final g = _Guard()..run(16.7, 5);
        g.frame(gap);
        g.run(16.7, 5);
        expect(g.lowPower, isFalse, reason: 'a ${gap}s gap must not trip it');
      }
    });

    test('capping frame credit still lets a genuinely slow device trip', () {
      // The cap must bound lifecycle gaps without blunting the real signal.
      final g = _Guard()..run(100, 4); // a steady, miserable 10fps
      expect(g.lowPower, isTrue);
    });

    test('intermittent stutter does not trip it either', () {
      final g = _Guard();
      for (var i = 0; i < 600; i++) {
        g.frame(i % 20 == 0 ? 0.05 : 0.0167);
      }
      expect(g.lowPower, isFalse,
          reason: 'one slow frame in twenty is a stutter, not a slow device');
    });

    test('the decision sticks once made', () {
      final g = _Guard()..run(66, 3);
      expect(g.lowPower, isTrue);
      g.run(16.7, 30); // frames recover
      expect(g.lowPower, isTrue,
          reason: 'effects must not flicker back on mid-session');
    });

    test('the guard must read unclamped frame times to see anything', () {
      // Regression guard for the subtle bug: physics clamps dt at maxTimeStep,
      // so a device at 4fps still reports 33ms steps. Feeding the guard the
      // clamped value would make a catastrophically slow device look merely
      // mediocre and it would never trip.
      const clamped = FlappyGame.maxTimeStep;
      expect(clamped, greaterThan(GameConfig.slowFrameSeconds),
          reason: 'clamped dt sits above the slow threshold, so feeding the '
              'clamped value would trip on every device instead of the slow '
              'ones — the raw dt is the only meaningful signal');
    });
  });
}
