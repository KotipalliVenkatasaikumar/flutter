import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/facility_management/qr_scanner.dart';
import 'package:ajna/screens/util.dart';
import 'package:url_launcher/url_launcher.dart'; // For launching URLs

class ScanSchedule {
  final String projectName;
  final String location;
  final String scheduleTime;
  final String status;
  final String userName;
  final int scheduleId;
  final bool isEnabled;

  ScanSchedule({
    required this.projectName,
    required this.location,
    required this.scheduleTime,
    required this.status,
    required this.userName,
    required this.scheduleId,
    required this.isEnabled,
  });

  factory ScanSchedule.fromJson(Map<String, dynamic> json, bool isEnabled) {
    String scheduleTimeStr = json['scheduleTime'];
    DateTime? scheduleTime;

    // Handle invalid time formats
    try {
      scheduleTime = DateFormat("HH:mm").parseStrict(scheduleTimeStr);
    } catch (e) {
      // Use a default time or handle it according to your logic
      scheduleTime = DateTime.now();
    }

    return ScanSchedule(
      projectName: json['projectName'],
      location: json['location'],
      scheduleTime: scheduleTimeStr,
      status: json['status'] ?? 'I', // Default to 'I' if status is missing
      userName: json['userName'],
      scheduleId: json['scheduleId'],
      isEnabled: isEnabled,
    );
  }
}

Future<List<ScanSchedule>> fetchScanSchedulesFromApi(
    BuildContext context, int userId) async {
  try {
    final response = await ApiService.fetchScanSchedules(userId);

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      DateFormat format = DateFormat("HH:mm"); // Assuming time format is HH:mm
      String formattedNow =
          format.format(DateTime.now()); // Formatted current time as HH:mm

      List<ScanSchedule> schedules = data.map((item) {
        DateTime? scheduleTime;
        try {
          scheduleTime = format.parse(item['scheduleTime']);
        } catch (e) {
          scheduleTime = DateTime.now(); // Or handle according to your logic
        }

        Duration difference =
            scheduleTime.difference(format.parse(formattedNow));
        bool isEnabled =
            difference.inMinutes <= 10 && difference.inMinutes >= -10;

        return ScanSchedule.fromJson(item, isEnabled);
      }).toList();

      return schedules;
    } else {
      ErrorHandler.handleError(
        context,
        'Failed to load QR data. Please try again later.',
        'Failed to load QR data: ${response.statusCode}',
      );
      return [];
    }
  } catch (e) {
    ErrorHandler.handleError(
      context,
      'Failed to load QR data. Please try again later.',
      'Failed to load QR data: $e',
    );
    return [];
  }
}

class ScanScheduleScreen extends StatefulWidget {
  @override
  _ScanScheduleScreenState createState() => _ScanScheduleScreenState();
}

class _ScanScheduleScreenState extends State<ScanScheduleScreen> {
  Future<List<ScanSchedule>>? futureScanSchedules;
  int? userId;

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  Future<void> initializeData() async {
    userId = await Util.getUserId();
    if (userId != null) {
      setState(() {
        futureScanSchedules = fetchScanSchedulesFromApi(context, userId!);
      });
    } else {
      ErrorHandler.handleError(
        context,
        'User ID not found',
        'Failed to retrieve User ID',
      );
    }
  }

  Future<void> _refreshData() async {
    await initializeData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: const Text(
          'QR Schedule',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Center(
          child: FutureBuilder<List<ScanSchedule>>(
            future: futureScanSchedules,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text(
                  'No Schedules available',
                  style: TextStyle(
                    fontSize: 20.0, // Adjust the font size here
                    fontWeight: FontWeight.bold, // Example: make it bold
                    color: Color.fromRGBO(6, 73, 105,
                        1), // Set custom text color using Color.fromRGBO
                    // You can add more properties like fontFamily, letterSpacing, etc. if needed
                  ),
                );
              } else {
                // Group schedules by project name and location
                Map<String, Map<String, List<ScanSchedule>>> groupedSchedules =
                    {};

                snapshot.data!.forEach((schedule) {
                  if (!groupedSchedules.containsKey(schedule.projectName)) {
                    groupedSchedules[schedule.projectName] = {};
                  }
                  if (!groupedSchedules[schedule.projectName]!
                      .containsKey(schedule.location)) {
                    groupedSchedules[schedule.projectName]![schedule.location] =
                        [];
                  }
                  groupedSchedules[schedule.projectName]![schedule.location]!
                      .add(schedule);
                });

                return Scrollbar(
                  child: ListView(
                    padding: const EdgeInsets.all(10),
                    children: groupedSchedules.entries.map((projectEntry) {
                      String projectName = projectEntry.key;
                      Map<String, List<ScanSchedule>> locationSchedules =
                          projectEntry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Project Name
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              'Project: $projectName',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Schedules grouped by location
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                locationSchedules.entries.map((locationEntry) {
                              String location = locationEntry.key;
                              List<ScanSchedule> schedules =
                                  locationEntry.value;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Location Name
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Text(
                                      'Location: $location',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  // List of schedules for this location
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3, // Number of columns
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio:
                                          2, // Width to height ratio of each tile
                                    ),
                                    itemCount: schedules.length,
                                    itemBuilder: (context, index) {
                                      ScanSchedule schedule = schedules[index];
                                      bool isEnabled = schedule.isEnabled;

                                      return GestureDetector(
                                        onTap: isEnabled
                                            ? () {
                                                print(
                                                    'Schedule Time: ${schedule.scheduleTime}');
                                                print(
                                                    'Schedule Id: ${schedule.scheduleId}');
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        QrScannerScreen(
                                                      scheduleTime:
                                                          schedule.scheduleTime,
                                                      scheduleId:
                                                          schedule.scheduleId,
                                                      location:
                                                          schedule.location,
                                                      // Send the location to scan page
                                                    ),
                                                  ),
                                                );
                                              }
                                            : null,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isEnabled
                                                ? const Color.fromRGBO(
                                                    79, 142, 172, 1)
                                                : const Color.fromARGB(
                                                    255, 206, 202, 202),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.all(10),
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 5),
                                          child: Center(
                                            child: Text(
                                              schedule.scheduleTime,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isEnabled
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              }
            },
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
      bottomNavigationBar: Container(
        color: const Color.fromRGBO(6, 73, 105, 1),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'Powered by ',
                style: TextStyle(
                  color: Color.fromARGB(255, 230, 227, 227),
                  fontSize: 12,
                ),
              ),
              TextSpan(
                text: 'Core',
                style: const TextStyle(
                  color: Color.fromARGB(255, 37, 219, 9),
                  fontSize: 14,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    launch('https://www.corenuts.com');
                  },
              ),
              TextSpan(
                text: 'Nuts',
                style: const TextStyle(
                  color: Color.fromARGB(255, 221, 10, 10),
                  fontSize: 14,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    launch('https://www.corenuts.com');
                  },
              ),
              const TextSpan(
                text: ' Technologies',
                style: TextStyle(
                  color: Color.fromARGB(255, 230, 227, 227),
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}