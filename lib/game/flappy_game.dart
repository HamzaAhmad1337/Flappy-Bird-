import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../components/ambience.dart';
import '../components/background.dart';
import '../components/bird.dart';
import '../components/coin.dart';
import '../components/floating_text.dart';
import '../components/ground.dart';
import '../components/lens_overlay.dart';
import '../components/lightning.dart';
import '../components/particles.dart';
import '../components/pipe_pair.dart';
import '../components/powerup.dart';
import '../components/rain.dart';
import '../components/reflections.dart';
import '../components/sky_shader.dart';
import '../services/progression.dart';
import '../services/sfx.dart';
import '../services/storage.dart';
import 'config.dart';
import 'level.dart';
import 'skins.dart';

/// The heart of the game: owns state, spawns obstacles / collectibles, runs
/// collision + scoring, drives power-ups, day-night time, combos, slow-motion
/// and screen shake, and coordinates every visual component.
class FlappyGame extends FlameGame with KeyboardEvents {
  // A fixed logical resolution keeps the layout identical on every device,
  // letterboxing to fit. FlameGame wires this camera to its world for us.
  FlappyGame()
      : super(
          camera: CameraComponent.withFixedResolution(
            width: GameConfig.width,
            height: GameConfig.height,
          ),
        );

  // Reactive values the Flutter overlays listen to.
  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> best = ValueNotifier<int>(0);
  final ValueNotifier<int> wallet = ValueNotifier<int>(0);

  /// The current phase, exposed as a listenable so overlays can react to a
  /// transition instead of polling. The HUD's "get ready" prompt is driven by
  /// this: the HUD itself doesn't rebuild every frame (deliberately), so a
  /// plain field would have left the prompt frozen on screen after the first
  /// flap.
  final ValueNotifier<GameState> phase = ValueNotifier<GameState>(GameState.menu);

  GameState get state => phase.value;
  set state(GameState v) => phase.value = v;

  late final Bird bird;
  late final Background background;
  late final ParticleField particles;
  final List<PipePair> _pipes = [];
  final List<Coin> _coins = [];
  final List<PowerUp> _powerups = [];

  BirdSkin skin = Skins.byId('classic');
  bool get reducedMotion => Storage.reducedMotion;

  double scrollSpeed = GameConfig.pipeSpeed;
  /// Distance travelled since the last pipe — pipes are spaced by distance.
  double _sinceSpawn = 0;
  late final LevelGenerator _level = LevelGenerator();
  double _idleTime = 0;
  double _worldTime = 0.1 * GameConfig.dayCycleSeconds; // start mid-morning
  final Random _rng = Random();

  // Run economy & flair.
  int runCoins = 0;
  int comboCount = 0;
  double _comboTimer = 0;
  int _pipesSinceType = 0; // ensures power-up variety

  // Per-run tallies folded into long-term progression on death.
  int runBestCombo = 0;
  int runNearMisses = 0;
  int runPowerups = 0;

  /// Set on death when this run beat the previous best.
  bool lastRunWasBest = false;

  /// Missions completed / achievements unlocked by the run that just ended.
  List<int> lastMissionsCompleted = const [];
  List<Achievement> lastUnlocked = const [];

  // Power-up timers (real seconds remaining).
  double shieldRemaining = 0;
  double slowmoRemaining = 0;
  double magnetRemaining = 0;
  double _invuln = 0;

  // Slow-motion / juice.
  double _timeScale = 1;
  double _nearMissTimer = 0;
  double _shake = 0;

  bool get shieldActive => shieldRemaining > 0;
  bool get magnetActive => magnetRemaining > 0;
  double get skyPhase => (_worldTime / GameConfig.dayCycleSeconds) % 1.0;

  // ---- Render-side state (read by the shader layers) -----------------------
  /// Total distance the world has scrolled — drives sky/cloud parallax.
  double worldScroll = 0;

  /// 0..1 lightning brightness, published by the Lightning component so the
  /// sky and lens passes can bloom in sync with the bolt.
  double lightningFlash = 0;

  double get stormIntensity => GameConfig.stormIntensity;

  /// How lit the world is right now, 0 at midnight to 1 at midday.
  double get dayness =>
      (0.5 + 0.5 * cos((skyPhase - 0.25) * 2 * pi)).clamp(0.0, 1.0);

  /// Multiplied into the world sprites so they track the sky.
  ///
  /// Every texture is baked under the same neutral studio light, so without
  /// this the ground and pipes stayed daylit under a midnight sky — the most
  /// jarring thing left in the scene once the day/night cycle went in.
  Color get worldTint {
    final d = dayness;
    return Color.lerp(
      const Color(0xFF6E7DA0), // night: dim and cool
      const Color(0xFFFFFFFF), // midday: as baked
      d * d * (3 - 2 * d), // smoothstep, so dusk lingers a little
    )!;
  }

  /// Physics never integrates more than this much time in a single step.
  ///
  /// Without a cap, one long frame — the hitch when overlays rebuild as a run
  /// starts, a shader warming up, the app resuming from background — applies
  /// hundreds of milliseconds of gravity at once and teleports the bird
  /// straight into the ground. Briefly slowing time during a hitch is far
  /// better than dying to it.
  static const double maxTimeStep = 1 / 30;

  /// Pipes currently in the world, for layers that need to draw them again
  /// (the wet-ground reflection).
  Iterable<PipePair> get visiblePipes => _pipes;

  List<({PowerType type, double remaining})> get activePowers {
    final l = <({PowerType type, double remaining})>[];
    if (shieldRemaining > 0) l.add((type: PowerType.shield, remaining: shieldRemaining));
    if (slowmoRemaining > 0) l.add((type: PowerType.slowmo, remaining: slowmoRemaining));
    if (magnetRemaining > 0) l.add((type: PowerType.magnet, remaining: magnetRemaining));
    return l;
  }

  @override
  Color backgroundColor() => GameConfig.skyTop;

  @override
  Future<void> onLoad() async {
    // Put world (0,0) at the top-left of the fixed viewport so components can
    // use screen-like coordinates (0..width, 0..height).
    camera.viewfinder
      ..anchor = Anchor.topLeft
      ..position = Vector2.zero();

    background = Background();
    bird = Bird();
    particles = ParticleField();

    world.addAll([
      SkyShaderLayer(),   // volumetric sky (GPU)
      background,         // mountains / city / haze
      Ground(),
      Reflections(),      // wet-ground mirror of the pipes & bird
      Ambience(),         // fireflies / motes / ground mist
      bird,
      particles,
      Rain(),
      Lightning(),
      LensOverlay(),      // rain-on-lens, vignette, grain (GPU)
    ]);

    best.value = Storage.highScore;
    wallet.value = Storage.coins;
    refreshSkin();
    overlays.add('mainMenu');
  }

  void refreshSkin() => skin = Skins.byId(Storage.selectedSkin);

  /// Popups, outermost last — the order the back gesture unwinds them in.
  static const List<String> _modalIds = [
    'dailyReward',
    'missions',
    'shop',
    'settings',
    'pauseMenu',
  ];

  /// Dismisses every popup. A run must never start underneath one — anything
  /// opened from the menu (or scheduled asynchronously, like the daily reward)
  /// would otherwise sit on top of live gameplay, blocking the flap surface.
  void _closeModals() {
    for (final id in _modalIds) {
      overlays.remove(id);
    }
  }

  /// Closes the frontmost open popup, if any. Returns whether one was closed,
  /// so the back gesture can fall through to pausing when nothing is open.
  bool closeTopModal() {
    for (final id in _modalIds) {
      if (overlays.isActive(id)) {
        overlays.remove(id);
        // Backing out of the pause panel should resume, not leave the game
        // sitting frozen with no visible way back.
        if (id == 'pauseMenu' && state == GameState.paused) {
          state = GameState.playing;
        }
        return true;
      }
    }
    return false;
  }

  // ---- Input ---------------------------------------------------------------

  void onAction() {
    switch (state) {
      case GameState.menu:
        // Same as tapping Play: leave the bird hovering and let the next press
        // be the one that commits. Flapping straight through would make the
        // keyboard path skip the ready beat the touch path gets.
        startGame();
        break;
      case GameState.ready:
      case GameState.playing:
        flapInput();
        break;
      case GameState.paused:
      case GameState.gameOver:
        break;
    }
  }

  /// Flap, driven by the HUD's press surface. Safe to call repeatedly — a flap
  /// sets the vertical velocity rather than accumulating it.
  void flapInput() {
    if (state == GameState.ready) {
      // First flap commits: physics and spawning start from here.
      state = GameState.playing;
      bird.flap();
      Sfx.flap();
      return;
    }
    if (state != GameState.playing) return;
    bird.flap();
    Sfx.flap();
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
    // Browsers (and iOS in some states) refuse to start audio until the user
    // has interacted, so the looping beds begin here rather than at launch.
    Sfx.startBeds();
    _clearField();
    refreshSkin();
    score.value = 0;
    runCoins = 0;
    comboCount = 0;
    runBestCombo = 0;
    runNearMisses = 0;
    runPowerups = 0;
    lastRunWasBest = false;
    _comboTimer = 0;
    _pipesSinceType = 0;
    shieldRemaining = slowmoRemaining = magnetRemaining = 0;
    _invuln = 0;
    _timeScale = 1;
    _nearMissTimer = 0;
    scrollSpeed = GameConfig.pipeSpeed;
    _level.reset(startCenter: GameConfig.birdStartY);
    // Give the player a beat before the first pipe arrives.
    _sinceSpawn = GameConfig.pipeSpacing * 0.35;
    bird.reset();
    state = GameState.ready;
    _closeModals();
    overlays.remove('mainMenu');
    overlays.remove('gameOver');
    overlays.add('hud');
  }

  void pause() {
    if (state != GameState.playing) return;
    state = GameState.paused;
    Sfx.button();
    overlays.add('pauseMenu');
  }

  void resume() {
    if (state != GameState.paused) return;
    Sfx.button();
    state = GameState.playing;
    overlays.remove('pauseMenu');
  }

  void restart() {
    Sfx.button();
    overlays.remove('gameOver');
    overlays.remove('pauseMenu');
    startGame();
  }

  void goToMenu() {
    Sfx.button();
    _clearField();
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
    shake(GameConfig.shakeOnHit);
    particles.burst(bird.position.x, bird.position.y, skin.body, count: 30);

    // Commit run rewards.
    if (runCoins > 0) {
      await Storage.addCoins(runCoins);
      wallet.value = Storage.coins;
    }
    await Storage.incGamesPlayed();
    if (score.value > best.value) {
      lastRunWasBest = true;
      best.value = score.value;
      await Storage.setHighScore(best.value);
    }

    // Fold the run into missions, achievements and lifetime stats.
    final result = await Progression.recordRun(RunStats(
      score: score.value,
      coins: runCoins,
      bestCombo: runBestCombo,
      nearMisses: runNearMisses,
      powerupsUsed: runPowerups,
    ));
    lastMissionsCompleted = result.missionsCompleted;
    lastUnlocked = result.unlocked;
    wallet.value = Storage.coins;

    overlays.remove('hud');
    overlays.add('gameOver');
  }

  // ---- Juice helpers -------------------------------------------------------

  void shake(double amount) {
    if (reducedMotion) amount *= 0.4;
    _shake = max(_shake, amount);
  }

  void _triggerNearMiss() {
    _nearMissTimer = 0.55;
    runNearMisses += 1;
    comboCount += 1;
    _comboTimer = LevelGenerator.intervalFor(score.value) * 2.4;
    Sfx.swoosh();
    spawnText('CLOSE!', bird.position + Vector2(0, -40), PowerType.slowmo.color, size: 24);
  }

  /// A confetti burst + banner used for milestones and personal bests.
  void celebrate(String text, Color color) {
    Sfx.powerup();
    if (!reducedMotion) {
      particles.confetti(bird.position.x + 30, bird.position.y, count: 34);
      shake(5);
    }
    spawnText(text, bird.position + Vector2(0, -66), color, size: 30);
  }

  void spawnText(String text, Vector2 pos, Color color, {double size = 26}) {
    world.add(FloatingText(start: pos, text: text, color: color, fontSize: size));
  }

  // ---- Loop ----------------------------------------------------------------

  @override
  void update(double dt) {
    // Never integrate a huge frame in one go (see maxTimeStep).
    dt = min(dt, maxTimeStep);

    _worldTime += dt;
    worldScroll += (state == GameState.playing ? scrollSpeed : 26.0) * dt;
    _updatePowerTimers(dt);
    _updateTimeScale(dt);
    _updateShake(dt);

    // Everything advances on scaled time for a cohesive slow-mo effect.
    final scaled = dt * _timeScale;
    super.update(scaled);

    if (state == GameState.menu || state == GameState.ready) {
      _idleTime += dt;
      bird.idleBob(dt, _idleTime);
      return;
    }
    if (state != GameState.playing) return;

    scrollSpeed = LevelGenerator.speedFor(score.value);

    if (_comboTimer > 0) {
      _comboTimer -= scaled;
      if (_comboTimer <= 0) comboCount = 0;
    }

    _sinceSpawn += scrollSpeed * scaled;
    if (_sinceSpawn >= GameConfig.pipeSpacing) {
      _sinceSpawn -= GameConfig.pipeSpacing;
      _spawnPipe();
    }

    _handleScoringAndCleanup();
    _handleCollectibles();
    _checkNearMiss();
    _checkCollisions();
  }

  void _updatePowerTimers(double dt) {
    if (shieldRemaining > 0) shieldRemaining = max(0, shieldRemaining - dt);
    if (slowmoRemaining > 0) slowmoRemaining = max(0, slowmoRemaining - dt);
    if (magnetRemaining > 0) magnetRemaining = max(0, magnetRemaining - dt);
    if (_invuln > 0) _invuln = max(0, _invuln - dt);
    if (_nearMissTimer > 0) _nearMissTimer = max(0, _nearMissTimer - dt);
  }

  void _updateTimeScale(double dt) {
    double target = 1;
    if (_nearMissTimer > 0) target = min(target, GameConfig.nearMissSlowmo);
    if (slowmoRemaining > 0) target = min(target, GameConfig.slowmoFactor);
    // Ease toward the target so speed changes feel smooth.
    _timeScale += (target - _timeScale) * min(1, dt * 12);
  }

  void _updateShake(double dt) {
    if (_shake > 0.2) {
      _shake = max(0, _shake - dt * 60);
      final ox = (_rng.nextDouble() * 2 - 1) * _shake;
      final oy = (_rng.nextDouble() * 2 - 1) * _shake;
      camera.viewfinder.position = Vector2(ox, oy);
    } else {
      _shake = 0;
      camera.viewfinder.position = Vector2.zero();
    }
  }

  // ---- Spawning ------------------------------------------------------------

  void _spawnPipe() {
    final placement = _level.next(score.value);
    final gap = placement.gap;
    final center = placement.gapCenter;

    const x = GameConfig.width + 20;
    final pipe = PipePair(gapCenter: center, gap: gap)..position = Vector2(x, 0);
    _pipes.add(pipe);
    world.add(pipe);

    _pipesSinceType++;

    // Occasionally place a power-up in the gap...
    if (_pipesSinceType >= 4 && _rng.nextDouble() < GameConfig.powerupSpawnChance) {
      _pipesSinceType = 0;
      final type = PowerType.values[_rng.nextInt(PowerType.values.length)];
      final p = PowerUp(Vector2(x + GameConfig.pipeWidth / 2 + 120, center), type);
      _powerups.add(p);
      world.add(p);
    } else if (_rng.nextDouble() < GameConfig.coinSpawnChance) {
      // ...otherwise a little arc of coins.
      const n = 3;
      for (int i = 0; i < n; i++) {
        final cy = center + (i - 1) * 34.0;
        final coin = Coin(Vector2(x + GameConfig.pipeWidth / 2 + 100 + i * 34, cy));
        _coins.add(coin);
        world.add(coin);
      }
    }
  }

  // ---- Scoring / collectibles ---------------------------------------------

  void _handleScoringAndCleanup() {
    for (final pipe in _pipes) {
      if (!pipe.scored && pipe.right < bird.position.x) {
        pipe.scored = true;
        score.value += 1;
        comboCount += 1;
        if (comboCount > runBestCombo) runBestCombo = comboCount;
        _comboTimer = LevelGenerator.intervalFor(score.value) * 2.4;
        Sfx.score();
        if (comboCount >= 3 && comboCount % 3 == 0) {
          runCoins += 1; // combo bounty
          spawnText('COMBO x$comboCount  +1', bird.position + Vector2(0, -46),
              const Color(0xFFFFD447), size: 22);
        }
        // The moment you overtake your own record — called out mid-run because
        // it's the most motivating beat in the whole loop.
        if (!lastRunWasBest && best.value > 0 && score.value == best.value + 1) {
          lastRunWasBest = true;
          celebrate('NEW BEST!', const Color(0xFFFFD447));
        }
        // Every tenth pipe gets a small celebration to break up a long run.
        if (score.value % 10 == 0) {
          celebrate('${score.value}!', const Color(0xFF7FC4FF));
        }
      }
    }
    _pipes.removeWhere((p) {
      final gone = p.right < -20;
      if (gone) p.removeFromParent();
      return gone;
    });
  }

  /// Squared distance between two points, without allocating a Vector2 for the
  /// difference — this runs for every collectible on screen, every frame.
  static double _dist2(double ax, double ay, double bx, double by) {
    final dx = ax - bx;
    final dy = ay - by;
    return dx * dx + dy * dy;
  }

  void _handleCollectibles() {
    final b = bird.bounds;

    final coinReach = b.r + Coin.r;
    final coinReach2 = coinReach * coinReach;
    for (final coin in _coins) {
      if (coin.collected) continue;
      if (_dist2(coin.position.x, coin.position.y, b.x, b.y) <= coinReach2) {
        coin.collected = true;
        coin.removeFromParent();
        runCoins += 1;
        Sfx.coin();
        particles.sparkle(coin.position.x, coin.position.y, const Color(0xFFFFD447));
      }
    }
    _coins.removeWhere((c) => c.collected || c.isRemoving);

    final powerReach = b.r + PowerUp.r;
    final powerReach2 = powerReach * powerReach;
    for (final p in _powerups) {
      if (p.collected) continue;
      if (_dist2(p.position.x, p.position.y, b.x, b.y) <= powerReach2) {
        p.collected = true;
        p.removeFromParent();
        _activatePower(p.type);
      }
    }
    _powerups.removeWhere((p) => p.collected || p.isRemoving);
  }

  void _activatePower(PowerType type) {
    runPowerups += 1;
    Sfx.powerup();
    particles.sparkle(bird.position.x, bird.position.y, type.color, count: 16);
    spawnText(type.label.toUpperCase(), bird.position + Vector2(0, -46), type.color, size: 22);
    switch (type) {
      case PowerType.shield:
        shieldRemaining = type.duration;
        break;
      case PowerType.slowmo:
        slowmoRemaining = type.duration;
        break;
      case PowerType.magnet:
        magnetRemaining = type.duration;
        break;
    }
  }

  // ---- Collisions ----------------------------------------------------------

  void _checkNearMiss() {
    final b = bird.bounds;
    for (final pipe in _pipes) {
      if (pipe.nearMissed || pipe.scored) continue;
      final overlapsX = b.x >= pipe.position.x && b.x <= pipe.right;
      if (!overlapsX) continue;
      final distTop = (b.y - b.r) - pipe.topPipeBottom;
      final distBot = pipe.bottomPipeTop - (b.y + b.r);
      final closest = min(distTop, distBot);
      if (closest > 0 && closest < GameConfig.nearMissDist) {
        pipe.nearMissed = true;
        _triggerNearMiss();
      }
    }
  }

  void _checkCollisions() {
    final b = bird.bounds;
    const groundY = GameConfig.height - GameConfig.groundHeight;

    // Ground.
    if (b.y + b.r >= groundY) {
      if (_invuln > 0 || shieldActive) {
        bird.position.y = groundY - b.r;
        bird.velocity = GameConfig.flapVelocity * 0.7;
        if (shieldActive && _invuln <= 0) _breakShield();
      } else {
        bird.position.y = groundY - b.r;
        _gameOver();
        return;
      }
    }
    // Ceiling.
    if (b.y - b.r <= 0) {
      bird.position.y = b.r;
      bird.velocity = 0;
    }

    if (_invuln > 0) return; // brief grace after a shield break

    for (final pipe in _pipes) {
      if (pipe.collidesWith(b)) {
        if (shieldActive) {
          _breakShield();
        } else {
          _gameOver();
        }
        return;
      }
    }
  }

  void _breakShield() {
    shieldRemaining = 0;
    _invuln = 1.1;
    Sfx.shield();
    shake(GameConfig.shakeOnShield);
    particles.burst(bird.position.x, bird.position.y, PowerType.shield.color, count: 22);
    spawnText('SHIELD!', bird.position + Vector2(0, -46), PowerType.shield.color, size: 22);
    // Nudge the bird toward the gap center to give a fair recovery.
    bird.velocity = GameConfig.flapVelocity * 0.6;
  }

  // ---- Cleanup -------------------------------------------------------------

  void _clearField() {
    for (final p in _pipes) {
      p.removeFromParent();
    }
    for (final c in _coins) {
      c.removeFromParent();
    }
    for (final p in _powerups) {
      p.removeFromParent();
    }
    _pipes.clear();
    _coins.clear();
    _powerups.clear();
    particles.clear();
  }
}
