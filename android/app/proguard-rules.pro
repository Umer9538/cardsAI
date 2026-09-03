# R8 rules.
#
# Flutter's own engine classes are kept by the plugin's consumer rules, and
# every AndroidX/Firebase/Play library ships its own. What is left is the set
# of things R8 cannot see are used because they are reached by reflection or
# from native code.

# Flutter's deferred-components and Play Core hooks. R8 warns about these being
# missing whenever an app does not use deferred components — which is this app —
# and the warning fails the build under full mode.
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# flutter_local_notifications serialises its scheduled notifications to JSON
# with Gson and reads them back after a reboot. Obfuscating those field names
# loses every pending reminder the first time the phone restarts — and it fails
# silently, which is the worst way for a reminder to break.
-keep class com.dexterous.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keepattributes Signature
-keepattributes *Annotation*

# Models Gson reflects over inside the notification plugin.
-keepclassmembers class ** {
    @com.google.gson.annotations.SerializedName <fields>;
}

# in_app_purchase: Play Billing's response objects are constructed reflectively.
-keep class com.android.billingclient.api.** { *; }

# mobile_scanner reaches ML Kit's barcode models through reflection.
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
