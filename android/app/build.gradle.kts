// `java.util` does not resolve inside a Gradle block, where `java` is the
// Java plugin extension. Imported here instead.
import java.util.Base64

import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing.
//
// `android/key.properties` and the keystore beside it are gitignored: they are
// the app's identity on Play and losing them means never being able to publish
// an update. Absent, the release build falls back to the debug key — which
// installs and runs, so the mistake is invisible until an upload is rejected.
// `tool/build_release.sh` refuses to build in that state for exactly that
// reason; this file only has to make the fallback obvious rather than silent.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.carbsai.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time, which does not exist
        // below API 26. Desugaring back-ports it rather than raising minSdk and
        // dropping the older half of the Android install base.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.carbsai.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                // Loud, not silent: a debug-signed release cannot be uploaded,
                // and finding that out at the upload step wastes a build.
                logger.warn("WARNING: no android/key.properties — signing the release with the DEBUG key.")
                signingConfigs.getByName("debug")
            }

            // R8 in full mode. Off by default in a Flutter project, which
            // leaves every unused class from Firebase, AdMob, Play Billing and
            // the scanner in the APK — worth several megabytes on a download
            // size that decides whether people install at all.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// A release APK without WORKER_URL builds, installs, and cannot reach the
// backend at all — no scan, no plan, no receipt check, no account deletion.
// Nothing in `flutter analyze` or the test suite sees it, and the binary looks
// perfectly normal, so it has now been shipped to a phone three times: once
// surfacing as a blank grey scan result, once as "The plan could not be built",
// and once caught only by the start-up guard in `main()`.
//
// `tool/build_release.sh` passes the define, but a bare
// `flutter build apk --release` and Android Studio's Build > Build APK do not,
// and either will happily overwrite a good build with a broken one of the same
// name. Refusing here is the only place that covers all three, because Gradle
// is what every one of them ends up calling.
//
// Flutter hands its --dart-define values to Gradle as `dart-defines`: a
// comma-separated list of base64-encoded KEY=VALUE strings.
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { it.name.contains("Release") }
    if (!buildingRelease) return@whenReady

    val defines = (project.findProperty("dart-defines") as String? ?: "")
        .split(",")
        .filter { it.isNotBlank() }
        .mapNotNull {
            runCatching { String(Base64.getDecoder().decode(it)) }.getOrNull()
        }
    val workerUrl = defines
        .firstOrNull { it.startsWith("WORKER_URL=") }
        ?.removePrefix("WORKER_URL=")
        ?.trim()

    if (workerUrl.isNullOrEmpty()) {
        throw GradleException(
            "\n\n  This release build has no WORKER_URL, so the app it produces " +
                "cannot\n  reach the backend: no scan, no plan, no purchases.\n\n" +
                "  Build it with:  tool/build_release.sh apk --dev\n" +
                "  (or pass --dart-define=WORKER_URL=... yourself)\n"
        )
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
