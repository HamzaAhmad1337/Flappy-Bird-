import 'dart:math';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../components/background.dart';
import '../components/bird.dart';
import '../components/ground.dart';
import '../components/lightning.dart';
import '../components/pipe_pair.dart';
import '../components/rain.dart';
import '../services/sfx.dart';
import '../services/storage.dart';
import 'config.dart';

/// The heart of the game: owns state, spawns pipes, runs collision detection
/// and scoring, and coordinates every visual component. A fixed-resolution
/// camera keeps the layout identical on every device.
class FlappyGame extends FlameGame with KeyboardEvents {
  FlappyGame();

  // Reactive values the Flutter overlays listen to.
  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> best = ValueNotifier<int>(0);

  GameState state = GameState.menu;

  late final Bird bird;
  late final Background background;
  final List<PipePair> _pipes = [];

  double scrollSpeed = GameConfig.pipeSpeed;
  double _spawnTimer = 0;
  double _idleTime = 0;
  final Random _rng = Random();

  @override
  Color backgroundColor() => GameConfig.skyTop;

  @override
  Future<void> onLoad() async {
    // Fixed logical resolution — letterboxed to fit any screen, so the game
    // plays exactly the same on a phone, tablet or the web preview. We adjust
    // the game's existing camera rather than replacing it (which would leave
    // the default camera orphaned in the component tree).
    camera.viewport = FixedResolutionViewport(
      resolution: Vector2(GameConfig.width, GameConfig.height),
    );
    camera.viewfinder
      ..anchor = Anchor.topLeft
      ..position = Vector2.zero();

    background = Background();
    bird = Bird();

    world.addAll([
      background,
      Ground(),
      bird,
      Rain(),
      Lightning(),
    ]);

    best.value = Storage.highScore;
    overlays.add('mainMenu');
  }

  // ---- Input ---------------------------------------------------------------

  /// A tap / click / space press. Behaviour depends on the current state.
  void onAction() {
    switch (state) {
      case GameState.menu:
        startGame();
        bird.flap();
        break;
      case GameState.playing:
        bird.flap();
        Sfx.flap();
        break;
      case GameState.paused:
      case GameState.gameOver:
        break; // handled by overlay buttons
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.arrowUp)) {
      onAction();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- State transitions ---------------------------------------------------

  void startGame() {
    _clearPipes();
    score.value = 0;
    scrollSpeed = GameConfig.pipeSpeed;
    _spawnTimer = GameConfig.pipeSpawnInterval * 0.6;
    bird.reset();
    state = GameState.playing;
    overlays.remove('mainMenu');
    overlays.remove('gameOver');
    overlays.add('hud');
  }

  void pause() {
    if (state != GameState.playing) return;
    state = GameState.paused;
    overlays.add('pauseMenu');
  }

  void resume() {
    if (state != GameState.paused) return;
    state = GameState.playing;
    overlays.remove('pauseMenu');
  }

  void restart() {
    overlays.remove('gameOver');
    overlays.remove('pauseMenu');
    startGame();
  }

  void goToMenu() {
    _clearPipes();
    overlays.remove('gameOver');
    overlays.remove('pauseMenu');
    overlays.remove('hud');
    bird.reset();
    state = GameState.menu;
    overlays.add('mainMenu');
  }

  Future<void> _gameOver() async {
    if (state == GameState.gameOver) return;
    state = GameState.gameOver;
    Sfx.hit();
    if (score.value > best.value) {
      best.value = score.value;
      await Storage.setHighScore(best.value);
    }
    overlays.remove('hud');
    overlays.add('gameOver');
  }

  // ---- Loop ----------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);

    if (state == GameState.menu) {
      _idleTime += dt;
      bird.idleBob(dt, _idleTime);
      return;
    }
    if (state != GameState.playing) return;

    // Gentle difficulty ramp.
    final bonus = min(score.value * GameConfig.speedPerPoint, GameConfig.maxSpeedBonus);
    scrollSpeed = GameConfig.pipeSpeed + bonus;

    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnPipe();
      _spawnTimer = GameConfig.pipeSpawnInterval;
    }

    _handleScoringAndCleanup();
    _checkCollisions();
  }

  void _spawnPipe() {
    final gap = max(
      GameConfig.minGap,
      GameConfig.pipeGap - score.value * GameConfig.gapShrinkPerPoint,
    );
    final groundY = GameConfig.height - GameConfig.groundHeight;
    final minC = GameConfig.pipeMinMargin + gap / 2;
    final maxC = groundY - GameConfig.pipeMinMargin - gap / 2;
    final center = minC + _rng.nextDouble() * (maxC - minC);

    final pipe = PipePair(gapCenter: center, gap: gap)
      ..position = Vector2(GameConfig.width + 20, 0);
    _pipes.add(pipe);
    world.add(pipe);
  }

  void _handleScoringAndCleanup() {
    for (final pipe in _pipes) {
      if (!pipe.scored && pipe.right < bird.position.x) {
        pipe.scored = true;
        score.value += 1;
        Sfx.score();
      }
    }
    final gone = _pipes.where((p) => p.right < -20).toList();
    for (final p in gone) {
      p.removeFromParent();
      _pipes.remove(p);
    }
  }

  void _checkCollisions() {
    final b = bird.bounds;

    // Ground / ceiling.
    final groundY = GameConfig.height - GameConfig.groundHeight;
    if (b.y + b.r >= groundY) {
      bird.position.y = groundY - b.r;
      _gameOver();
      return;
    }
    if (b.y - b.r <= 0) {
      bird.position.y = b.r;
      bird.velocity = 0;
    }

    for (final pipe in _pipes) {
      if (pipe.collidesWith(b)) {
        _gameOver();
        return;
      }
    }
  }

  void _clearPipes() {
    for (final p in _pipes) {
      p.removeFromParent();
    }
    _pipes.clear();
  }
}
