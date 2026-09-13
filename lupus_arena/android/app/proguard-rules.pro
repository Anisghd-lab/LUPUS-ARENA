# Configuration ProGuard / R8 pour Lupus Arena

# Agora RTC Engine
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# Unity Ads
-keep class com.unity3d.ads.** { *; }
-keep class com.unity3d.services.** { *; }
-dontwarn com.unity3d.ads.**
-dontwarn com.unity3d.services.**

# Firebase & Flutter
-keep class io.flutter.** { *; }
-keep class com.google.firebase.** { *; }
