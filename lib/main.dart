import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/config.dart';
import 'game/flappy_game.dart';
import 'overlays/game_over.dart';
import 'overlays/hud.dart';
import 'overlays/ui_kit.dart';
import 'overlays/main_menu.dart';
import 'overlays/pause_menu.dart';
import 'overlays/daily_reward.dart';
import 'overlays/missions.dart';
import 'overlays/settings.dart';
import 'overlays/shop.dart';
import 'services/assets.dart';
import 'services/sfx.dart';
import 'services/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only, fullscreen immersive — this is a phone game.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await Storage.init();
  await Sfx.init(); // synthesized sound effects (fails silently)
  // Baked 3D sprites + GPU shaders (fails silently). Only the equipped skin is
  // decoded here; the rest load on demand when the shop is opened.
  await GameAssets.load(selectedSkin: Storage.selectedSkin);

  runApp(const FlappyRainApp());
}

class FlappyRainApp extends StatelessWidget {
  const FlappyRainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flappy Rain',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: UiKit.fontFamily),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final FlappyGame _game = FlappyGame();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-pause when the app is backgrounded so the player doesn't lose a run.
    final backgrounded = state != AppLifecycleState.resumed;
    if (backgrounded && _game.state == GameState.playing) {
      _game.pause();
    }
    // Don't keep raining into someone's headphones after they switch away.
    Sfx.setPaused(backgrounded);
  }

  /// Android's back gesture. Backing out of a run should pause it or step back
  /// through the open panel — quitting the app mid-flight is never what the
  /// player meant, and losing a good run that way is the kind of thing that
  /// gets an app uninstalled.
  void _onBack() {
    if (_game.closeTopModal()) return;
    if (_game.state == GameState.playing) {
      _game.pause();
      return;
    }
    if (_game.state == GameState.gameOver || _game.state == GameState.ready) {
      // Backing out before the first flap costs nothing, so go straight to the
      // menu rather than pausing an un-started run — or, worse, quitting.
      _game.goToMenu();
      return;
    }
    // On the menu with nothing open, fall through and let the OS close the app.
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: GameConfig.skyTop,
        // Input is handled inside each overlay (see Hud/MainMenu/GameOverMenu):
        // pointer events reach overlay widgets reliably, and it keeps every
        // screen owning its own gestures instead of one global handler guessing.
        body: GameWidget<FlappyGame>(
          game: _game,
          overlayBuilderMap: {
            'mainMenu': (_, game) => MainMenu(game: game),
            'hud': (_, game) => Hud(game: game),
            'pauseMenu': (_, game) => PauseMenu(game: game),
            'gameOver': (_, game) => GameOverMenu(game: game),
            'shop': (_, game) => Shop(game: game),
            'settings': (_, game) => Settings(game: game),
            'missions': (_, game) => MissionsPanel(game: game),
            'dailyReward': (_, game) => DailyRewardPopup(game: game),
          },
        ),
      ),
    );
  }
}
