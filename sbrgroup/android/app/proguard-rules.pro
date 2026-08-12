# Google Play Core — referenced by the Flutter engine's deferred-components
# code path even when the app does not use it.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }

# Firebase Installations backs the FCM token; R8 strips it otherwise and
# notifications stop arriving in release only.
-dontwarn com.google.firebase.installations.**
-keep class com.google.firebase.installations.** { *; }
-keep interface com.google.firebase.installations.** { *; }

# TensorFlow Lite is reached through JNI, so R8 cannot see the references.
-dontwarn org.tensorflow.**
-keep class org.tensorflow.** { *; }
-keep interface org.tensorflow.** { *; }

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
