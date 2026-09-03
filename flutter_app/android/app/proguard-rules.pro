# Flutter & Core Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.**  { *; }

# MediaPipe & Gemma Rules (Fixes flutter_gemma R8 error)
-dontwarn com.google.mediapipe.**
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.auto.value.**
-dontwarn javax.lang.model.**
-dontwarn autovalue.shaded.**

# OkHttp & Network TLS Rules (Fixes OkHttp & BouncyCastle warnings)
-dontwarn org.bouncycastle.jsse.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn okhttp3.internal.platform.**

# Generic Missing Classes Suppression
-dontwarn javax.annotation.**
-ignorewarnings

# ----------------------------------------------------------------------
# Offline LLM Native Rules (Fixes llama_flutter_android release build)
# ----------------------------------------------------------------------
-keep class com.write4me.llama_flutter_android.** { *; }
-keep class kotlin.jvm.functions.Function1
-keepclassmembers class * implements kotlin.jvm.functions.Function1 {
    public java.lang.Object invoke(java.lang.Object);
}
-keepclasseswithmembernames class * {
    native <methods>;
}
