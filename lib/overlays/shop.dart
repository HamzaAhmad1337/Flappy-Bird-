import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/flappy_game.dart';
import '../game/skins.dart';
import '../services/sfx.dart';
import '../services/storage.dart';
import 'ui_kit.dart';

/// The bird shop: browse, buy (with coins) and equip skins. Each preview is
/// drawn with the same procedural style as the in-game bird.
class Shop extends StatefulWidget {
  const Shop({super.key, required this.game});
  final FlappyGame game;

  @override
  State<Shop> createState() => _ShopState();
}

class _ShopState extends State<Shop> {
  void _close() {
    Sfx.button();
    widget.game.overlays.remove('shop');
  }

  void _onSkin(BirdSkin skin) {
    final unlocked = Storage.isUnlocked(skin.id);
    if (unlocked) {
      Sfx.button();
      Storage.setSelectedSkin(skin.id);
      widget.game.refreshSkin();
      setState(() {});
    } else if (Storage.coins >= skin.price) {
      Sfx.coin();
      Storage.setCoins(Storage.coins - skin.price);
      Storage.unlockSkin(skin.id);
      Storage.setSelectedSkin(skin.id);
      widget.game.wallet.value = Storage.coins;
      widget.game.refreshSkin();
      setState(() {});
    } else {
      Sfx.button(); // not enough coins — no-op feedback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GlassPanel(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('SHOP', style: UiKit.title(28)),
                    const Spacer(),
                    ValueListenableBuilder<int>(
                      valueListenable: widget.game.wallet,
                      builder: (_, coins, __) => CoinPill(count: coins),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _close,
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: Skins.all.length,
                    itemBuilder: (_, i) {
                      final skin = Skins.all[i];
                      return _SkinCard(
                        skin: skin,
                        unlocked: Storage.isUnlocked(skin.id),
                        selected: Storage.selectedSkin == skin.id,
                        affordable: Storage.coins >= skin.price,
                        onTap: () => _onSkin(skin),
                      );
                    },
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

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.unlocked,
    required this.selected,
    required this.affordable,
    required this.onTap,
  });

  final BirdSkin skin;
  final bool unlocked;
  final bool selected;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color border = selected
        ? UiKit.accent
        : (unlocked ? Colors.white24 : Colors.white10);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x33000000),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: selected ? 2.5 : 1.2),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(size: const Size(72, 60), painter: _BirdPreviewPainter(skin)),
                  if (!unlocked)
                    const Positioned(
                      right: 0, top: 0,
                      child: Icon(Icons.lock_rounded, color: Colors.white70, size: 18),
                    ),
                ],
              ),
            ),
            Text(skin.name, style: UiKit.label(15)),
            const SizedBox(height: 6),
            _action(),
          ],
        ),
      ),
    );
  }

  Widget _action() {
    if (selected) {
      return _pill('EQUIPPED', UiKit.accent, const Color(0xFF3A2E00));
    }
    if (unlocked) {
      return _pill('SELECT', const Color(0xFF2C5B78), Colors.white);
    }
    // Locked: show price.
    final color = affordable ? const Color(0xFF2E7D32) : const Color(0x552C5B78);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16, height: 16,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [Color(0xFFFFF3B0), Color(0xFFFFC93C)]),
          ),
        ),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
          child: Text('${skin.price}', style: UiKit.label(14)),
        ),
      ],
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: UiKit.label(13, color: fg)),
    );
  }
}

/// Draws a compact version of the bird using a skin's palette.
class _BirdPreviewPainter extends CustomPainter {
  _BirdPreviewPainter(this.skin);
  final BirdSkin skin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    const r = 22.0;

    if (skin.glow) {
      canvas.drawCircle(
        Offset.zero, r * 1.6,
        Paint()
          ..color = skin.trail.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    final bodyRect = Rect.fromCenter(center: Offset.zero, width: r * 2.3, height: r * 2.0);
    canvas.drawOval(
      bodyRect,
      Paint()
        ..shader = ui.Gradient.linear(
          bodyRect.topCenter, bodyRect.bottomCenter, [skin.hi, skin.body, skin.lo], const [0, 0.55, 1.0]),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-1, 5), width: r * 1.5, height: r * 1.1),
      Paint()..color = skin.belly.withValues(alpha: 0.7),
    );
    // Wing.
    final wingRect = Rect.fromCenter(center: const Offset(-5, 2), width: r * 1.5, height: r * 1.0);
    canvas.drawOval(wingRect, Paint()..color = skin.wing);
    // Beak.
    final beak = Path()
      ..moveTo(r * 0.9, -2)
      ..lineTo(r * 1.8, 1)
      ..lineTo(r * 0.9, 5)
      ..close();
    canvas.drawPath(beak, Paint()..color = skin.beak);
    // Eye.
    canvas.drawCircle(const Offset(7, -6), 6, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(8.4, -6), 2.7, Paint()..color = const Color(0xFF20303A));
    canvas.drawCircle(const Offset(9.2, -7), 1.0, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _BirdPreviewPainter old) => old.skin.id != skin.id;
}
