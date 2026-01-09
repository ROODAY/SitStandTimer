# Keep Flutter Local Notifications classes from being obfuscated
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationManagerCompat { *; }

# Keep notification-related classes
-keep class * extends android.app.Notification { *; }
-keep class * extends android.app.Notification$* { *; }

# Keep Gson classes (used by flutter_local_notifications for serialization)
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.** { *; }
-dontwarn com.google.gson.**

# Keep generic type information for serialization (CRITICAL for Gson)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes Exceptions

# Keep TypeToken and its subclasses (needed for Gson generic type handling)
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken { *; }

# Keep anonymous inner classes in flutter_local_notifications (used for TypeToken)
-keep class com.dexterous.flutterlocalnotifications.**$* { *; }

# Keep all classes that might be serialized by Gson
-keep class * implements java.io.Serializable { *; }

# Keep all fields and methods in classes that use Gson
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Additional rule: Keep all members of classes that extend TypeToken
-keepclassmembers class * extends com.google.gson.reflect.TypeToken {
    <init>(...);
}

# Keep the specific anonymous inner class that's causing issues
-keep class com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin$* { *; }

# Ensure TypeToken can access superclass type parameters via reflection
-keepclassmembers class * extends com.google.gson.reflect.TypeToken {
    protected java.lang.Class getRawType();
}

# Disable optimization that might break Gson's type parameter reflection
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify
