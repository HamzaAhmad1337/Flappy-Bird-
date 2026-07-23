import 'package:shared_preferences/shared_preferences.dart';

import '../game/config.dart';

/// Thin wrapper around shared_preferences for persisting the high score.
class Storage {
  Storage._();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static int get highScore => _prefs?.getInt(GameConfig.highScoreKey) ?? 0;

  static Future<void> setHighScore(int value) async {
    await _prefs?.setInt(GameConfig.highScoreKey, value);
  }
}
