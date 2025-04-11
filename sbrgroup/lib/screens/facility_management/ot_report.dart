import 'dart:convert';
import 'dart:io';

import 'package:ajna/main.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/connectivity_handler.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/facility_management/custom_date_picker.dart';
import 'package:ajna/screens/util.dart';
import 'package:dio/dio.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmployeeShift {
  final int? id;
  final int? projectId;
  final String? projectName;
  final int? roleId;
  final String? roleName;
  final int? employeeId;
  final String? firstName;
  final String? shiftTime;
  final DateTime? createdDate;
  final String? status;
  final int? toLocation;
  final String? toLocationName;
  final int? organizationId;

  EmployeeShift({
    this.id,
    this.projectId,
    this.projectName,
    this.roleId,
    this.roleName,
    this.employeeId,
    this.firstName,
    this.shiftTime,
    this.createdDate,
    this.status,
    this.toLocation,
    this.toLocationName,
    this.organizationId,
  });

  factory EmployeeShift.fromJson(Map<String, dynamic> json) {
    return EmployeeShift(
      id: json['id'] as int?,
      projectId: json['projectId'] as int?,
      projectName: json['projectName'] as String?,
      roleId: json['roleId'] as int?,
      roleName: json['roleName'] as String?,
      employeeId: json['employeeId'] as int?,
      firstName: json['firstName'] as String?,
      shiftTime: json['shiftTime'] as String?,
      createdDate: json['createdDate'] != null
          ? DateTime.parse(json['createdDate'] as String)
          : null,
      status: json['status'] as String?,
      toLocation: json['toLocation'] as int?,
      toLocationName: json['toLocationName'] as String?,
      organizationId: json['organizationId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'projectName': projectName,
      'roleId': roleId,
      'roleName': roleName,
      'employeeId': employeeId,
      'firstName': firstName,
      'shiftTime': shiftTime,
      'createdDate': createdDate?.toIso8601String(),
      'status': status,
      'toLocation': toLocation,
      'toLocationName': toLocationName,
      'organizationId': organizationId,
    };
  }
}

class Project {
  final int projectId;
  final String projectName;

  Project({
    required this.projectId,
    required this.projectName,
  });

  // From JSON
  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      projectId: json['projectId'],
      projectName: json['projectName'],
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'projectId': projectId,
      'projectName': projectName,
    };
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

class OtReportScreen extends StatefulWidget {
  final int projectId;
  final String selectedDateRange;
  final String projectName;

  OtReportScreen({
    required this.projectId,
    required this.selectedDateRange,
    required this.projectName,
  });
  @override
  _OtReportScreenState createState() => _OtReportScreenState();
}

class _OtReportScreenState extends State<OtReportScreen> {
  final TextEditingController _projrctName = TextEditingController();
  final TextEditingController _roleName = TextEditingController();
  final TextEditingController _firstName = TextEditingController();
  final ConnectivityHandler connectivityHandler = ConnectivityHandler();
  final ScrollController _scrollController = ScrollController();

  List<EmployeeShift> report = [];

  bool isLoadingMore = false; // To track if more data is being loaded
  String _apkUrl = 'http://www.corenuts.com/ajna-app-release.apk';
  bool _isDownloading = false; // Add downloading state
  double _downloadProgress = 0.0; // Add download progress

  int? userId;
  String? accessToken;
  int? intOraganizationId;
  int? intRoleId;
  bool _isExpanded = false;
  // String _selectedRange = 'Custom';
  String selectedProjectId = '';
  String selectedRoleId = '';
  String selectedVendorId = '0';
  String roleSearchQuery = '';
  String projectSearchQuery = '';
  String nameSearchQuery = '';
  String selectedDateRange = '';
  bool isLoading = true;

  String prjectName = '';
  String venderName = '';

  List<Project> projects = [];
  List<Role> roles = [];

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    selectedProjectId = widget.projectId?.toString() ?? '';
    selectedDateRange = widget.selectedDateRange;
  }

  Future<void> _checkConnectivity() async {
    bool isConnected = await connectivityHandler.checkConnectivity(context);
    if (isConnected) {
      // Proceed with other initialization steps if connected
      _checkForUpdate();
      initializeData();
    }
  }

  Future<void> initializeData() async {
    intOraganizationId = await Util.getOrganizationId();
    intRoleId = await Util.getRoleId();
    userId = await Util.getUserId();
    accessToken = await Util.getAccessToken();
    fetchProjectData(intOraganizationId);
    fetchOtReport();
    fetchRoles();
    // _scrollListener();
  }

  Future<List<Project>> fetchProjectData(int? orgId) async {
    try {
      // Fetch the response from the API
      final response = await ApiService.fetchProjectsInOtScreen(orgId!);

      // Print the status code and response body for debugging
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      // Check if the response is successful
      if (response.statusCode == 200) {
        // Parse the JSON response into a List of Project objects
        final List<dynamic> data = json.decode(response.body);

        // Convert the List<dynamic> into a List of Project objects
        projects = data.map((item) => Project.fromJson(item)).toList();

        return projects;
      } else {
        // Handle errors (non-200 status code)
        throw Exception('Failed to load project data');
      }
    } catch (e) {
      // Print any error that occurs during the fetch process
      print('Error fetching project data: $e');
      rethrow; // Optionally, rethrow the error to handle it elsewhere
    }
  }

  Future<void> fetchOtReport({bool isLoadingMore = false}) async {
    try {
      // Show loading indicator
      setState(() {
        isLoading = true;
      });

      final response = await ApiService.fetchOtReport(
        projectId: selectedProjectId ?? '',
        roleId: selectedRoleId ?? '',
        firstName: nameSearchQuery ?? '',
        range: selectedDateRange,
        organizationId: intOraganizationId,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('API Response Data: $data');

        if (data.isNotEmpty) {
          final List<EmployeeShift> fetchedReports =
              data.map((item) => EmployeeShift.fromJson(item)).toList();

          setState(() {
            // Append data if loading more, else replace the list
            if (isLoadingMore) {
              report.addAll(fetchedReports);
            } else {
              report = fetchedReports;
            }
          });
        } else {
          setState(() {
            if (!isLoadingMore) {
              report = []; // Clear the list if not loading more
            }
          });
          print('No data found.');
        }
      } else {
        throw Exception(
            'Failed to load OT reports. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      // Provide user feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching OT reports: $e')),
      );
    } finally {
      // Hide loading indicator
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchRoles() async {
    try {
      final response = await ApiService.fetchOrgRoles(
        intOraganizationId!,
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

  Future<void> refreshData() async {
    // _fetchTransactionData();
    _checkForUpdate();
    initializeData();
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Don't forget to dispose the controller
    super.dispose();
  }

//   void _scrollListener() {
//     if (_scrollController.position.pixels ==
//             _scrollController.position.maxScrollExtent &&
//         !isLoadingMore) {
//       _loadMoreTransactions();
//     }
//   }

  void _onDateRangeSelected(
      DateTime startDate, DateTime endDate, String range) {
    setState(() {
      selectedDateRange = range;
      // isLoading = true;
    });

    fetchOtReport().catchError((error) {
      ErrorHandler.handleError(
        context,
        'Failed to fetch attendance data.',
        'Error fetching data: $error',
      );
    }).whenComplete(() {
      setState(() => isLoading = false);
    });
  }

//   Future<void> _loadMoreTransactions() async {
//     if (isLoadingMore) return;

//     setState(() {
//       isLoadingMore = true;
//     });

//     try {
//       await fetchOtReport(isLoadingMore: true);
//     } catch (e) {
//       print('Error loading more transactions: $e');
//     } finally {
//       setState(() {
//         isLoadingMore = false;
//       });
//     }
//   }

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
      } else if (response.statusCode == 200) {
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OT Report',
              style: TextStyle(
                fontSize: screenWidth > 600 ? 20 : 16,
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshData,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Filter Row (ExpansionTile)
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
                        Text(
                          "Filters",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.filter_alt,
                      size: 24,
                      color: Colors.grey,
                    ),
                    onExpansionChanged: (bool expanded) {
                      setState(() {
                        _isExpanded = expanded;
                      });
                    },
                    children: [
                      const SizedBox(height: 10),
                      CustomDateRangePicker(
                        onDateRangeSelected: _onDateRangeSelected,
                        selectedDateRange: selectedDateRange,
                      ),
                      const SizedBox(height: 10.0),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: Color.fromRGBO(8, 101, 145, 1),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 2,
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: DropdownButtonFormField2<String>(
                                  decoration: const InputDecoration(
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 16.0),
                                    border: InputBorder.none,
                                  ),
                                  value: projects.any((project) =>
                                          project.projectId.toString() ==
                                          selectedProjectId)
                                      ? selectedProjectId
                                      : null, // Use null if no match is found
                                  hint: const Text('Project Name'),
                                  items: [
                                    DropdownMenuItem(
                                      value: '',
                                      child: const Text('All'),
                                    ),
                                    ...projects.map((project) {
                                      return DropdownMenuItem<String>(
                                        value: project.projectId.toString(),
                                        child: Text(project.projectName),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      selectedProjectId = value ??
                                          ''; // Safely handle null values
                                    });
                                    fetchOtReport(); // Fetch data based on the current selection
                                    // fetchRoles();
                                  },
                                  isExpanded: true,
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
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: Color.fromRGBO(8, 101, 145, 1),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 2,
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: DropdownButtonFormField2<String>(
                                  decoration: const InputDecoration(
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 16.0),
                                    border: InputBorder.none,
                                  ),
                                  value: roles.any((role) =>
                                          role.roleId.toString() ==
                                          selectedRoleId)
                                      ? selectedRoleId
                                      : null, // Use null if no match is found
                                  hint: const Text('Role Name'),
                                  items: [
                                    DropdownMenuItem(
                                      value: '',
                                      child: const Text('All'),
                                    ),
                                    ...roles.map((role) {
                                      return DropdownMenuItem<String>(
                                        value: role.roleId.toString(),
                                        child: Text(role.roleName),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      selectedRoleId = value ??
                                          ''; // Safely handle null values
                                    });
                                    fetchOtReport(); // Fetch data based on the current selection
                                  },
                                  isExpanded: true,
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
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: Color.fromRGBO(8, 101, 145,
                                        1), // Border color applied here
                                    width:
                                        1.0, // Border width, adjust as needed
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 2,
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _firstName,
                                  decoration: const InputDecoration(
                                    hintText: 'Name',
                                    border: InputBorder.none,
                                    hintStyle: TextStyle(fontSize: 14),
                                    prefixIcon: Icon(Icons.search,
                                        color: Color.fromRGBO(6, 73, 105, 1)),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      nameSearchQuery = value;

                                      fetchOtReport();
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: report.isNotEmpty
                      ? ListView.builder(
                          itemCount: report.length,
                          itemBuilder: (context, index) {
                            final currentReport = report[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 8),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.person,
                                          color: Colors.blue,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          currentReport.firstName ??
                                              'Unknown Name',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(thickness: 1, height: 16),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.work,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Role: ${currentReport.roleName ?? 'Not Assigned'}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.assignment,
                                          color: Colors.orange,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Project: ${currentReport.projectName ?? 'Not Available'}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          color: Colors.purple,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Shift: ${currentReport.shiftTime ?? 'Not Set'}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          currentReport.createdDate != null
                                              ? 'Date: ${currentReport.createdDate!.toLocal().toString().split(' ')[0]}'
                                              : 'Date: Not Available',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          color: Colors.teal,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'To Location: ${currentReport.toLocationName ?? 'Not Available'}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Text(
                            'No OT Report Found',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                ),
              ],
            ),
          ),
          // Work Orders List
        ),
      ),
    );
  }
}
