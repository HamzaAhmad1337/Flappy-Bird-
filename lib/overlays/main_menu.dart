import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/flappy_game.dart';
import '../services/progression.dart';
import '../services/sfx.dart';
import '../services/storage.dart';
import 'ui_kit.dart';

/// Start screen: title, rank, coin balance and the way into Goals / Shop /
/// Settings. Tapping anywhere that isn't a button starts a run.
class MainMenu extends StatefulWidget {
  const MainMenu({super.key, required this.game});
  final FlappyGame game;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> with TickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
        ..forward();

  @override
  void initState() {
    super.initState();
    // Show the daily reward once, the first time the menu appears in a session.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Progression.ensureFreshMissions();
      if (!mounted) return;
      // Rolling the missions over touches storage, and on a slow device that
      // await can outlast the menu — a player who taps Play immediately would
      // otherwise get the reward popping up on top of a run already in
      // progress. Re-check where we are before showing anything.
      if (widget.game.state != GameState.menu) return;
      if (!widget.game.overlays.isActive('mainMenu')) return;
      if (Progression.dailyRewardAvailable &&
          !widget.game.overlays.isActive('dailyReward')) {
        widget.game.overlays.add('dailyReward');
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _enter.dispose();
    super.dispose();
  }

  bool get _hasClaimableMission {
    final missions = Progression.todayMissions;
    final prog = Storage.missionProgress;
    final claimed = Storage.missionClaimed;
    for (var i = 0; i < missions.length && i < prog.length; i++) {
      if (!claimed[i] && prog[i] >= missions[i].target) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final best = Storage.highScore;
    final rank = Progression.rankFor(best);
    final slide = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);

    return GestureDetector(
      // Tap anywhere (outside a button) to fly.
      behavior: HitTestBehavior.opaque,
      // Starting leaves the bird hovering in the ready state; the player's
      // next tap is what commits them to the run.
      onTap: widget.game.startGame,
      child: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: ValueListenableBuilder<int>(
                  valueListenable: widget.game.wallet,
                  builder: (_, coins, __) => CoinPill(count: coins),
                ),
              ),
            ),
            // Rank badge, top-left.
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xCC102A3B),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: rank.color.withValues(alpha: 0.7)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_rounded, size: 15, color: rank.color),
                      const SizedBox(width: 6),
                      Text(rank.name, style: UiKit.label(13, color: rank.color)),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: slide,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Spacer(flex: 2),
                    _Title(anim: slide),
                    const SizedBox(height: 8),
                    Text('BEST  $best',
                        style: UiKit.label(18,
                            color: Colors.white.withValues(alpha: 0.85))),
                    if (Storage.streak > 1) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              color: Color(0xFFFF8A5B), size: 16),
                          const SizedBox(width: 4),
                          Text('${Storage.streak} day streak',
                              style: UiKit.label(13, color: const Color(0xFFFF8A5B))),
                        ],
                      ),
                    ],
                    const Spacer(flex: 3),
                    GameButton(
                      label: 'PLAY',
                      icon: Icons.play_arrow_rounded,
                      onTap: widget.game.startGame,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MenuIcon(
                          icon: Icons.flag_rounded,
                          label: 'Goals',
                          badge: _hasClaimableMission,
                          onTap: () {
                            Sfx.button();
                            widget.game.overlays.add('missions');
                          },
                        ),
                        const SizedBox(width: 10),
                        _MenuIcon(
                          icon: Icons.storefront_rounded,
                          label: 'Shop',
                          onTap: () {
                            Sfx.button();
                            widget.game.overlays.add('shop');
                          },
                        ),
                        const SizedBox(width: 10),
                        _MenuIcon(
                          icon: Icons.settings_rounded,
                          label: 'Settings',
                          onTap: () {
                            Sfx.button();
                            widget.game.overlays.add('settings');
                          },
                        ),
                      ],
                    ),
                    const Spacer(flex: 2),
                    FadeTransition(
                      opacity: Tween(begin: 0.35, end: 0.9).animate(_pulse),
                      child: Text('tap anywhere to fly',
                          style: UiKit.label(15,
                              color: Colors.white.withValues(alpha: 0.8))),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Title with a soft gradient fill and a drop shadow.
class _Title extends StatelessWidget {
  const _Title({required this.anim});
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Transform.translate(
        offset: Offset(0, (1 - anim.value) * -18),
        child: Column(
          children: [
            Text('FLAPPY', style: UiKit.title(50)),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF3B0), Color(0xFFFFD447), Color(0xFFE8A317)],
              ).createShader(r),
              child: Text('RAIN', style: UiKit.title(64).copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuIcon extends StatelessWidget {
  const _MenuIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xAA2C5B78),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              if (badge)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: UiKit.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF102A3B), width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(label,
              style: UiKit.label(12, color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}
