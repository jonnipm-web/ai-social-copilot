# InsightValues — ProGuard / R8 rules for release builds.
#
# PLAY-READINESS-18 / IV-CORE-MOBILE-COMMERCIAL-01
# Flutter's own shrinking is conservative by default; this file adds the
# app-specific keeps required by Supabase, Stripe, and other plugins.

# ──────────────────────────────────────────────────────────────────────────────
# Flutter engine
# ──────────────────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.editing.** { *; }

# ──────────────────────────────────────────────────────────────────────────────
# Supabase / Realtime (uses reflection for JSON deserialization)
# ──────────────────────────────────────────────────────────────────────────────
-keep class io.supabase.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# ──────────────────────────────────────────────────────────────────────────────
# Kotlin serialization
# ──────────────────────────────────────────────────────────────────────────────
-keepattributes InnerClasses
-keep class kotlinx.serialization.** { *; }
-keepclassmembers class ** {
    @kotlinx.serialization.Serializable *;
}

# ──────────────────────────────────────────────────────────────────────────────
# Android standard keeps
# ──────────────────────────────────────────────────────────────────────────────
-keepclassmembers class * {
    native <methods>;
}
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Preserve line number information for crash reports (Crashlytics / Play Console)
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
