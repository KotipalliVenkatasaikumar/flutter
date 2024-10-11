import 'dart:convert';

import 'package:ajna/screens/facility_management/reports_scan_schedule.dart';
import 'package:flutter/material.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/home_screen.dart';
import 'custom_date_picker.dart';

class User {
  final String username;
  final String status;
  final int userId;

  User({
    required this.username,
    required this.status,
    required this.userId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['userName'],
      status: json['overallStatus'],
      userId: json['userId'],
    );
  }
}

class UserScreen extends StatefulWidget {
  final int organizationId;
  final int projectId;
  final int qrgeneratorId;
  final String selectedDateRange;

  UserScreen({
    required this.organizationId,
    required this.projectId,
    required this.qrgeneratorId,
    required this.selectedDateRange,
  });

  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  List<User> users = [];
  bool isLoading = true;
  String selectedDateRange = '0';

  @override
  void initState() {
    super.initState();
    selectedDateRange = widget.selectedDateRange;
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    try {
      var response = await ApiService.fetchReportUserWise(
        widget.organizationId,
        widget.projectId,
        selectedDateRange,
        widget.qrgeneratorId,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          users = data.map((item) => User.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        // showErrorSnackBar('Failed to load locations: ${response.statusCode}');
        ErrorHandler.handleError(
          context,
          'Failed to load locations. Please try again later.',
          'Error load locations: ${response.statusCode}',
        );
      }
    } catch (e) {
      // showErrorSnackBar('Error fetching locations: $e');
      ErrorHandler.handleError(
        context,
        'Failed to load locations. Please try again later.',
        'Error load locations: $e',
      );
    }
  }

  // void showErrorSnackBar(String message) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(message),
  //       duration: const Duration(seconds: 3),
  //     ),
  //   );
  // }

  void _onDateRangeSelected(
      DateTime startDate, DateTime endDate, String range) {
    setState(() {
      selectedDateRange = range;
      isLoading = true;
    });
    fetchUsers();
  }

  void navigateToScheduleReportScreen(User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleReportScreen(
          organizationId: widget.organizationId,
          projectId: widget.projectId,
          qrgeneratorId: widget.qrgeneratorId,
          selectedDateRange: selectedDateRange,
          userId: user.userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: const Text('User Wise - QR Scan Report',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      body: Stack(
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
                      //   crossAxisCount: 3,
                      //   crossAxisSpacing: 10.0,
                      //   mainAxisSpacing: 10.0,
                      // ),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return GestureDetector(
                          onTap: () => navigateToScheduleReportScreen(
                              user), // Navigate to ScheduleReportScreen
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: user.status == 'Yes'
                                    ? Colors.green
                                    : Colors.red,
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'User Name: ',
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
                                          user.username,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16),
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
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(width: 4.0),
                                      Text(
                                        user.status,
                                        style: const TextStyle(
                                            color: Color.fromARGB(
                                                255, 255, 255, 255),
                                            fontSize: 18),
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
