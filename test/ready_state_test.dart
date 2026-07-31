import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flappy_rain/game/config.dart';
import 'package:flappy_rain/game/flappy_game.dart';
import 'package:flappy_rain/overlays/hud.dart';

/// The "get ready" beat exists so a mistimed Play tap can't cost a life before
/// the player has looked at the screen. These tests pin the two things that
/// make it work: the phase is observable, and the prompt disappears the moment
/// the run actually starts.
void main() {
  testWidgets('the ready prompt shows in ready and clears once playing',
      (tester) async {
    final game = FlappyGame();
    game.state = GameState.ready;

    await tester.pumpWidget(MaterialApp(home: Hud(game: game)));
    expect(find.text('GET READY'), findsOneWidget);

    // The HUD deliberately does not rebuild every frame, so this only passes
    // because the prompt listens to the phase notifier rather than reading a
    // plain field once at build time.
    game.state = GameState.playing;
    await tester.pump();
    expect(find.text('GET READY'), findsNothing);
  });

  testWidgets('the prompt is absent for every other phase', (tester) async {
    final game = FlappyGame();
    await tester.pumpWidget(MaterialApp(home: Hud(game: game)));

    for (final phase in [
      GameState.menu,
      GameState.playing,
      GameState.paused,
      GameState.gameOver,
    ]) {
      game.state = phase;
      await tester.pump();
      expect(find.text('GET READY'), findsNothing, reason: 'phase $phase');
    }
  });

  test('the phase notifier and the state field stay in sync', () {
    final game = FlappyGame();
    expect(game.state, GameState.menu);
    expect(game.phase.value, GameState.menu);

    game.state = GameState.playing;
    expect(game.phase.value, GameState.playing);

    game.phase.value = GameState.gameOver;
    expect(game.state, GameState.gameOver);
  });
}
