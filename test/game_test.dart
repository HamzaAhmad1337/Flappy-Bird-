import 'package:flutter_test/flutter_test.dart';
import 'package:flappy_rain/game/config.dart';

void main() {
  group('GameConfig sanity', () {
    test('design resolution is portrait', () {
      expect(GameConfig.height, greaterThan(GameConfig.width));
    });

    test('a flap always overcomes one frame of gravity', () {
      // At 60fps a single frame adds gravity/60 downward velocity; the flap
      // impulse must be strong enough to visibly lift the bird.
      final oneFrameGravity = GameConfig.gravity / 60;
      expect(GameConfig.flapVelocity.abs(), greaterThan(oneFrameGravity));
    });

    test('difficulty never shrinks the gap below the playable minimum', () {
      for (var score = 0; score <= 200; score++) {
        final gap = (GameConfig.pipeGap - score * GameConfig.gapShrinkPerPoint)
            .clamp(GameConfig.minGap, GameConfig.pipeGap);
        expect(gap, greaterThanOrEqualTo(GameConfig.minGap));
      }
    });

    test('the pipe gap always fits between the margins', () {
      final playable = GameConfig.height -
          GameConfig.groundHeight -
          2 * GameConfig.pipeMinMargin;
      expect(GameConfig.minGap, lessThan(playable));
    });
  });
}
