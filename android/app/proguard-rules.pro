# R8 keeps the Flutter embedding and every plugin's platform channel handlers.
# The Dart side is AOT-compiled and untouched by shrinking; these rules only
# cover the Java/Kotlin surface the engine reflects into.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# audioplayers (behind flame_audio) drives ExoPlayer/media3 for the looping
# rain and music beds; it resolves renderers reflectively.
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class xyz.luan.audioplayers.** { *; }
