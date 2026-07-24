import 'dart:async';

import 'package:flutter/material.dart';

import '../game/flappy_game.dart';
import 'ui_kit.dart';

/// End-of-run screen.
///
/// This is where a player decides to stop or go again, so it is built to make
/// "again" the easy choice: tap anywhere to retry, the gap to your best shown
/// as a concrete number, and any rewards the run earned surfaced immediately.
class GameOverMenu extends StatefulWidget {
  const GameOverMenu({super.key, required this.game});
  final FlappyGame game;

  @override
  State<GameOverMenu> createState() => _GameOverMenuState();
}

class _GameOverMenuState extends State<GameOverMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420))
        ..forward();

  bool _canTapRetry = false;
  Timer? _guard;

  @override
  void initState() {
    super.initState();
    // Brief guard so the tap that killed the run can't instantly restart it.
    _guard = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _canTapRetry = true);
    });
  }

  @override
  void dispose() {
    _guard?.cancel();
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
    final g = widget.game;
    final score = g.score.value;
    final best = g.best.value;
    final isNewBest = g.lastRunWasBest;
    final medal = _medal(score);
    final gap = best - score;

    return GestureDetector(
      // Tap anywhere to go again — the single biggest "one more run" lever.
      onTap: _canTapRetry ? g.restart : null,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GlassPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isNewBest)
                      Text('NEW BEST!',
                          style: UiKit.title(30).copyWith(color: UiKit.accent))
                    else
                      Text('GAME OVER',
                          style: UiKit.title(30)
                              .copyWith(color: const Color(0xFFFF6B6B))),
                    const SizedBox(height: 14),
                    if (medal != null) ...[
                      _Medal(name: medal.name, color: medal.color),
                      const SizedBox(height: 12),
                    ],
                    _ScoreRow(label: 'SCORE', value: score),
                    const SizedBox(height: 6),
                    _ScoreRow(label: 'BEST', value: best),

                    // The "so close" beat: a concrete, small-feeling target.
                    if (!isNewBest && gap > 0 && gap <= 5) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x33FFD447),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: UiKit.accent.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          gap == 1
                              ? 'Just 1 more to beat your best!'
                              : 'Only $gap more to beat your best!',
                          style: UiKit.label(13, color: UiKit.accent),
                        ),
                      ),
                    ],

                    if (g.runCoins > 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded,
                              color: Color(0xFFFFD447), size: 20),
                          CoinPill(count: g.runCoins),
                          const SizedBox(width: 8),
                          Text('collected',
                              style: UiKit.label(13,
                                  color: Colors.white.withValues(alpha: 0.6))),
                        ],
                      ),
                    ],

                    // Rewards earned by this run.
                    if (g.lastMissionsCompleted.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _Banner(
                        icon: Icons.task_alt_rounded,
                        text: g.lastMissionsCompleted.length == 1
                            ? 'Mission complete!'
                            : '${g.lastMissionsCompleted.length} missions complete!',
                        color: const Color(0xFF7FC4FF),
                      ),
                    ],
                    for (final a in g.lastUnlocked) ...[
                      const SizedBox(height: 8),
                      _Banner(
                          icon: a.icon,
                          text: 'Unlocked: ${a.name}',
                          color: UiKit.accent),
                    ],

                    const SizedBox(height: 20),
                    GameButton(
                      label: 'Play Again',
                      icon: Icons.refresh_rounded,
                      onTap: g.restart,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GameButton(
                          label: 'Goals',
                          icon: Icons.flag_rounded,
                          primary: false,
                          onTap: () => g.overlays.add('missions'),
                        ),
                        const SizedBox(width: 10),
                        GameButton(
                          label: 'Menu',
                          icon: Icons.home_rounded,
                          primary: false,
                          onTap: g.goToMenu,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedOpacity(
                      opacity: _canTapRetry ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Text('tap anywhere to retry',
                          style: UiKit.label(12,
                              color: Colors.white.withValues(alpha: 0.55))),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(text, style: UiKit.label(13, color: color)),
        ],
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
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color.lerp(color, Colors.white, 0.4)!, color],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 16)],
          ),
          child: const Icon(Icons.star_rounded, color: Color(0x66000000), size: 32),
        ),
        const SizedBox(height: 5),
        Text(name, style: UiKit.label(13, color: color)),
      ],
    );
  }
}
