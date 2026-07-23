import 'package:flutter/material.dart';

import '../game/flappy_game.dart';
import 'ui_kit.dart';

/// In-game heads-up display: big live score at the top and a pause button.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.game});
  final FlappyGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // Score, centered near the top.
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ValueListenableBuilder<int>(
                valueListenable: game.score,
                builder: (_, s, __) => Text('$s', style: UiKit.title(56)),
              ),
            ),
          ),
          // Pause button, top-right.
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: GestureDetector(
                onTap: game.pause,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x552C5B78),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: const Icon(Icons.pause_rounded, color: Colors.white, size: 26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
