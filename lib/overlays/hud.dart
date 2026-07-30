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
    // Only the parts that actually change every frame sit inside the ticker.
    // Wrapping the whole HUD rebuilt the flap surface and the pause button 60
    // times a second for nothing.
    return SafeArea(
      child: Stack(
        children: [
          // Flap surface.
          //
          // Input lives here rather than on a GestureDetector wrapping the
          // GameWidget: taps only reliably reach Flutter *overlay* widgets,
          // and handling them in the state's own overlay keeps each screen
          // owning its input. The pause corner is carved out of the layout
          // so pressing it can never also flap.
          Column(
            children: [
              SizedBox(
                height: 76,
                child: Row(
                  children: [
                    Expanded(child: _FlapArea(game: game)),
                    const SizedBox(width: 76), // pause button corner
                  ],
                ),
              ),
              Expanded(child: _FlapArea(game: game)),
            ],
          ),
          // Score — repaints only when the score actually changes.
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: ValueListenableBuilder<int>(
                valueListenable: game.score,
                builder: (_, score, __) => Column(
                  children: [
                    _PoppingScore(score: score),
                    // The combo readout changes on the same beat as the score.
                    if (game.comboCount >= 3) _ComboFlame(combo: game.comboCount),
                  ],
                ),
              ),
            ),
          ),
          // Coins collected this run, and the live power-up timers. These are
          // the only continuously-animating readouts, so the ticker drives just
          // this corner.
          AnimatedBuilder(
            animation: _ticker,
            builder: (context, _) => Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CoinPill(count: game.runCoins),
                  ),
                ),
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
            ),
          ),
          // Pause — static.
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
        ],
      ),
    );
  }
}

/// A transparent region that flaps the instant it is pressed.
///
/// Deliberately a [Listener] rather than a GestureDetector: a tap *gesture*
/// has to win the gesture arena before it reports, which can delay or drop it
/// when other recognizers are in the tree. What we want here is the raw
/// "screen was pressed" signal, which is also the lowest-latency option. The
/// pause button is excluded by layout, so nothing competes for this area.
class _FlapArea extends StatelessWidget {
  const _FlapArea({required this.game});
  final FlappyGame game;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => game.flapInput(),
      child: const SizedBox.expand(),
    );
  }
}

/// The score, which punches up briefly each time it changes.
class _PoppingScore extends StatefulWidget {
  const _PoppingScore({required this.score});
  final int score;

  @override
  State<_PoppingScore> createState() => _PoppingScoreState();
}

class _PoppingScoreState extends State<_PoppingScore>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));

  @override
  void didUpdateWidget(covariant _PoppingScore old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // Quick overshoot then settle.
        final t = Curves.easeOut.transform(_c.value);
        final scale = 1.0 + 0.28 * (1 - t) * (_c.isAnimating ? 1 : 0);
        return Transform.scale(scale: scale, child: child);
      },
      child: Text('${widget.score}', style: UiKit.title(56)),
    );
  }
}

/// Combo readout with a flame that grows as the streak climbs.
class _ComboFlame extends StatelessWidget {
  const _ComboFlame({required this.combo});
  final int combo;

  @override
  Widget build(BuildContext context) {
    final heat = (combo / 15).clamp(0.0, 1.0);
    final color = Color.lerp(UiKit.accent, const Color(0xFFFF5B3B), heat)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department_rounded, color: color, size: 16 + heat * 6),
        const SizedBox(width: 4),
        Text('COMBO x$combo', style: UiKit.label(16, color: color)),
      ],
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
