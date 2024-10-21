import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/facility_management/reports_users.dart';
import 'package:ajna/screens/home_screen.dart';
import 'custom_date_picker.dart';

class Location {
  final String locationName;
  final String status;
  final int qrgeneratorId;
  Location({
    required this.locationName,
    required this.status,
    required this.qrgeneratorId,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      locationName: json['location'],
      status: json['overallStatus'],
      qrgeneratorId: json['qrgeneratorId'],
    );
  }
}

class LocationsScreen extends StatefulWidget {
  final int organizationId;
  final int projectId;
  final String selectedDateRange;
  final int qrgeneratorId; // Declare qrgeneratorId here
  LocationsScreen({
    required this.organizationId,
    required this.projectId,
    required this.selectedDateRange,
    required this.qrgeneratorId, // Initialize qrgeneratorId in the constructor
  });

  @override
  _LocationsScreenState createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  List<Location> locations = [];
  bool isLoading = true;
  late String selectedDateRange;

  @override
  void initState() {
    super.initState();
    selectedDateRange = widget.selectedDateRange;
    fetchLocations();
  }

  Future<void> fetchLocations() async {
    try {
      var response = await ApiService.fetchReportLocationWise(
        widget.organizationId,
        widget.projectId,
        selectedDateRange,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          locations = data.map((item) => Location.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to load locations. Please try again later.',
          'Error load locations: ${response.statusCode}',
        );
      }
    } catch (e) {
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

  void navigateToUserScreen(int qrgeneratorId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserScreen(
          organizationId: widget.organizationId,
          projectId: widget.projectId,
          qrgeneratorId: qrgeneratorId,
          selectedDateRange: selectedDateRange,
        ),
      ),
    );
  }

  void updateDateRangeAndFetchData(String newDateRange) {
    setState(() {
      selectedDateRange = newDateRange; // Update the selectedDateRange state
    });
    fetchLocations(); // Fetch data with the updated selectedDateRange
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: const Text('Location Wise - QR Scan Report',
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
                    onDateRangeSelected: (start, end, range) {
                      updateDateRangeAndFetchData(
                          range); // Update date range and fetch data when changed
                    },
                    selectedDateRange: selectedDateRange,
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
                      itemCount: locations.length,
                      itemBuilder: (context, index) {
                        final location = locations[index];
                        return GestureDetector(
                          onTap: () => navigateToUserScreen(location
                              .qrgeneratorId), // Pass qrgeneratorId when tapping
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: location.status == 'Yes'
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
                                        'Location: ',
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
                                          location.locationName,
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
                                    //mainAxisAlignment: MainAxisAlignment.center,
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
                                        location.status,
                                        style: const TextStyle(
                                            color: Color.fromARGB(
                                                255, 255, 255, 255),
                                            fontSize: 18),
                                        textAlign: TextAlign.center,
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
