import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/facility_management/ImageFullScreen%20.dart';
import 'package:ajna/screens/home_screen.dart';
import 'custom_date_picker.dart';

class Schedule {
  final String scheduleTime;
  final String status;
  final String createdDate;
  final String projectName;
  final String userName;
  final String imageUrl;
  final String phoneNumber;

  Schedule({
    required this.scheduleTime,
    required this.status,
    required this.createdDate,
    required this.projectName,
    required this.userName,
    required this.imageUrl,
    required this.phoneNumber,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      scheduleTime: json['scheduleTime'],
      status: json['status'],
      createdDate: json['createdDate'],
      projectName: json['projectName'],
      userName: json['userName'],
      imageUrl: json['imageUrl'] ?? '',
      phoneNumber: json['phoneNumber'],
    );
  }
}

class ScheduleReportScreen extends StatefulWidget {
  final int organizationId;
  final int projectId;
  final int qrgeneratorId;
  final String selectedDateRange;
  final int userId;

  ScheduleReportScreen({
    required this.organizationId,
    required this.projectId,
    required this.qrgeneratorId,
    required this.selectedDateRange,
    required this.userId,
  });

  @override
  _ScheduleReportScreenState createState() => _ScheduleReportScreenState();
}

class _ScheduleReportScreenState extends State<ScheduleReportScreen> {
  List<Schedule> schedules = [];
  Map<String, List<Schedule>> groupedSchedules = {};
  bool isLoading = true;
  late String selectedDateRange;
  String userName = '';
  String location = '';
  int scannedCount = 0;
  int unScannedCount = 0;
  String overAllStatus = '';

  @override
  void initState() {
    super.initState();
    selectedDateRange = widget.selectedDateRange;
    fetchSchedules();
  }

  Future<void> fetchSchedules() async {
    try {
      var response = await ApiService.fetchReportScheduleWise(
        widget.organizationId,
        widget.projectId,
        selectedDateRange,
        widget.qrgeneratorId,
        widget.userId,
      );

      if (response.statusCode == 200) {
        var responseBody = jsonDecode(response.body);
        print('Response body: $responseBody'); // Debug print

        if (responseBody is Map<String, dynamic> &&
            responseBody['reportList'] is List) {
          List<dynamic> data = responseBody['reportList'];
          setState(() {
            schedules = data.map((item) => Schedule.fromJson(item)).toList();
            userName = data.isNotEmpty ? data.first['userName'] : '';
            location = data.isNotEmpty ? data.first['location'] : '';
            scannedCount = responseBody['scannedCount'];
            unScannedCount = responseBody['unScannedCount'];
            overAllStatus = responseBody['overAllStatus'];
            groupedSchedules = _groupSchedulesByDate(schedules);
            isLoading = false;
          });
        } else {
          // showErrorSnackBar('Unexpected response format');
          setState(() {
            isLoading = false;
          });
        }
      } else {
        // showErrorSnackBar('Failed to load schedules: ${response.statusCode}');
        ErrorHandler.handleError(
          context,
          'Failed to fetching schedules. Please try again later.',
          'Error load schedules: ${response.statusCode}',
        );
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      // showErrorSnackBar('Error fetching schedules: $e');
      ErrorHandler.handleError(
        context,
        'Failed to fetching schedules. Please try again later.',
        'Error fetching schedules: $e',
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Map<String, List<Schedule>> _groupSchedulesByDate(List<Schedule> schedules) {
    Map<String, List<Schedule>> grouped = {};
    for (var schedule in schedules) {
      String date = schedule.createdDate.split('T').first;
      if (grouped[date] == null) {
        grouped[date] = [];
      }
      grouped[date]!.add(schedule);
    }
    return grouped;
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
    fetchSchedules();
  }

  void sendApiCall(Schedule schedule, BuildContext context) async {
    var imageResponse = await ApiService.downloadImage(
      projectName: schedule.projectName,
      date: schedule.createdDate,
      userName: schedule.userName,
      phoneNumber: schedule.phoneNumber,
      imageUrl: schedule.imageUrl,
    );

    if (imageResponse.statusCode == 200) {
      print('Image downloaded successfully');
      var imageData = imageResponse.bodyBytes; // Get image bytes
      // Navigate to the full image screen to display the image blob
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullImageScreen(imageData: imageData),
        ),
      );
    } else {
      print('Failed to download image: ${imageResponse.statusCode}');
      // Handle error appropriately
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: const Text('Schedule Report',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
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
                    selectedDateRange: selectedDateRange,
                  ),
                  const SizedBox(height: 15),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Container(
                        width: MediaQuery.of(context)
                            .size
                            .width, // Set the desired width here
                        decoration: BoxDecoration(
                          color: Colors
                              .white, // Set the desired background color here
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 3,
                              blurRadius: 5,
                              offset:
                                  Offset(0, 2), // changes position of shadow
                            ),
                          ],
                          borderRadius: BorderRadius.circular(
                              10), // Optional: add border radius
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(15, 16, 15, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'User Name:',
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 48, 133, 141),
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Location:',
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 48, 133, 141),
                                      fontSize: 16,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      location,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.right,
                                      softWrap: true,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Scanned Count:',
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 48, 133, 141),
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '$scannedCount',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Not Scanned Count:',
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 48, 133, 141),
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '$unScannedCount',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  //const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: groupedSchedules.keys.length,
                      itemBuilder: (context, index) {
                        String date = groupedSchedules.keys.elementAt(index);
                        List<Schedule> schedulesForDate =
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
                              GridView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3, // Updated to 3 columns
                                  crossAxisSpacing: 10.0,
                                  mainAxisSpacing: 10.0,
                                ),
                                itemCount: schedulesForDate.length,
                                itemBuilder: (context, index) {
                                  final schedule = schedulesForDate[index];

                                  return GestureDetector(
                                    onTap: () {
                                      if (schedule.status == 'On Time') {
                                        // Trigger API call when item is clicked
                                        sendApiCall(schedule,
                                            context); // Pass both schedule and context
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: schedule.status == 'On Time'
                                            ? Colors.green
                                            : Colors.red,
                                        borderRadius:
                                            BorderRadius.circular(10.0),
                                      ),
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.schedule,
                                                color: Colors.white,
                                                size: 14.0,
                                              ),
                                              const SizedBox(width: 4.0),
                                              Text(
                                                schedule.scheduleTime,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8.0),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                schedule.status,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8.0),
                                          if (schedule.status == 'On Time') ...[
                                            LayoutBuilder(
                                              builder: (context, constraints) {
                                                // Get screen width and height
                                                double screenWidth =
                                                    MediaQuery.of(context)
                                                        .size
                                                        .width;
                                                double screenHeight =
                                                    MediaQuery.of(context)
                                                        .size
                                                        .height;

                                                // Adjust font size and padding based on screen size
                                                double fontSize =
                                                    screenWidth < 600 ? 10 : 12;
                                                double padding =
                                                    screenWidth < 600
                                                        ? 6.0
                                                        : 8.0;
                                                double margin =
                                                    screenWidth < 600
                                                        ? 2.0
                                                        : 4.0;

                                                return Container(
                                                  margin: EdgeInsets.symmetric(
                                                      vertical: margin),
                                                  padding:
                                                      EdgeInsets.all(padding),
                                                  decoration: BoxDecoration(
                                                    color: const Color.fromARGB(
                                                            255, 103, 180, 243)
                                                        .withOpacity(0.7),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 2,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.2),
                                                        blurRadius: 4.0,
                                                        offset:
                                                            const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Text(
                                                    'View Image',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: fontSize,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
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
