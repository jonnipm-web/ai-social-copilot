import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// PLAY-READINESS-18 (Section 6-7) — standard Flutter/Android release-signing
// pattern: reads android/key.properties (never committed -- see
// android/.gitignore) if it exists. The actual keystore file and its
// passwords are created and kept by the Owner only; this file is only
// prepared to CONSUME that config once it exists.
//
// FAIL-CLOSED: a release-capable Gradle invocation (any task name containing
// "Release", e.g. assembleRelease/bundleRelease) with no valid
// key.properties now HARD FAILS instead of silently signing with the debug
// keystore. A debug build (assembleDebug, this repo's CI build gate) is
// unaffected when key.properties is absent -- release and debug signing are
// fully independent.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val keyPropertiesFileExists = keystorePropertiesFile.exists()
if (keyPropertiesFileExists) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Codex Gate (GOOGLE-AUTH-ANDROID-IDENTITY-GATE-17, P2 ACCEPTED) — the
// signingConfigs block below used to cast these 4 properties directly (`as
// String`), so a key.properties present but missing/misspelling one field
// failed with an opaque Kotlin ClassCastException instead of saying which
// field is missing. Validated explicitly, once, here.
val requiredKeys = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
val missingKeys = requiredKeys.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
val hasReleaseSigning = keyPropertiesFileExists && missingKeys.isEmpty()

val requestedTaskNames = gradle.startParameter.taskNames
val isReleaseTaskRequested = requestedTaskNames.any { it.contains("Release", ignoreCase = true) }

if (isReleaseTaskRequested && !hasReleaseSigning) {
    val reason = if (!keyPropertiesFileExists) {
        "android/key.properties was not found at ${keystorePropertiesFile.absolutePath}."
    } else {
        "android/key.properties exists but is missing or has empty values for: " +
            "${missingKeys.joinToString(", ")}. Expected all four of: " +
            "${requiredKeys.joinToString(", ")}."
    }
    throw GradleException(
        "PLAY-READINESS-18: fail-closed release signing -- a release task was " +
            "requested (${requestedTaskNames.joinToString(", ")}) but valid release " +
            "signing is not configured. $reason Release builds are no longer allowed " +
            "to silently fall back to the debug keystore. Create/complete " +
            "android/key.properties (never committed -- see android/.gitignore) with " +
            "keyAlias, keyPassword, storeFile, storePassword pointing at the real " +
            "upload keystore, then retry."
    )
} else if (!hasReleaseSigning) {
    // Not a release-capable invocation (e.g. assembleDebug in CI, or a local
    // debug build while key.properties is still being filled in) -- release
    // and debug signing are fully independent, so an absent or incomplete
    // key.properties never blocks a debug build. The release buildType's
    // signingConfig is simply left unassigned below, harmless because that
    // variant is never assembled in this scenario.
    logger.warn(
        "[insightvalues] release signing not fully configured in android/key.properties " +
            "-- this is fine for a debug build, but any release-capable task " +
            "(assembleRelease/bundleRelease) will now FAIL FAST instead of silently " +
            "signing with the debug keystore."
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
            // Fail-closed (see doc comment above): if this variant is ever
            // actually assembled, hasReleaseSigning is guaranteed true here
            // -- otherwise the release-task check above already aborted the
            // build. When hasReleaseSigning is false, no signingConfig is
            // assigned; harmless, because that only happens for a
            // non-release invocation that never touches this variant.
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
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
