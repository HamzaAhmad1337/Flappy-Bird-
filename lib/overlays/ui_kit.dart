import 'package:flutter/material.dart';

/// Shared widgets & styling so every overlay feels like one polished app.
class UiKit {
  UiKit._();

  static const Color accent = Color(0xFFFFD447);
  static const Color panel = Color(0xF2102A3B);
  static const Color panelBorder = Color(0x33FFFFFF);

  static const String fontFamily = 'Display';

  static TextStyle title(double size) => TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 1.5,
        shadows: const [
          Shadow(color: Color(0xAA000000), blurRadius: 8, offset: Offset(0, 3)),
          Shadow(color: Color(0x66FFD447), blurRadius: 18),
        ],
      );

  static TextStyle label(double size, {Color color = Colors.white}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.5,
      );
}

/// Full-screen dimmed barrier sitting behind a modal panel.
///
/// Gives every popup the same backdrop and the same behaviour: the dimmed area
/// swallows pointer events so nothing behind it reacts, and — where it makes
/// sense — tapping it closes the panel. Previously each overlay hand-rolled a
/// `Container(color: …)`; that does block taps (its `ColoredBox` hit-tests as
/// opaque), but only the game-over screen offered tap-outside-to-dismiss, so
/// the shop, settings and goals panels could only be closed via their little
/// ✕. This makes the barrier explicit and the affordance consistent.
///
/// Pass [onDismiss] to let a tap on the dimmed area close the panel; leave it
/// null — as the pause screen does — and the barrier still swallows the tap.
class ModalScrim extends StatelessWidget {
  const ModalScrim({
    super.key,
    required this.child,
    this.onDismiss,
    this.opacity = 0.55,
  });

  final Widget child;
  final VoidCallback? onDismiss;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: opacity),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// A little golden coin balance pill.
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.count, this.big = false});
  final int count;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final s = big ? 22.0 : 16.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 16 : 12, vertical: big ? 8 : 5),
      decoration: BoxDecoration(
        color: const Color(0xCC102A3B),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0x55FFD447)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: s, height: s,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color(0xFFFFF3B0), Color(0xFFFFC93C)]),
            ),
            child: Icon(Icons.star_rounded, size: s * 0.7, color: const Color(0x778A5D00)),
          ),
          SizedBox(width: big ? 8 : 6),
          Text('$count', style: UiKit.label(big ? 20 : 15)),
        ],
      ),
    );
  }
}

/// A frosted, rounded card used by the menus.
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: UiKit.panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: UiKit.panelBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 12)),
        ],
      ),
      child: child,
    );
  }
}

/// A chunky, tappable button with a pressed animation.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool primary;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final Color base = widget.primary ? UiKit.accent : const Color(0xFF2C5B78);
    final Color textColor = widget.primary ? const Color(0xFF3A2E00) : Colors.white;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [base, Color.lerp(base, Colors.black, 0.25)!],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Color.lerp(base, Colors.black, 0.5)!,
              offset: Offset(0, _down ? 2 : 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: textColor, size: 22),
              const SizedBox(width: 8),
            ],
            Text(widget.label, style: UiKit.label(18, color: textColor)),
          ],
        ),
      ),
    );
  }
}
