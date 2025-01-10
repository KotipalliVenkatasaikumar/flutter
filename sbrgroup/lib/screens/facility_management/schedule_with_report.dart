import 'dart:convert';
import 'dart:io';
import 'package:ajna/main.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/connectivity_handler.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/facility_management/ImageFullScreen%20.dart';
import 'package:ajna/screens/facility_management/custom_date_picker.dart';
import 'package:ajna/screens/util.dart';
import 'package:dio/dio.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Project {
  final int projectId;
  final String projectName;

  Project({required this.projectId, required this.projectName});

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      projectId: json['projectId'],
      projectName: json['projectName'] ?? '', // Default value if null
    );
  }
}

class Schedule {
  final String projectName;
  final String location;
  final String scheduleTime;
  final String status;
  final int userId;
  final String userName;
  final String phoneNumber;
  final int scheduleId;
  final int scheduleTimeId;
  final String? imageUrl; // This can be null
  final String createdDate;
  final String qrScanStatus;
  final String formatedScheduleTime;

  Schedule({
    required this.projectName,
    required this.location,
    required this.scheduleTime,
    required this.status,
    required this.userId,
    required this.userName,
    required this.phoneNumber,
    required this.scheduleId,
    required this.scheduleTimeId,
    this.imageUrl, // Allow it to be null
    required this.createdDate,
    required this.qrScanStatus,
    required this.formatedScheduleTime,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      projectName: json['projectName'] ?? '', // Default value if null
      location: json['location'] ?? '',
      scheduleTime: json['scheduleTime'] ?? '',
      status: json['status'] ?? '',
      userId: json['userId'] ?? 0, // Default to 0 if null
      userName: json['userName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      scheduleId: json['scheduleId'] ?? 0,
      scheduleTimeId: json['scheduleTimeId'] ?? 0,
      imageUrl: json['imageUrl'], // This can be null
      createdDate: json['createdDate'] ?? '',
      qrScanStatus: json['qrScanStatus'] ?? '',
      formatedScheduleTime: json['formatedScheduleTime'] ?? '',
    );
  }
}

class ScheduleReportsScreen extends StatefulWidget {
  final int organizationId;
  final int projectId;
  final String selectedDateRange;
  final String projectName;

  ScheduleReportsScreen({
    required this.organizationId,
    required this.projectId,
    required this.selectedDateRange,
    required this.projectName,
  });
  @override
  _ScheduleReportsScreenState createState() => _ScheduleReportsScreenState();
}

class _ScheduleReportsScreenState extends State<ScheduleReportsScreen> {
  final ConnectivityHandler connectivityHandler = ConnectivityHandler();

  List<Project> projects = [];
  List<Schedule> schedules = [];
  bool isLoading = true;
  int? intOrganizationId;
  String selectedDateRange = '0'; // Default to '0' for today
  int? selectedProjectId;
  Map<String, Map<String, List<Schedule>>> groupedSchedules = {};

  String _apkUrl = 'http://www.corenuts.com/ajna-app-release.apk';
  bool _isDownloading = false; // Add downloading state
  double _downloadProgress = 0.0; // Add download progress

  @override
  void initState() {
    super.initState();
    // selectedDateRange = widget.selectedDateRange;
    // fetchReportData();
    // _checkForUpdate();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    bool isConnected = await connectivityHandler.checkConnectivity(context);
    if (isConnected) {
      // Proceed with other initialization steps if connected
      selectedDateRange = widget.selectedDateRange;
      _checkForUpdate();
      fetchReportData();
    }
  }
  // Future<void> _fetchProjects(int organizationId) async {
  //   setState(() {
  //     isLoading = true;
  //   });

  //   try {
  //     final response = await ApiService.fetchOrgProjects(organizationId);

  //     if (response.statusCode == 200) {
  //       final List<dynamic> data = jsonDecode(response.body);
  //       setState(() {
  //         projects = data.map((project) => Project.fromJson(project)).toList();
  //         if (projects.isNotEmpty) {
  //           // selectedProjectId = projects.first.projectId;
  //           // fetchReportData(); // Fetch report data for today by default
  //         }
  //         isLoading = false;
  //       });
  //     } else {
  //       _handleError(
  //         'Failed to load projects. Please try again later.',
  //         response.statusCode,
  //       );
  //     }
  //   } catch (e) {
  //     _handleError('Error fetching projects. Please try again later.', e);
  //   }
  // }

  Future<void> fetchReportData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiService.fetchScheduleReports(
        widget.organizationId,
        widget.projectId,
        selectedDateRange,
      );

      if (response.statusCode == 200) {
        final List<dynamic> reportData = jsonDecode(response.body);
        setState(() {
          schedules =
              reportData.map((item) => Schedule.fromJson(item)).toList();
          groupedSchedules = _groupSchedulesByDateAndLocation(schedules);
        });
      } else {
        _handleError(
          'Failed to load report data. Please try again later.',
          response.statusCode,
        );
      }
    } catch (e) {
      _handleError('Failed to load report data. Please try again later.', e);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Map<String, Map<String, List<Schedule>>> _groupSchedulesByDateAndLocation(
  //     List<Schedule> schedules) {
  //   Map<String, Map<String, List<Schedule>>> grouped = {};
  //   for (var schedule in schedules) {
  //     String date =
  //         schedule.createdDate.split('T').first; // Extract the date part

  //     String location = schedule.location;

  //     grouped.putIfAbsent(date, () => {});
  //     grouped[date]!.putIfAbsent(location, () => []).add(schedule);
  //   }
  //   return grouped;
  // }

  Map<String, Map<String, List<Schedule>>> _groupSchedulesByDateAndLocation(
      List<Schedule> schedules) {
    Map<String, Map<String, List<Schedule>>> grouped = {};
    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (var schedule in schedules) {
      String date;

      if (schedule.createdDate == null || schedule.createdDate.isEmpty) {
        date = todayDate;
      } else {
        date = schedule.createdDate.split('T').first;
      }
      String location = schedule.location;

      grouped.putIfAbsent(date, () => {});
      grouped[date]!.putIfAbsent(location, () => []).add(schedule);
    }
    return grouped;
  }

  void _handleError(String message, dynamic error) {
    ErrorHandler.handleError(context, message, 'Error: $error');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void sendApiCall(Schedule schedule, BuildContext context) async {
    if (schedule.imageUrl == null) {
      _handleError('Image URL is missing for this schedule.', null);
      return; // Exit early if there's no image URL
    }

    var imageResponse = await ApiService.downloadImage(
      projectName: schedule.projectName,
      date: schedule.createdDate,
      userName: schedule.userName,
      phoneNumber: schedule.phoneNumber,
      imageUrl: schedule.imageUrl!, // Use the non-nullable imageUrl
    );

    if (imageResponse.statusCode == 200) {
      var imageData = imageResponse.bodyBytes; // Get image bytes
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullImageScreen(imageData: imageData),
        ),
      );
    } else {
      _handleError('Failed to download image: ${imageResponse.statusCode}',
          imageResponse.statusCode);
    }
  }

  Future<void> _refreshData() async {
    _checkForUpdate();
    await fetchReportData();
  }

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
      // appBar: AppBar(
      //   backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
      //   title: const Text('Project Wise - QR Scan Report',
      //       style: TextStyle(
      //           color: Colors.white,
      //           fontSize: 16,
      //           fontWeight: FontWeight.bold)),
      //   centerTitle: true,
      //   iconTheme: const IconThemeData(
      //     color: Colors.white,
      //   ),
      // ),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QR Scan Report',
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
        onRefresh: _refreshData,
        child: Stack(
          children: [
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 30, 10, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomDateRangePicker(
                      onDateRangeSelected: (start, end, range) {
                        setState(() {
                          selectedDateRange = range;
                        });
                        fetchReportData();
                      },
                      selectedDateRange: selectedDateRange,
                    ),
                    // const SizedBox(height: 20),
                    // Padding(
                    //   padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                    //   child: DropdownButtonFormField2<int>(
                    //     decoration: InputDecoration(
                    //       labelText: 'Select Project',
                    //       border: OutlineInputBorder(
                    //         borderRadius: BorderRadius.circular(8.0),
                    //       ),
                    //       enabledBorder: OutlineInputBorder(
                    //         borderSide: const BorderSide(
                    //           color: Color.fromARGB(255, 41, 221, 200),
                    //           width: 1.0,
                    //         ),
                    //         borderRadius: BorderRadius.circular(8.0),
                    //       ),
                    //       focusedBorder: OutlineInputBorder(
                    //         borderSide: const BorderSide(
                    //           color: Color.fromARGB(255, 23, 158, 142),
                    //           width: 2.0,
                    //         ),
                    //         borderRadius: BorderRadius.circular(8.0),
                    //       ),
                    //       contentPadding: const EdgeInsets.symmetric(
                    //         vertical: 12.0,
                    //         horizontal: 16.0,
                    //       ),
                    //     ),
                    //     value: selectedProjectId,
                    //     isExpanded:
                    //         true, // Allows the dropdown to take up the full width
                    //     items: projects.isNotEmpty
                    //         ? projects
                    //             .map<DropdownMenuItem<int>>((Project project) {
                    //             return DropdownMenuItem<int>(
                    //               value: project.projectId,
                    //               child: Text(
                    //                 project.projectName,
                    //                 style: const TextStyle(
                    //                   fontSize: 16,
                    //                   color: Color.fromARGB(255, 80, 79, 79),
                    //                 ),
                    //               ),
                    //             );
                    //           }).toList()
                    //         : [
                    //             const DropdownMenuItem<int>(
                    //               value: -1,
                    //               child: Text('No Projects Available'),
                    //             ),
                    //           ],
                    //     onChanged: (int? value) {
                    //       if (value != null) {
                    //         setState(() {
                    //           selectedProjectId = value;
                    //         });
                    //         fetchReportData(); // Fetch report data based on the selected project
                    //       }
                    //     },
                    //     validator: (value) {
                    //       if (value == null || value == -1) {
                    //         return 'Please select a project';
                    //       }
                    //       return null;
                    //     },
                    //     dropdownStyleData: DropdownStyleData(
                    //       maxHeight: 300,
                    //       width: MediaQuery.of(context).size.width *
                    //           0.9, // Set dropdown width to 90% of the screen width
                    //       decoration: BoxDecoration(
                    //         borderRadius: BorderRadius.circular(8.0),
                    //       ),
                    //     ),
                    //   ),
                    // ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        widget.projectName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Expanded(
                      child: ListView.builder(
                        itemCount: groupedSchedules.keys.length,
                        itemBuilder: (context, index) {
                          String date = groupedSchedules.keys.elementAt(index);
                          Map<String, List<Schedule>> schedulesByLocation =
                              groupedSchedules[date]!;

                          return Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),
                                Text(
                                  'Date: $date',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Iterate over locations for the current date
                                for (var locationEntry
                                    in schedulesByLocation.entries)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Location: ${locationEntry.key}', // Display the location
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      // Grid for schedules at this location
                                      const SizedBox(height: 4),
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3, // Three columns
                                          crossAxisSpacing: 10.0,
                                          mainAxisSpacing: 10.0,
                                        ),
                                        itemCount: locationEntry.value.length,
                                        itemBuilder: (context, index) {
                                          final schedule =
                                              locationEntry.value[index];

                                          return GestureDetector(
                                            onTap: () {
                                              if (schedule.qrScanStatus ==
                                                  'On Time') {
                                                // Trigger API call when item is clicked
                                                sendApiCall(schedule,
                                                    context); // Pass both schedule and context
                                              }
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: schedule.qrScanStatus ==
                                                        'On Time'
                                                    ? Colors.green
                                                    : schedule.qrScanStatus ==
                                                            'Not Yet Scanned'
                                                        ? Colors.grey
                                                        : Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(10.0),
                                              ),
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      const Icon(
                                                        Icons.schedule,
                                                        color: Colors.white,
                                                        size: 14.0,
                                                      ),
                                                      const SizedBox(
                                                          width: 4.0),
                                                      Text(
                                                        schedule
                                                            .formatedScheduleTime,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8.0),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          schedule.userName,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8.0),
                                                  if (schedule.qrScanStatus ==
                                                      'On Time') ...[
                                                    LayoutBuilder(
                                                      builder: (context,
                                                          constraints) {
                                                        double screenWidth =
                                                            MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width;
                                                        double fontSize =
                                                            screenWidth < 600
                                                                ? 10
                                                                : 12;
                                                        double padding =
                                                            screenWidth < 600
                                                                ? 6.0
                                                                : 8.0;

                                                        return Container(
                                                          padding:
                                                              EdgeInsets.all(
                                                                  padding),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: const Color
                                                                    .fromARGB(
                                                                    255,
                                                                    103,
                                                                    180,
                                                                    243)
                                                                .withOpacity(
                                                                    0.7),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8.0),
                                                            border: Border.all(
                                                              color:
                                                                  Colors.white,
                                                              width: 2,
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        0.2),
                                                                blurRadius: 4.0,
                                                                offset:
                                                                    const Offset(
                                                                        0, 2),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Text(
                                                            'View Image',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize:
                                                                  fontSize,
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
