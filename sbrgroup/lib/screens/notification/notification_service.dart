import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/util.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  NotificationService._internal();
  String? _deviceToken;
  String? _androidId;
  int? _userId;
  int? organizationId;

  factory NotificationService() => _instance;

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission();
    print('Notification permission: ${settings.authorizationStatus}');
    _userId = await Util.getUserId();
    _androidId = await Util.getUserAndroidId();
    organizationId = await Util.getOrganizationId();

    // Get and print the token
    _messaging.getToken().then((token) {
      _deviceToken = token;
      print("Device Token: $_deviceToken");

      if (_deviceToken != null && _androidId != null && _userId != null) {
        _storeDeviceToken(
            _userId!, _deviceToken!, _androidId!, organizationId!);
      }
    });

    // Listen to foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotificationDialog(message, navigatorKey);
    });

    // Handle app opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateToRoute(message, navigatorKey);
    });

    // Handle notification when the app was terminated
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _navigateToRoute(initialMessage, navigatorKey);
    }

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('Token refreshed: $newToken');
      if (_androidId != null && _userId != null) {
        _updateDeviceTokenInDatabase(
            _userId!, newToken, _androidId!, organizationId!);
      }
    });
  }

  void _showNotificationDialog(
      RemoteMessage message, GlobalKey<NavigatorState> navigatorKey) {
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        builder: (_) => AlertDialog(
          title: Text(message.notification?.title ?? 'Notification'),
          content: Text(message.notification?.body ?? 'No content'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(navigatorKey.currentContext!).pop();
                _navigateToRoute(message, navigatorKey);
              },
              child: Text('View'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(navigatorKey.currentContext!).pop();
              },
              child: Text('Dismiss'),
            ),
          ],
        ),
      );
    }
  }

  void _navigateToRoute(
      RemoteMessage message, GlobalKey<NavigatorState> navigatorKey) {
    String route = message.data['route'] ?? '/main';
    navigatorKey.currentState?.pushNamed(route);
  }

  // // Retrieve Android ID
  // Future<String?> _getAndroidId() async {
  //   DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  //   AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
  //   return androidInfo.id;
  // }

  // Method to update device token and Android ID in the backend
  Future<void> _updateDeviceTokenInDatabase(
      int userId, String newToken, String androidId, int organizationId) async {
    try {
      final response = await ApiService.updateDeviceTokenWithAndroidId(
          userId, newToken, androidId, organizationId);
      print("Response Status: ${response.statusCode}");
      if (response.statusCode == 200) {
        print(
            "Device token and Android ID updated successfully in the database");
      } else {
        print("Failed to update device token: ${response.body}");
      }
    } catch (e) {
      print("Error while updating device token and Android ID: $e");
    }
  }

  // Method to store device token with query parameters (matching your Java backend)
  Future<void> _storeDeviceToken(int userId, String deviceToken,
      String androidId, int organizationId) async {
    try {
      final response = await ApiService.storeDeviceToken(
          userId, deviceToken, androidId, organizationId);

      print("Response Status: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        print("Device token stored successfully");
      } else {
        print("Failed to store device token: ${response.body}");
      }
    } catch (e) {
      print("Error while sending token to server: $e");
    }
  }
}
