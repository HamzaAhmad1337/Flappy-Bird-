import 'package:flappy_rain/services/progression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('daily reward', () {
    test('never prices a day below day one', () {
      // The popup can ask about day 0 for one frame, before the claim resolves.
      // Unclamped this returned 5 — cheaper than day 1, which reads as a bug to
      // anyone who catches the frame.
      expect(Progression.dailyRewardFor(0), Progression.dailyRewardFor(1));
      for (var d = 0; d <= 30; d++) {
        expect(Progression.dailyRewardFor(d),
            greaterThanOrEqualTo(Progression.dailyRewardFor(1)));
      }
    });

    test('grows with the streak, then plateaus', () {
      expect(Progression.dailyRewardFor(2),
          greaterThan(Progression.dailyRewardFor(1)));
      // Capped so a long streak can't run away.
      expect(Progression.dailyRewardFor(50), Progression.dailyRewardFor(7));
    });
  });

  group('ranks', () {
    test('every score maps to a rank, and thresholds ascend', () {
      var last = -1;
      for (final r in Progression.ranks) {
        expect(r.minScore, greaterThan(last));
        last = r.minScore;
      }
      for (var s = 0; s <= 200; s++) {
        final rank = Progression.rankFor(s);
        expect(s, greaterThanOrEqualTo(rank.minScore));
        final next = Progression.nextRankAfter(s);
        if (next != null) expect(next.minScore, greaterThan(s));
      }
    });
  });

  group('daily missions', () {
    test('are stable within a day and differ across days', () {
      final a = Progression.missionsFor(100);
      final b = Progression.missionsFor(100);
      final c = Progression.missionsFor(101);
      expect(a.map((m) => '${m.kind}:${m.target}'),
          b.map((m) => '${m.kind}:${m.target}'));
      expect(a.map((m) => m.kind).toSet().length, 3, reason: 'no duplicates');
      expect(
          a.map((m) => '${m.kind}:${m.target}').join() !=
              c.map((m) => '${m.kind}:${m.target}').join(),
          isTrue);
    });

    test('targets and rewards are always positive', () {
      for (var day = 0; day < 400; day++) {
        for (final m in Progression.missionsFor(day)) {
          expect(m.target, greaterThan(0));
          expect(m.reward, greaterThan(0));
          expect(m.title, isNotEmpty);
        }
      }
    });
  });
}
