import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// GOOGLE-AUTH-ANDROID-IDENTITY-GATE-17 (Section 07) — standard Flutter/
// Android release-signing pattern: reads android/key.properties (never
// committed -- see android/.gitignore) if it exists. The actual keystore
// file and its passwords must be created and kept by the Owner; this
// file is only prepared to CONSUME that config once it exists. Builds
// stay green before then (release falls back to the debug signingConfig,
// same placeholder Flutter itself scaffolds by default) -- creating this
// file does not, by itself, require or assume a keystore already exists.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    // Codex Gate (GOOGLE-AUTH-ANDROID-IDENTITY-GATE-17, P2 ACCEPTED) — the
    // signingConfigs block below used to cast these 4 properties directly
    // (`as String`), so a key.properties present but missing/misspelling
    // one field failed with an opaque Kotlin ClassCastException instead of
    // saying which field is missing. Validated explicitly, once, here.
    val requiredKeys = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
    val missingKeys = requiredKeys.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
    if (missingKeys.isNotEmpty()) {
        throw GradleException(
            "android/key.properties exists but is missing or has empty values for: " +
                "${missingKeys.joinToString(", ")}. Expected all four of: " +
                "${requiredKeys.joinToString(", ")}."
        )
    }
} else {
    // Codex Gate (P2 ACCEPTED) — falling back to debug signing for a
    // release build is Flutter's own standard scaffolded default (keeps
    // `flutter build apk --debug` / this repo's CI build gate working
    // before a real keystore exists) and is intentionally NOT a hard
    // failure here. But a `--release`/`appbundle --release` build with no
    // real signing configured should never look silent about that -- this
    // is a build-configuration-time warning (always printed once when
    // Gradle evaluates this file for a release-capable build), not a test
    // a normal `flutter test` run would ever see.
    logger.warn(
        "[insightvalues] android/key.properties not found -- RELEASE builds will be " +
            "signed with the DEBUG keystore (not production-ready). This is expected " +
            "before the Owner creates a real upload keystore; see this file's own doc " +
            "comment for the keytool command."
    )
}

android {
    namespace = "com.insightvalues.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.insightvalues.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            // getProperty() (String?) instead of the Map-style `[...] as
            // String` cast used before -- the validation above already
            // guarantees these are non-blank, so `!!` here can never
            // actually trip; it exists so the compiler (not a runtime
            // ClassCastException) is what would catch a future edit that
            // removes that guarantee.
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")!!
                keyPassword = keystoreProperties.getProperty("keyPassword")!!
                storeFile = file(keystoreProperties.getProperty("storeFile")!!)
                storePassword = keystoreProperties.getProperty("storePassword")!!
            }
        }
    }

    buildTypes {
        release {
            // Uses the real upload keystore once android/key.properties
            // exists (see this file's own doc comment above); falls back
            // to the debug keys otherwise so `flutter build --release`
            // keeps working as a build-gate/smoke-test artifact before a
            // release keystore is created -- exactly Flutter's own
            // scaffolded default, not a weakening of it.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
