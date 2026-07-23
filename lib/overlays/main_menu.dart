import 'package:flutter/material.dart';

import '../services/sfx.dart';
import '../game/flappy_game.dart';
import 'ui_kit.dart';

/// Start screen: title, coin balance, Play / Shop / Settings, and a gently
/// pulsing "tap to play" hint (the whole screen is tappable to start).
class MainMenu extends StatefulWidget {
  const MainMenu({super.key, required this.game});
  final FlappyGame game;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(flex: 2),
                Text('FLAPPY', style: UiKit.title(52)),
                Text('RAIN', style: UiKit.title(64).copyWith(color: UiKit.accent)),
                const SizedBox(height: 8),
                ValueListenableBuilder<int>(
                  valueListenable: widget.game.best,
                  builder: (_, best, __) => Text(
                    'BEST  $best',
                    style: UiKit.label(18, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ),
                const Spacer(flex: 3),
                GameButton(
                  label: 'PLAY',
                  icon: Icons.play_arrow_rounded,
                  onTap: () {
                    widget.game.startGame();
                    widget.game.bird.flap();
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GameButton(
                      label: 'Shop',
                      icon: Icons.storefront_rounded,
                      primary: false,
                      onTap: () {
                        Sfx.button();
                        widget.game.overlays.add('shop');
                      },
                    ),
                    const SizedBox(width: 12),
                    GameButton(
                      label: 'Settings',
                      icon: Icons.settings_rounded,
                      primary: false,
                      onTap: () {
                        Sfx.button();
                        widget.game.overlays.add('settings');
                      },
                    ),
                  ],
                ),
                const Spacer(flex: 2),
                FadeTransition(
                  opacity: Tween(begin: 0.35, end: 0.9).animate(_c),
                  child: Text('tap anywhere to fly',
                      style: UiKit.label(15, color: Colors.white.withValues(alpha: 0.8))),
                ),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
