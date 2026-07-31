# Shipping Flappy Rain

Everything here is the work that can only be done on your own machine and
under your own developer accounts. The app itself is complete.

## Before the first upload — three things only you can set

1. **Application id / bundle id.** Both platforms currently use the
   placeholder `com.flappyrain.flappy_rain`. It is permanent once published,
   so change it to a domain you control first:
   - Android: `applicationId` and `namespace` in `android/app/build.gradle.kts`
   - iOS: `PRODUCT_BUNDLE_IDENTIFIER` in Xcode (Runner → Signing & Capabilities)
2. **A privacy policy URL.** Google Play and App Store Connect both require a
   reachable URL, not a file. Publish `PRIVACY.md` somewhere public (GitHub
   Pages off this repo is enough) and paste that link into both consoles.
3. **The upload keystore** (Android) — see below.

## Android

Generate an upload key once and keep it somewhere you will not lose it; if
it's lost you cannot ship an update to the same listing.

```sh
keytool -genkey -v -keystore ~/flappy-rain-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (already gitignored — never commit it):

```properties
storeFile=/absolute/path/to/flappy-rain-upload.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

`android/app/build.gradle.kts` picks that file up automatically and signs the
release with it. Without the file the release build falls back to the debug
key so `flutter run --release` keeps working locally — but a debug-signed
bundle is rejected by Play, so check the console output before uploading.

```sh
flutter build appbundle --release   # -> build/app/outputs/bundle/release/*.aab
```

R8 shrinking is configured (`android/app/proguard-rules.pro`) but switched off
in `build.gradle.kts`. A wrong keep rule surfaces only as a crash in a shrunk
release build, and the Dart AOT code — most of the app's size — isn't shrunk
either way. Turn `isMinifyEnabled`/`isShrinkResources` on only after you've run
a shrunk build on a real device.

**Not verified here:** this container has no Android SDK, so the Gradle changes
above were never compiled. Run `flutter build appbundle --release` once before
you rely on them.

## iOS

Needs a Mac with Xcode and an Apple Developer account; none of it can be done
from this repo.

```sh
flutter build ipa --release
```

Then open `build/ios/archive/Runner.xcarchive` in Xcode and distribute, or use
`xcrun altool`. Set your team in Runner → Signing & Capabilities first.

The Info.plist is already portrait-only, hides the status bar, and declares
`ITSAppUsesNonExemptEncryption=false`, so App Store Connect will not ask about
export compliance on each upload.

## Store listing copy

**Title (30 chars):** Flappy Rain

**Short description (80 chars):**
A gorgeous rain-soaked flyer. One tap, endless storms, and a bird with wings.

**Full description:**

> Fly through a living thunderstorm.
>
> Flappy Rain takes the one-tap game everyone knows and gives it weather. Rain
> streaks past a moonlit skyline, lightning cracks behind the mountains,
> droplets bead on the lens, and the whole world drifts from dawn through dusk
> to night while you fly.
>
> • **One tap to fly.** Easy to start, brutal to master.
> • **A world that reacts.** Volumetric storm clouds, god rays, aurora on clear
>   nights, and rain that runs down the screen you're playing on.
> • **Power-ups.** Shields, slow-motion and a coin magnet, earned mid-flight.
> • **Combos and near misses.** Thread a pipe closely and time itself slows.
> • **Daily missions, streaks and ranks.** Something to come back for.
> • **A shop full of birds.** Spend the coins you earn on new plumage.
> • **Plays offline. No ads. No tracking. No accounts.**
>
> Free to play, and free of everything you didn't ask for.

**Category:** Games → Arcade
**Content rating:** Everyone / 4+
**Contains ads:** No · **In-app purchases:** No · **Data collected:** None

## Screenshots

Play needs at least 2 phone screenshots (min 1080px on the short side); the
App Store needs 6.7" and 6.5" iPhone sets. Capture them on device — the ones
in this repo's history were rendered by a software GPU and are dimmer and
lower-framerate than the real thing.

Good moments to capture: the menu with the rank badge, a near miss at speed
with the combo counter lit, a shield active during lightning, the night sky
with the aurora, and the game-over card on a personal best.

## Still worth doing on real hardware

The flap feel and the difficulty curve were tuned against a simulated player
(`test/difficulty_test.dart` — median score 39, range 19–68). That validates
the *shape* of the curve, not how it feels in your hands. Play twenty runs on
a real phone before you decide `GameConfig.flapVelocity` and `gravity` are
right; they're the two numbers most worth trusting your thumbs over a
simulation on.
