# 🐦 Flappy Rain

A beautiful, storm-themed Flappy Bird game built with **Flutter** and the
**Flame** game engine — a real native app you can ship to both the **Google
Play Store** and the **Apple App Store** from a single codebase.

Every asset is **generated from source** — the 3D models are raytraced offline
by a small PBR renderer, the sky and lens effects are real GPU fragment
shaders, and the sound is synthesized. Nothing was hand-painted in a binary
editor, so the whole look is editable in code.

## ✨ Features

**Graphics — baked 3D + GPU shaders**
- **Real 3D models, offline-raytraced.** Every character and prop is a
  signed-distance-field model rendered by `tools/render3d.py` with
  Cook-Torrance GGX PBR shading, soft shadows, ambient occlusion, bump-mapped
  surface detail and ACES tonemapping — then baked to sprite sheets. The bird
  has feather relief and a wing that casts a shadow on its body; the coin is
  milled gold with an embossed star; the pipes are weathered, rusted metal.
- **Skin re-tinting for free.** The bird is rendered *once* into separate
  lighting buffers (diffuse / specular / material mask), so all 8 skins are
  produced from one raymarch — and every skin keeps the same real lighting.
- **Volumetric sky shader** (`shaders/sky.frag`) — raymarched FBM cloud layers
  lit by the sun, atmospheric gradient, god rays, sun/moon bloom and stars.
- **Cinematic lens pass** (`shaders/lens.frag`) — rain beading and running down
  the glass, vignette, chromatic fringing, film grain and lightning bloom.
- **Wet-ground reflections** — the pipes and bird mirror into the rain-soaked
  ground, squashed, rippled and faded with depth.
- **Ambient life** — fireflies that pulse at night, sunlit motes by day, and
  mist rolling along the ground.
- **Aurora and shooting stars** on the night side of the day/night cycle.
- **Graceful degradation**: if a texture or shader fails to load on a device,
  each component silently falls back to its hand-drawn canvas version, so the
  game always renders.

**World & atmosphere**
- **Full day → night cycle** — the sky continuously shifts through dawn, day,
  dusk and night, with a crossfading sun & moon and twinkling stars.
- **Living storm environment** — layered parallax sky, mountains, a city
  silhouette with glowing windows, and drifting clouds.
- **Falling rain** — hundreds of wind-slanted raindrops with ground splashes.
- **Lightning** — random flashes and forked bolts light up the sky.

**Gameplay & juice**
- **A 3D-rendered bird** — feather relief, a flapping wing that shadows the
  body, velocity-based tilt and a flight trail.
- **Collectible coins** — a real coin wallet that persists between sessions.
- **Power-ups** — 🛡️ Shield (survive a hit), ⏳ Slow-Mo (bullet time), and
  🧲 Magnet (vacuum up coins), each with live HUD timers.
- **Combos** — chain pipes for combo call-outs and bonus coins.
- **Near-miss bullet-time**, **screen shake**, and a burst of feathers on
  impact.
- **Rendered pipes & ground** — weathered metal tubes with rust and moss, and a
  seamlessly tiling rocky embankment.

**Progression & goals**
- **Daily reward with a visible streak ladder** — escalating coins for coming
  back, capped so it never becomes a chore.
- **Three daily missions** that rotate at midnight (score, coins, near-misses,
  combos, power-ups), each paying coins.
- **12 achievements** and a **7-tier rank** (Fledgling → Legend) with progress
  toward the next tier always on screen.
- **Instant retry** — tap anywhere on the game-over screen to go again, and
  when you fall just short it tells you exactly how many more you needed.
- **Milestone celebrations** — confetti and a banner every 10 pipes, and the
  moment you overtake your own record mid-run.

**Meta & polish**
- **Bird shop** — 8 unlockable skins (Robin, Blue Jay, Phoenix, Midas…) bought
  with coins; some legendary skins glow.
- **Full game flow** — animated menu, live HUD, pause, and a game-over screen
  with medals (Bronze → Platinum) and a "New Best!" flourish.
- **Real synthesized sound effects** (bundled WAV assets) + haptics.
- **Settings** — toggle sound, haptics, and a reduced-motion mode.
- **Persistent** high score, coins, unlocked skins & settings via
  `shared_preferences`.
- Gentle difficulty ramp, auto-pause when backgrounded, portrait-locked
  immersive fullscreen.
- Ships with a **generated app icon** and runs on **Android, iOS, and the web**.

## 🏗️ Project structure

```
lib/
├── main.dart                  # App entry, GameWidget + overlays, lifecycle
├── game/
│   ├── config.dart            # All tunable constants, palette, power-up types
│   ├── flappy_game.dart       # FlameGame: state, spawning, collisions, juice
│   └── skins.dart             # Bird skin definitions (the shop catalog)
├── components/
│   ├── background.dart        # Parallax storm sky + day/night cycle
│   ├── rain.dart / lightning.dart
│   ├── bird.dart              # Player bird (physics + skinned rendering)
│   ├── pipe_pair.dart         # Obstacle pipes + collision
│   ├── ground.dart            # Scrolling ground
│   ├── coin.dart / powerup.dart
│   ├── particles.dart         # Feathers, sparkles, bursts, trails
│   ├── floating_text.dart     # Score / combo pop-ups
│   ├── sky_shader.dart        # Volumetric sky (GPU)
│   └── lens_overlay.dart      # Rain-on-lens / vignette / grain (GPU)
│   ├── reflections.dart       # Wet-ground mirror of pipes & bird
│   └── ambience.dart          # Fireflies / motes / ground mist
├── overlays/                  # menu, HUD, pause, game over, shop, settings,
│                              # missions/awards, daily reward
└── services/
    ├── storage.dart           # Save data (score, coins, skins, settings)
    ├── progression.dart       # Daily rewards, missions, achievements, ranks
    ├── assets.dart            # Loads baked sprites + shaders (fails soft)
    └── sfx.dart               # Sound effects + haptics
shaders/
├── sky.frag                   # Volumetric clouds, god rays, stars
└── lens.frag                  # Rain on glass, vignette, grain, bloom
tools/
├── render3d.py                # SDF raymarcher: PBR, soft shadows, AO
├── gen_models.py              # The 3D models + bake targets
├── gen_audio.py               # Sound-effect synthesis
└── gen_icon.py                # App icon
assets/
├── models/                    # Baked 3D sprite sheets & tiling textures
├── audio/                     # Synthesized WAV sound effects
├── fonts/                     # Bundled UI font (SIL OFL, see LICENSE.txt)
└── icon/icon.png              # Source app icon
```

### Regenerating the art

All art is generated from source — nothing is hand-painted in a binary editor:

```bash
pip install numpy pillow
python3 tools/gen_models.py          # everything (~7 min)
python3 tools/gen_models.py coin     # or just one target
```

Edit a model in `tools/gen_models.py` (they're plain SDF math) and re-run.

Tune everything in **`lib/game/config.dart`** — gravity, flap strength, pipe
gap/speed, rain density, difficulty ramp, coin/power-up rates, day length, and
the palette. Add a bird skin in **`lib/game/skins.dart`** (just a palette).

## 🚀 Getting started

### 1. Install Flutter

Follow <https://docs.flutter.dev/get-started/install> (Flutter 3.27+ / Dart
3.6+). Verify with:

```bash
flutter doctor
```

### 2. Platform folders are included ✅

The `android/`, `ios/`, and `web/` runner projects are already generated (with a
placeholder org `com.flappyrain`). **Before publishing, change the app id** to
your own reverse-domain identifier:

- **Android** — `applicationId` in `android/app/build.gradle`.
- **iOS** — *Bundle Identifier* in Xcode (`ios/Runner.xcworkspace`).

(If you ever need to regenerate them, `flutter create .` adds missing platform
scaffolding without overwriting `lib/` or `pubspec.yaml`.)

### 3. Run it

```bash
flutter pub get
flutter run                 # on a connected device/emulator
flutter run -d chrome       # quick preview in the browser
```

## 🎮 How to play

Tap anywhere (or press **Space** / **↑** on desktop) to flap. Fly through the
gaps in the pipes — each cleared pipe is a point. Grab **coins** to spend in the
shop and snag **power-ups** for an edge. Chain pipes for **combos**. Don't hit a
pipe or the ground, and beat your best.

## 🎨 App icon & sound (already included)

- **Icon**: a source icon lives at `assets/icon/icon.png` and the native
  launcher icons are pre-generated. To change it, drop in a new 1024×1024 PNG and
  run `dart run flutter_launcher_icons`.
- **Sound**: real synthesized effects ship in `assets/audio/` (generated with
  `tools/gen_audio.py`). Regenerate or tweak them with
  `python3 tools/gen_audio.py`.

---

## 📦 Publishing

> The native projects already exist in `android/`, `ios/`, and `web/`. Remember
> to change the placeholder app id (`com.flappyrain`) to your own first.

### Android → Google Play

1. **Set app identity & version**: `applicationId` in
   `android/app/build.gradle`; version in `pubspec.yaml` (`1.0.0+1` — bump the
   `+build` number every upload).
2. **Create a signing key**:

   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   Create `android/key.properties` (git-ignored) with `storeFile`,
   `storePassword`, `keyAlias`, `keyPassword`, and wire it into
   `android/app/build.gradle`'s `signingConfigs` — see
   <https://docs.flutter.dev/deployment/android#signing-the-app>.
3. **Build the App Bundle**:

   ```bash
   flutter build appbundle --release
   # output: build/app/outputs/bundle/release/app-release.aab
   ```
4. Upload the `.aab` at <https://play.google.com/console> (create the app, fill
   store listing, content rating, privacy policy, then release to a testing
   track and finally production).

### iOS → Apple App Store

> Requires a **Mac with Xcode** and an **Apple Developer Program** membership.

1. Open the iOS project:

   ```bash
   open ios/Runner.xcworkspace
   ```
2. In Xcode → *Runner* target → *Signing & Capabilities*, select your Team and
   set a unique Bundle Identifier.
3. Build the archive:

   ```bash
   flutter build ipa --release
   ```
4. Upload with **Transporter** (or Xcode Organizer) to App Store Connect at
   <https://appstoreconnect.apple.com>, complete the listing, and submit for
   review.

### Store assets you'll need

App icon, a short/long description, screenshots (phone + tablet sizes), a
feature graphic (Play), and a **privacy policy URL**. This game collects no
personal data and stores only the high score locally — state that in your
privacy details.

## 🧪 Tests

```bash
flutter test
```

## 📄 License

MIT — see [LICENSE](LICENSE). Do your own thing with it.
