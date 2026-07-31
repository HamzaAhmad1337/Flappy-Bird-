import 'package:flutter/material.dart';

import '../game/flappy_game.dart';
import '../services/progression.dart';
import '../services/sfx.dart';
import '../services/storage.dart';
import 'ui_kit.dart';

/// Goals screen: today's three missions plus the achievement wall.
///
/// This is the "what do I do next" surface — there should always be something
/// here that's close to done.
class MissionsPanel extends StatefulWidget {
  const MissionsPanel({super.key, required this.game});
  final FlappyGame game;

  @override
  State<MissionsPanel> createState() => _MissionsPanelState();
}

class _MissionsPanelState extends State<MissionsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    // The body below is built from the selected index rather than being a
    // TabBarView, so the panel has to repaint when the selection changes.
    ..addListener(_onTabChanged);

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _close() {
    Sfx.button();
    widget.game.overlays.remove('missions');
  }

  Future<void> _claim(int i) async {
    final got = await Progression.claimMission(i);
    if (got > 0) {
      Sfx.coin();
      widget.game.wallet.value = Storage.coins;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final missions = Progression.todayMissions;
    final progress = Storage.missionProgress;
    final claimed = Storage.missionClaimed;
    final best = Storage.highScore;
    final rank = Progression.rankFor(best);
    final next = Progression.nextRankAfter(best);

    return ModalScrim(
      onDismiss: _close,
      opacity: 0.6,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GlassPanel(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('GOALS', style: UiKit.title(26)),
                    const Spacer(),
                    ValueListenableBuilder<int>(
                      valueListenable: widget.game.wallet,
                      builder: (_, c, __) => CoinPill(count: c),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _close,
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _RankBar(rank: rank, next: next, best: best),
                const SizedBox(height: 10),
                TabBar(
                  controller: _tabs,
                  indicatorColor: UiKit.accent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: UiKit.label(14),
                  tabs: const [Tab(text: 'TODAY'), Tab(text: 'AWARDS')],
                ),
                const SizedBox(height: 8),
                // Deliberately not a TabBarView: that widget takes every pixel
                // it is offered and forces both tabs to one height, so the
                // three-item TODAY list floated above a third of a screen of
                // empty glass. Building only the selected tab lets the panel
                // hug whichever one is showing, and AnimatedSize makes the
                // change between them read as a resize instead of a jump.
                Flexible(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _tabs.index == 0
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (int i = 0; i < missions.length; i++)
                                _MissionRow(
                                  mission: missions[i],
                                  progress:
                                      i < progress.length ? progress[i] : 0,
                                  claimed: i < claimed.length && claimed[i],
                                  onClaim: () => _claim(i),
                                ),
                              const SizedBox(height: 6),
                              Text('New goals every day',
                                  style: UiKit.label(12,
                                      color:
                                          Colors.white.withValues(alpha: 0.5))),
                            ],
                          )
                        : ConstrainedBox(
                            // The award wall is open-ended, so it scrolls — and
                            // the bottom row fades rather than being sliced
                            // flat, which is what says "there is more below".
                            constraints: const BoxConstraints(maxHeight: 320),
                            child: ShaderMask(
                              shaderCallback: (r) => const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white,
                                  Colors.white,
                                  Colors.transparent
                                ],
                                stops: [0, 0.86, 1],
                              ).createShader(r),
                              blendMode: BlendMode.dstIn,
                              child: GridView.builder(
                                padding: EdgeInsets.zero,
                                physics: const BouncingScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.86,
                                ),
                                itemCount: Progression.achievements.length,
                                itemBuilder: (_, i) {
                                  final a = Progression.achievements[i];
                                  return _AwardTile(
                                      achievement: a,
                                      unlocked: Storage.hasAchievement(a.id));
                                },
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankBar extends StatelessWidget {
  const _RankBar({required this.rank, required this.next, required this.best});
  final Rank rank;
  final Rank? next;
  final int best;

  @override
  Widget build(BuildContext context) {
    final span = next == null ? 1 : (next!.minScore - rank.minScore);
    final done =
        next == null ? 1.0 : ((best - rank.minScore) / span).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rank.color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded, color: rank.color, size: 20),
              const SizedBox(width: 8),
              Text(rank.name.toUpperCase(),
                  style: UiKit.label(15, color: rank.color)),
              const Spacer(),
              Text(
                next == null
                    ? 'MAX RANK'
                    : 'Next: ${next!.name} @ ${next!.minScore}',
                style: UiKit.label(12,
                    color: Colors.white.withValues(alpha: 0.65)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: done,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(rank.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({
    required this.mission,
    required this.progress,
    required this.claimed,
    required this.onClaim,
  });

  final Mission mission;
  final int progress;
  final bool claimed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final complete = progress >= mission.target;
    final frac = (progress / mission.target).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: complete && !claimed ? UiKit.accent : Colors.white12,
          width: complete && !claimed ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(mission.icon,
                  color: claimed ? Colors.white38 : UiKit.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(mission.title,
                    style: UiKit.label(14,
                        color: claimed ? Colors.white38 : Colors.white)),
              ),
              if (claimed)
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white38, size: 22)
              else if (complete)
                GestureDetector(
                  onTap: onClaim,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: UiKit.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('+${mission.reward}',
                        style: UiKit.label(13, color: const Color(0xFF3A2E00))),
                  ),
                )
              else
                Text('${progress.clamp(0, mission.target)}/${mission.target}',
                    style: UiKit.label(13, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(
                  claimed ? Colors.white24 : UiKit.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _AwardTile extends StatelessWidget {
  const _AwardTile({required this.achievement, required this.unlocked});
  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: unlocked ? UiKit.accent : Colors.white12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(unlocked ? achievement.icon : Icons.lock_rounded,
              color: unlocked ? UiKit.accent : Colors.white24, size: 28),
          const SizedBox(height: 6),
          Text(
            achievement.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: UiKit.label(11,
                color: unlocked ? Colors.white : Colors.white38),
          ),
          const SizedBox(height: 2),
          Text(
            achievement.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: UiKit.label(9, color: Colors.white.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }
}
