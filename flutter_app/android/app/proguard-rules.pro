# Flutter Engine & Plugin Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# OkHttp, Network & TLS Security Rules (Supabase / Web calls ke liye)
-dontwarn org.bouncycastle.jsse.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn okhttp3.internal.platform.**
-dontwarn javax.annotation.**

# Supabase, Serialization & Reflection Rules
-keepattributes *Annotation*,EnclosingMethod,Signature,InnerClasses
-dontwarn sun.misc.**
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Image Picker & Native Hardware Methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Suppress harmless build warnings
-ignorewarnings
