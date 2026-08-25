import 'dart:convert';

import 'package:ajna/main.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/app_bar.dart';
import 'package:ajna/screens/attendace/absent_list_screen.dart';
import 'package:ajna/screens/attendace/attendace_report.dart';
import 'package:ajna/screens/attendace/fo_attendance.dart';
import 'package:ajna/screens/attendance/attendance_dashboard.dart';
import 'package:ajna/screens/connectivity_handler.dart';
import 'package:ajna/screens/crm/crm_home_screen.dart';
import 'package:ajna/screens/crm/raise-issue.dart';
import 'package:ajna/screens/face_detection/admin_face_registration.dart';
import 'package:ajna/screens/face_detection/face_detection.dart';
import 'package:ajna/screens/face_detection/logout_face_detection.dart';
import 'package:ajna/screens/facility_management/customer_consumption.dart';
import 'package:ajna/screens/facility_management/fo_report.dart';
import 'package:ajna/screens/facility_management/ot_project_wise_report.dart';
import 'package:ajna/screens/facility_management/ot_screen.dart';
import 'package:ajna/screens/facility_management/manual_attendance.dart';
import 'package:ajna/screens/hrm/employee_list_screen.dart';
import 'package:ajna/screens/facility_management/qr_generator.dart';
import 'package:ajna/screens/facility_management/qr_schedule.dart';
import 'package:ajna/screens/facility_management/qrregenerate.dart';
import 'package:ajna/screens/facility_management/reports_projects.dart';
import 'package:ajna/screens/facility_management/reset_android_id.dart';
import 'package:ajna/screens/facility_management/user_manage_screen.dart';
import 'package:ajna/screens/facility_management/user_registration.dart';
import 'package:ajna/screens/incident/site_incident.dart';
import 'package:ajna/screens/notification/notification_sending.dart';
import 'package:ajna/screens/parking/parking_home_screen.dart';
import 'package:ajna/screens/sqflite/displaystored_data.dart';
import 'package:ajna/screens/student/MathTablesTestScreen.dart';
import 'package:ajna/screens/util.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:ajna/utils/update_checker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MaterialApp(
    home: HomeScreen(),
  ));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

/// A single module tile in the home grid.
///
/// Card-on-canvas: a white surface with a hairline border and a soft brand
/// shadow, holding a rounded, brand-tinted icon plate. Each tile takes an
/// [accentColor] from [AppColors.tileAccent] so the grid reads as a set instead
/// of a wall of identical squares.
class IconButtonWidget extends StatelessWidget {
  final String? imagePath;
  final IconData? icon;
  final String label;
  final Function() onTap;
  final Color accentColor;
  final double textSize; // Dynamic text size

  const IconButtonWidget({
    Key? key,
    this.icon,
    this.imagePath,
    required this.label,
    required this.onTap,
    this.accentColor = AppColors.primary,
    this.textSize = 12.0, // Default text size
  })  : assert(imagePath != null || icon != null,
            'Either imagePath or icon must be provided'),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: accentColor.withOpacity(0.12),
        highlightColor: accentColor.withOpacity(0.06),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The plate behind the glyph.
              //
              // A flat tinted square reads as a placeholder; the gradient plus
              // the hairline ring gives it an edge to catch the light, which is
              // what separates a tile that looks designed from one that looks
              // unfinished. Both are derived from the tile's accent, so the
              // grid stays one family rather than twenty-five colours.
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.tint(accentColor, 0.18),
                      AppColors.tint(accentColor, 0.07),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: accentColor.withOpacity(0.16),
                  ),
                ),
                alignment: Alignment.center,
                child: imagePath != null
                    ? Image.asset(imagePath!, width: 32, height: 32)
                    : Icon(icon, size: 27, color: accentColor),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: textSize,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  final ConnectivityHandler connectivityHandler = ConnectivityHandler();
  List<Map<String, dynamic>>? _iconDetails;

  final Set<String> staticLabels = {
    'QR Generator',
    'Sales',
    'QR Scan',
    'Site Visit Form',
    'User Registration',
    'Scan Report',
    'Re Generate Qr',
    'QR Assign',
    'QR Schedule',
    'Consumption',
    'Reset Android Id',
    'CRM',
    'Raise Issue',
    'Add Lead',
    'FO Visit',
    'Account Entry',
    'Attendance Report',
    'Schedule Report',
    'Stored Data',
    'OT',
    'OT Report',
    'Math Quiz',
    'Add Absent List',
    'Facial Attendance',
    'Parking',
    'Site Incident',
    'Manual Attendance',
    'Employee',
  };

  /// Labels shown even when the role/menu API has not been updated yet.
  ///
  /// The grid normally renders only what `fetchAdditionalData` returns for the
  /// user's role. Parking is new, so until "Parking" is added to the role menu
  /// on the backend the tile would never appear and the module would be
  /// unreachable. **Remove this once the backend returns it** — otherwise the
  /// tile is visible to every role, bypassing the menu permissions.
  static const Set<String> _alwaysVisibleLabels = {'Parking'};

  final List<Map<String, dynamic>> predefinedIcons = [
    {
      //'icon': Icons.qr_code,
      'icon': Icons.qr_code_2_rounded,
      'imagePath': null,
      'label': 'QR Generator',
      'onTap': () => const QrGeneratorScreen(),
    },
    // {
    //   //'icon': Icons.business_center,
    //   'icon': null,
    //   'imagePath': 'lib/assets/images/sales.png',
    //   'label': 'Sales',
    //   'onTap': () => PresalesPage(),
    // },
    // {
    //   //'icon': Icons.visibility,
    //   'icon': null,
    //   'imagePath': 'lib/assets/images/site_visit.png',
    //   'label': 'Site Visit Form',
    //   'onTap': () => SiteVisitForm(),
    // },
    {
      //'icon': Icons.app_registration,
      'icon': Icons.person_add_alt_1_rounded,
      'imagePath': null,
      'label': 'User Registration',
      'onTap': () => UserFormScreen(),
    },
    {
      //'icon': Icons.bar_chart,
      'icon': Icons.summarize_rounded,
      'imagePath': null,
      'label': 'Scan Report',
      'onTap': () => ReportsHomeScreen(),
    },
    {
      //'icon': Icons.dataset_linked,
      'icon': Icons.autorenew_rounded,
      'imagePath': null,
      'label': 'Re Generate Qr',
      'onTap': () => const QrRegenerate(),
    },
    {
      //'icon': Icons.assessment,
      'icon': Icons.assignment_ind_rounded,
      'imagePath': null,
      'label': 'QR Assign',
      'onTap': () => const UserManageScreen(),
    },
    {
      //'icon': Icons.qr_code_scanner,
      'icon': Icons.qr_code_scanner_rounded,
      'imagePath': null,
      'label': 'QR Scan',
      'onTap': () => ScanScheduleScreen(),
    },
    {
      //'icon': Icons.construction,
      'icon': Icons.speed_rounded,
      'imagePath': null,
      'label': 'Consumption',
      'onTap': () => CustomerConsumptionScreen(),
    },
    {
      //'icon': Icons.reset_tv,
      'icon': Icons.phonelink_erase_rounded,
      'imagePath': null,
      'label': 'Reset Android Id',
      'onTap': () => ResetAndroidIdScreen(),
    },
    {
      //'icon': Icons.bar_chart,
      'icon': Icons.handshake_rounded,
      'imagePath': null,
      'label': 'CRM',
      'onTap': () => const CrmHomeScreen(),
    },
    {
      //'icon': Icons.bar_chart,
      'icon': Icons.report_problem_rounded,
      'imagePath': null,
      'label': 'Raise Issue',
      'onTap': () => RaiseIssue(),
    },
    // {
    //   //'icon': Icons.bar_chart,
    //   'icon': null,
    //   'imagePath': 'lib/assets/images/lead.png',
    //   'label': 'Add Lead',
    //   'onTap': () => AddLeadScreen(),
    // },
    {
      //'icon': Icons.bar_chart,
      'icon': Icons.directions_walk_rounded,
      'imagePath': null,
      'label': 'FO Visit',
      'onTap': () => const AttendanceScreen(),
    },
    // {
    //   //'icon': Icons.bar_chart,
    //   'icon': null,
    //   'imagePath': 'lib/assets/images/account.png',
    //   'label': 'Account Entry',
    //   'onTap': () => TransactionHistoryScreen(),
    // },
    {
      //'icon': Icons.bar_chart,
      'icon': Icons.event_note_rounded,
      'imagePath': null,
      'label': 'Attendance Report',
      'onTap': () => AttendanceReportScreen(),
    },
    {
      'icon': Icons.fact_check_rounded,
      'imagePath': null,
      'label': 'Manual Attendance',
      'onTap': () => const ManualAttendanceScreen(),
    },
    {
      'icon': Icons.badge_rounded,
      'imagePath': null,
      'label': 'Employee',
      'onTap': () => const EmployeeListScreen(),
    },
    {
      //'icon': Icons.construction,
      'icon': Icons.calendar_month_rounded,
      'imagePath': null,
      'label': 'Schedule Report',
      'onTap': () => ReportsHomeScreen(),
    },
    {
      //'icon': Icons.construction,
      'icon': Icons.inventory_2_rounded,
      'imagePath': null,
      'label': 'Stored Data',
      'onTap': () => SchedulesScreen(),
    },
    {
      //'icon': Icons.construction,
      'icon': Icons.more_time_rounded,
      'imagePath': null,
      'label': 'OT',
      'onTap': () => OtScreen(),
    },
    {
      //'icon': Icons.construction,
      'icon': Icons.pending_actions_rounded,
      'imagePath': null,
      'label': 'OT Report',
      'onTap': () => OtReportProjectWise(),
      // 'onTap': () => OtReportScreen(),
    },
    {
      //'icon': Icons.construction,
      'icon': Icons.calculate_rounded,
      'imagePath': null,
      'label': 'Math Quiz',
      'onTap': () => MathTablesTestScreen(),
      // 'onTap': () => OtReportScreen(),
    },

    {
      //'icon': Icons.construction,
      'icon': Icons.assignment_turned_in_rounded,
      'imagePath': null,
      'label': 'Fo Report',
      'onTap': () => FoReportsScreen(),
      // 'onTap': () => OtReportScreen(),
    },

    {
      //'icon': Icons.construction,
      'icon': Icons.notifications_active_rounded,
      'imagePath': null,
      'label': 'Notification',
      'onTap': () => NotificationSendingScreen(),
      // 'onTap': () => OtReportScreen(),
    },
    {
      //'icon': Icons.bar_chart,
      'icon': Icons.face_retouching_natural_rounded,
      'imagePath': null,
      'label': 'Face Registration',
      'onTap': () => AdminFaceRegisterScreen(),
    },

    {
      //'icon': Icons.bar_chart,
      'icon': Icons.how_to_reg_rounded,
      'imagePath': null,
      'label': 'Facial Attendance',
      'onTap': () => AttendanceDashboardScreen(),
    },
    {
      // No artwork for parking yet — the tile falls back to a Material icon,
      // which IconButtonWidget already supports via `icon`.
      'icon': Icons.local_parking_rounded,
      'imagePath': null,
      'label': 'Parking',
      'onTap': () => const ParkingHomeScreen(),
    },
    {
      'icon': Icons.crisis_alert_rounded,
      'imagePath': null,
      'label': 'Site Incident',
      'onTap': () => const SiteIncidentScreen(),
    },
    // {
    //   //'icon': Icons.bar_chart,
    //   'icon': null,
    //   'imagePath': 'lib/assets/images/recognition.png',
    //   'label': 'Out Face Recognition',
    //   'onTap': () => LogOutFaceAttendanceScreen(),
    // },

    // {
    //   //'icon': Icons.bar_chart,
    //   'icon': null,
    //   'imagePath': 'lib/assets/images/absent.png',
    //   'label': 'Add Absent List',
    //   'onTap': () => AbsentListScreen(),
    // },
  ];

// Global navigator key for controlling navigation
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  String? androidId;
  late FirebaseMessaging _messaging;
  String? _deviceToken;
  int? userId;
  int? organizationId;
  int? roleId;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _checkConnectivity();
  }

  // Method to check connectivity when the app starts
  Future<void> _checkConnectivity() async {
    bool isConnected = await connectivityHandler.checkConnectivity(context);
    if (isConnected) {
      // Proceed with other initialization steps if connected
      _checkSession();
      // Store-based update prompt — replaces the old in-app APK download.
      // forceUpdate mirrors SBR WorkHub: once the backend bumps `ajna_version`,
      // the prompt is mandatory and cannot be dismissed.
      if (mounted) UpdateChecker.checkForUpdate(context, forceUpdate: true);
      _initializeFirebaseMessaging();
    }
  }

  Future<void> _initializeData() async {
    androidId = await Util.getUserAndroidId();
    userId = await Util.getUserId();
    organizationId = await Util.getOrganizationId();
    roleId = await Util.getRoleId();
    List<String>? iconLabels = await Util.getIconsAndLabels();
    List<Map<String, dynamic>> matchedIcons = [];

    if (iconLabels != null) {
      for (var predefinedIcon in predefinedIcons) {
        if (iconLabels.contains(predefinedIcon['label'])) {
          matchedIcons.add(predefinedIcon);
        }
      }
    }

    // Add any always-visible tile the role menu did not return, so a new module
    // is reachable before the backend menu is updated. See the field's doc.
    for (final predefinedIcon in predefinedIcons) {
      final String label = predefinedIcon['label'] as String;
      if (_alwaysVisibleLabels.contains(label) &&
          !matchedIcons.any((m) => m['label'] == label)) {
        matchedIcons.add(predefinedIcon);
      }
    }

    if (!mounted) return;
    setState(() {
      _iconDetails = matchedIcons;
    });

    // fetchHeadline();
  }

  static Future<void> _fetchAdditionalData(int roleId) async {
    try {
      final response = await ApiService.fetchAdditionalData(roleId);
      if (response.statusCode == 200) {
        var additionalData = json.decode(response.body);
        print('Decoded additionalData: $additionalData');

        if (additionalData is List<dynamic>) {
          List<String>? iconsAndLabels = additionalData.cast<String>();
          if (iconsAndLabels != null) {
            await Util.saveIconsAndLabels(iconsAndLabels);
            print('Saved Icons and Labels: $iconsAndLabels');
          } else {
            print('Failed to cast additional data to List<String>.');
          }
        } else {
          print(
              'Additional data is not in the expected format: ${additionalData.runtimeType}');
        }
      } else {
        print(
            'Failed to fetch additional data. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 403) {
          print(
              '403 Forbidden: Access denied. Check your permissions or token.');
        } else if (response.statusCode == 401) {
          print('401 Unauthorized: Invalid or expired token.');
        } else {
          print('Unhandled status code: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error fetching additional data: $e');
    }
  }

  Future<void> _initializeFirebaseMessaging() async {
    try {
      // Initialize Firebase Messaging
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Request notification permissions
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print("Notifications permission denied by the user.");
        return;
      }

      // Retry logic to get the device token
      String? token = await _getDeviceTokenWithRetry();
      if (token != null) {
        // Presence only — the FCM token is a push credential.
        debugPrint("Device token retrieved.");

        // Save token locally and handle errors
        bool isSaved = await Util.saveDeviceToken(token);
        if (isSaved) {
          print("Device token saved locally.");
        } else {
          print("Failed to save device token locally.");
        }

        // Store token on the server and handle errors
        if (userId != null && organizationId != null && androidId != null) {
          await _storeDeviceToken(userId!, token, androidId!, organizationId!);
        }
      } else {
        print("Failed to retrieve device token after retries.");
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        print("New device token: $newToken");

        if (userId != null && androidId != null && organizationId != null) {
          await _updateDeviceTokenInDatabase(
              userId!, newToken, androidId!, organizationId!);
        }
      });
    } catch (e) {
      print("Error initializing Firebase Messaging: $e");
    }
  }

  Future<String?> _getDeviceTokenWithRetry(
      {int retries = 3, Duration delay = const Duration(seconds: 2)}) async {
    String? token;
    for (int attempt = 0; attempt < retries; attempt++) {
      token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        return token;
      }
      print("Retrying to fetch device token... Attempt: ${attempt + 1}");
      await Future.delayed(delay);
    }
    return null; // Return null if token retrieval fails after retries
  }

  // Future<String?> getAndroidId() async {
  //   DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  //   AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
  //   return androidInfo.id; // This provides the unique device ID
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

  /// Validates the stored session whenever the home screen loads or refreshes.
  ///
  /// This call used to double as the in-app APK update check. The app now ships
  /// through the App Store / Play Store, so the version comparison and APK
  /// download were removed — but the 401 branch is unrelated to updating and is
  /// still load-bearing: it clears a stale session and pushes the user back to
  /// login. Only that behaviour remains.
  Future<void> _checkSession() async {
    try {
      final response = await ApiService.checkForUpdate();

      if (response.statusCode == 401) {
        // Clear preferences and show session expired dialog
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Show session expired dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Session Expired'),
            content: const Text(
                'Your session has expired. Please log in again to continue.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );

        // Automatically navigate to login after 5 seconds if no action
        Future.delayed(const Duration(seconds: 5), () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context); // Close dialog if still open
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        });

        return; // Early exit due to session expiration
      }
    } catch (e) {
      debugPrint('Error checking session: $e');
    }
  }

  Future<void> _refreshData() async {
    await _initializeData();
    await _fetchAdditionalData(roleId!);
    _checkSession();
  }

  Future<Map<String, String?>> getUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userName = prefs.getString('userName');
    String? designation = prefs.getString('designation');
    return {'userName': userName, 'designation': designation};
  }

  // Future<void> fetchHeadline() async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse(
  //           'https://your-api-url.com/headline?userId=$userId'), // API with userId query parameter
  //     );

  //     if (response.statusCode == 200) {
  //       var data = json.decode(response.body);
  //       setState(() {
  //         headline = data['headline'] ?? "No headline available for this user";
  //       });
  //     } else {
  //       setState(() {
  //         headline = "Failed to fetch headline";
  //       });
  //     }
  //   } catch (e) {
  //     setState(() {
  //       headline = "Error fetching headline";
  //     });
  //   }
  // }

  /// A soft, blurred colour blob used to decorate the hero gradient — the
  /// logo's two chevron colours, bled out behind the greeting.
  Widget _glowBlob(Color color, double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? messageText =
        ModalRoute.of(context)?.settings.arguments as String?;

    // Display the SnackBar after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messageText != null) {
        // Show a SnackBar with the notification message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageText)),
        );
      }
    });
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const CustomAppBar(),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _refreshData,
        child: Center(
          child: Column(
            children: <Widget>[
              // ── Brand hero: the logo's azure→emerald sweep, with the two
              // chevrons echoed as soft glow blobs behind the greeting.
              Container(
                height: 118,
                width: MediaQuery.of(context).size.width,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.heroGradient,
                    stops: AppColors.heroStops,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.heroShadow.withOpacity(0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -28,
                      top: -34,
                      child: _glowBlob(AppColors.emeraldGlow, 118, 0.20),
                    ),
                    Positioned(
                      right: 54,
                      bottom: -46,
                      child: _glowBlob(AppColors.azureGlow, 104, 0.22),
                    ),
                    FutureBuilder<Map<String, String?>>(
                            future: getUserDetails(),
                            builder: (BuildContext context,
                                AsyncSnapshot<Map<String, String?>> snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.onPrimary),
                                );
                              } else if (snapshot.hasError) {
                                return const Center(
                                  child: Text(
                                    "Error fetching user details",
                                    style: TextStyle(
                                        color: AppColors.onPrimary),
                                  ),
                                );
                              } else if (snapshot.hasData) {
                                String? profileImageUrl =
                                    snapshot.data!['profileImageUrl'];
                                final String? designation =
                                    snapshot.data!['designation'];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 16),
                                  child: Row(
                                    children: [
                                      // Ring lifts the avatar off the gradient.
                                      Container(
                                        padding: const EdgeInsets.all(2.5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.onPrimary
                                              .withOpacity(0.28),
                                        ),
                                        child: CircleAvatar(
                                          radius: 32,
                                          backgroundColor: AppColors.onPrimary,
                                          backgroundImage: profileImageUrl !=
                                                  null
                                              ? NetworkImage(profileImageUrl)
                                              : const AssetImage(
                                                      'lib/assets/images/avatar.png')
                                                  as ImageProvider,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Hi! Welcome.",
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: 0.2,
                                                color: AppColors.onPrimary
                                                    .withOpacity(0.85),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              snapshot.data!['userName'] ??
                                                  "No username found",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.onPrimary,
                                              ),
                                            ),
                                            if (designation != null &&
                                                designation.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 9, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppColors.onPrimary
                                                      .withOpacity(0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  designation,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.onPrimary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                return const Center(
                                  child: Text(
                                    "No user details found",
                                    style: TextStyle(
                                        color: AppColors.onPrimary),
                                  ),
                                );
                              }
                            },
                          ),
                  ],
                ),
              ),
              // Container(
              //   height: 60,
              //   margin: const EdgeInsets.symmetric(vertical: 20),
              //   padding: const EdgeInsets.symmetric(horizontal: 20),
              //   decoration: BoxDecoration(
              //     gradient: LinearGradient(
              //       colors: [Colors.blue, Colors.blueAccent],
              //       begin: Alignment.topLeft,
              //       end: Alignment.bottomRight,
              //     ),
              //     borderRadius: BorderRadius.circular(12),
              //     boxShadow: [
              //       BoxShadow(
              //         color: Colors.black26,
              //         offset: Offset(0, 2),
              //         blurRadius: 6,
              //       ),
              //     ],
              //   ),
              //   child: SingleChildScrollView(
              //     scrollDirection: Axis.horizontal, // Horizontal scrolling
              //     child: Row(
              //       children: [
              //         Padding(
              //           padding: const EdgeInsets.only(right: 30.0),
              //           child: Text(
              //             headline, // This will be the fetched headline
              //             style: TextStyle(
              //               fontSize: 18,
              //               fontWeight: FontWeight.bold,
              //               color: Colors.white,
              //             ),
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // ),

              // Expanded(
              //   child: Container(
              //     padding: const EdgeInsets.all(16.0),
              //     child: _iconDetails == null
              //         ? const CircularProgressIndicator()
              //         : GridView.count(
              //             shrinkWrap: true,
              //             crossAxisCount: 3,
              //             crossAxisSpacing: 10.0,
              //             mainAxisSpacing: 10.0,
              //             children: _iconDetails!.map((iconDetail) {
              //               return IconButtonWidget(
              //                 icon: iconDetail['icon'],
              //                 imagePath: iconDetail['imagePath'],
              //                 label: iconDetail['label'],
              //                 iconColor: Colors.white,
              //                 backgroundColor:
              //                     const Color.fromRGBO(255, 255, 255, 255),
              //                 onTap: () {
              //                   Navigator.push(
              //                     context,
              //                     MaterialPageRoute(
              //                       builder: (context) => iconDetail['onTap'](),
              //                     ),
              //                   );
              //                 },
              //               );
              //             }).toList(),
              //           ),
              //   ),
              // ),

              // ── Section label above the module grid.
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 15,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (_iconDetails != null)
                      Text(
                        '${_iconDetails!.length} modules',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _iconDetails == null
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            double screenWidth = constraints.maxWidth;
                            double textSize = screenWidth < 400
                                ? 10.0
                                : 14.0; // Adjust text size

                            // Column count follows the available width instead
                            // of being fixed at 3 — on a tablet three tiles
                            // stretched to ~300px each and looked broken.
                            final int columns =
                                gridColumns(screenWidth, minColumns: 3);

                            return GridView.count(
                              shrinkWrap: true,
                              crossAxisCount: columns,
                              crossAxisSpacing: 12.0,
                              mainAxisSpacing: 12.0,
                              childAspectRatio: 0.92,
                              children: _iconDetails!
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final iconDetail = entry.value;
                                return IconButtonWidget(
                                  icon: iconDetail['icon'],
                                  imagePath: iconDetail['imagePath'],
                                  label: iconDetail['label'],
                                  accentColor:
                                      AppColors.tileAccent(entry.key),
                                  textSize: textSize, // Pass dynamic text size
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            iconDetail['onTap'](),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Powered by  ',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              TextSpan(
                text: 'Core',
                style: const TextStyle(
                  color: Color.fromARGB(255, 37, 219, 9),
                  fontSize: 14,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    //ignore: deprecated_member_use
                    launch('https://www.corenuts.com');
                  },
              ),
              TextSpan(
                text: 'Nuts',
                style: const TextStyle(
                  color: Color.fromARGB(255, 221, 10, 10),
                  fontSize: 14,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    //ignore: deprecated_member_use
                    launch('https://www.corenuts.com');
                  },
              ),
              TextSpan(
                text: ' Technologies',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
