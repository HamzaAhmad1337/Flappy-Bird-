import 'package:flappy_rain/overlays/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the modal barrier.
///
/// The contract is: the dimmed area never lets a tap through to the game, it
/// optionally dismisses, and it never swallows taps meant for its own panel.
void main() {
  /// Builds a "game" layer that records taps, with [modal] stacked on top.
  Future<int Function()> pumpStack(WidgetTester tester, Widget modal) async {
    var behindTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => behindTaps++,
              child: const SizedBox.expand(),
            ),
            modal,
          ],
        ),
      ),
    );
    return () => behindTaps;
  }

  testWidgets('a tap on the dimmed area never reaches the game behind it',
      (tester) async {
    final behind = await pumpStack(
      tester,
      const ModalScrim(
        child: SizedBox(width: 100, height: 100, child: Text('panel')),
      ),
    );

    // Top-left corner: well outside the little panel in the middle.
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    expect(behind(), 0, reason: 'the tap leaked through the scrim');
  });

  testWidgets('onDismiss fires when the dimmed area is tapped', (tester) async {
    var dismissed = 0;
    final behind = await pumpStack(
      tester,
      ModalScrim(
        onDismiss: () => dismissed++,
        child: const SizedBox(width: 100, height: 100),
      ),
    );

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    expect(dismissed, 1);
    expect(behind(), 0);
  });

  testWidgets('a scrim with no onDismiss still swallows the tap',
      (tester) async {
    // The pause screen deliberately has no dismiss action; resuming must be an
    // explicit choice. It still must not let the tap through to the flap
    // handler underneath.
    final behind = await pumpStack(
      tester,
      const ModalScrim(child: SizedBox(width: 100, height: 100)),
    );

    await tester.tapAt(const Offset(400, 600));
    await tester.pump();

    expect(behind(), 0);
  });

  testWidgets('a plain Container backdrop also blocks taps', (tester) async {
    // Characterisation test. A bare `Container(color: …)` — what each overlay
    // used before — already hit-tests as opaque, so swapping in ModalScrim was
    // about consistency and the dismiss affordance, not about plugging a leak.
    // Pinned here so the reasoning stays honest if anyone revisits it.
    final behind = await pumpStack(
      tester,
      Container(
        color: Colors.black.withValues(alpha: 0.5),
        alignment: Alignment.center,
        child: const SizedBox(width: 100, height: 100),
      ),
    );

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    expect(behind(), 0);
  });

  testWidgets('controls inside the panel still receive their taps',
      (tester) async {
    var buttonTaps = 0;
    final behind = await pumpStack(
      tester,
      ModalScrim(
        onDismiss: () {},
        child: GameButton(label: 'Play Again', onTap: () => buttonTaps++),
      ),
    );

    await tester.tap(find.text('Play Again'));
    await tester.pump();

    expect(buttonTaps, 1, reason: 'the scrim swallowed its own button');
    expect(behind(), 0);
  });
}
