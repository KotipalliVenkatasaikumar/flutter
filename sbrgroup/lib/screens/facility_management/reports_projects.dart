import 'dart:convert';

import 'package:ajna/screens/facility_management/schedule_with_report.dart';
import 'package:flutter/material.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/facility_management/reports_location.dart';
import 'package:ajna/screens/home_screen.dart';
import 'package:ajna/screens/util.dart';

import 'custom_date_picker.dart'; // Import the new LocationsScreen

class Project {
  final int projectId;
  final String projectName;
  final String status;

  Project({
    required this.projectId,
    required this.projectName,
    required this.status,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      projectId: json['projectId'],
      projectName: json['projectName'],
      status: json['overallStatus'],
    );
  }
}

class ReportsHomeScreen extends StatefulWidget {
  @override
  _ReportsHomeScreenState createState() => _ReportsHomeScreenState();
}

class _ReportsHomeScreenState extends State<ReportsHomeScreen> {
  List<Project> projects = [];
  bool isLoading = true;
  int? intOrganizationId;
  String selectedDateRange = '0'; // Initialize with '0' for today

  @override
  void initState() {
    super.initState();
    initializeData();
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
      var response = await ApiService.fetchReportProjectWise(
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

  Future<void> fetchReportAndSchedule(int projectId) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleReportsScreen(
          organizationId: intOrganizationId!,
          projectId: projectId,
          selectedDateRange: selectedDateRange,
          // qrgeneratorId: 0,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: const Text('Project Wise - QR Scan Report',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
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
                              fetchReportAndSchedule(project.projectId);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: project.status == 'Yes'
                                      ? Colors.green
                                      : Colors.red,
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    // const Text(
                                    //   'Project Name: ',
                                    //   style: TextStyle(
                                    //       color: Colors.black, fontSize: 14),
                                    //   textAlign: TextAlign.center,
                                    // ),
                                    // Text(
                                    //   project.projectName,
                                    //   style: const TextStyle(
                                    //       color: Colors.white, fontSize: 14),
                                    //   textAlign: TextAlign.center,
                                    // ),
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
                                                color: Colors.white,
                                                fontSize: 14),
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
                                          'Scan Status: ',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 4.0),
                                        Text(
                                          project.status,
                                          style: const TextStyle(
                                              color: Color.fromARGB(
                                                  255, 255, 255, 255),
                                              fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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
      bottomNavigationBar: Container(
        padding: EdgeInsets.zero,
        color: const Color.fromRGBO(6, 73, 105, 1),
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
