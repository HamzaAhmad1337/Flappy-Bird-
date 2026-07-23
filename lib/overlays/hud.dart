import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/flappy_game.dart';
import 'ui_kit.dart';

/// In-game heads-up display: live score, coin tally, combo call-out, active
/// power-up timers, and a pause button. Rebuilds every frame via a ticker so
/// the power-up bars animate smoothly.
class Hud extends StatefulWidget {
  const Hud({super.key, required this.game});
  final FlappyGame game;

  @override
  State<Hud> createState() => _HudState();
}

class _HudState extends State<Hud> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return SafeArea(
      child: AnimatedBuilder(
        animation: _ticker,
        builder: (context, _) {
          return Stack(
            children: [
              // Score.
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Column(
                    children: [
                      Text('${game.score.value}', style: UiKit.title(56)),
                      if (game.comboCount >= 3)
                        Text('COMBO x${game.comboCount}',
                            style: UiKit.label(16, color: UiKit.accent)),
                    ],
                  ),
                ),
              ),
              // Coins collected this run.
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CoinPill(count: game.runCoins),
                ),
              ),
              // Pause.
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
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
              // Active power-ups (left side, below the coin pill).
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in game.activePowers) _PowerChip(p: p),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PowerChip extends StatelessWidget {
  const _PowerChip({required this.p});
  final ({PowerType type, double remaining}) p;

  @override
  Widget build(BuildContext context) {
    final frac = (p.remaining / p.type.duration).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: 128,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC102A3B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.type.color.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon(p.type), color: p.type.color, size: 16),
                const SizedBox(width: 6),
                Text(p.type.label, style: UiKit.label(13)),
                const Spacer(),
                Text('${p.remaining.ceil()}',
                    style: UiKit.label(13, color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(p.type.color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(PowerType t) => switch (t) {
        PowerType.shield => Icons.shield_rounded,
        PowerType.slowmo => Icons.hourglass_bottom_rounded,
        PowerType.magnet => Icons.explore_rounded,
      };
}
