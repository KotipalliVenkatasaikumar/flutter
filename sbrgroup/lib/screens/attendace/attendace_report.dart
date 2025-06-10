import 'dart:convert';
import 'dart:io';

import 'package:ajna/main.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/attendace/generate_report_screen.dart';
import 'package:ajna/screens/connectivity_handler.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/facility_management/custom_date_picker.dart';
import 'package:ajna/screens/util.dart';
import 'package:dio/dio.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  bool showAttendanceList = true;
  String _apkUrl = 'http://www.corenuts.com/ajna-app-release.apk';
  bool _isDownloading = false; // Add downloading state
  double _downloadProgress = 0.0; // Add download progress

  @override
  void initState() {
    super.initState();
    // _initializeData();
    // _checkForUpdate();
    // _scrollController.addListener(_scrollListener);
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    bool isConnected = await connectivityHandler.checkConnectivity(context);
    if (isConnected) {
      _checkForUpdate();
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
      fetchRoleReport(); // API call for Role Report
      // fetchRoles();
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

  Future<void> fetchRoles() async {
    try {
      final response = await ApiService.fetchRoles(
        organizationId!,
        selectedLocation,
      );
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          roles = jsonData.map<Role>((json) => Role.fromJson(json)).toList();
        });
      } else {
        throw Exception('Failed to load roles');
      }
    } catch (error) {
      ErrorHandler.handleError(
        context,
        'Failed to load roles data.',
        'Location data error: $error',
      );
    }
  }

  Future<void> fetchAttendanceDashboard() async {
    if (organizationId == null || userId == null) return;

    // Reset attendance details before fetching new dashboard data
    setState(() {
      attendaceReportDetails = [];
      fetchRoleReport(); // API call for Role Report
    });

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
    _checkForUpdate();
    await fetchAttendanceDashboard();
    // attendaceReportDetails = [];
    // fetchAttendanceDetails('', '');
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

  Future<void> _checkForUpdate() async {
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

      if (response.statusCode == 200) {
        final latestVersion = jsonDecode(response.body)['commonRefValue'];
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (latestVersion != currentVersion) {
          final apkUrlResponse = await ApiService.getApkDownloadUrl();
          if (apkUrlResponse.statusCode == 200) {
            _apkUrl = jsonDecode(apkUrlResponse.body)['commonRefValue'];
            setState(() {});
            // bool isDeleted = await Util.deleteDeviceTokenInDatabase();

            // if (isDeleted) {
            //   print("Logout successful, device token deleted.");
            // } else {
            //   print("Logout successful, but failed to delete device token.");
            // }

            // // Clear user session data
            // SharedPreferences prefs = await SharedPreferences.getInstance();
            // await prefs.clear();

            // Show update dialog
            _showUpdateDialog(_apkUrl);
          } else {
            print(
                'Failed to fetch APK download URL: ${apkUrlResponse.statusCode}');
          }
        } else {
          setState(() {}); // Update state if no update required
        }
      } else {
        print('Failed to fetch latest app version: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking for update: $e');
      setState(() {});
    }
  }

  void _showUpdateDialog(String apkUrl) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dialog from closing on tap outside
        builder: (context) {
          return AlertDialog(
            title: const Text('Update Available'),
            content: const Text(
                'A new version of the app is available. Please update.'),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // Dismiss dialog
                  await downloadAndInstallAPK(apkUrl);
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      );
    });
  }

  Future<void> downloadAndInstallAPK(String url) async {
    Dio dio = Dio();
    String savePath = await getFilePath('ajna-app-release.apk');
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      setState(() {
        _isDownloading = false;
      });

      if (await Permission.requestInstallPackages.request().isGranted) {
        InstallPlugin.installApk(savePath, appId: 'com.example.ajna')
            .then((result) {
          print('Install result: $result');
          // After installation, navigate back to the login page
          // Navigator.pushAndRemoveUntil(
          //   context,
          //   MaterialPageRoute(builder: (context) => const LoginPage()),
          //   (Route<dynamic> route) => false,
          // );
        }).catchError((error) {
          print('Install error: $error');
        });
      } else {
        print('Install permission denied.');
      }
    } catch (e) {
      print('Download error: $e');
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<String> getFilePath(String fileName) async {
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;
    return '$tempPath/$fileName';
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
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
            if (_isDownloading)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
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
                                          color: Color.fromRGBO(6, 73, 105, 1),
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
                                            color:
                                                Color.fromRGBO(6, 73, 105, 1),
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
                                        fetchAttendanceDashboard();
                                        fetchRoleReport();
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
                            // Row(
                            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            //   children: [
                            //     // Location Dropdown
                            //     Expanded(
                            //       child: Padding(
                            //         padding: const EdgeInsets.symmetric(
                            //             horizontal:
                            //                 12.0), // Adjust the horizontal padding as needed
                            //         child: DropdownButtonFormField2<String>(
                            //           decoration: InputDecoration(
                            //             labelText: 'Role',
                            //             labelStyle: TextStyle(
                            //               color: Colors.grey[700],
                            //               fontWeight: FontWeight.w500,
                            //             ),
                            //             prefixIcon: Icon(
                            //               Icons.supervised_user_circle,
                            //               color:
                            //                   Color.fromARGB(255, 23, 158, 142),
                            //             ),
                            //             contentPadding:
                            //                 const EdgeInsets.symmetric(
                            //               vertical: 12.0,
                            //               horizontal: 12.0,
                            //             ),
                            //             filled: true,
                            //             fillColor: Colors.white,
                            //             border: OutlineInputBorder(
                            //               borderRadius:
                            //                   BorderRadius.circular(12.0),
                            //               borderSide: BorderSide(
                            //                   color: Colors.grey.shade300),
                            //             ),
                            //             enabledBorder: OutlineInputBorder(
                            //               borderSide: BorderSide(
                            //                 color: Color.fromARGB(
                            //                     255, 41, 221, 200),
                            //                 width: 1.0,
                            //               ),
                            //               borderRadius:
                            //                   BorderRadius.circular(12.0),
                            //             ),
                            //             focusedBorder: OutlineInputBorder(
                            //               borderSide: BorderSide(
                            //                 color: Color.fromARGB(
                            //                     255, 23, 158, 142),
                            //                 width: 2.0,
                            //               ),
                            //               borderRadius:
                            //                   BorderRadius.circular(12.0),
                            //             ),
                            //           ),
                            //           alignment:
                            //               AlignmentDirectional.bottomStart,
                            //           value: selectedRole != '0'
                            //               ? selectedRole
                            //               : '0',
                            //           items: [
                            //             DropdownMenuItem<String>(
                            //               value: '0',
                            //               child: Text('All',
                            //                   style: TextStyle(
                            //                       color: Colors.black87)),
                            //             ),
                            //             ...roles.map((roles) {
                            //               return DropdownMenuItem<String>(
                            //                 value: roles.roleId.toString(),
                            //                 child: Text(
                            //                   roles.roleName,
                            //                   style: TextStyle(
                            //                       color: Colors.black87),
                            //                 ),
                            //               );
                            //             }).toList(),
                            //           ],
                            //           onChanged: (value) {
                            //             setState(() {
                            //               selectedRole = value!;
                            //             });
                            //             // fetchAttendanceDashboard();
                            //             // fetchRoleReport();
                            //             fetchAttendanceDetails('', '');
                            //           },
                            //           isExpanded: true,
                            //           dropdownStyleData: DropdownStyleData(
                            //             maxHeight: 250,
                            //             width:
                            //                 MediaQuery.of(context).size.width *
                            //                     0.9,
                            //             decoration: BoxDecoration(
                            //               borderRadius:
                            //                   BorderRadius.circular(12.0),
                            //               color: Colors.white,
                            //               boxShadow: const [
                            //                 BoxShadow(
                            //                   color: Colors.black12,
                            //                   blurRadius: 8,
                            //                   offset: Offset(0, 4),
                            //                 ),
                            //               ],
                            //             ),
                            //           ),
                            //         ),
                            //       ),
                            //     ),
                            //   ],
                            // ),
                            // const SizedBox(height: 25),
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
                                      TextButton(
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
                                          style: TextStyle(
                                            color:
                                                Color.fromRGBO(6, 73, 105, 1),
                                          ),
                                        ),
                                      ),
                                      TextButton(
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
                                          style: TextStyle(
                                            color:
                                                Color.fromRGBO(6, 73, 105, 1),
                                          ),
                                        ),
                                      ),
                                      TextButton(
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
                                          style: TextStyle(
                                            color:
                                                Color.fromRGBO(6, 73, 105, 1),
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
                                    selectedColor:
                                        Color.fromRGBO(6, 73, 105, 1),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                      border: Border.all(
                                          color: Color.fromRGBO(6, 73, 105, 1)),
                                    ),
                                    buttonIcon: const Icon(
                                      Icons.access_time,
                                      color: Color.fromRGBO(6, 73, 105, 1),
                                    ),
                                    buttonText: Text(
                                      "Select Shifts",
                                      style: TextStyle(
                                        color: Color.fromRGBO(6, 73, 105, 1),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    dialogWidth:
                                        MediaQuery.of(context).size.width *
                                            0.75,
                                    itemsTextStyle:
                                        const TextStyle(fontSize: 12),
                                    checkColor: Color.fromRGBO(6, 73, 105, 1),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    showAttendanceList = true;
                                    selectedStatus = 'Logged In';
                                  });
                                  fetchAttendanceDetails(selectedStatus, '');
                                },
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                  color: Colors.green.shade50,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 10), // Adjusted padding
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.login,
                                            color: Colors.green.shade600,
                                            size: 24), // Reduced icon size
                                        const SizedBox(
                                            height: 4), // Reduced space
                                        const Text(
                                          'Logged In',
                                          style: TextStyle(
                                            fontSize: 14, // Reduced font size
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(
                                            height: 2), // Reduced space
                                        Text(
                                          '${attendanceRecords.firstWhere((element) => element.attendanceStatus == 'Logged In', orElse: () => Attendance(count: 0, attendanceStatus: 'Logged In', createdDate: null, lateComerCount: 0, earlyLeaverCount: 0)).count}',
                                          style: const TextStyle(
                                            fontSize: 16, // Reduced font size
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    showAttendanceList = true;
                                    selectedStatus = 'Not Logged In';
                                  });
                                  fetchAttendanceDetails(selectedStatus, '');
                                },
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                  color: Colors.red.shade50,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 10), // Adjusted padding
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.block,
                                            color: Colors.red.shade600,
                                            size: 24), // Reduced icon size
                                        const SizedBox(
                                            height: 4), // Reduced space
                                        const Text(
                                          'Not Logged In',
                                          style: TextStyle(
                                            fontSize: 14, // Reduced font size
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(
                                            height: 2), // Reduced space
                                        Text(
                                          '${attendanceRecords.firstWhere((element) => element.attendanceStatus == 'Not Logged In', orElse: () => Attendance(count: 0, attendanceStatus: 'Not Logged In', createdDate: null, lateComerCount: 0, earlyLeaverCount: 0)).count}',
                                          style: const TextStyle(
                                            fontSize: 16, // Reduced font size
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        showAttendanceList = true;
                                        fetchAttendanceDetails('', '');
                                      });
                                    },
                                    child: const Text(
                                      'All Attendance',
                                      style: TextStyle(
                                          fontSize: 12), // Smaller font
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8), // Less padding
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      minimumSize:
                                          const Size(0, 36), // Minimum height
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        showAttendanceList = false;
                                        fetchRoleReport();
                                      });
                                    },
                                    child: const Text(
                                      'Role Report',
                                      style: TextStyle(
                                          fontSize: 12), // Smaller font
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8), // Less padding
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      minimumSize:
                                          const Size(0, 36), // Minimum height
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              GenerateReportScreen(
                                                  locations: locations),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Generate Report',
                                      style: TextStyle(
                                          fontSize: 12), // Smaller font
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8), // Less padding
                                      backgroundColor: Colors.orange,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      minimumSize:
                                          const Size(0, 36), // Minimum height
                                    ),
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

                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          height: screenHeight - 400, // Adjust height as needed
                          child: showAttendanceList
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
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8.0, horizontal: 10.0),
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
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  record.attendanceStatus,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        record.attendanceStatus ==
                                                                "Logged In"
                                                            ? Colors.green
                                                            : const Color
                                                                .fromARGB(255,
                                                                241, 58, 58),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            // In and Out Times Row
                                            Row(
                                              children: [
                                                Icon(Icons.login,
                                                    color: Colors.blueAccent,
                                                    size: 14),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    'In: ${record.attendanceInTime} - ${record.logInLocationName}',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black54),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                        color: Colors.black54),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                      color: Colors.black54),
                                                ),
                                                Text(
                                                  'Out Date: ${record.attendanceOutDate != null ? DateFormat('yyyy-MM-dd').format(record.attendanceOutDate!) : "--"}',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.black54),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : ListView.builder(
                                  itemCount: roleReportDetails.length +
                                      1, // Add one for the last record space
                                  itemBuilder: (context, index) {
                                    if (index == roleReportDetails.length) {
                                      return const SizedBox(
                                          height:
                                              80); // Space for the last record
                                    }

                                    final report = roleReportDetails[index];

                                    return GestureDetector(
                                      // onTap: () async {
                                      //   print('Tapped on: ${report.roleName}');
                                      //   final selectedRole =
                                      //       report.roleId as String;
                                      //   print(
                                      //       'Calling fetchAttendanceDetails() for role: $selectedRole');

                                      //   try {
                                      //     await fetchAttendanceDetails('',
                                      //         ''); // Pass the selected roleId
                                      //     print(
                                      //         'API call completed successfully');
                                      //   } catch (e) {
                                      //     print('Error during API call: $e');
                                      //   }
                                      // },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 8.0),
                                        padding: const EdgeInsets.all(16.0),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.grey.withOpacity(0.1),
                                              spreadRadius: 1,
                                              blurRadius: 8,
                                              offset: Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8.0),
                                              decoration: const BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: Color.fromARGB(
                                                        255,
                                                        201,
                                                        199,
                                                        199), // Border color
                                                    width: 1.0, // Border width
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  // Optional space between texts

                                                  Expanded(
                                                    child: Text(
                                                      report.roleName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                        color: Colors.blueGrey,
                                                      ),
                                                    ),
                                                  ),
                                                  // Optional space between texts
                                                  Expanded(
                                                    child: Text(
                                                      'No Of Staff: ${report.totalAttendance}',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors
                                                            .blueGrey[700],
                                                        fontSize: 15,
                                                      ),
                                                      textAlign: TextAlign
                                                          .right, // Corrected here
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Logged In: ${report.loggedInCount}',
                                                    style: TextStyle(
                                                      color: Colors.green[700],
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    'Not Logged In: ${report.notLoggedInCount}',
                                                    style: TextStyle(
                                                      color: Colors.red[700],
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    textAlign: TextAlign.right,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
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
