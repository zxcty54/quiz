# ==============================================================================
# 1. Flutter Engine & Core Plugins
# ==============================================================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ==============================================================================
# 2. Flutter InAppWebView (CRITICAL for JavaScript Injection & RTPS Autofill)
# ==============================================================================
-keep class com.pichillilorenzo.flutter_inappwebview_android.** { *; }
-keepattributes *Annotation*,EnclosingMethod,Signature,InnerClasses,JavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-dontwarn com.pichillilorenzo.flutter_inappwebview_android.**

# Android WebKit components
-keep public class * extends android.webkit.WebViewClient
-keep public class * extends android.webkit.WebChromeClient

# ==============================================================================
# 3. OkHttp, Network & TLS Security Rules (Supabase / REST calls)
# ==============================================================================
-dontwarn org.bouncycastle.jsse.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn okhttp3.internal.platform.**
-dontwarn javax.annotation.**

# ==============================================================================
# 4. Supabase, Serialization & Model Reflection
# ==============================================================================
-dontwarn sun.misc.**
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ==============================================================================
# 5. Native Methods & Image Picker
# ==============================================================================
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Custom Model Classes (Data Models reflect safely)
-keep class com.mocktester.app.models.** { *; }

# Suppress harmless build warnings
-ignorewarnings
