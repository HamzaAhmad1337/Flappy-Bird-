import 'package:shared_preferences/shared_preferences.dart';

import '../game/config.dart';

/// Persistent save data: high score, coin wallet, unlocked/selected bird skins,
/// and player settings. Backed by shared_preferences.
class Storage {
  Storage._();

  static SharedPreferences? _prefs;

  static const _kHigh = GameConfig.highScoreKey;
  static const _kCoins = 'flappy_rain_coins_v1';
  static const _kUnlocked = 'flappy_rain_unlocked_v1';
  static const _kSelected = 'flappy_rain_selected_skin_v1';
  static const _kSound = 'flappy_rain_sound_v1';
  static const _kHaptics = 'flappy_rain_haptics_v1';
  static const _kMotion = 'flappy_rain_reduced_motion_v1';
  static const _kGames = 'flappy_rain_games_played_v1';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---- Scores --------------------------------------------------------------
  static int get highScore => _prefs?.getInt(_kHigh) ?? 0;
  static Future<void> setHighScore(int v) async => _prefs?.setInt(_kHigh, v);

  static int get gamesPlayed => _prefs?.getInt(_kGames) ?? 0;
  static Future<void> incGamesPlayed() async =>
      _prefs?.setInt(_kGames, gamesPlayed + 1);

  // ---- Coins ---------------------------------------------------------------
  static int get coins => _prefs?.getInt(_kCoins) ?? 0;
  static Future<void> setCoins(int v) async => _prefs?.setInt(_kCoins, v);
  static Future<void> addCoins(int v) async => setCoins(coins + v);

  // ---- Skins ---------------------------------------------------------------
  static List<String> get unlockedSkins =>
      _prefs?.getStringList(_kUnlocked) ?? ['classic'];

  static Future<void> unlockSkin(String id) async {
    final list = unlockedSkins;
    if (!list.contains(id)) {
      list.add(id);
      await _prefs?.setStringList(_kUnlocked, list);
    }
  }

  static bool isUnlocked(String id) => unlockedSkins.contains(id);

  static String get selectedSkin => _prefs?.getString(_kSelected) ?? 'classic';
  static Future<void> setSelectedSkin(String id) async =>
      _prefs?.setString(_kSelected, id);

  // ---- Progression: daily reward & streak ----------------------------------
  static const _kLastDaily = 'flappy_rain_last_daily_v1';
  static const _kStreak = 'flappy_rain_streak_v1';

  /// Day index of the last claimed daily reward (-1 = never).
  static int get lastDailyDay => _prefs?.getInt(_kLastDaily) ?? -1;
  static Future<void> setLastDailyDay(int v) async => _prefs?.setInt(_kLastDaily, v);

  static int get streak => _prefs?.getInt(_kStreak) ?? 0;
  static Future<void> setStreak(int v) async => _prefs?.setInt(_kStreak, v);

  // ---- Progression: daily missions -----------------------------------------
  static const _kMissionDay = 'flappy_rain_mission_day_v1';
  static const _kMissionProg = 'flappy_rain_mission_prog_v1';
  static const _kMissionDone = 'flappy_rain_mission_done_v1';

  static int get missionDay => _prefs?.getInt(_kMissionDay) ?? -1;
  static Future<void> setMissionDay(int v) async => _prefs?.setInt(_kMissionDay, v);

  static List<int> get missionProgress {
    final raw = _prefs?.getStringList(_kMissionProg);
    if (raw == null || raw.length < 3) return [0, 0, 0];
    return raw.map((e) => int.tryParse(e) ?? 0).toList();
  }

  static Future<void> setMissionProgress(List<int> v) async =>
      _prefs?.setStringList(_kMissionProg, v.map((e) => '$e').toList());

  static List<bool> get missionClaimed {
    final raw = _prefs?.getStringList(_kMissionDone);
    if (raw == null || raw.length < 3) return [false, false, false];
    return raw.map((e) => e == '1').toList();
  }

  static Future<void> setMissionClaimed(List<bool> v) async =>
      _prefs?.setStringList(_kMissionDone, v.map((e) => e ? '1' : '0').toList());

  // ---- Progression: achievements & lifetime stats --------------------------
  static const _kAchievements = 'flappy_rain_achievements_v1';
  static const _kLifeCoins = 'flappy_rain_life_coins_v1';
  static const _kLifeNear = 'flappy_rain_life_near_v1';
  static const _kLifePower = 'flappy_rain_life_power_v1';
  static const _kBestCombo = 'flappy_rain_best_combo_v1';

  static List<String> get unlockedAchievements =>
      _prefs?.getStringList(_kAchievements) ?? const [];

  static bool hasAchievement(String id) => unlockedAchievements.contains(id);

  static Future<void> unlockAchievement(String id) async {
    final l = List<String>.from(unlockedAchievements);
    if (!l.contains(id)) {
      l.add(id);
      await _prefs?.setStringList(_kAchievements, l);
    }
  }

  static int get lifetimeCoins => _prefs?.getInt(_kLifeCoins) ?? 0;
  static int get lifetimeNearMisses => _prefs?.getInt(_kLifeNear) ?? 0;
  static int get lifetimePowerups => _prefs?.getInt(_kLifePower) ?? 0;
  static int get bestCombo => _prefs?.getInt(_kBestCombo) ?? 0;
  static Future<void> setBestCombo(int v) async => _prefs?.setInt(_kBestCombo, v);

  static Future<void> addLifetime({
    int coins = 0,
    int nearMisses = 0,
    int powerups = 0,
  }) async {
    await _prefs?.setInt(_kLifeCoins, lifetimeCoins + coins);
    await _prefs?.setInt(_kLifeNear, lifetimeNearMisses + nearMisses);
    await _prefs?.setInt(_kLifePower, lifetimePowerups + powerups);
  }

  // ---- Settings ------------------------------------------------------------
  static bool get soundOn => _prefs?.getBool(_kSound) ?? true;
  static Future<void> setSoundOn(bool v) async => _prefs?.setBool(_kSound, v);

  static bool get hapticsOn => _prefs?.getBool(_kHaptics) ?? true;
  static Future<void> setHapticsOn(bool v) async => _prefs?.setBool(_kHaptics, v);

  static bool get reducedMotion => _prefs?.getBool(_kMotion) ?? false;
  static Future<void> setReducedMotion(bool v) async =>
      _prefs?.setBool(_kMotion, v);
}
