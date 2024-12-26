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

class EmployeeOtReport {
  final int id;
  final int projectId;
  final String projectName;
  final int roleId;
  final String roleName;
  final int employeeId;
  final String firstName;
  final String shiftTime;
  final DateTime createdDate;
  final String status;

  EmployeeOtReport({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.roleId,
    required this.roleName,
    required this.employeeId,
    required this.firstName,
    required this.shiftTime,
    required this.createdDate,
    required this.status,
  });

  factory EmployeeOtReport.fromJson(Map<String, dynamic> json) {
    return EmployeeOtReport(
      id: json['id'],
      projectId: json['projectId'],
      projectName: json['projectName'],
      roleId: json['roleId'],
      roleName: json['roleName'],
      employeeId: json['employeeId'],
      firstName: json['firstName'],
      shiftTime: json['shiftTime'],
      createdDate: DateTime.parse(json['createdDate']),
      status: json['status'],
    );
  }
}

class OtReportScreen extends StatefulWidget {
  const OtReportScreen({super.key});
  @override
  _OtReportScreenState createState() => _OtReportScreenState();
}

class _OtReportScreenState extends State<OtReportScreen> {
  final TextEditingController _projrctName = TextEditingController();
  final TextEditingController _roleName = TextEditingController();
  final TextEditingController _firstName = TextEditingController();
  final ConnectivityHandler connectivityHandler = ConnectivityHandler();
  final ScrollController _scrollController = ScrollController();

  List<EmployeeOtReport> report = [];

  bool isLoadingMore = false; // To track if more data is being loaded
  String _apkUrl = 'http://www.corenuts.com/main-app-release.apk';
  bool _isDownloading = false; // Add downloading state
  double _downloadProgress = 0.0; // Add download progress

  int? userId;
  String? accessToken;
  int? intOraganizationId;
  int? intRoleId;
  bool _isExpanded = false;
  // String _selectedRange = 'Custom';
  String selectedProjectId = '0';
  String selectedVendorId = '0';
  String roleSearchQuery = '';
  String projectSearchQuery = '';
  String nameSearchQuery = '';
  String selectedDateRange = '0';
  bool isLoading = true;

  String prjectName = '';
  String venderName = '';

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    bool isConnected = await connectivityHandler.checkConnectivity(context);
    if (isConnected) {
      // Proceed with other initialization steps if connected
      initializeData();
    }
  }

  Future<void> initializeData() async {
    intOraganizationId = await Util.getOrganizationId();
    intRoleId = await Util.getRoleId();
    userId = await Util.getUserId();
    accessToken = await Util.getAccessToken();
    fetchOtReport();
    // _scrollListener();
  }

  Future<void> fetchOtReport({bool isLoadingMore = false}) async {
    try {
      final response = await ApiService.fetchOtReport(
        projectName: projectSearchQuery ?? '',
        roleName: roleSearchQuery ?? '',
        firstName: nameSearchQuery ?? '',
        range: selectedDateRange,
      );

      // Check if the API call was successful
      if (response.statusCode == 401) {
        // Clear preferences and show session expired dialog
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Show session expired dialog
        showDialog(
          context: context,
          barrierDismissible: false, // Prevent dismissing dialog without action
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
                    MaterialPageRoute(
                      builder: (context) => const LoginPage(), // Login Page
                    ),
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
            MaterialPageRoute(
              builder: (context) => const LoginPage(), // Login Page
            ),
          );
        });

        return; // Early return since session expired
      } else if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('API Response Data: $data');

        if (data.isNotEmpty) {
          final List<EmployeeOtReport> fetchedReports =
              data.map((item) => EmployeeOtReport.fromJson(item)).toList();

          // Update the state with the fetched data
          setState(() {
            report = fetchedReports;
          });
        } else {
          // If the data is empty, display a message in the UI
          setState(() {
            report = [];
          });
        }
      } else {
        // Handle failure (non-200 response)
        throw Exception(
            'Failed to load OT reports. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      // Handle the error (e.g., show a toast or dialog)
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
      if (response.statusCode == 200) {
        final latestVersion = jsonDecode(response.body)['commonRefValue'];
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (latestVersion != currentVersion) {
          final apkUrlResponse = await ApiService.getApkDownloadUrl();
          if (apkUrlResponse.statusCode == 200) {
            _apkUrl = jsonDecode(apkUrlResponse.body)['commonRefValue'];
            setState(() {});
            bool isDeleted = await Util.deleteDeviceTokenInDatabase();

            if (isDeleted) {
              print("Logout successful, device token deleted.");
            } else {
              print("Logout successful, but failed to delete device token.");
            }
            // Clear user session data
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.clear();

            // Show update dialog
            _showUpdateDialog(_apkUrl);
          } else {
            print(
                'Failed to fetch APK download URL: ${apkUrlResponse.statusCode}');
          }
        } else {
          setState(() {});
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
    String savePath = await getFilePath('main-app-release.apk');
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
        InstallPlugin.installApk(savePath, appId: 'com.example.sbrgrouperp')
            .then((result) {
          print('Install result: $result');
          // After installation, navigate back to the login page
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
          );
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
                                  controller: _projrctName,
                                  decoration: const InputDecoration(
                                    hintText: 'Project Name',
                                    border: InputBorder.none,
                                    hintStyle: TextStyle(fontSize: 14),
                                    prefixIcon: Icon(Icons.search,
                                        color: Color.fromRGBO(6, 73, 105, 1)),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      projectSearchQuery = value;

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
                                  controller: _roleName,
                                  decoration: const InputDecoration(
                                    hintText: 'Role Name',
                                    border: InputBorder.none,
                                    hintStyle: TextStyle(fontSize: 14),
                                    prefixIcon: Icon(Icons.search,
                                        color: Color.fromRGBO(6, 73, 105, 1)),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      roleSearchQuery = value;

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
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Name: ${currentReport.firstName}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text('Role: ${currentReport.roleName}'),
                                    Text(
                                        'Project: ${currentReport.projectName}'),
                                    Text('Shift: ${currentReport.shiftTime}'),
                                    Text(
                                        'Date: ${currentReport.createdDate.toLocal().toString().split(' ')[0]}'),
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
