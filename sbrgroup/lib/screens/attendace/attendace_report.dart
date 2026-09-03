import 'dart:async';
import 'dart:convert';

import 'package:ajna/main.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/attendace/absent_list_screen.dart';
import 'package:ajna/screens/attendace/generate_report_screen.dart';
import 'package:ajna/screens/connectivity_handler.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/util.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';

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
    _searchDebounce?.cancel();
    _searchController.dispose();
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

  /// Guards the paging fetch below. The listener fires on every scroll
  /// notification, so sitting at the bottom of the page used to queue one
  /// request after another.
  bool _isLoadingMore = false;

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (_isLoadingMore) return;
      _isLoadingMore = true;
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

      fetchAttendanceDetails(statusToFetch, '')
          .whenComplete(() => _isLoadingMore = false);
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

  int get _loggedInCount => _countFor('Logged In');
  int get _notLoggedInCount => _countFor('Not Logged In');
  int get _headcount => _loggedInCount + _notLoggedInCount;

  /// Share of the headcount that has logged in, 0–1.
  double get _presenceRate => _headcount == 0 ? 0 : _loggedInCount / _headcount;

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------
  /// Held so the field can be cleared from its own suffix button.
  final TextEditingController _searchController = TextEditingController();

  /// Typing used to fire a request on every keystroke past the third. The
  /// timer collapses a burst of typing into one call.
  Timer? _searchDebounce;

  void _onSearchChanged(String value) {
    setState(() => searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (searchQuery.length >= 3 || searchQuery.isEmpty) {
        fetchAttendanceDetails(selectedStatus, searchQuery);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Filter summary — what the collapsed "Filters" card reports, so the numbers
  // below it are never read against filters the user cannot see.
  // ---------------------------------------------------------------------------
  String get _dateRangeLabel {
    final String r = selectedDateRange;
    if (r.startsWith('&startDate=')) {
      try {
        final parts = r.split('&');
        final start = DateTime.parse(parts[1].split('=')[1]);
        final end = DateTime.parse(parts[2].split('=')[1]);
        final f = DateFormat('d MMM');
        return '${f.format(start)} – ${f.format(end)}';
      } catch (_) {
        return 'Custom range';
      }
    }
    switch (r) {
      case '0':
        return 'Today';
      case '1':
        return 'Yesterday';
      case '7':
        return 'Last 7 days';
      case '15':
        return 'Last 15 days';
      case '13':
        return 'This month';
      case '30':
        return 'Last month';
      case '130':
        return 'Last 30 days';
      case '90':
        return 'Last 90 days';
      default:
        return 'Today';
    }
  }

  String get _locationLabel {
    if (selectedLocation == '0') return 'All sites';
    for (final l in locations) {
      if (l.id.toString() == selectedLocation) return l.location;
    }
    return 'All sites';
  }

  String get _roleLabel {
    if (selectedRole == '0') return 'All roles';
    for (final r in _selectableRoles) {
      if (r.roleId.toString() == selectedRole) return r.roleName;
    }
    return 'All roles';
  }

  String get _shiftLabel {
    if (selectedShifts.isEmpty || selectedShiftIds.contains(0)) {
      return 'All shifts';
    }
    if (selectedShifts.length == 1) return selectedShifts.first.commonRefKey;
    return '${selectedShifts.length} shifts';
  }

  // ---------------------------------------------------------------------------
  // Filter bar
  // ---------------------------------------------------------------------------
  /// A filter drawn as a chip that IS the control: the label says what is
  /// applied and tapping opens a sheet for that one filter.
  ///
  /// It replaces the "Filters" card, which stacked three dropdowns and a shift
  /// panel behind a chevron and — even collapsed — pushed the counts most of a
  /// screen down the page.
  Widget _filterPill({
    required IconData icon,
    required String label,
    required bool isDefault,
    required VoidCallback onTap,
  }) {
    // A filter that is doing something reads as filled; an untouched one stays
    // quiet, so "what am I actually looking at" is answerable at a glance.
    final Color fg = isDefault ? AppColors.textSecondary : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isDefault
            ? AppColors.surface
            : AppColors.tint(AppColors.primary, 0.10),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(11, 8, 8, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDefault
                    ? AppColors.divider
                    : AppColors.tint(AppColors.primary, 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isDefault ? FontWeight.w500 : FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
                Icon(Icons.expand_more_rounded, size: 16, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterBar() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterPill(
            icon: Icons.event_outlined,
            label: _dateRangeLabel,
            isDefault: selectedDateRange == '0',
            onTap: _openDateSheet,
          ),
          _filterPill(
            icon: Icons.location_on_outlined,
            label: _locationLabel,
            isDefault: selectedLocation == '0',
            onTap: _openLocationSheet,
          ),
          _filterPill(
            icon: Icons.badge_outlined,
            label: _roleLabel,
            isDefault: selectedRole == '0',
            onTap: _openRoleSheet,
          ),
          _filterPill(
            icon: Icons.access_time,
            label: _shiftLabel,
            isDefault: selectedShifts.isEmpty || selectedShiftIds.contains(0),
            onTap: _openShiftSheet,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter sheets
  // ---------------------------------------------------------------------------
  /// Shared chrome for the four filter sheets.
  Future<void> _showFilterSheet({
    required String title,
    required Widget Function(BuildContext sheetContext) builder,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                Flexible(child: builder(sheetContext)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// One selectable line in a single-choice sheet.
  Widget _sheetOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded,
                  size: 19, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  /// The preset ranges, in the order the web dashboard lists them. Codes are
  /// the values the API already expects.
  static const List<List<String>> _datePresets = [
    ['0', 'Today'],
    ['1', 'Yesterday'],
    ['7', 'Last 7 Days'],
    ['15', 'Last 15 Days'],
    ['13', 'This Month'],
    ['30', 'Last Month'],
    ['130', 'Last 30 Days'],
    ['90', 'Last 90 Days'],
  ];

  /// Start and end for a preset code — the same arithmetic
  /// CustomDateRangePicker does, so the request is unchanged.
  List<DateTime> _presetRange(String code) {
    final DateTime now = DateTime.now();
    switch (code) {
      case '1':
        final d = now.subtract(const Duration(days: 1));
        return [d, d];
      case '7':
        return [now.subtract(const Duration(days: 7)), now];
      case '15':
        return [now.subtract(const Duration(days: 15)), now];
      case '13':
        return [DateTime(now.year, now.month, 1), now];
      case '30':
        return [
          DateTime(now.year, now.month - 1, 1),
          DateTime(now.year, now.month, 0),
        ];
      case '130':
        return [now.subtract(const Duration(days: 30)), now];
      case '90':
        return [now.subtract(const Duration(days: 90)), now];
      default:
        return [now, now];
    }
  }

  /// Date range. The presets are rows in the sheet itself: putting the old
  /// dropdown in here meant a menu opening on top of a sheet — two stacked
  /// overlays for one choice.
  void _openDateSheet() {
    _showFilterSheet(
      title: 'Date range',
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          ..._datePresets.map(
            (preset) => _sheetOption(
              label: preset[1],
              selected: selectedDateRange == preset[0],
              onTap: () {
                Navigator.pop(sheetContext);
                final range = _presetRange(preset[0]);
                _onDateRangeSelected(range[0], range[1], preset[0]);
              },
            ),
          ),
          Divider(height: 1, color: AppColors.divider),
          _sheetOption(
            label: selectedDateRange.startsWith('&startDate=')
                ? _dateRangeLabel
                : 'Custom range…',
            selected: selectedDateRange.startsWith('&startDate='),
            onTap: () {
              Navigator.pop(sheetContext);
              _pickCustomRange();
            },
          ),
        ],
      ),
    );
  }

  /// Two-date picker for a custom span. The string handed back is byte for
  /// byte what the old dialog produced.
  Future<void> _pickCustomRange() async {
    final DateTime now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Select date range',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    _onDateRangeSelected(
      picked.start,
      picked.end,
      '&startDate=${DateFormat('yyyy-MM-ddT00:00:00').format(picked.start)}'
      '&endDate=${DateFormat('yyyy-MM-ddT23:59:59').format(picked.end)}',
    );
  }

  void _openLocationSheet() {
    String query = '';
    _showFilterSheet(
      title: 'Location',
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final List<Location> shown = query.isEmpty
              ? locations
              : locations
                  .where((l) =>
                      l.location.toLowerCase().contains(query.toLowerCase()))
                  .toList();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (locations.length > 6)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: TextField(
                    autofocus: false,
                    onChanged: (v) => setSheetState(() => query = v),
                    style: TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search site',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.divider),
                      ),
                    ),
                  ),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _sheetOption(
                      label: 'All sites',
                      selected: selectedLocation == '0',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _applyLocation('0');
                      },
                    ),
                    ...shown.map(
                      (l) => _sheetOption(
                        label: l.location,
                        selected: selectedLocation == l.id.toString(),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _applyLocation(l.id.toString());
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Same three refreshes the location dropdown ran.
  void _applyLocation(String value) {
    setState(() => selectedLocation = value);
    // Refreshes all three views — the role and site breakdowns are started
    // inside, so calling either again here would only duplicate the request.
    fetchAttendanceDashboard();
    fetchAttendanceDetails(selectedStatus, '');
    // The role list is scoped to location.
    fetchRoles();
  }

  void _openRoleSheet() {
    _showFilterSheet(
      title: 'Role',
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          _sheetOption(
            label: 'All roles',
            selected: selectedRole == '0',
            onTap: () {
              Navigator.pop(sheetContext);
              _applyRole('0');
            },
          ),
          ..._selectableRoles.map(
            (r) => _sheetOption(
              label: r.roleName,
              selected: selectedRole == r.roleId.toString(),
              onTap: () {
                Navigator.pop(sheetContext);
                _applyRole(r.roleId.toString());
              },
            ),
          ),
        ],
      ),
    );
  }

  void _applyRole(String value) {
    setState(() => selectedRole = value);
    fetchAttendanceDashboard();
    fetchAttendanceDetails(selectedStatus, '');
  }

  /// Shifts are multi-select, so the sheet edits a local copy and applies once
  /// — toggling used to fire a dashboard request per tick.
  void _openShiftSheet() {
    List<ShiftTiming> draft = List<ShiftTiming>.from(selectedShifts);
    // The synthetic "All Shifts" row fetchShiftData() inserts at id 0.
    final Iterable<ShiftTiming> allRows = shifts.where((s) => s.id == 0);
    final ShiftTiming? allShift = allRows.isEmpty ? null : allRows.first;

    _showFilterSheet(
      title: 'Shifts',
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bool allSelected =
              draft.isEmpty || draft.any((s) => s.id == 0);

          void selectGroup(String match) {
            setSheetState(() {
              draft =
                  shifts.where((s) => s.commonRefKey.contains(match)).toList();
            });
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The old Morning / Night quick buttons, kept.
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => selectGroup('Morning'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.divider),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Morning',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => selectGroup('Night'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.divider),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Night',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _sheetOption(
                      label: 'All shifts',
                      selected: allSelected,
                      onTap: () => setSheetState(() {
                        draft = allShift == null ? [] : [allShift];
                      }),
                    ),
                    ...shifts.where((s) => s.id != 0).map(
                          (shift) => CheckboxListTile(
                            dense: true,
                            controlAffinity: ListTileControlAffinity.trailing,
                            activeColor: AppColors.primary,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 18),
                            title: Text(
                              '${shift.commonRefKey} · ${shift.commonRefValue}',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textPrimary),
                            ),
                            value: draft.any((s) => s.id == shift.id),
                            onChanged: (checked) => setSheetState(() {
                              draft.removeWhere((s) => s.id == 0);
                              if (checked == true) {
                                if (!draft.any((s) => s.id == shift.id)) {
                                  draft.add(shift);
                                }
                              } else {
                                draft.removeWhere((s) => s.id == shift.id);
                              }
                            }),
                          ),
                        ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      setState(() {
                        // Nothing ticked means "everything", the same value the
                        // screen starts on.
                        selectedShifts = draft.isEmpty
                            ? (allShift == null ? [] : [allShift])
                            : draft;
                        selectedShiftIds =
                            selectedShifts.map((s) => s.id).toList();
                      });
                      fetchAttendanceDashboard();
                    },
                    child: const Text('Apply',
                        style: TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Headline numbers
  // ---------------------------------------------------------------------------
  /// Counts and presence in one card. They were three separate cards stacked
  /// down the page, which is a lot of height for four numbers.
  Widget _summaryCard() {
    final int total = _headcount;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 10),
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
      child: Column(
        children: [
          Row(
            children: [
              _statHalf(
                label: 'Logged In',
                count: _loggedInCount,
                tone: AppColors.success,
                status: 'Logged In',
              ),
              Container(
                width: 1,
                height: 34,
                color: AppColors.divider,
              ),
              _statHalf(
                label: 'Not Logged In',
                count: _notLoggedInCount,
                tone: AppColors.danger,
                status: 'Not Logged In',
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : _presenceRate,
              minHeight: 8,
              backgroundColor: total == 0
                  ? AppColors.surfaceAlt
                  : AppColors.tint(AppColors.danger, 0.14),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              total == 0 ? 'No headcount yet' : '$total total',
              style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
            ),
          ),
        ],
      ),
    );
  }

  /// Half of the summary card's footer. Tapping still loads that status into
  /// the list below, and the loaded one is tinted so the list has a source.
  Widget _statHalf({
    required String label,
    required int count,
    required Color tone,
    required String status,
  }) {
    final bool selected =
        activeView == 'attendance' && selectedStatus == status;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            activeView = 'attendance';
            selectedStatus = status;
          });
          fetchAttendanceDetails(selectedStatus, '');
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.tint(tone, 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: tone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The "ROLE WISE ATTENDANCE" table from the web dashboard.
  ///
  /// Shares [_breakdownRow] with the site view so both read as the same table —
  /// Role, Logged In, Not Logged In, Total — rather than one being cards and
  /// the other columns.
  ///
  /// Not scrollable itself: the whole page is one scroll view, so a nested
  /// list here would trap the drag and needed a hard-coded height to exist.
  Widget _roleBreakdownList() {
    if (roleReportDetails.isEmpty) {
      return _emptyBreakdown();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _breakdownHeader('Role'),
        // Total sits above the rows, not under them as the web table has it:
        // on a phone the bottom of a fifteen-row list is a scroll away, and the
        // total is the number most people open this for.
        _breakdownRow(
          name: 'Total',
          loggedIn: roleLoggedInTotal,
          notLoggedIn: roleNotLoggedInTotal,
          total: roleTotal,
          isTotalRow: true,
        ),
        ...roleReportDetails.map(
          (r) => _breakdownRow(
            name: r.roleName,
            loggedIn: r.loggedInCount,
            notLoggedIn: r.notLoggedInCount,
            total: r.totalAttendance,
          ),
        ),
      ],
    );
  }

  /// Shared empty state for both breakdowns, wording taken from the web table.
  Widget _emptyBreakdown() => _emptyState(
        icon: Icons.insights_outlined,
        title: 'Nothing to show',
        message: 'No attendance found for the selected filters.',
      );

  /// One look for every "there is nothing here" case on this screen.
  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 46, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }

  /// The "SITE WISE ATTENDANCE" table from the web dashboard, as a list.
  ///
  /// Rows are not tappable: the web drills into a per-site list, which the
  /// mobile allAttendance endpoint cannot filter by location id on its own.
  Widget _siteBreakdownList() {
    if (isLocationWiseLoading && locationWiseDetails.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
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
        ...locationWiseDetails.map(
          (row) => _breakdownRow(
            name: row.location,
            loggedIn: row.loggedInCount,
            notLoggedIn: row.notLoggedInCount,
            total: row.totalCount,
          ),
        ),
      ],
    );
  }

  /// One of the three view switchers, drawn as a segmented control: with three
  /// separate buttons it was never obvious which list was on screen.
  Widget _viewSegment({
    required String label,
    required String view,
    required VoidCallback onSelect,
  }) {
    final bool active = activeView == view;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (activeView != view) {
            setState(() => activeView = view);
            onSelect();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
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
      color: AppColors.textPrimary,
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
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: isTotalRow
            ? AppColors.tint(AppColors.primary, 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTotalRow
              ? AppColors.primary.withOpacity(0.35)
              : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(name,
                style: nameStyle, overflow: TextOverflow.ellipsis, maxLines: 2),
          ),
          cell(loggedIn, AppColors.success),
          cell(notLoggedIn, AppColors.danger),
          cell(total, AppColors.textSecondary),
        ],
      ),
    );
  }

  /// Column captions for the breakdown lists — the equivalent of the web
  /// table's <thead>, which a plain list would otherwise leave unlabelled.
  Widget _breakdownHeader(String first) {
    final TextStyle style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.3,
      color: AppColors.textSecondary,
    );
    Widget head(String t) => Expanded(
          flex: 2,
          child: Text(t, textAlign: TextAlign.center, style: style),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(first, style: style)),
          head('Logged In'),
          head('Not Logged'),
          head('Total'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Attendance list
  // ---------------------------------------------------------------------------
  /// Up to two initials for the avatar plate.
  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// Blank-ish values arrive from the API as a single space, not as null.
  String _orDash(String? v) =>
      (v == null || v.trim().isEmpty) ? '—' : v.trim();

  /// One punch: the icon, the time, the date and where it was scanned.
  Widget _punchCell({
    required IconData icon,
    required Color tone,
    required String caption,
    required String? time,
    required DateTime? date,
    required String? location,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: tone),
              const SizedBox(width: 4),
              Text(
                caption,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            _orDash(time),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            date != null ? DateFormat('d MMM yyyy').format(date) : '—',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 11, color: AppColors.textFaint),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  _orDash(location),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.textFaint),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One person's row in the attendance list.
  Widget _attendanceCard(AttendanceRecord record) {
    final bool isIn = record.attendanceStatus == 'Logged In';
    final Color tone = isIn ? AppColors.success : AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tint(tone, 0.14),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _initials(record.userName),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tone,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (record.commonRefValue.trim().isNotEmpty)
                      Text(
                        'Shift · ${record.commonRefValue}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status pill — a coloured word was easy to miss on a dense list.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tint(tone, 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tone.withOpacity(0.35)),
                ),
                child: Text(
                  record.attendanceStatus,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tone,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _punchCell(
                icon: Icons.login_rounded,
                tone: AppColors.success,
                caption: 'IN',
                time: record.attendanceInTime,
                date: record.attendanceInDate,
                location: record.logInLocationName,
              ),
              Container(
                width: 1,
                height: 58,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: AppColors.divider,
              ),
              _punchCell(
                icon: Icons.logout_rounded,
                tone: AppColors.danger,
                caption: 'OUT',
                time: record.attendanceOutTime,
                date: record.attendanceOutDate,
                location: record.logOutLocationName,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Title above whichever list is on screen.
  String get _sectionTitle {
    switch (activeView) {
      case 'site':
        return 'SITE WISE ATTENDANCE';
      case 'role':
        return 'ROLE WISE ATTENDANCE';
      default:
        return selectedStatus.isEmpty
            ? 'ATTENDANCE LIST'
            : 'ATTENDANCE LIST · ${selectedStatus.toUpperCase()}';
    }
  }

  /// Everything above the list: the filter bar, the summary, the view
  /// switcher, the two actions and the search box — deliberately short, so the
  /// first record is on screen without scrolling.
  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterBar(),
        const SizedBox(height: 12),
        _summaryCard(),
        const SizedBox(height: 12),

        // ---- View switcher ---------------------------------------------------
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              _viewSegment(
                label: 'Attendance',
                view: 'attendance',
                onSelect: () => fetchAttendanceDetails('', ''),
              ),
              _viewSegment(
                label: 'Site Report',
                view: 'site',
                onSelect: fetchLocationWiseReport,
              ),
              _viewSegment(
                label: 'Role Report',
                view: 'role',
                onSelect: fetchRoleReport,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ---- Actions ---------------------------------------------------------
        Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: Icons.description_outlined,
                label: 'Generate Report',
                tone: AppColors.primary,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GenerateReportScreen(
                        locations: locations,
                        selectedStatus: selectedStatus,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionButton(
                icon: Icons.person_off_outlined,
                label: 'Mark Absent',
                tone: AppColors.primary,
                filled: false,
                onPressed: () async {
                  // Push (not pushAndRemoveUntil) so this report stays
                  // underneath and the absent screen keeps its back button.
                  final marked = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                        builder: (context) => AbsentListScreen()),
                  );
                  if (marked == true && mounted) {
                    await refreshData();
                  }
                },
              ),
            ),
          ],
        ),

        // ---- Search ----------------------------------------------------------
        if (showAttendanceList) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by name…',
              hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 14),
              prefixIcon:
                  Icon(Icons.search, size: 20, color: AppColors.textSecondary),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close,
                          size: 18, color: AppColors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
              filled: true,
              fillColor: AppColors.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.4),
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ],
        const SizedBox(height: 14),

        // ---- Section title ---------------------------------------------------
        // So the list below is labelled the way the web's SITE WISE / ROLE WISE
        // tables are — three views sharing one area is otherwise ambiguous.
        Row(
          children: [
            Expanded(
              child: Text(
                _sectionTitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (activeView == 'attendance' && attendaceReportDetails.isNotEmpty)
              Text(
                '${attendaceReportDetails.length} shown',
                style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// [filled] false gives the tonal variant — one solid button per row keeps
  /// the primary action obvious instead of two competing fills.
  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color tone,
    required VoidCallback onPressed,
    bool filled = true,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: filled ? AppColors.onPrimary : tone,
        backgroundColor: filled ? tone : AppColors.tint(tone, 0.10),
        elevation: filled ? 1 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: filled
              ? BorderSide.none
              : BorderSide(color: tone.withOpacity(0.35)),
        ),
        minimumSize: const Size(0, 42),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.bg,
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
        title: Text(
          'Attendance Report',
          style: TextStyle(
            fontSize: screenWidth > 600 ? 22 : 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: refreshData,
        color: AppColors.primary,
        // One scroll view for the whole screen. The list used to sit in a box
        // of `screenHeight - 400` inside another scroll view, which left a
        // second scrollbar in the middle of the page and cut the last rows off
        // on short screens.
        child: isLoading
            ? ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)),
                ],
              )
            : CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
                    sliver: SliverToBoxAdapter(child: _buildHeader(context)),
                  ),
                  if (activeView == 'attendance')
                    if (attendaceReportDetails.isEmpty)
                      SliverToBoxAdapter(
                        child: _emptyState(
                          icon: Icons.people_outline,
                          title: 'No attendance records',
                          message: searchQuery.isNotEmpty
                              ? 'No one matches “$searchQuery”.'
                              : 'Nothing was recorded for the selected '
                                  'filters.',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _attendanceCard(
                                attendaceReportDetails[index]),
                            childCount: attendaceReportDetails.length,
                          ),
                        ),
                      )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      sliver: SliverToBoxAdapter(
                        child: activeView == 'site'
                            ? _siteBreakdownList()
                            : _roleBreakdownList(),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: 28 + bottomBarInset(context)),
                  ),
                ],
              ),
      ),
    );
  }
}
