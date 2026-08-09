import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload keystore, kept out of version control (see .gitignore). Create
// android/key.properties with storeFile / storePassword / keyAlias /
// keyPassword to produce a Play-signable bundle; without it the release build
// falls back to the debug key so `flutter run --release` still works locally.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.flappyrain.flappy_rain"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Change this to your own reverse-DNS id before the first Play upload —
        // an application id is permanent once published.
        applicationId = "com.flappyrain.flappy_rain"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Flutter no longer ships a 32-bit x86 engine, but a transitive
        // AndroidX dependency still contributes lib/x86/*.so. That is enough
        // for Android's installer to pick x86 as the primary ABI on such a
        // device and then fail to find libflutter.so — an install that
        // launches straight into a crash. Ship only the ABIs that carry a
        // complete engine.
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "upload" else "debug")
            // R8 shrinking is wired up (see proguard-rules.pro) but left off:
            // a bad keep rule only shows up as a crash in a release build, and
            // the Dart AOT code — nearly all of this app's size — is not
            // shrunk anyway, so there is little to win. Flip this to true once
            // you have run a shrunk release build on a real device.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
