import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/config.dart';
import 'game/flappy_game.dart';
import 'overlays/game_over.dart';
import 'overlays/hud.dart';
import 'overlays/main_menu.dart';
import 'overlays/pause_menu.dart';
import 'overlays/settings.dart';
import 'overlays/shop.dart';
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
  await Sfx.init(); // preload synthesized sound effects (fails silently)

  runApp(const FlappyRainApp());
}

class FlappyRainApp extends StatelessWidget {
  const FlappyRainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flappy Rain',
      debugShowCheckedModeBanner: false,
      home: GameScreen(),
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
    if (state != AppLifecycleState.resumed &&
        _game.state == GameState.playing) {
      _game.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameConfig.skyTop,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _game.onAction,
        child: GameWidget<FlappyGame>(
          game: _game,
          overlayBuilderMap: {
            'mainMenu': (_, game) => MainMenu(game: game),
            'hud': (_, game) => Hud(game: game),
            'pauseMenu': (_, game) => PauseMenu(game: game),
            'gameOver': (_, game) => GameOverMenu(game: game),
            'shop': (_, game) => Shop(game: game),
            'settings': (_, game) => Settings(game: game),
          },
        ),
      ),
    );
  }
}
