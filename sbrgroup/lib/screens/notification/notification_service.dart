import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/util.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

const MethodChannel _audioChannel = MethodChannel('emergency_audio_channel');

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final AudioPlayer _emergencyPlayer = AudioPlayer();

  NotificationService._internal();
  factory NotificationService() => _instance;

  String? _deviceToken;
  String? _androidId;
  int? _userId;
  int? _organizationId;
  bool _isEmergencySoundPlaying = false;

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );
    debugPrint(
        '🔔 Notification permission status: ${settings.authorizationStatus}');

    _userId = await Util.getUserId();
    _androidId = await Util.getUserAndroidId();
    _organizationId = await Util.getOrganizationId();
    _deviceToken = await _messaging.getToken();
    debugPrint("✅ Device Token: $_deviceToken");

    if (_deviceToken != null &&
        _androidId != null &&
        _userId != null &&
        _organizationId != null) {
      await _storeDeviceToken(
          _userId!, _deviceToken!, _androidId!, _organizationId!);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📨 Foreground notification received");
      _handleNotificationSound(message, isForeground: true);
      _showNotificationDialog(message, navigatorKey);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("📨 App opened from background notification");
      _handleNotificationSound(message, isForeground: false);
      _showNotificationDialog(message, navigatorKey);
    });

    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("📨 App opened from terminated state via notification");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationSound(initialMessage, isForeground: false);
        _showNotificationDialog(initialMessage, navigatorKey);
      });
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('♻️ Token refreshed: $newToken');
      if (_androidId != null && _userId != null && _organizationId != null) {
        _updateDeviceTokenInDatabase(
            _userId!, newToken, _androidId!, _organizationId!);
      }
    });

    FirebaseMessaging.onBackgroundMessage(_handleBackgroundNotification);
  }

  void _handleNotificationSound(RemoteMessage message,
      {required bool isForeground}) {
    final isEmergency = message.data['emergency'] == 'true';
    if (isEmergency) {
      if (isForeground) {
        playEmergencyRingtone();
      }
      // Background/terminated sound is handled by native code
    } else {
      if (isForeground) {
        playNormalNotificationSound();
      }
      // Background/terminated sound is the system default for the channel
    }
  }

  void _showNotificationDialog(
      RemoteMessage message, GlobalKey<NavigatorState> navigatorKey) {
    if (navigatorKey.currentContext == null) return;

    final isEmergency = message.data['emergency'] == 'true';

    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible:
          false, // Prevent dismissing by tapping outside or back button
      builder: (_) => AlertDialog(
        title: Text(message.notification?.title ?? 'Notification'),
        content: Text(message.notification?.body ?? 'No content'),
        actions: [
          if (!isEmergency)
            TextButton(
              onPressed: () {
                stopRingtone();
                Navigator.of(navigatorKey.currentContext!).pop();
                _navigateToRoute(message, navigatorKey);
              },
              child: const Text('View'),
            ),
          TextButton(
            onPressed: () {
              stopRingtone();
              Navigator.of(navigatorKey.currentContext!).pop();
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    ); // Do not stop sound on dialog dismiss, only on button tap
  }

  void _navigateToRoute(
      RemoteMessage message, GlobalKey<NavigatorState> navigatorKey) {
    stopRingtone();
    final route = message.data['route'] ?? '/main';
    navigatorKey.currentState?.pushNamed(route);
  }

  // static Future<void> _handleBackgroundNotification(
  //     RemoteMessage message) async {
  //   if (message.data['emergency'] == 'true') {
  //     try {
  //       await _audioChannel.invokeMethod('playEmergencySound');
  //     } catch (e) {
  //       debugPrint(
  //           "❌ Error playing emergency sound (background - MethodChannel): $e");
  //       // Keep the fallback in case of issues with the MethodChannel
  //       playEmergencyRingtoneInBackground();
  //     }
  //   } else {
  //     // No specific sound to play here for normal notifications in the background/terminated state.
  //     // The system will play the default sound for the "high_importance_channel".
  //   }
  // }

  static Future<void> _handleBackgroundNotification(
      RemoteMessage message) async {
    if (message.data['emergency'] == 'true') {
      try {
        await _audioChannel.invokeMethod('playEmergencySound');
      } catch (e) {
        debugPrint("❌ Error playing emergency sound in background: $e");
      }
    }
  }

  void playEmergencyRingtone() async {
    try {
      await _emergencyPlayer.setReleaseMode(ReleaseMode.loop);
      await _emergencyPlayer.play(AssetSource('sounds/emergency_tone.mp3'));
      _isEmergencySoundPlaying = true;
      debugPrint("🚨 Playing emergency ringtone (Flutter)");
    } catch (e) {
      debugPrint("❌ Error playing emergency sound (Flutter): $e");
    }
  }

  static Future<void> playEmergencyRingtoneInBackground() async {
    try {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('sounds/emergency_tone.mp3'));
      // We don't track _isEmergencySoundPlaying here as this is for background fallback
      debugPrint(
          "🚨 Playing emergency ringtone (Flutter - Background Fallback)");
      // It's crucial to stop this player when the app comes to foreground or is dismissed
      // This might require more sophisticated handling based on your app's lifecycle.
      // For a simple approach, we might rely more on the native implementation for looping in the background.
    } catch (e) {
      debugPrint(
          "❌ Error playing emergency sound (Flutter - Background Fallback): $e");
    }
  }

  static void playNormalNotificationSound() {
    try {
      FlutterRingtonePlayer.play(
        android: AndroidSounds.notification,
        ios: IosSounds.triTone,
        looping: false,
        volume: 1.0,
      );
      debugPrint("🔔 Playing normal notification sound");
    } catch (e) {
      debugPrint("❌ Error playing normal notification sound: $e");
    }
  }

  void stopRingtone() async {
    try {
      if (_isEmergencySoundPlaying) {
        await _emergencyPlayer.stop();
        _isEmergencySoundPlaying = false;
        debugPrint("⏹ Emergency ringtone stopped (Flutter)");
      }
      try {
        await _audioChannel.invokeMethod('stopEmergencySound');
        debugPrint("⏹ Emergency sound stopped (Native)");
      } catch (e) {
        debugPrint("❌ Error stopping emergency sound (Native): $e");
      }
    } catch (e) {
      debugPrint("❌ Error stopping ringtone (Flutter): $e");
    }
  }

  Future<void> _storeDeviceToken(
    int userId,
    String deviceToken,
    String androidId,
    int organizationId,
  ) async {
    try {
      final response = await ApiService.storeDeviceToken(
        // Placeholder
        userId,
        deviceToken,
        androidId,
        organizationId,
      );
      debugPrint("📦 Store Token Response: ${response.statusCode}");
      if (response.statusCode == 200) {
        debugPrint("✅ Device token stored successfully");
      } else {
        debugPrint("❌ Failed to store token: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Exception while storing token: $e");
    }
  }

  Future<void> _updateDeviceTokenInDatabase(
    int userId,
    String newToken,
    String androidId,
    int organizationId,
  ) async {
    try {
      final response = await ApiService.updateDeviceTokenWithAndroidId(
        // Placeholder
        userId,
        newToken,
        androidId,
        organizationId,
      );
      debugPrint("🔁 Update Token Response: ${response.statusCode}");
      if (response.statusCode == 200) {
        debugPrint("✅ Device token updated successfully");
      } else {
        debugPrint("❌ Failed to update token: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Exception while updating token: $e");
    }
  }
}
