import 'package:flutter/material.dart';

import '../game/flappy_game.dart';
import '../services/progression.dart';
import '../services/sfx.dart';
import '../services/storage.dart';
import 'ui_kit.dart';

/// "Welcome back" screen: grants the daily coin reward and shows the streak as
/// a row of days, so the run of consecutive days is visible and worth keeping.
class DailyRewardPopup extends StatefulWidget {
  const DailyRewardPopup({super.key, required this.game});
  final FlappyGame game;

  @override
  State<DailyRewardPopup> createState() => _DailyRewardPopupState();
}

class _DailyRewardPopupState extends State<DailyRewardPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 480))
        ..forward();

  int _coins = 0;
  int _streak = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _claim();
  }

  Future<void> _claim() async {
    final r = await Progression.claimDaily();
    if (!mounted) return;
    setState(() {
      _coins = r?.coins ?? 0;
      _streak = r?.streak ?? Storage.streak;
      _done = true;
    });
    widget.game.wallet.value = Storage.coins;
    Sfx.coin();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _close() {
    Sfx.button();
    widget.game.overlays.remove('dailyReward');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _close,
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        alignment: Alignment.center,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: GlassPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('DAILY REWARD', style: UiKit.title(26)),
                  const SizedBox(height: 6),
                  Text(
                    _streak > 1 ? '$_streak day streak!' : 'Welcome back',
                    style: UiKit.label(15, color: UiKit.accent),
                  ),
                  const SizedBox(height: 18),
                  // Streak ladder — the next few days and what they pay.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int d = _streak; d < _streak + 4; d++)
                        _DayChip(
                          day: d,
                          coins: Progression.dailyRewardFor(d),
                          isToday: d == _streak,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_done && _coins > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('+', style: UiKit.title(28)),
                        const SizedBox(width: 4),
                        CoinPill(count: _coins, big: true),
                      ],
                    ),
                  ] else
                    Text('Already claimed today',
                        style: UiKit.label(14,
                            color: Colors.white.withValues(alpha: 0.6))),
                  const SizedBox(height: 20),
                  GameButton(label: 'Nice!', icon: Icons.check_rounded, onTap: _close),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.coins, required this.isToday});
  final int day;
  final int coins;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isToday ? UiKit.accent.withValues(alpha: 0.18) : const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday ? UiKit.accent : Colors.white24,
          width: isToday ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text('Day $day',
              style: UiKit.label(11, color: Colors.white.withValues(alpha: 0.75))),
          const SizedBox(height: 4),
          Icon(Icons.star_rounded,
              size: 18, color: isToday ? UiKit.accent : Colors.white54),
          const SizedBox(height: 2),
          Text('$coins', style: UiKit.label(13)),
        ],
      ),
    );
  }
}
