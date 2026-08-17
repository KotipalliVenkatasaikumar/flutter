import 'dart:convert';

import 'package:ajna/main.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/attendace/absent_list_screen.dart';
import 'package:ajna/screens/attendace/generate_report_screen.dart';
import 'package:ajna/screens/connectivity_handler.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/facility_management/custom_date_picker.dart';
import 'package:ajna/screens/util.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajna/theme/app_colors.dart';

class Attendance {
  final int count;
  final String attendanceStatus;
  final String? createdDate;
  final int lateComerCount;
  final int earlyLeaverCount;

  Attendance({
    required this.count,
    required this.attendanceStatus,
    required this.createdDate,
    required this.lateComerCount,
    required this.earlyLeaverCount,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      count: json['count'] ?? 0,
      attendanceStatus: json['attendanceStatus'] ?? 'Unknown',
      createdDate: json['createdDate'] ?? 'N/A',
      lateComerCount: json['lateComerCount'] ?? 0,
      earlyLeaverCount: json['earlyLeaverCount'] ?? 0,
    );
  }
}

class ShiftTiming {
  final int id;
  final String commonRefKey;
  final String commonRefValue;

  ShiftTiming({
    required this.id,
    required this.commonRefKey,
    required this.commonRefValue,
  });

  factory ShiftTiming.fromJson(Map<String, dynamic> json) {
    return ShiftTiming(
      id: json['id'],
      commonRefKey: json['commonRefKey'],
      commonRefValue: json['commonRefValue'],
    );
  }
}

class Location {
  final int id;
  final String location;

  Location({required this.id, required this.location});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'],
      location: json['location'],
    );
  }
}

class AttendanceRecord {
  final int attendanceId;
  final int userId;
  final String userName;
  final DateTime? attendanceInDate; // Nullable to handle missing data
  final DateTime? attendanceOutDate; // Nullable to handle missing data
  final String? attendanceInTime; // Nullable to handle missing data
  final String? attendanceOutTime; // Nullable to handle missing data
  final int? logInLocationId;
  final int? logOutLocationId;
  final String? logInLocationName;
  final String? logOutLocationName;

  final String attendanceStatus;
  final int shiftId;
  final String commonRefKey;
  final String commonRefValue;
  final int employeeId;

  AttendanceRecord({
    required this.attendanceId,
    required this.userId,
    required this.userName,
    this.attendanceInDate,
    this.attendanceOutDate,
    this.attendanceInTime,
    this.attendanceOutTime,
    this.logInLocationId,
    this.logOutLocationId,
    this.logInLocationName,
    this.logOutLocationName,
    required this.attendanceStatus,
    required this.shiftId,
    required this.commonRefKey,
    required this.commonRefValue,
    required this.employeeId,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      attendanceId: json['attendanceId'],
      userId: json['userId'],
      userName: json['userName'],
      attendanceInDate: json['attendanceInDate'] != null
          ? DateTime.parse(json['attendanceInDate'])
          : null,
      attendanceOutDate: json['attendanceOutDate'] != null
          ? DateTime.parse(json['attendanceOutDate'])
          : null,
      attendanceInTime: json['attendanceInTime'] ?? " ",
      attendanceOutTime: json['attendanceOutTime'] ?? " ",
      logInLocationId: json['logInLocationId'],
      logOutLocationId: json['logOutLocationId'],
      logInLocationName: json['logInLocationName'] ?? " ",
      logOutLocationName: json['logOutLocationName'] ?? " ",
      attendanceStatus: json['attendanceStatus'],
      shiftId: json['shiftId'],
      commonRefKey: json['commonRefKey'],
      commonRefValue: json['commonRefValue'],
      employeeId: json['employeeId'],
    );
  }
}

class RoleReport {
  final int roleId;
  final String roleName;
  final int totalAttendance;
  final int loggedInCount;
  final int notLoggedInCount;

  RoleReport({
    required this.roleId,
    required this.roleName,
    required this.totalAttendance,
    required this.loggedInCount,
    required this.notLoggedInCount,
  });

  factory RoleReport.fromJson(Map<String, dynamic> json) {
    return RoleReport(
      roleId: json['roleId'] ?? 0,
      roleName: json['roleName'] ?? 'Unknown',
      totalAttendance: json['totalAttendance'] ?? 0,
      loggedInCount: json['loggedInCount'] ?? 0,
      notLoggedInCount: json['notLoggedInCount'] ?? 0,
    );
  }
}

class Role {
  final int roleId;
  final String roleName;

  Role({
    required this.roleId,
    required this.roleName,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      roleId: json['roleId'] ?? 0,
      roleName: json['roleName'] ?? 'Unknown',
    );
  }
}

/// One row of the web dashboard's "SITE WISE ATTENDANCE" table.
///
/// The backend returns loggedInCount/notLoggedInCount as SQL SUMs (BigDecimal)
/// and totalCount as a COUNT (Long), so they arrive as different JSON number
/// types — everything is read through [_toInt] rather than cast.
class LocationWiseReport {
  final int locationId;
  final String location;
  final int loggedInCount;
  final int notLoggedInCount;
  final int totalCount;

  LocationWiseReport({
    required this.locationId,
    required this.location,
    required this.loggedInCount,
    required this.notLoggedInCount,
    required this.totalCount,
  });

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString()) ??
        double.tryParse(v.toString())?.round() ??
        0;
  }

  factory LocationWiseReport.fromJson(Map<String, dynamic> json) {
    return LocationWiseReport(
      locationId: _toInt(json['locationId']),
      location: json['location']?.toString() ?? 'Unknown',
      loggedInCount: _toInt(json['loggedInCount']),
      notLoggedInCount: _toInt(json['notLoggedInCount']),
      totalCount: _toInt(json['totalCount']),
    );
  }
}

class AttendanceReportScreen extends StatefulWidget {
  @override
  _AttendanceReportScreenState createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final ConnectivityHandler connectivityHandler = ConnectivityHandler();

  bool isLoading = true;
  List<Attendance> attendanceRecords = [];
  List<AttendanceRecord> attendaceReportDetails = [];
  List<RoleReport> roleReportDetails = [];
  String selectedDateRange = '0';
  int? organizationId;
  int? userId;
  List<Location> locations = [];
  List<ShiftTiming> shifts = [];
  String selectedLocation = '0';
  String selectedShift = '0';
  String selectedRole = '0';
  List<Role> roles = [];

  String attendanceStatus = '';
  String searchQuery = '';
  String selectedStatus = '';
  String page = '0';
  int size = 10;
  final ScrollController _scrollController = ScrollController();
  late int _itemCount;
  List<ShiftTiming> selectedShifts = [];
  List<int> selectedShiftIds = [0]; // Initialize with 0 for "All Shifts"

  bool isNotificationSent = false;

  // Which of the three lists is on screen: 'attendance', 'role' or 'site'.
  // The web dashboard stacks the site and role tables; on a phone they are
  // switched between instead so neither is squeezed.
  String activeView = 'attendance';

  /// Kept so the existing reads below carry on working unchanged.
  bool get showAttendanceList => activeView == 'attendance';

  List<LocationWiseReport> locationWiseDetails = [];
  bool isLocationWiseLoading = false;

  /// Late comers / early leavers ride along on the dashboard response rather
  /// than having an endpoint of their own — the web reads them off the first
  /// row for the same reason.

  int get siteLoggedInTotal =>
      locationWiseDetails.fold(0, (s, r) => s + r.loggedInCount);
  int get siteNotLoggedInTotal =>
      locationWiseDetails.fold(0, (s, r) => s + r.notLoggedInCount);
  int get siteTotal => locationWiseDetails.fold(0, (s, r) => s + r.totalCount);

  int get roleLoggedInTotal =>
      roleReportDetails.fold(0, (s, r) => s + r.loggedInCount);
  int get roleNotLoggedInTotal =>
      roleReportDetails.fold(0, (s, r) => s + r.notLoggedInCount);
  int get roleTotal =>
      roleReportDetails.fold(0, (s, r) => s + r.totalAttendance);

  @override
  void initState() {
    super.initState();
    // _initializeData();
    // _checkSession();
    // _scrollController.addListener(_scrollListener);
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    bool isConnected = await connectivityHandler.checkConnectivity(context);
    if (isConnected) {
      _checkSession();
      // Proceed with other initialization steps if connected
      _initializeData();

      _scrollController.addListener(_scrollListener);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      organizationId = await Util.getOrganizationId();
      userId = await Util.getUserId();
      fetchAttendanceDashboard();
      fetchShiftData();
      fetchAttendanceLocation(organizationId!);
      // The role and site breakdowns are not requested here:
      // fetchAttendanceDashboard() above already starts both, and calling them
      // again fired every one of those two requests twice on each open.

      // The list itself was never loaded on open — the screen came up blank
      // until a count card was tapped, while the web opens with its attendance
      // list already filled. '' means every status, matching "All Attendance".
      fetchAttendanceDetails('', '');
      fetchRoles();
    } catch (error) {
      ErrorHandler.handleError(
        context,
        'Failed to initialize data. Please try again later.',
        'Initialization error: $error',
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      setState(() {
        size += 10; // Increase the size by 10 each time
      });

      // // Determine the status to fetch based on the dashboard selection and list of records
      String statusToFetch = '';
      if (attendaceReportDetails.isNotEmpty) {
        final uniqueStatuses = attendaceReportDetails
            .map((record) => record.attendanceStatus)
            .toSet(); // Get unique statuses

        // If only one unique status exists, use it; otherwise, set to '' to fetch all records
        if (uniqueStatuses.length == 1) {
          statusToFetch = uniqueStatuses.first;
        } else {
          print("else" + statusToFetch);
        }
      }

      fetchAttendanceDetails(statusToFetch, '');
    }
  }

  // Future<void> fetchShiftData() async {
  //   try {
  //     final response = await ApiService.fetchshiftData();
  //     if (response.statusCode == 200) {
  //       final jsonData = jsonDecode(response.body);
  //       setState(() {
  //         shifts = jsonData
  //             .map<ShiftTiming>((json) => ShiftTiming.fromJson(json))
  //             .toList();
  //       });
  //     } else {
  //       throw Exception('Failed to load shifts');
  //     }
  //   } catch (error) {
  //     ErrorHandler.handleError(
  //       context,
  //       'Failed to load shift data.',
  //       'Shift data error: $error',
  //     );
  //   }
  // }

  Future<void> fetchShiftData() async {
    try {
      final response = await ApiService.fetchshiftData();
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);

        setState(() {
          shifts = jsonData.map((json) => ShiftTiming.fromJson(json)).toList();

          // Add "All Shifts" option if it doesn't exist
          ShiftTiming allShift = ShiftTiming(
              id: 0, commonRefKey: 'All Shifts', commonRefValue: 'All');

          if (!shifts.any((shift) => shift.id == 0)) {
            shifts.insert(0, allShift);
          }

          // Set default selected shift as "All Shifts"
          selectedShifts = [allShift];
          selectedShiftIds = selectedShifts
              .map((shift) => shift.id)
              .toList(); // Update selected IDs
        });
      } else {
        throw Exception('Failed to load shifts');
      }
    } catch (error) {
      print("Error loading shift data: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load shift data.')),
      );
    }
  }

  Future<void> fetchAttendanceLocation(int organizationId) async {
    // fetchRoles();

    try {
      final response = await ApiService.fetchAttendanceLocation(organizationId);
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          locations = jsonData
              .map<Location>((json) => Location.fromJson(json))
              .toList();
        });
      } else {
        throw Exception('Failed to load locations');
      }
    } catch (error) {
      ErrorHandler.handleError(
        context,
        'Failed to load location data.',
        'Location data error: $error',
      );
    }
  }

  /// Roles for the Role filter. Fails quietly on purpose: the filter is
  /// optional, and a dialog on open would interrupt someone who only wants the
  /// counts. Without it the dropdown simply offers "All".
  Future<void> fetchRoles() async {
    if (organizationId == null) return;
    try {
      final response = await ApiService.fetchRoles(
        organizationId!,
        selectedLocation,
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> rows = decoded is List ? decoded : const [];
        if (!mounted) return;

        // These endpoints return a trailing all-null row (the dashboard call
        // does the same), which Role.fromJson turns into roleId 0 — the value
        // already used for "All". Two items with the same value makes the
        // dropdown assert, so blanks are dropped and ids de-duplicated.
        final seen = <int>{};
        final cleaned = <Role>[];
        for (final json in rows.whereType<Map<String, dynamic>>()) {
          final role = Role.fromJson(json);
          if (role.roleId == 0) continue;
          if (role.roleName.trim().isEmpty || role.roleName == 'Unknown') {
            continue;
          }
          if (!seen.add(role.roleId)) continue;
          cleaned.add(role);
        }

        setState(() {
          roles = cleaned;
          // Roles are scoped to the location, so changing location can drop the
          // one that is selected. A dropdown whose value is not among its items
          // throws, so fall back to "All" when that happens.
          final bool stillThere = selectedRole == '0' ||
              roles.any((r) => r.roleId.toString() == selectedRole);
          if (!stillThere) selectedRole = '0';
        });
      } else {
        debugPrint(
            'Roles failed: HTTP ${response.statusCode} ${response.body}');
      }
    } catch (error) {
      debugPrint('Roles error: $error');
    }
  }

  Future<void> fetchAttendanceDashboard() async {
    if (organizationId == null || userId == null) return;

    // Reset attendance details before fetching new dashboard data
    setState(() {
      attendaceReportDetails = [];
    });

    // Started outside the setState callback above: both of these call setState
    // themselves, and the site-wise one does so synchronously before its first
    // await, which would be a setState raised from inside another setState.
    //
    // Every filter change routes through this method — date range, the shift
    // buttons, the shift dialog and the location dropdown — so refreshing the
    // two breakdowns here keeps all three views on the same filters.
    fetchRoleReport();
    fetchLocationWiseReport();

    try {
      String shiftIds = selectedShiftIds.join(',');
      var response = await ApiService.fetchAttendanceReport(
        userId!,
        organizationId!,
        selectedLocation,
        // selectedShift,
        shiftIds,
        selectedRole,
        selectedDateRange,
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          List<dynamic> jsonData = jsonDecode(response.body);
          print('Decoded JSON data: $jsonData'); // Logs decoded data structure

          // Convert JSON data to attendance records
          setState(() {
            attendanceRecords =
                jsonData.map((json) => Attendance.fromJson(json)).toList();
          });

          // Reset notification flag after success
          isNotificationSent = false; // Reset notification flag after success
        } catch (parsingError) {
          ErrorHandler.handleError(
            context,
            'Error parsing attendance data. Please check the data format.',
            'Parsing error: $parsingError, Response: ${response.body}',
          );

          // Send notification only if connected to Wi-Fi and no notification sent before
          // if (!isNotificationSent) {
          //   var connectivityResult = await Connectivity().checkConnectivity();
          //   if (connectivityResult == ConnectivityResult.wifi) {
          //     await ApiService.sendNotification(
          //       [
          //         userId!
          //       ], // Send the current userId or other relevant userId list
          //       'Attendance Data Error',
          //       'There was an error fetching attendance data: $parsingError',
          //     );
          //     // Set the flag to true to prevent further notifications
          //     isNotificationSent = true;
          //   }
          // }
        }
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to fetch attendance data. Status code: ${response.statusCode}',
          'Response body: ${response.body}',
        );

        // Send notification only if connected to Wi-Fi and no notification sent before
        // if (!isNotificationSent) {
        //   var connectivityResult = await Connectivity().checkConnectivity();
        //   if (connectivityResult == ConnectivityResult.wifi) {
        //     await ApiService.sendNotification(
        //       [
        //         userId!
        //       ], // Send the current userId or other relevant userId list
        //       'Attendance Data Error',
        //       'Failed to fetch attendance data. Status code: ${response.statusCode}',
        //     );
        //     // Set the flag to true to prevent further notifications
        //     isNotificationSent = true;
        //   }
        // }
      }
    } catch (error) {
      ErrorHandler.handleError(
        context,
        'Failed to fetch attendance data. Please try again later.',
        'General error: $error',
      );
      // Send notification only if connected to Wi-Fi and no notification sent before
      // if (!isNotificationSent) {
      //   var connectivityResult = await Connectivity().checkConnectivity();
      //   if (connectivityResult == ConnectivityResult.wifi) {
      //     await ApiService.sendNotification(
      //       [userId!], // Send the current userId or other relevant userId list
      //       'Attendance Data Error',
      //       'Error occurred while fetching attendance data: $error',
      //     );
      //     // Set the flag to true to prevent further notifications
      //     isNotificationSent = true;
      //   }
      // }
    }
  }

  Future<void> refreshData() async {
    _checkSession();
    // _initializeData() calls fetchAttendanceDashboard() itself, so pulling to
    // refresh was running the dashboard — and the two breakdowns under it —
    // twice on every pull.
    await _initializeData();
  }

  Future<void> fetchAttendanceDetails(
      String attendanceStatus, String? userName) async {
    if (userId == null) return;

    try {
      String shiftIds = selectedShiftIds.join(',');
      var response = await ApiService.fetchAttendanceDetails(
        userId!,
        userName ?? '',
        attendanceStatus,
        selectedLocation,
        // selectedShift,
        shiftIds,
        selectedRole,
        selectedDateRange,
        page,
        size,
      );

      if (response.statusCode == 200) {
        try {
          // Attempt to decode the JSON response
          Map<String, dynamic> jsonData = jsonDecode(response.body);
          print('Decoded JSON data: $jsonData'); // Logs decoded data structure

          // Check if "records" key exists and extract data
          if (jsonData.containsKey('records') && jsonData['records'] is List) {
            setState(() {
              // Map the records and filter out nulls, ensuring non-null type
              attendaceReportDetails = (jsonData['records'] as List)
                  .map<AttendanceRecord?>((record) {
                    try {
                      return AttendanceRecord.fromJson(record);
                    } catch (e) {
                      print('Error parsing record: $record\nError: $e');
                      return null; // Return null if parsing fails
                    }
                  })
                  .where((record) => record != null) // Filter out nulls
                  .cast<AttendanceRecord>() // Cast to List<AttendanceRecord>
                  .toList();

              // You can also access pagination data here if needed
              int totalRecords = jsonData['totalRecords'] ?? 0;
              print('Total Records: $totalRecords'); // Use this as needed
            });
          } else {
            ErrorHandler.handleError(
              context,
              'No attendance records found or incorrect data format.',
              'Response body: ${response.body}',
            );
          }
        } catch (parsingError) {
          print('Parsing error: $parsingError');
          ErrorHandler.handleError(
            context,
            'Error parsing attendance details. Please check the data format.',
            'Parsing error: $parsingError, Response: ${response.body}',
          );
        }
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to fetch attendance details. Status code: ${response.statusCode}',
          'Response body: ${response.body}',
        );
      }
    } catch (error) {
      ErrorHandler.handleError(
        context,
        'Failed to fetch attendance details. Please try again later.',
        'General error: $error',
      );
    } finally {}
  }

  Future<void> fetchRoleReport() async {
    if (userId == null) return;

    try {
      String shiftIds = selectedShiftIds.join(',');
      var response = await ApiService.fetchRoleReport(
        userId!,
        organizationId!,
        selectedLocation,
        shiftIds,
        selectedRole,
        selectedDateRange,
      );

      if (response.statusCode == 200) {
        try {
          // Attempt to decode the JSON response
          List<dynamic> jsonData =
              jsonDecode(response.body); // Parse the response body as a List
          print('Decoded JSON data: $jsonData'); // Logs decoded data structure

          setState(() {
            // Map the JSON response to a list of RoleReport objects
            List<RoleReport> roleReports = jsonData
                .map<RoleReport?>((record) {
                  try {
                    return RoleReport.fromJson(record);
                  } catch (e) {
                    print('Error parsing record: $record\nError: $e');
                    return null; // Return null if parsing fails
                  }
                })
                .where((record) => record != null) // Filter out nulls
                .cast<RoleReport>() // Cast to List<RoleReport>
                .toList();

            // Store the fetched role reports
            roleReportDetails = roleReports;
          });
        } catch (parsingError) {
          print('Parsing error: $parsingError');
          ErrorHandler.handleError(
            context,
            'Error parsing role reports. Please check the data format.',
            'Parsing error: $parsingError, Response: ${response.body}',
          );
        }
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to fetch role reports. Status code: ${response.statusCode}',
          'Response body: ${response.body}',
        );
      }
    } catch (error) {
      ErrorHandler.handleError(
        context,
        'Failed to fetch role reports. Please try again later.',
        'General error: $error',
      );
    } finally {}
  }

  /// Site-wise counts behind the "Site Report" view.
  ///
  /// Deliberately never raises a dialog: it loads alongside the dashboard, and
  /// a failure here should not interrupt someone reading the attendance list.
  /// The empty state on screen says there is nothing to show.
  Future<void> fetchLocationWiseReport() async {
    if (userId == null || organizationId == null) return;

    setState(() => isLocationWiseLoading = true);

    try {
      final String shiftIds = selectedShiftIds.join(',');
      final response = await ApiService.fetchLocationWiseReport(
        userId!,
        organizationId!,
        selectedLocation,
        shiftIds,
        selectedRole,
        selectedDateRange,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> rows = decoded is List ? decoded : const [];
        if (!mounted) return;
        setState(() {
          locationWiseDetails = rows
              .whereType<Map<String, dynamic>>()
              .map(LocationWiseReport.fromJson)
              .toList();
        });
      } else {
        debugPrint('Site-wise report failed: HTTP ${response.statusCode} '
            '${response.body}');
        if (!mounted) return;
        setState(() => locationWiseDetails = []);
      }
    } catch (error) {
      debugPrint('Site-wise report error: $error');
      if (!mounted) return;
      setState(() => locationWiseDetails = []);
    } finally {
      if (mounted) setState(() => isLocationWiseLoading = false);
    }
  }

  void _onDateRangeSelected(
      DateTime startDate, DateTime endDate, String range) {
    setState(() {
      selectedDateRange = range;
      // isLoading = true;
    });

    fetchAttendanceDashboard().catchError((error) {
      ErrorHandler.handleError(
        context,
        'Failed to fetch attendance data.',
        'Error fetching data: $error',
      );
    }).whenComplete(() {
      setState(() => isLoading = false);
    });
  }

  // app update check

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
      setState(() {});
    }
  }

  /// Roles that are safe to put in the dropdown: never id 0 — that value is
  /// taken by "All" — and never a repeated id.
  ///
  /// Filtered here as well as in [fetchRoles] because the assertion this
  /// prevents is raised during build and brings the whole screen down. Any
  /// state that survives without re-fetching, a hot reload being the obvious
  /// one, would otherwise still hold the unfiltered list.
  List<Role> get _selectableRoles {
    final seen = <int>{};
    return roles
        .where((r) => r.roleId != 0 && r.roleName.trim().isNotEmpty)
        .where((r) => seen.add(r.roleId))
        .toList();
  }

  /// Count for a status, or 0 when the dashboard has not returned that bucket.
  int _countFor(String status) {
    for (final r in attendanceRecords) {
      if (r.attendanceStatus == status) return r.count;
    }
    return 0;
  }

  /// A headline count. Tapping loads that status into the attendance list, so
  /// the selected one is outlined to show where the list below came from.
  Widget _kpiCard({
    required String label,
    required int count,
    required IconData icon,
    required MaterialColor tone,
    required VoidCallback onTap,
  }) {
    final bool selected = activeView == 'attendance' && selectedStatus == label;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: tone.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? tone.shade400 : tone.shade100,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: tone.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: tone.shade700,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The "ROLE WISE ATTENDANCE" table from the web dashboard.
  ///
  /// Shares [_breakdownRow] with the site view so both read as the same table —
  /// Role, Logged In, Not Logged In, Total — rather than one being cards and
  /// the other columns.
  Widget _roleBreakdownList() {
    if (roleReportDetails.isEmpty) {
      return _emptyBreakdown();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _breakdownHeader('Role'),
        // Total sits above the rows and outside the scrollable, not under them
        // as the web table has it: on a phone the bottom of a fifteen-row list
        // is a scroll away, and the total is the number most people open this
        // for. Here it is on screen from the start and stays put.
        _breakdownRow(
          name: 'Total',
          loggedIn: roleLoggedInTotal,
          notLoggedIn: roleNotLoggedInTotal,
          total: roleTotal,
          isTotalRow: true,
        ),
        Expanded(
          child: ListView.builder(
            itemCount: roleReportDetails.length + 1,
            itemBuilder: (context, index) {
              if (index == roleReportDetails.length) {
                return const SizedBox(height: 80);
              }
              final r = roleReportDetails[index];
              return _breakdownRow(
                name: r.roleName,
                loggedIn: r.loggedInCount,
                notLoggedIn: r.notLoggedInCount,
                total: r.totalAttendance,
              );
            },
          ),
        ),
      ],
    );
  }

  /// Shared empty state for both breakdowns, wording taken from the web table.
  Widget _emptyBreakdown() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No attendance found for the selected filters.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ),
    );
  }

  /// The "SITE WISE ATTENDANCE" table from the web dashboard, as a list.
  ///
  /// Rows are not tappable: the web drills into a per-site list, which the
  /// mobile allAttendance endpoint cannot filter by location id on its own.
  Widget _siteBreakdownList() {
    if (isLocationWiseLoading && locationWiseDetails.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (locationWiseDetails.isEmpty) {
      return _emptyBreakdown();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _breakdownHeader('Site'),
        // Pinned above the rows for the same reason as the role table.
        _breakdownRow(
          name: 'Total',
          loggedIn: siteLoggedInTotal,
          notLoggedIn: siteNotLoggedInTotal,
          total: siteTotal,
          isTotalRow: true,
        ),
        Expanded(
          child: ListView.builder(
            // +1: trailing space so the last site clears the bottom.
            itemCount: locationWiseDetails.length + 1,
            itemBuilder: (context, index) {
              if (index == locationWiseDetails.length) {
                return const SizedBox(height: 80);
              }
              final row = locationWiseDetails[index];
              return _breakdownRow(
                name: row.location,
                loggedIn: row.loggedInCount,
                notLoggedIn: row.notLoggedInCount,
                total: row.totalCount,
              );
            },
          ),
        ),
      ],
    );
  }

  /// One of the three view switchers. The active one stays filled so it is
  /// clear which list is below — with three buttons and no tabs, identical
  /// buttons would leave the current view ambiguous.
  Widget _viewButton({
    required String label,
    required String view,
    required Color tone,
    required VoidCallback onSelect,
  }) {
    final bool active = activeView == view;
    return ElevatedButton(
      onPressed: () {
        setState(() => activeView = view);
        onSelect();
      },
      style: ElevatedButton.styleFrom(
        foregroundColor: active ? Colors.white : tone,
        backgroundColor: active ? tone : Colors.white,
        elevation: active ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: tone, width: active ? 0 : 1.2),
        ),
        minimumSize: const Size(0, 36),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.w600),
      ),
    );
  }

  /// A row of the site / role breakdown, laid out as columns so the numbers
  /// line up down the list the way the web table does.
  Widget _breakdownRow({
    required String name,
    required int loggedIn,
    required int notLoggedIn,
    required int total,
    bool isTotalRow = false,
  }) {
    final TextStyle nameStyle = TextStyle(
      fontSize: isTotalRow ? 14 : 13.5,
      fontWeight: isTotalRow ? FontWeight.bold : FontWeight.w600,
      color: isTotalRow ? Colors.black87 : Colors.blueGrey.shade800,
    );
    Widget cell(int v, Color c) => Expanded(
          flex: 2,
          child: Text(
            '$v',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isTotalRow ? 14 : 13.5,
              fontWeight: isTotalRow ? FontWeight.bold : FontWeight.w600,
              color: c,
            ),
          ),
        );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: isTotalRow ? AppColors.primary.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTotalRow
              ? AppColors.primary.withOpacity(0.35)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(name,
                style: nameStyle, overflow: TextOverflow.ellipsis, maxLines: 2),
          ),
          cell(loggedIn, Colors.green.shade700),
          cell(notLoggedIn, Colors.red.shade700),
          cell(total, Colors.blueGrey.shade700),
        ],
      ),
    );
  }

  /// Column captions for the breakdown lists — the equivalent of the web
  /// table's <thead>, which a plain list would otherwise leave unlabelled.
  Widget _breakdownHeader(String first) {
    Widget head(String t) => Expanded(
          flex: 2,
          child: Text(t,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(first,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54)),
          ),
          head('Logged In'),
          head('Not Logged'),
          head('Total'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        // Brand hero gradient — matches CustomAppBar and the home header.
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.heroGradient,
              stops: AppColors.heroStops,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Report',
              style: TextStyle(
                fontSize: screenWidth > 600 ? 22 : 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: refreshData,
        child: Stack(
          children: [
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 30, 10, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ExpansionTile(
                          title: const Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              // Icon(
                              //   Icons.filter_alt, // Use any filter icon you prefer
                              //   size: 20,
                              //   color: Colors.grey, // Adjust color to your preference
                              // ),
                              Text(
                                "Filters",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          //leading: Icon(Icons.info), // Custom leading icon
                          trailing: const Icon(
                            Icons.filter_alt,
                            color: Colors.grey,
                          ),
                          children: [
                            const SizedBox(height: 10),
                            CustomDateRangePicker(
                              onDateRangeSelected: _onDateRangeSelected,
                              selectedDateRange: selectedDateRange,
                            ),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Location Dropdown
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal:
                                            12.0), // Adjust the horizontal padding as needed
                                    child: DropdownButtonFormField2<String>(
                                      decoration: InputDecoration(
                                        labelText: 'Location',
                                        labelStyle: TextStyle(
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.location_on,
                                          color: AppColors.primary,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          vertical: 12.0,
                                          horizontal: 12.0,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color:
                                                Color.fromRGBO(8, 101, 145, 1),
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: AppColors.primary,
                                            width: 2.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                        ),
                                      ),
                                      alignment:
                                          AlignmentDirectional.bottomStart,
                                      value: selectedLocation != '0'
                                          ? selectedLocation
                                          : '0',
                                      items: [
                                        DropdownMenuItem<String>(
                                          value: '0',
                                          child: Text('All',
                                              style: TextStyle(
                                                  color: Colors.black87)),
                                        ),
                                        ...locations.map((location) {
                                          return DropdownMenuItem<String>(
                                            value: location.id.toString(),
                                            child: Text(
                                              location.location,
                                              style: TextStyle(
                                                  color: Colors.black87),
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          selectedLocation = value!;
                                        });
                                        // Refreshes all three views — the role
                                        // and site breakdowns are started
                                        // inside, so calling either again here
                                        // would only duplicate the request.
                                        fetchAttendanceDashboard();
                                        fetchAttendanceDetails(
                                            selectedStatus, '');
                                        // The role list is scoped to location.
                                        fetchRoles();
                                      },
                                      isExpanded: true,
                                      dropdownStyleData: DropdownStyleData(
                                        maxHeight: 250,
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.9,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          color: Colors.white,
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 8,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Role filter, matching the web dashboard's
                            // Role dropdown. Only the location and role
                            // filters narrow the two breakdowns, so both live
                            // here together.
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12.0),
                              child: DropdownButtonFormField2<String>(
                                decoration: InputDecoration(
                                  labelText: 'Role',
                                  labelStyle: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.badge_outlined,
                                    color: AppColors.primary,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12.0,
                                    horizontal: 12.0,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Color.fromRGBO(8, 101, 145, 1),
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 2.0,
                                    ),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                ),
                                alignment: AlignmentDirectional.bottomStart,
                                isExpanded: true,
                                // Never hand the dropdown a value it has no
                                // item for: that assertion is raised during
                                // build, so it takes the whole screen with it
                                // rather than just the dropdown.
                                value: _selectableRoles.any((r) =>
                                        r.roleId.toString() == selectedRole)
                                    ? selectedRole
                                    : '0',
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: '0',
                                    child: Text('All',
                                        style:
                                            TextStyle(color: Colors.black87)),
                                  ),
                                  ..._selectableRoles
                                      .map((role) => DropdownMenuItem<String>(
                                            value: role.roleId.toString(),
                                            child: Text(
                                              role.roleName,
                                              style: const TextStyle(
                                                  color: Colors.black87),
                                            ),
                                          )),
                                ],
                                onChanged: (value) {
                                  setState(() => selectedRole = value ?? '0');
                                  fetchAttendanceDashboard();
                                  fetchAttendanceDetails(selectedStatus, '');
                                },
                                dropdownStyleData: DropdownStyleData(
                                  maxHeight: 250,
                                  width:
                                      MediaQuery.of(context).size.width * 0.9,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12.0),
                                    color: Colors.white,
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.teal.shade100),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12.withOpacity(0.05),
                                    spreadRadius: 2,
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Buttons to select all "Morning" or "Night" shifts based on partial key match
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            minimumSize: const Size(0, 40),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              // Select all shifts that contain "Night" in their commonRefKey
                                              selectedShifts = shifts
                                                  .where((shift) => shift
                                                      .commonRefKey
                                                      .contains('All'))
                                                  .toList();
                                              selectedShiftIds = selectedShifts
                                                  .map((shift) => shift.id)
                                                  .toList();
                                            });
                                            fetchAttendanceDashboard();
                                          },
                                          child: Text(
                                            "All Shifts",
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            minimumSize: const Size(0, 40),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              // Select all shifts that contain "Morning" in their commonRefKey
                                              selectedShifts = shifts
                                                  .where((shift) => shift
                                                      .commonRefKey
                                                      .contains('Morning'))
                                                  .toList();
                                              selectedShiftIds = selectedShifts
                                                  .map((shift) => shift.id)
                                                  .toList();
                                            });
                                            fetchAttendanceDashboard();
                                          },
                                          child: Text(
                                            "Morning Shifts",
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            minimumSize: const Size(0, 40),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              // Select all shifts that contain "Night" in their commonRefKey
                                              selectedShifts = shifts
                                                  .where((shift) => shift
                                                      .commonRefKey
                                                      .contains('Night'))
                                                  .toList();
                                              selectedShiftIds = selectedShifts
                                                  .map((shift) => shift.id)
                                                  .toList();
                                            });
                                            fetchAttendanceDashboard();
                                          },
                                          child: const Text(
                                            "Night Shifts",
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  MultiSelectDialogField<ShiftTiming>(
                                    items: shifts
                                        .map((shift) =>
                                            MultiSelectItem<ShiftTiming>(
                                              shift,
                                              '${shift.commonRefKey} - ${shift.commonRefValue}',
                                            ))
                                        .toList(),
                                    initialValue: selectedShifts,
                                    title: const Text(
                                      "Select Shifts",
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    selectedColor: AppColors.primary,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                      border:
                                          Border.all(color: AppColors.primary),
                                    ),
                                    buttonIcon: const Icon(
                                      Icons.access_time,
                                      color: AppColors.primary,
                                    ),
                                    buttonText: Text(
                                      "Select Shifts",
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    dialogWidth:
                                        MediaQuery.of(context).size.width *
                                            0.75,
                                    itemsTextStyle:
                                        const TextStyle(fontSize: 12),
                                    checkColor: AppColors.primary,
                                    dialogHeight:
                                        MediaQuery.of(context).size.height *
                                            0.5,
                                    onConfirm: (values) {
                                      setState(() {
                                        selectedShifts = values;
                                        selectedShiftIds = values
                                            .map((shift) => shift.id)
                                            .toList();
                                      });
                                      fetchAttendanceDashboard();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Two headline counts, as the web dashboard has them.
                      // The old third card, "Client Meeting", was removed: this
                      // screen's endpoint pins attendance_status to exactly
                      // "Logged In" or "Not Logged In", so that card could only
                      // ever read 0 and its tap only ever opened an empty list.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _kpiCard(
                                label: 'Logged In',
                                count: _countFor('Logged In'),
                                icon: Icons.login,
                                tone: Colors.green,
                                onTap: () {
                                  setState(() {
                                    activeView = 'attendance';
                                    selectedStatus = 'Logged In';
                                  });
                                  fetchAttendanceDetails(selectedStatus, '');
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _kpiCard(
                                label: 'Not Logged In',
                                count: _countFor('Not Logged In'),
                                icon: Icons.block,
                                tone: Colors.red,
                                onTap: () {
                                  setState(() {
                                    activeView = 'attendance';
                                    selectedStatus = 'Not Logged In';
                                  });
                                  fetchAttendanceDetails(selectedStatus, '');
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),
                      Column(
                        children: [
                          // First Row - Buttons
                          // ...existing code...
                          // Two rows: the first switches which breakdown is
                          // on screen, the second runs an action. Five buttons
                          // on one row left no room for their labels.
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 6.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _viewButton(
                                    label: 'Attendance',
                                    view: 'attendance',
                                    tone: Colors.blue,
                                    onSelect: () =>
                                        fetchAttendanceDetails('', ''),
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: _viewButton(
                                    label: 'Site Report',
                                    view: 'site',
                                    tone: AppColors.primary,
                                    onSelect: fetchLocationWiseReport,
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: _viewButton(
                                    label: 'Role Report',
                                    view: 'role',
                                    tone: Colors.green,
                                    onSelect: fetchRoleReport,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 2.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              GenerateReportScreen(
                                            locations: locations,
                                            selectedStatus: selectedStatus,
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                      backgroundColor: Colors.orange,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      minimumSize: const Size(0, 36),
                                    ),
                                    child: const Text('Generate Report',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                AbsentListScreen()),
                                        (route) => false,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                      backgroundColor: Colors.deepPurple,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      minimumSize: const Size(0, 36),
                                    ),
                                    child: const Text('Mark Absent',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ],
                            ),
                          ),
// ...existing code...

                          // Second Row - Search Input
                          if (showAttendanceList)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText: 'Search by name...',
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade400),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                              color: Colors.blue, width: 2),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          searchQuery = value;
                                        });
                                        if (searchQuery.length >= 3 ||
                                            searchQuery.isEmpty) {
                                          fetchAttendanceDetails(
                                              selectedStatus, searchQuery);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(
                          height:
                              16.0), // Space between the search row and the list
                      // Flexible ListView to adapt to available space

                      // Section title, so the list below is labelled the way the
                      // web's SITE WISE / ROLE WISE tables are — three views
                      // sharing one area is otherwise ambiguous.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                        child: Text(
                          activeView == 'site'
                              ? 'SITE WISE ATTENDANCE'
                              : activeView == 'role'
                                  ? 'ROLE WISE ATTENDANCE'
                                  : selectedStatus.isEmpty
                                      ? 'ATTENDANCE LIST'
                                      : 'ATTENDANCE LIST · '
                                          '${selectedStatus.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          height: screenHeight - 400, // Adjust height as needed
                          child: activeView == 'site'
                              ? _siteBreakdownList()
                              : showAttendanceList
                                  ? ListView.builder(
                                      controller: _scrollController,
                                      itemCount: attendaceReportDetails.length +
                                          1, // Increase count for padding
                                      itemBuilder: (context, index) {
                                        if (index ==
                                            attendaceReportDetails.length) {
                                          // Add extra space at the end of the list
                                          return const SizedBox(
                                              height:
                                                  80); // Adjust height as needed
                                        }

                                        final record =
                                            attendaceReportDetails[index];
                                        return Card(
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 4.0, horizontal: 10.0),
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8.0,
                                                horizontal: 10.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // User and Status Row
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        record.userName,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.black87,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      record.attendanceStatus,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            record.attendanceStatus ==
                                                                    "Logged In"
                                                                ? Colors.green
                                                                : const Color
                                                                    .fromARGB(
                                                                    255,
                                                                    241,
                                                                    58,
                                                                    58),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                // In and Out Times Row
                                                Row(
                                                  children: [
                                                    Icon(Icons.login,
                                                        color:
                                                            Colors.blueAccent,
                                                        size: 14),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        'In: ${record.attendanceInTime} - ${record.logInLocationName}',
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.black54),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.logout,
                                                        color: Colors.redAccent,
                                                        size: 14),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        'Out: ${record.attendanceOutTime} - ${record.logOutLocationName}',
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.black54),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                // In and Out Dates Row
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'In Date: ${record.attendanceInDate != null ? DateFormat('yyyy-MM-dd').format(record.attendanceInDate!) : "--"}',
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.black54),
                                                    ),
                                                    Text(
                                                      'Out Date: ${record.attendanceOutDate != null ? DateFormat('yyyy-MM-dd').format(record.attendanceOutDate!) : "--"}',
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.black54),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                // Add shift time display
                                                Text(
                                                  'Shift Time: ${record.commonRefValue}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color.fromARGB(
                                                        136, 2, 2, 2),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : _roleBreakdownList(),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
