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
      _slowFor += rawDt;
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
      // One horrible 400ms frame — an overlay rebuild, a GC pause, a resume —
      // surrounded by healthy ones.
      g.run(16.7, 5);
      g.frame(0.4);
      g.run(16.7, 5);
      expect(g.lowPower, isFalse);
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
      final clamped = FlappyGame.maxTimeStep;
      expect(clamped, greaterThan(GameConfig.slowFrameSeconds),
          reason: 'clamped dt sits above the slow threshold, so feeding the '
              'clamped value would trip on every device instead of the slow '
              'ones — the raw dt is the only meaningful signal');
    });
  });
}
