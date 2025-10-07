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
import 'package:android_intent_plus/android_intent.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FieldOfficerPatrol {
  final int fieldOfficerPatrolId;
  final DateTime inTime;
  final DateTime? outTime;
  final int userId;
  final String userName;
  final String phoneNumber;
  final int locationId;
  final String location;
  final int projectId;
  final String projectName;
  final int orgId;
  final String organizationName;
  final String status;
  final int qrTypeId;
  final String qrType;
  final String inImageUrl;
  final String? outImageUrl;
  final DateTime createdDate;

  FieldOfficerPatrol({
    required this.fieldOfficerPatrolId,
    required this.inTime,
    this.outTime,
    required this.userId,
    required this.userName,
    required this.phoneNumber,
    required this.locationId,
    required this.location,
    required this.projectId,
    required this.projectName,
    required this.orgId,
    required this.organizationName,
    required this.status,
    required this.qrTypeId,
    required this.qrType,
    required this.inImageUrl,
    this.outImageUrl,
    required this.createdDate,
  });

  factory FieldOfficerPatrol.fromJson(Map<String, dynamic> json) {
    return FieldOfficerPatrol(
      fieldOfficerPatrolId: json['fieldOfficerPatrolId'] ?? 0,
      inTime: DateTime.parse(json['inTime']),
      outTime:
          json['outTime'] != null ? DateTime.tryParse(json['outTime']) : null,
      userId: json['userId'] ?? 0,
      userName: json['userName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      locationId: json['locationId'] ?? 0,
      location: json['location'] ?? '',
      projectId: json['projectId'] ?? 0,
      projectName: json['projectName'] ?? '',
      orgId: json['orgId'] ?? 0,
      organizationName: json['organizationName'] ?? '',
      status: json['status'] ?? '',
      qrTypeId: json['qrTypeId'] ?? 0,
      qrType: json['qrType'] ?? '',
      inImageUrl: json['inImageUrl'] ?? '',
      outImageUrl: json['outImageUrl'], // Nullable field
      createdDate: DateTime.parse(json['createdDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fieldOfficerPatrolId': fieldOfficerPatrolId,
      'inTime': inTime.toIso8601String(),
      'outTime': outTime?.toIso8601String(), // Handle nullable field
      'userId': userId,
      'userName': userName,
      'phoneNumber': phoneNumber,
      'locationId': locationId,
      'location': location,
      'projectId': projectId,
      'projectName': projectName,
      'orgId': orgId,
      'organizationName': organizationName,
      'status': status,
      'qrTypeId': qrTypeId,
      'qrType': qrType,
      'inImageUrl': inImageUrl,
      'outImageUrl': outImageUrl, // Nullable field
      'createdDate': createdDate.toIso8601String(),
    };
  }
}

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

class FoReportsScreen extends StatefulWidget {
  @override
  _FoReportsScreenState createState() => _FoReportsScreenState();
}

class _FoReportsScreenState extends State<FoReportsScreen> {
  final ConnectivityHandler connectivityHandler = ConnectivityHandler();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _userName = TextEditingController();
  String searchQuery = '';
  List<Project> projects = [];
  List<FieldOfficerPatrol> schedules = [];
  bool isLoading = true;
  int? intOrganizationId;
  String selectedDateRange = '0'; // Default to '0' for today
  String _selectedProjectId = ''; // Keep it as String
  Map<String, Map<String, List<FieldOfficerPatrol>>>
      groupedFieldOfficerPatrols = {};

  String _apkUrl = 'http://www.corenuts.com/ajna-app-release.apk';
  bool _isDownloading = false; // Add downloading state
  double _downloadProgress = 0.0; // Add download progress

  int _currentPage = 0;
  int _pageSize = 14;

  bool isLoadingMore = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();

    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    bool isConnected = await connectivityHandler.checkConnectivity(context);
    if (isConnected) {
      // Proceed with other initialization steps if connected
      intOrganizationId = await Util.getOrganizationId();

      _checkForUpdate();
      _fetchProjects(intOrganizationId!);
      _scrollController.addListener(_scrollListener);
      fetchReportData(isLoadingMore: true);
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !isLoadingMore) {
      _currentPage += 1;
      _loadMoreTransactions();
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (isLoadingMore) return;

    setState(() {
      isLoadingMore = true;
    });

    try {
      await fetchReportData(isLoadingMore: true);
    } catch (e) {
      print('Error loading more transactions: $e');
    } finally {
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  Future<void> _fetchProjects(int organizationId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiService.fetchOrgProjects(organizationId);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          projects = data.map((project) => Project.fromJson(project)).toList();
          if (projects.isNotEmpty) {
            // selectedProjectId = projects.first.projectId;
            // fetchReportData(); // Fetch report data for today by default
          }
          isLoading = false;
        });
      } else {
        _handleError(
          'Failed to load projects. Please try again later.',
          response.statusCode,
        );
      }
    } catch (e) {
      _handleError('Error fetching projects. Please try again later.', e);
    }
  }

  Future<void> fetchReportData({bool isLoadingMore = false}) async {
    if (!isLoadingMore) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      print("Organization ID: $intOrganizationId");
      print("Project ID: $_selectedProjectId");
      print("Selected Date Range: $selectedDateRange");

      final response = await ApiService.fetchFieldOfficerPatrolReports(
        intOrganizationId!,
        _selectedProjectId,
        selectedDateRange,
        _currentPage,
        _pageSize,
        searchQuery,
      );

      print("API Response Status Code: ${response.statusCode}");
      print("API Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);

        print("Decoded Response Type: ${decodedResponse.runtimeType}");
        print("Decoded Response: $decodedResponse");

        List<dynamic> reportData = [];

        if (decodedResponse is List) {
          // ✅ If response is a list, use it directly
          reportData = decodedResponse;
        } else if (decodedResponse is Map<String, dynamic>) {
          // ✅ If response is an object, check if it contains a list
          if (decodedResponse.containsKey('data') &&
              decodedResponse['data'] is List) {
            reportData = decodedResponse['data'];
          } else if (decodedResponse.containsKey('records') &&
              decodedResponse['records'] is List) {
            // 🔹 Alternative key check (e.g., if the data is under "records")
            reportData = decodedResponse['records'];
          } else {
            throw Exception("Unexpected API response format. No list found.");
          }
        } else {
          throw Exception("Invalid API response format.");
        }

        setState(() {
          if (isLoadingMore) {
            schedules.addAll(reportData
                .map((item) => FieldOfficerPatrol.fromJson(item))
                .toList());
          } else {
            schedules = reportData
                .map((item) => FieldOfficerPatrol.fromJson(item))
                .toList();
          }
          groupedFieldOfficerPatrols =
              _groupSchedulesByDateAndLocation(schedules);
        });
      } else {
        _handleError(
          'Failed to load report data. Please try again later.',
          response.statusCode,
        );
      }
    } catch (e) {
      print("Error: $e"); // Print the error for debugging
      _handleError('Failed to load report data. Please try again later.', 500);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Map<String, Map<String, List<FieldOfficerPatrol>>>
      _groupSchedulesByDateAndLocation(List<FieldOfficerPatrol> schedules) {
    Map<String, Map<String, List<FieldOfficerPatrol>>> grouped = {};
    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (var schedule in schedules) {
      String date;
      if (schedule.createdDate == null) {
        date = todayDate;
      } else {
        date = DateFormat('yyyy-MM-dd').format(schedule.createdDate);
      }
      String projectName = schedule.projectName;

      if (!grouped.containsKey(date)) {
        grouped[date] = {};
      }
      if (!grouped[date]!.containsKey(projectName)) {
        grouped[date]![projectName] = [];
      }
      grouped[date]![projectName]!.add(schedule);
    }
    return grouped;
  }

  void _handleError(String message, dynamic error) {
    ErrorHandler.handleError(context, message, 'Error: $error');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void viewImage(BuildContext context, FieldOfficerPatrol schedule,
      String imageType) async {
    String? imageUrl =
        (imageType == 'in') ? schedule.inImageUrl : schedule.outImageUrl;
    DateTime? date = (imageType == 'in') ? schedule.inTime : schedule.outTime;

    if (imageUrl == null || imageUrl.isEmpty) {
      _handleError('Image URL is missing for this schedule.', null);
      return;
    }

    if (date == null) {
      _handleError('Date is missing for this schedule.', null);
      return;
    }

    var imageResponse = await ApiService.FodownloadImage(
      projectName: schedule.projectName,
      date:
          date.toIso8601String(), // Sending the correct date based on imageType
      userName: schedule.userName,
      phoneNumber: schedule.phoneNumber,
      imageUrl: imageUrl,
    );

    if (imageResponse.statusCode == 200) {
      var imageData = imageResponse.bodyBytes;
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
    _currentPage = 0;
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

     await Util.installApk(savePath);
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

  final DateFormat formatter = DateFormat('dd MMM yyyy, hh:mm a');

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
              'FO Report',
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
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
                          title: const Text(
                            "Filters",
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
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
                            const SizedBox(height: 5),
                            CustomDateRangePicker(
                              onDateRangeSelected: (start, end, range) {
                                setState(() {
                                  selectedDateRange = range;
                                });
                                _currentPage = 0;
                                fetchReportData();
                              },
                              selectedDateRange: selectedDateRange,
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: DropdownButtonFormField2<String>(
                                decoration: InputDecoration(
                                  labelText: 'Select Project',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                        color: Color.fromRGBO(8, 101, 145, 1),
                                        width: 1.5),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                        color: Color.fromRGBO(6, 73, 105, 1),
                                        width: 2),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12.0,
                                    horizontal: 16.0,
                                  ),
                                ),
                                value: _selectedProjectId.isNotEmpty
                                    ? _selectedProjectId
                                    : '',
                                isExpanded: true,
                                hint: const Text(
                                  'Select a Project',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: '',
                                    child: Text(
                                      'All',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color.fromARGB(255, 80, 79, 79),
                                      ),
                                    ),
                                  ),
                                  ...projects.map<DropdownMenuItem<String>>(
                                      (Project project) {
                                    return DropdownMenuItem<String>(
                                      value: project.projectId.toString(),
                                      child: Text(
                                        project.projectName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color:
                                              Color.fromARGB(255, 80, 79, 79),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (String? value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedProjectId = value;
                                    });
                                    _currentPage = 0;
                                    fetchReportData();
                                  }
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select a project';
                                  }
                                  return null;
                                },
                                dropdownStyleData: DropdownStyleData(
                                  maxHeight: 300,
                                  width:
                                      MediaQuery.of(context).size.width * 0.9,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10.0),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        border: Border.all(
                                          color: Color.fromRGBO(6, 73, 105,
                                              1), // Border color applied here
                                          width:
                                              1.0, // Border width, adjust as needed
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.1),
                                            spreadRadius: 2,
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: TextField(
                                        controller: _userName,
                                        decoration: const InputDecoration(
                                          hintText: 'User Name',
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(fontSize: 14),
                                          prefixIcon: Icon(Icons.search,
                                              color: Color.fromRGBO(
                                                  6, 73, 105, 1)),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            searchQuery = value;
                                            _currentPage = 0;
                                            fetchReportData();
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
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: groupedFieldOfficerPatrols.length,
                    itemBuilder: (context, index) {
                      String date =
                          groupedFieldOfficerPatrols.keys.elementAt(index);
                      Map<String, List<FieldOfficerPatrol>>
                          schedulesByLocation =
                          groupedFieldOfficerPatrols[date]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Date: $date',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Column(
                            children: schedulesByLocation.entries
                                .map((locationEntry) {
                              String location = locationEntry.key;
                              List<FieldOfficerPatrol> patrolList =
                                  locationEntry.value;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 12.0),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          color: Color.fromRGBO(
                                              6, 73, 105, 1), // Updated color
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          location,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color.fromRGBO(6, 73, 105,
                                                1), // Updated text color
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: patrolList.map((schedule) {
                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        elevation: 2,
                                        child: ListTile(
                                          title: Text(
                                            schedule.userName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                          ),
                                          subtitle: Text(
                                            'In: ${formatter.format(schedule.inTime.toLocal())}'
                                            '\nOut: ${schedule.outTime != null ? formatter.format(schedule.outTime!.toLocal()) : "N/A"}',
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (schedule.inImageUrl != null &&
                                                  schedule
                                                      .inImageUrl!.isNotEmpty)
                                                IconButton(
                                                  icon: const Icon(Icons.image,
                                                      color: Colors.blue),
                                                  onPressed: () {
                                                    viewImage(context, schedule,
                                                        'in');
                                                  },
                                                ),
                                              if (schedule.outImageUrl !=
                                                      null &&
                                                  schedule
                                                      .outImageUrl!.isNotEmpty)
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.image_outlined,
                                                      color: Colors.red),
                                                  onPressed: () {
                                                    viewImage(context, schedule,
                                                        'out');
                                                  },
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
