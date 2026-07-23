import 'package:flutter/material.dart';

import '../game/flappy_game.dart';
import 'ui_kit.dart';

/// End-of-run screen: final score, best score, an earned medal, and a "new
/// best" flourish. Scales in for a satisfying finish.
class GameOverMenu extends StatefulWidget {
  const GameOverMenu({super.key, required this.game});
  final FlappyGame game;

  @override
  State<GameOverMenu> createState() => _GameOverMenuState();
}

class _GameOverMenuState extends State<GameOverMenu> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  ({String name, Color color})? _medal(int score) {
    if (score >= 40) return (name: 'PLATINUM', color: const Color(0xFFE5E4E2));
    if (score >= 25) return (name: 'GOLD', color: const Color(0xFFFFD447));
    if (score >= 12) return (name: 'SILVER', color: const Color(0xFFC0C6CC));
    if (score >= 5) return (name: 'BRONZE', color: const Color(0xFFCD7F32));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.game.score.value;
    final best = widget.game.best.value;
    final isNewBest = score >= best && score > 0;
    final medal = _medal(score);

    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      alignment: Alignment.center,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('GAME OVER', style: UiKit.title(34).copyWith(color: const Color(0xFFFF6B6B))),
              const SizedBox(height: 18),
              if (medal != null) ...[
                _Medal(name: medal.name, color: medal.color),
                const SizedBox(height: 16),
              ],
              _ScoreRow(label: 'SCORE', value: score),
              const SizedBox(height: 8),
              _ScoreRow(label: 'BEST', value: best),
              if (isNewBest) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: UiKit.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('NEW BEST!',
                      style: UiKit.label(14, color: const Color(0xFF3A2E00))),
                ),
              ],
              const SizedBox(height: 24),
              GameButton(
                label: 'Play Again',
                icon: Icons.refresh_rounded,
                onTap: widget.game.restart,
              ),
              const SizedBox(height: 12),
              GameButton(
                label: 'Main Menu',
                icon: Icons.home_rounded,
                primary: false,
                onTap: widget.game.goToMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: UiKit.label(16, color: Colors.white.withValues(alpha: 0.7))),
        ),
        Text('$value', style: UiKit.title(26)),
      ],
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color.lerp(color, Colors.white, 0.4)!, color],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 16)],
          ),
          child: const Icon(Icons.star_rounded, color: Color(0x66000000), size: 34),
        ),
        const SizedBox(height: 6),
        Text(name, style: UiKit.label(14, color: color)),
      ],
    );
  }
}
