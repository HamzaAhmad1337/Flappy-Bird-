import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flappy_rain/game/config.dart';
import 'package:flappy_rain/game/flappy_game.dart';
import 'package:flappy_rain/game/skins.dart';

void main() {
  group('GameConfig sanity', () {
    test('design resolution is portrait', () {
      expect(GameConfig.height, greaterThan(GameConfig.width));
    });

    test('a flap always overcomes one frame of gravity', () {
      // At 60fps a single frame adds gravity/60 downward velocity; the flap
      // impulse must be strong enough to visibly lift the bird.
      const oneFrameGravity = GameConfig.gravity / 60;
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
      const playable = GameConfig.height -
          GameConfig.groundHeight -
          2 * GameConfig.pipeMinMargin;
      expect(GameConfig.minGap, lessThan(playable));
    });
  });

  group('frame timing', () {
    // Regression: an unbounded frame step used to apply hundreds of ms of
    // gravity at once (the hitch when overlays rebuild as a run starts), which
    // teleported the bird into the ground and ended the run instantly.
    test('a long frame cannot move the bird further than the playable height',
        () {
      const step = FlappyGame.maxTimeStep;
      // Worst case: already at terminal velocity for one clamped step.
      const worstDrop = GameConfig.maxFallSpeed * step;
      const playable = GameConfig.height - GameConfig.groundHeight;
      expect(worstDrop, lessThan(playable / 4),
          reason: 'one clamped step must be a small fraction of the screen');
    });

    test('the clamp is small enough to stay responsive', () {
      // Still at least ~30fps of simulation, so gameplay is not slowed visibly.
      expect(FlappyGame.maxTimeStep, lessThanOrEqualTo(1 / 30 + 1e-9));
      expect(FlappyGame.maxTimeStep, greaterThan(0));
    });

    test('a flap out-climbs one clamped step of gravity', () {
      const gained = GameConfig.gravity * FlappyGame.maxTimeStep;
      expect(GameConfig.flapVelocity.abs(), greaterThan(gained));
    });
  });

  group('time of day', () {
    // The sprites are baked under one neutral studio light, so the world has
    // to be tinted to track the sky — otherwise the ground and pipes stay
    // daylit under a midnight storm.
    test('the world tint darkens at night and is neutral at midday', () {
      double luminance(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;

      // dayness is a cosine of the phase: 0.25 is midday, 0.75 midnight.
      double daynessAt(double phase) =>
          (0.5 + 0.5 * cos((phase - 0.25) * 2 * pi)).clamp(0.0, 1.0);

      expect(daynessAt(0.25), closeTo(1.0, 1e-9));
      expect(daynessAt(0.75), closeTo(0.0, 1e-9));

      Color tintFor(double dayness) {
        final t = dayness * dayness * (3 - 2 * dayness);
        return Color.lerp(const Color(0xFF6E7DA0), const Color(0xFFFFFFFF), t)!;
      }

      final midday = tintFor(daynessAt(0.25));
      final midnight = tintFor(daynessAt(0.75));
      expect(luminance(midday), closeTo(1.0, 1e-6),
          reason: 'midday must leave the baked art untouched');
      expect(luminance(midnight), lessThan(0.65),
          reason: 'midnight must visibly dim the world');
      // And it must be monotonic, so the transition never brightens backwards.
      var previous = luminance(midnight);
      for (var d = 0.0; d <= 1.0; d += 0.05) {
        final l = luminance(tintFor(d));
        expect(l, greaterThanOrEqualTo(previous - 1e-9));
        previous = l;
      }
    });
  });

  _assetTests();
}

// ---------------------------------------------------------------------------
// Baked-asset pipeline
// ---------------------------------------------------------------------------
void _assetTests() {
  group('baked 3D assets', () {
    test('every bird skin has a rendered sprite sheet', () {
      for (final skin in Skins.all) {
        final f = File('assets/models/bird_${skin.id}.png');
        expect(f.existsSync(), isTrue,
            reason: 'missing sprite sheet for skin "${skin.id}" — '
                'run: python3 tools/gen_models.py bird');
      }
    });

    test('shared textures and shaders are present', () {
      for (final p in [
        'assets/models/coin.png',
        'assets/models/orb.png',
        'assets/models/pipe_body.png',
        'assets/models/pipe_cap.png',
        'assets/models/ground.png',
        'shaders/sky.frag',
        'shaders/lens.frag',
      ]) {
        expect(File(p).existsSync(), isTrue, reason: 'missing $p');
      }
    });

    test('sprite sheets divide evenly into their frame count', () {
      // A sheet whose width isn't a multiple of the frame count would make
      // every blit sample across a frame boundary.
      final bird = _pngSize(File('assets/models/bird_classic.png'));
      expect(bird.$1 % GameConfig.birdSheetFrames, 0);
      final coin = _pngSize(File('assets/models/coin.png'));
      expect(coin.$1 % GameConfig.coinSheetFrames, 0);
    });
  });
}

/// Reads width/height straight from the PNG IHDR chunk.
(int, int) _pngSize(File f) {
  final b = f.readAsBytesSync();
  final d = ByteData.sublistView(b);
  return (d.getUint32(16), d.getUint32(20));
}
