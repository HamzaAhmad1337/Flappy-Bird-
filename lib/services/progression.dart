import 'dart:math';

import 'package:flutter/material.dart';

import 'storage.dart';

/// Long-term progression: daily rewards & streaks, rotating daily missions,
/// achievements and rank tiers.
///
/// The goal is to always leave the player with a visible next goal — "one more
/// run" should have a concrete reason behind it — without any manipulative
/// urgency or paid mechanics. Everything here is earned by playing.

// ---------------------------------------------------------------------------
// Run summary
// ---------------------------------------------------------------------------

/// What happened in a single run; fed to [Progression.recordRun].
class RunStats {
  const RunStats({
    required this.score,
    required this.coins,
    required this.bestCombo,
    required this.nearMisses,
    required this.powerupsUsed,
    this.countsAsRun = true,
  });

  final int score;
  final int coins;
  final int bestCombo;
  final int nearMisses;
  final int powerupsUsed;

  /// False for the tail of a run that was carried past a death by a continue —
  /// the same run reaching the end twice is still one run played.
  final bool countsAsRun;
}

// ---------------------------------------------------------------------------
// Missions
// ---------------------------------------------------------------------------

enum MissionKind { score, coins, nearMiss, combo, powerups, runs }

class Mission {
  const Mission(this.kind, this.target, this.reward);

  final MissionKind kind;
  final int target;
  final int reward; // coins

  String get title => switch (kind) {
        MissionKind.score => 'Score $target in one run',
        MissionKind.coins => 'Collect $target coins',
        MissionKind.nearMiss => 'Squeeze past $target pipes closely',
        MissionKind.combo => 'Reach a x$target combo',
        MissionKind.powerups => 'Grab $target power-ups',
        MissionKind.runs => 'Play $target runs',
      };

  IconData get icon => switch (kind) {
        MissionKind.score => Icons.flag_rounded,
        MissionKind.coins => Icons.star_rounded,
        MissionKind.nearMiss => Icons.bolt_rounded,
        MissionKind.combo => Icons.local_fire_department_rounded,
        MissionKind.powerups => Icons.auto_awesome_rounded,
        MissionKind.runs => Icons.replay_rounded,
      };

  /// Progress contributed by a single run. Score/combo are "best in one run",
  /// the rest accumulate.
  int progressFrom(RunStats s) => switch (kind) {
        MissionKind.score => s.score,
        MissionKind.coins => s.coins,
        MissionKind.nearMiss => s.nearMisses,
        MissionKind.combo => s.bestCombo,
        MissionKind.powerups => s.powerupsUsed,
        MissionKind.runs => s.countsAsRun ? 1 : 0,
      };

  bool get isPersonalBestStyle =>
      kind == MissionKind.score || kind == MissionKind.combo;
}

// ---------------------------------------------------------------------------
// Achievements
// ---------------------------------------------------------------------------

class Achievement {
  const Achievement(this.id, this.name, this.description, this.icon, this.test);

  final String id;
  final String name;
  final String description;
  final IconData icon;

  /// Evaluated against lifetime stats after each run.
  final bool Function(LifetimeStats l) test;
}

/// Lifetime totals used by achievement predicates.
class LifetimeStats {
  const LifetimeStats(this.best, this.runs, this.coins, this.combo,
      this.nearMisses, this.powerups);
  final int best, runs, coins, combo, nearMisses, powerups;
}

// ---------------------------------------------------------------------------
// Rank tiers
// ---------------------------------------------------------------------------

class Rank {
  const Rank(this.name, this.minScore, this.color);
  final String name;
  final int minScore;
  final Color color;
}

class Progression {
  Progression._();

  static const List<Rank> ranks = [
    Rank('Fledgling', 0, Color(0xFF9E9E9E)),
    Rank('Sparrow', 5, Color(0xFF8D6E63)),
    Rank('Swift', 12, Color(0xFFCD7F32)),
    Rank('Falcon', 22, Color(0xFFC0C6CC)),
    Rank('Storm Rider', 35, Color(0xFFFFD447)),
    Rank('Skylord', 55, Color(0xFF7FC4FF)),
    Rank('Legend', 80, Color(0xFFE5B3FF)),
  ];

  static Rank rankFor(int best) {
    var r = ranks.first;
    for (final x in ranks) {
      if (best >= x.minScore) r = x;
    }
    return r;
  }

  static Rank? nextRankAfter(int best) {
    for (final x in ranks) {
      if (x.minScore > best) return x;
    }
    return null;
  }

  static const List<Achievement> achievements = [
    Achievement('first_flight', 'First Flight', 'Play your first run',
        Icons.flight_takeoff_rounded, _firstFlight),
    Achievement('score_10', 'Getting the Hang', 'Score 10 in a run',
        Icons.trending_up_rounded, _score10),
    Achievement('score_25', 'Sky Veteran', 'Score 25 in a run',
        Icons.military_tech_rounded, _score25),
    Achievement('score_50', 'Untouchable', 'Score 50 in a run',
        Icons.workspace_premium_rounded, _score50),
    Achievement('coins_100', 'Coin Purse', 'Collect 100 coins in total',
        Icons.savings_rounded, _coins100),
    Achievement('coins_500', 'Treasury', 'Collect 500 coins in total',
        Icons.account_balance_rounded, _coins500),
    Achievement('combo_10', 'On Fire', 'Reach a x10 combo',
        Icons.local_fire_department_rounded, _combo10),
    Achievement('nearmiss_50', 'Daredevil', 'Squeeze past 50 pipes',
        Icons.bolt_rounded, _near50),
    Achievement('powerups_25', 'Power Hungry', 'Grab 25 power-ups',
        Icons.auto_awesome_rounded, _power25),
    Achievement(
        'runs_50', 'Persistent', 'Play 50 runs', Icons.replay_rounded, _runs50),
    Achievement('streak_3', 'Regular', 'Play 3 days in a row',
        Icons.calendar_month_rounded, _streak3),
    Achievement('streak_7', 'Devoted', 'Play 7 days in a row',
        Icons.local_activity_rounded, _streak7),
  ];

  static bool _firstFlight(LifetimeStats l) => l.runs >= 1;
  static bool _score10(LifetimeStats l) => l.best >= 10;
  static bool _score25(LifetimeStats l) => l.best >= 25;
  static bool _score50(LifetimeStats l) => l.best >= 50;
  static bool _coins100(LifetimeStats l) => l.coins >= 100;
  static bool _coins500(LifetimeStats l) => l.coins >= 500;
  static bool _combo10(LifetimeStats l) => l.combo >= 10;
  static bool _near50(LifetimeStats l) => l.nearMisses >= 50;
  static bool _power25(LifetimeStats l) => l.powerups >= 25;
  static bool _runs50(LifetimeStats l) => l.runs >= 50;
  static bool _streak3(LifetimeStats l) => Storage.streak >= 3;
  static bool _streak7(LifetimeStats l) => Storage.streak >= 7;

  static Achievement? byId(String id) {
    for (final a in achievements) {
      if (a.id == id) return a;
    }
    return null;
  }

  // ---- Daily missions ------------------------------------------------------

  /// Three missions chosen deterministically from the day number, so every
  /// player on a given day gets the same set and they refresh at midnight.
  static List<Mission> missionsFor(int dayIndex) {
    final rng = Random(dayIndex * 7919);
    final kinds = List<MissionKind>.from(MissionKind.values)..shuffle(rng);
    final picked = kinds.take(3).toList();
    return [
      for (final k in picked) _mission(k, rng),
    ];
  }

  static Mission _mission(MissionKind k, Random rng) => switch (k) {
        MissionKind.score => Mission(k, 8 + rng.nextInt(10), 12),
        MissionKind.coins => Mission(k, 15 + rng.nextInt(20), 10),
        MissionKind.nearMiss => Mission(k, 4 + rng.nextInt(6), 14),
        MissionKind.combo => Mission(k, 5 + rng.nextInt(5), 12),
        MissionKind.powerups => Mission(k, 2 + rng.nextInt(3), 10),
        MissionKind.runs => Mission(k, 3 + rng.nextInt(4), 8),
      };

  static int get todayIndex =>
      DateTime.now().toUtc().difference(DateTime.utc(2024, 1, 1)).inDays;

  static List<Mission> get todayMissions => missionsFor(todayIndex);

  /// Rolls missions over when the day changes.
  static Future<void> ensureFreshMissions() async {
    if (Storage.missionDay != todayIndex) {
      await Storage.setMissionDay(todayIndex);
      await Storage.setMissionProgress([0, 0, 0]);
      await Storage.setMissionClaimed([false, false, false]);
    }
  }

  // ---- Daily reward --------------------------------------------------------

  /// Coins granted for the Nth consecutive day (capped so it stays sane).
  ///
  /// Day numbers are 1-based; clamping guards day 0, which the popup can ask
  /// about for one frame before the claim resolves and would otherwise be
  /// priced *below* day 1.
  static int dailyRewardFor(int streak) => 10 + min(max(streak, 1) - 1, 6) * 5;

  static bool get dailyRewardAvailable => Storage.lastDailyDay != todayIndex;

  /// Claims today's reward, extending or resetting the streak. Returns
  /// (coins, streak) or null if already claimed today.
  static Future<({int coins, int streak})?> claimDaily() async {
    if (!dailyRewardAvailable) return null;
    final last = Storage.lastDailyDay;
    final streak = (last == todayIndex - 1) ? Storage.streak + 1 : 1;
    final coins = dailyRewardFor(streak);
    await Storage.setStreak(streak);
    await Storage.setLastDailyDay(todayIndex);
    await Storage.addCoins(coins);
    return (coins: coins, streak: streak);
  }

  // ---- Recording a run -----------------------------------------------------

  /// Result of folding a run into long-term progress.
  static Future<({List<int> missionsCompleted, List<Achievement> unlocked})>
      recordRun(RunStats s) async {
    await ensureFreshMissions();

    // Lifetime totals.
    await Storage.addLifetime(
      coins: s.coins,
      nearMisses: s.nearMisses,
      powerups: s.powerupsUsed,
    );
    if (s.bestCombo > Storage.bestCombo) {
      await Storage.setBestCombo(s.bestCombo);
    }

    // Missions.
    final missions = todayMissions;
    final progress = Storage.missionProgress;
    final completed = <int>[];
    for (var i = 0; i < missions.length && i < progress.length; i++) {
      final m = missions[i];
      final add = m.progressFrom(s);
      final was = progress[i];
      // "Best in one run" missions take the max; the rest accumulate.
      progress[i] = m.isPersonalBestStyle ? max(was, add) : was + add;
      if (was < m.target && progress[i] >= m.target) completed.add(i);
    }
    await Storage.setMissionProgress(progress);

    // Achievements.
    final life = LifetimeStats(
      Storage.highScore,
      Storage.gamesPlayed,
      Storage.lifetimeCoins,
      Storage.bestCombo,
      Storage.lifetimeNearMisses,
      Storage.lifetimePowerups,
    );
    final unlocked = <Achievement>[];
    for (final a in achievements) {
      if (!Storage.hasAchievement(a.id) && a.test(life)) {
        await Storage.unlockAchievement(a.id);
        unlocked.add(a);
      }
    }

    return (missionsCompleted: completed, unlocked: unlocked);
  }

  /// Claims a completed mission's coin reward.
  static Future<int> claimMission(int index) async {
    final missions = todayMissions;
    if (index < 0 || index >= missions.length) return 0;
    final claimed = Storage.missionClaimed;
    final progress = Storage.missionProgress;
    if (claimed[index] || progress[index] < missions[index].target) return 0;
    claimed[index] = true;
    await Storage.setMissionClaimed(claimed);
    await Storage.addCoins(missions[index].reward);
    return missions[index].reward;
  }
}
