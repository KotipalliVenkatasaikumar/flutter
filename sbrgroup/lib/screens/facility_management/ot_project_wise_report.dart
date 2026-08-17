import 'dart:convert';

import 'package:ajna/main.dart';
import 'package:ajna/screens/connectivity_handler.dart';
import 'package:ajna/screens/facility_management/ot_report.dart';
import 'package:ajna/screens/facility_management/schedule_with_report.dart';
import 'package:flutter/material.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/facility_management/reports_location.dart';
import 'package:ajna/screens/home_screen.dart';
import 'package:ajna/screens/util.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajna/theme/app_colors.dart';

import 'custom_date_picker.dart'; // Import the new LocationsScreen

class Project {
  final String projectName;
  final int? otCount;
  final int projectId;

  Project({
    required this.projectName,
    this.otCount,
    required this.projectId,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      projectName: json['projectName'],
      otCount: json['otCount'],
      projectId: json['projectId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projectName': projectName,
      'otCount': otCount,
      'projectId': projectId,
    };
  }
}

class OtReportProjectWise extends StatefulWidget {
  const OtReportProjectWise({super.key});
  @override
  _OtReportProjectWiseState createState() => _OtReportProjectWiseState();
}

class _OtReportProjectWiseState extends State<OtReportProjectWise> {
  final ConnectivityHandler connectivityHandler = ConnectivityHandler();
  List<Project> projects = [];
  bool isLoading = true;
  int? intOrganizationId;
  String selectedDateRange = '0'; // Initialize with '0' for today

  bool _isDialogShown = false; // Flag to track dialog visibility

  @override
  void initState() {
    super.initState();
    // initializeData();
    // _checkSession();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    bool isConnected = await connectivityHandler.checkConnectivity(context);
    if (isConnected) {
      // Proceed with other initialization steps if connected
      _checkSession();
      initializeData();
    }
  }

  Future<void> initializeData() async {
    intOrganizationId = await Util.getOrganizationId();
    await fetchProjects();
  }

  Future<void> fetchProjects() async {
    setState(() {
      isLoading = true;
    });

    try {
      var response = await ApiService.fetchOtReportProjectWise(
          intOrganizationId!, selectedDateRange);

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          projects = data.map((item) => Project.fromJson(item)).toList();
        });
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to load projects. Please try again later.',
          'Error fetching projects: ${response.statusCode}',
        );
      }
    } catch (e) {
      ErrorHandler.handleError(
        context,
        'Failed to load projects. Please try again later.',
        'Error fetching projects: $e',
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Future<void> fetchLocations(int projectId) async {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => LocationsScreen(
  //         organizationId: intOrganizationId!,
  //         projectId: projectId,
  //         selectedDateRange: selectedDateRange,
  //         qrgeneratorId: 0,
  //       ),
  //     ),
  //   );
  // }

  Future<void> fetchReportAndSchedule(int projectId, String projectName) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtReportScreen(
          projectId: projectId,
          selectedDateRange: selectedDateRange,
          projectName: projectName,
        ),
      ),
    );
  }

  // void showErrorSnackBar(String message) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(message),
  //       duration: const Duration(seconds: 3),
  //     ),
  //   );
  // }

  Future<void> _refreshData() async {
    _checkSession();
    await initializeData();
  }

  void _onDateRangeSelected(
      DateTime startDate, DateTime endDate, String range) {
    setState(() {
      isLoading = false;
      selectedDateRange = range;
    });

    fetchProjects().then((_) {
      setState(() {
        isLoading = false;
      });
    }).catchError((error) {
      setState(() {
        isLoading = false;
      });
      // showErrorSnackBar('Error fetching projects: $error');
      ErrorHandler.handleError(
        context,
        'Failed to fetching projects. Please try again later.',
        'Error fetching projects: $error',
      );
    });
  }

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

  @override
  Widget build(BuildContext context) {
    // Retrieve the arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, String>?;

    String title = args?['title'] ?? 'Default Title';
    String body = args?['body'] ?? 'Default Body';

    // Show a dialog with the notification details if it hasn't been shown
    if (!_isDialogShown && args != null) {
      Future.microtask(() {
        setState(() {
          _isDialogShown = true; // Set the flag to prevent multiple dialogs
        });
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _isDialogShown =
                        false; // Reset flag to allow future dialogs
                  });
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }
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
              'Project Wise - OT Report',
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
                      onDateRangeSelected: _onDateRangeSelected,
                      selectedDateRange:
                          selectedDateRange, // Pass the selectedDateRange
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView.builder(
                        // gridDelegate:
                        //     const SliverGridDelegateWithFixedCrossAxisCount(
                        //   crossAxisCount: 1,
                        //   crossAxisSpacing: 10.0,
                        //   mainAxisSpacing: 10.0,
                        // ),
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          final project = projects[index];
                          return GestureDetector(
                            onTap: () {
                              fetchReportAndSchedule(
                                  project.projectId, project.projectName);
                            },
                            child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(255, 240, 240,
                                        240), // Light gray background
                                    borderRadius: BorderRadius.circular(10.0),
                                    border: Border.all(
                                      color: const Color.fromARGB(255, 200, 200,
                                          200), // Subtle border color
                                      width: 1.0,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Project: ',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(width: 4.0),
                                          Expanded(
                                            child: Text(
                                              project.projectName,
                                              style: const TextStyle(
                                                color: Colors
                                                    .black87, // Darker text color for better contrast
                                                fontSize: 14,
                                              ),
                                              softWrap: true,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8.0),
                                      Row(
                                        children: [
                                          const Text(
                                            'OT Count: ',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 4.0),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8.0, vertical: 4.0),
                                            decoration: BoxDecoration(
                                              color: const Color.fromARGB(
                                                  255,
                                                  76,
                                                  175,
                                                  80), // Green background for OT count
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                            ),
                                            child: Text(
                                              project.otCount?.toString() ??
                                                  '0', // Default to '0' if null
                                              style: const TextStyle(
                                                color: Colors
                                                    .white, // White text for contrast
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )),
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
      bottomNavigationBar: Container(
        padding: EdgeInsets.zero,
        color: AppColors.primary,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.home, size: 16),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          const HomeScreen()), // Replace with your actual Profile Screen
                );
              },
              padding: EdgeInsets.zero,
              color: Colors.white,
            ),
            const Text(
              'Home',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
