# 🐦 Flappy Rain

A beautiful, storm-themed Flappy Bird game built with **Flutter** and the
**Flame** game engine — a real native app you can ship to both the **Google
Play Store** and the **Apple App Store** from a single codebase.

Everything you see is drawn procedurally on the canvas (no heavy image
assets), so the app is small, sharp at every resolution, and fully editable in
code.

## ✨ Features

- **Living storm environment** — layered parallax sky, mountains, a city
  silhouette, and drifting clouds.
- **Falling rain** — hundreds of wind-slanted raindrops with ground splashes.
- **Lightning** — random flashes and forked bolts light up the sky.
- **A hand-drawn bird** — glossy body, flapping wing, and velocity-based tilt.
- **Polished pipes & ground** — gradient "tube" pipes with wet highlights and a
  seamlessly scrolling grassy ground.
- **Full game flow** — animated main menu, live HUD, pause screen, and a
  game-over screen with medals (Bronze → Platinum) and a "New Best!" flourish.
- **Persistent high score** via `shared_preferences`.
- **Haptic feedback**, gentle difficulty ramp, auto-pause when backgrounded,
  portrait-locked immersive fullscreen.
- Works on **Android, iOS, and the web** (great for quick previews).

## 🏗️ Project structure

```
lib/
├── main.dart                  # App entry, GameWidget + overlays, lifecycle
├── game/
│   ├── config.dart            # All tunable constants & palette
│   └── flappy_game.dart       # FlameGame: state, spawning, collisions, score
├── components/
│   ├── background.dart        # Parallax storm sky
│   ├── rain.dart              # Rain particle system
│   ├── lightning.dart         # Flashes & bolts
│   ├── bird.dart              # Player bird (physics + rendering)
│   ├── pipe_pair.dart         # Obstacle pipes + collision
│   └── ground.dart            # Scrolling ground
├── overlays/                  # Flutter UI: menu, HUD, pause, game over
└── services/
    ├── storage.dart           # High-score persistence
    └── sfx.dart               # Haptics (swap in real audio later)
```

Tune gameplay and colors in **`lib/game/config.dart`** — gravity, flap
strength, pipe gap/speed, rain density, difficulty ramp, and the palette all
live there.

## 🚀 Getting started

### 1. Install Flutter

Follow <https://docs.flutter.dev/get-started/install> (Flutter 3.27+ / Dart
3.6+). Verify with:

```bash
flutter doctor
```

### 2. Generate the native platform folders

This repo contains the game source (`lib/`, `pubspec.yaml`, `test/`). Generate
the `android/`, `ios/`, and `web/` runner projects with your own app identity:

```bash
cd Flappy-Bird-
flutter create --org com.yourcompany --project-name flappy_rain .
```

`flutter create .` **does not overwrite** existing files like `lib/` or
`pubspec.yaml`; it only adds the missing platform scaffolding. Pick a real
reverse-domain org (e.g. `com.yourname`) — it becomes your Android
`applicationId` / iOS bundle ID.

### 3. Run it

```bash
flutter pub get
flutter run                 # on a connected device/emulator
flutter run -d chrome       # quick preview in the browser
```

## 🎮 How to play

Tap anywhere (or press **Space** / **↑** on desktop) to flap. Fly through the
gaps in the pipes. Each pipe cleared is one point. Don't hit a pipe, the
ground, and try to beat your best.

## 🎨 Add an app icon (optional but recommended)

1. Put a 1024×1024 PNG at `assets/icon/icon.png`.
2. Run:

   ```bash
   flutter pub get
   dart run flutter_launcher_icons
   ```

Icon settings are already configured in `pubspec.yaml`.

## 🔊 Adding real sound effects (optional)

The game uses haptics so it ships with zero audio binaries. To add sound:

1. Add `flame_audio: ^2.10.1` to `pubspec.yaml`.
2. Put `flap.wav`, `score.wav`, `hit.wav` in `assets/audio/` and declare the
   folder under `flutter: assets:`.
3. Replace the haptic calls in `lib/services/sfx.dart` with
   `FlameAudio.play('flap.wav')`, etc.

---

## 📦 Publishing

> The commands assume you ran `flutter create .` (step 2 above) so the native
> projects exist.

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
