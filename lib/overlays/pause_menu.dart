import 'package:flutter/material.dart';

import '../game/flappy_game.dart';
import 'ui_kit.dart';

/// Modal pause screen with resume / restart / menu options.
class PauseMenu extends StatelessWidget {
  const PauseMenu({super.key, required this.game});
  final FlappyGame game;

  @override
  Widget build(BuildContext context) {
    return ModalScrim(
      opacity: 0.45,
      child: GlassPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PAUSED', style: UiKit.title(34)),
            const SizedBox(height: 22),
            GameButton(
                label: 'Resume',
                icon: Icons.play_arrow_rounded,
                onTap: game.resume),
            const SizedBox(height: 12),
            GameButton(
              label: 'Restart',
              icon: Icons.refresh_rounded,
              primary: false,
              onTap: game.restart,
            ),
            const SizedBox(height: 12),
            GameButton(
              label: 'Main Menu',
              icon: Icons.home_rounded,
              primary: false,
              onTap: game.goToMenu,
            ),
          ],
        ),
      ),
    );
  }
}
