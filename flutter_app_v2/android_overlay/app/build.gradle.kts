plugins {
    id("com.android.application")
    // MainActivity.kt is Kotlin; the Flutter Gradle Plugin must be applied after
    // the Android and Kotlin Gradle plugins (same order as the stock template).
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase / FCM resource generation from app/google-services.json.
//
// The file shipped in this repo is v1's project descriptor and still registers
// the old package `com.testing`, while this app is `com.mocktester.app`. The
// Google Services plugin treats that mismatch as a hard build error, so the
// plugin is applied only when the descriptor actually names *this* app: replace
// google-services.json with one generated for `com.mocktester.app` and Firebase
// resources appear automatically. Until then the build stays green and
// `AppBootstrap` reports `firebaseReady == false` instead of crashing.
//
// The plugin version is declared (apply false) in android/settings.gradle.kts.
val googleServicesDescriptor = file("google-services.json")
val googleServicesMatchesApp =
    googleServicesDescriptor.exists() &&
        googleServicesDescriptor.readText().contains("com.mocktester.app")
if (googleServicesMatchesApp) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.mocktester.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (java.time on API < 26).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.mocktester.app"

        // v1 shipped minSdk 26 via a CI sed patch; it is a real requirement here
        // because the app uses java.time based scheduling APIs.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // NB: the local must not be called `storeFile` - that name is the
            // SigningConfig setter, and shadowing it breaks the Kotlin DSL.
            val keystore = file(System.getenv("KEYSTORE_PATH") ?: "mocktester_key.jks")
            if (keystore.exists()) {
                storeFile = keystore
                storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "mocktester123"
                keyAlias = System.getenv("KEY_ALIAS") ?: "mocktester"
                keyPassword = System.getenv("KEY_PASSWORD") ?: "mocktester123"
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug signing for local builds without the keystore,
            // so `flutter build apk --release` always works.
            val releaseSigning = signingConfigs.findByName("release")
            val hasKeystore = file(System.getenv("KEYSTORE_PATH") ?: "mocktester_key.jks").exists()
            signingConfig = if (hasKeystore && releaseSigning != null) {
                releaseSigning
            } else {
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// ------------------------------------------------------- plugin compileSdk ---
// Flutter plugins ship their own compileSdk; a plugin built against an older
// SDK fails `checkReleaseAarMetadata` as soon as one of its dependencies (for
// example flutter_plugin_android_lifecycle) requires a newer one. The root
// script forces `:app` to be evaluated before every plugin, so registering the
// hook here runs before AGP finalises each plugin module - too late otherwise.
// `withGroovyBuilder` keeps this script independent of AGP's Kotlin API.
rootProject.subprojects {
    if (path == ":app") return@subprojects
    afterEvaluate {
        extensions.findByName("android")?.withGroovyBuilder {
            "compileSdkVersion"(36)
        }
    }
}
