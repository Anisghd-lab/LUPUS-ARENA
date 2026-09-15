# Configuration ProGuard / R8 pour Lupus Arena

# Agora RTC Engine
-keep class io.agora.** { *; }
-dontwarn io.agora.**


# Firebase & Flutter
-keep class io.flutter.** { *; }
-keep class com.google.firebase.** { *; }
