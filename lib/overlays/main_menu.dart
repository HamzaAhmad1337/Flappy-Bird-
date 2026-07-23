import 'package:flutter/material.dart';

import '../game/flappy_game.dart';
import 'ui_kit.dart';

/// Start screen: title, best score, and a "tap to play" prompt that gently
/// pulses to invite interaction.
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Spacer(flex: 2),
          Text('FLAPPY', style: UiKit.title(52)),
          Text('RAIN', style: UiKit.title(64).copyWith(color: UiKit.accent)),
          const SizedBox(height: 10),
          ValueListenableBuilder<int>(
            valueListenable: widget.game.best,
            builder: (_, best, __) => Text(
              'BEST  $best',
              style: UiKit.label(18, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
          const Spacer(flex: 3),
          FadeTransition(
            opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
            child: Column(
              children: [
                const Icon(Icons.touch_app_rounded, color: Colors.white, size: 40),
                const SizedBox(height: 6),
                Text('TAP  TO  PLAY', style: UiKit.label(20)),
              ],
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
