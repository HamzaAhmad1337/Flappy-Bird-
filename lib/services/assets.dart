import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Loads the baked 3D sprite sheets and the GPU shader programs.
///
/// Every load is individually guarded: if a texture or shader is missing or
/// fails to compile on a given device, the corresponding getter simply returns
/// null and the component falls back to its procedural (canvas-drawn) path.
/// The game therefore always renders, just with fewer bells and whistles.
///
/// Bird sheets are decoded **on demand**. Each one is 1344×148 RGBA — about
/// 0.8 MB decoded — so eagerly loading all eight skins cost ~6 MB of texture
/// memory and a slower cold start to show a single bird.
class GameAssets {
  GameAssets._();

  static final Map<String, ui.Image> _images = {};
  static final Set<String> _pendingSkins = {};

  static ui.FragmentShader? skyShader;
  static ui.FragmentShader? lensShader;

  static bool loaded = false;

  static ui.Image? image(String key) => _images[key];

  /// The sheet for [skinId] if it is already decoded.
  ///
  /// Returns null the first time a skin is asked for and kicks off its decode
  /// in the background; callers already handle a null sheet by drawing the
  /// procedural bird, so the worst case is a frame or two of the fallback.
  static ui.Image? birdSheet(String skinId) {
    final img = _images['bird_$skinId'];
    if (img != null) return img;
    ensureSkin(skinId);
    return null;
  }

  /// Decodes a skin sheet if it isn't loaded already. Safe to call repeatedly.
  static Future<void> ensureSkin(String skinId) async {
    final key = 'bird_$skinId';
    if (_images.containsKey(key) || _pendingSkins.contains(key)) return;
    _pendingSkins.add(key);
    final img = await _decode('assets/models/$key.png');
    _pendingSkins.remove(key);
    if (img != null) _images[key] = img;
  }

  /// Warms every skin sheet — called when the shop opens so the grid fills in
  /// rather than showing fallbacks.
  static Future<void> ensureAllSkins(Iterable<String> skinIds) async {
    await Future.wait(skinIds.map(ensureSkin));
  }

  /// Loads the shared textures and shaders. [selectedSkin] is decoded up front
  /// so the bird is right from the first frame.
  static Future<void> load({required String selectedSkin}) async {
    await Future.wait([
      _loadSharedImages(),
      _loadShaders(),
      ensureSkin(selectedSkin),
    ]);
    loaded = true;
  }

  static Future<void> _loadSharedImages() async {
    const targets = <String, String>{
      'coin': 'assets/models/coin.png',
      'orb': 'assets/models/orb.png',
      'pipe_body': 'assets/models/pipe_body.png',
      'pipe_cap': 'assets/models/pipe_cap.png',
      'ground': 'assets/models/ground.png',
      'mountains': 'assets/models/mountains.png',
      'skyline': 'assets/models/skyline.png',
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
    skyShader = (await _program('shaders/sky.frag'))?.fragmentShader();
    lensShader = (await _program('shaders/lens.frag'))?.fragmentShader();
  }

  static Future<ui.FragmentProgram?> _program(String path) async {
    try {
      return await ui.FragmentProgram.fromAsset(path);
    } catch (_) {
      return null;
    }
  }
}
