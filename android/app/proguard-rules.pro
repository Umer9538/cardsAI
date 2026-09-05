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
-keepattributes Signature
-keepattributes *Annotation*

# Gson reads a generic type off an anonymous TypeToken subclass, and under R8
# full mode `-keepattributes Signature` alone does not save it: the attribute
# survives only on classes R8 has been told to keep, and the anonymous
# `TypeToken<ArrayList<NotificationDetails>>` inside the notifications plugin is
# not one of them. With the signature gone Gson cannot tell what to
# deserialise into and throws.
#
# This is not theoretical and it is not quiet. It crashed the app outright:
#
#   Unable to start receiver ScheduledNotificationBootReceiver
#   Caused by: IllegalStateException: TypeToken must be created with a type
#   argument ... make sure that generic signatures are preserved.
#
# That receiver runs on BOOT_COMPLETED, so a release build died on every device
# restart — through the exact receiver that exists so reminders survive one.
# Release only, because R8 does not run in debug.
#
# `allowobfuscation, allowshrinking` is deliberate and is Gson's own documented
# rule for full mode: the classes may still be renamed and removed, which is
# the whole point of shrinking — it is only the generic signature that has to
# stay. A plain `-keep` would pin classes nothing uses.
#
# The rule this replaces named `TypeAdapter`, which is a different class from
# `TypeToken` and kept nothing that was failing.
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-dontwarn sun.misc.**

# Models Gson reflects over inside the notification plugin.
-keepclassmembers class ** {
    @com.google.gson.annotations.SerializedName <fields>;
}

# in_app_purchase: Play Billing's response objects are constructed reflectively.
-keep class com.android.billingclient.api.** { *; }

# mobile_scanner reaches ML Kit's barcode models through reflection.
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
