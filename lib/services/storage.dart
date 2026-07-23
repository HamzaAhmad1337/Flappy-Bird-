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

  // ---- Settings ------------------------------------------------------------
  static bool get soundOn => _prefs?.getBool(_kSound) ?? true;
  static Future<void> setSoundOn(bool v) async => _prefs?.setBool(_kSound, v);

  static bool get hapticsOn => _prefs?.getBool(_kHaptics) ?? true;
  static Future<void> setHapticsOn(bool v) async => _prefs?.setBool(_kHaptics, v);

  static bool get reducedMotion => _prefs?.getBool(_kMotion) ?? false;
  static Future<void> setReducedMotion(bool v) async =>
      _prefs?.setBool(_kMotion, v);
}
