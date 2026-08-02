import 'package:flutter_test/flutter_test.dart';

import 'package:flappy_rain/game/config.dart';
import 'package:flappy_rain/services/progression.dart';

/// A second chance touches the two things a player would notice being wrong:
/// their coin balance, and whether one run can be made to count as several.
void main() {
  group('continue pricing', () {
    test('costs more than a typical run earns, less than the cheapest skin', () {
      // Priced so it is a real decision — free would make death meaningless,
      // and skin-priced would make the shop feel held hostage.
      expect(GameConfig.continueCost, greaterThan(0));
      expect(GameConfig.continueCost, lessThan(30));
    });

    test('the revive grace is long enough to get your bearings', () {
      // Long enough to cover the reaction time the ready state hands back,
      // short enough that it is not a free run through the next pipe.
      expect(GameConfig.continueGrace, greaterThan(1.0));
      expect(GameConfig.continueGrace, lessThan(4.0));
    });
  });

  group('run accounting', () {
    // Regression: the run-count mission takes +1 from every recordRun call, so
    // a continued run reaching game over twice would have counted as two runs
    // played — a mission farm for 25 coins a pop.
    test('a continued run contributes only one run to the runs mission', () {
      const mission = Mission(MissionKind.runs, 4, 30);
      const firstLeg = RunStats(
        score: 8,
        coins: 3,
        bestCombo: 2,
        nearMisses: 1,
        powerupsUsed: 0,
      );
      const secondLeg = RunStats(
        score: 14,
        coins: 2,
        bestCombo: 1,
        nearMisses: 0,
        powerupsUsed: 1,
        countsAsRun: false,
      );

      expect(mission.progressFrom(firstLeg), 1);
      expect(mission.progressFrom(secondLeg), 0);
    });

    test('countsAsRun defaults to true, so ordinary runs still count', () {
      const mission = Mission(MissionKind.runs, 4, 30);
      const ordinary = RunStats(
        score: 5,
        coins: 0,
        bestCombo: 0,
        nearMisses: 0,
        powerupsUsed: 0,
      );
      expect(ordinary.countsAsRun, isTrue);
      expect(mission.progressFrom(ordinary), 1);
    });

    test('every other mission kind still reads the leg it is given', () {
      // Only the run counter is special-cased; coins, near misses and power-ups
      // are zeroed on the game side after a continue, not here.
      const leg = RunStats(
        score: 14,
        coins: 2,
        bestCombo: 6,
        nearMisses: 3,
        powerupsUsed: 1,
        countsAsRun: false,
      );
      expect(const Mission(MissionKind.coins, 15, 20).progressFrom(leg), 2);
      expect(const Mission(MissionKind.nearMiss, 5, 20).progressFrom(leg), 3);
      expect(const Mission(MissionKind.powerups, 3, 20).progressFrom(leg), 1);
      expect(const Mission(MissionKind.score, 10, 20).progressFrom(leg), 14);
      expect(const Mission(MissionKind.combo, 8, 20).progressFrom(leg), 6);
    });
  });
}
