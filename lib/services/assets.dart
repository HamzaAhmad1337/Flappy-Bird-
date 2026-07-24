import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../game/skins.dart';

/// Loads the baked 3D sprite sheets and the GPU shader programs.
///
/// Every load is individually guarded: if a texture or shader is missing or
/// fails to compile on a given device, the corresponding getter simply returns
/// null and the component falls back to its procedural (canvas-drawn) path.
/// The game therefore always renders, just with fewer bells and whistles.
class GameAssets {
  GameAssets._();

  static final Map<String, ui.Image> _images = {};
  static ui.FragmentProgram? _skyProgram;
  static ui.FragmentProgram? _lensProgram;

  static ui.FragmentShader? skyShader;
  static ui.FragmentShader? lensShader;

  static bool loaded = false;

  static ui.Image? image(String key) => _images[key];

  static ui.Image? birdSheet(String skinId) => _images['bird_$skinId'];

  static Future<void> load() async {
    await Future.wait([_loadImages(), _loadShaders()]);
    loaded = true;
  }

  static Future<void> _loadImages() async {
    final targets = <String, String>{
      'coin': 'assets/models/coin.png',
      'orb': 'assets/models/orb.png',
      'pipe_body': 'assets/models/pipe_body.png',
      'pipe_cap': 'assets/models/pipe_cap.png',
      'ground': 'assets/models/ground.png',
      for (final s in Skins.all) 'bird_${s.id}': 'assets/models/bird_${s.id}.png',
    };
    await Future.wait(targets.entries.map((e) async {
      final img = await _decode(e.value);
      if (img != null) _images[e.key] = img;
    }));
  }

  static Future<ui.Image?> _decode(String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _loadShaders() async {
    _skyProgram = await _program('shaders/sky.frag');
    _lensProgram = await _program('shaders/lens.frag');
    skyShader = _skyProgram?.fragmentShader();
    lensShader = _lensProgram?.fragmentShader();
  }

  static Future<ui.FragmentProgram?> _program(String path) async {
    try {
      return await ui.FragmentProgram.fromAsset(path);
    } catch (_) {
      return null;
    }
  }
}
