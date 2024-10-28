import 'dart:convert';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/facility_management/custom_date_picker.dart';
import 'package:ajna/screens/home_screen.dart';
import 'package:ajna/screens/util.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class Attendance {
  final int count;
  final String attendanceStatus;
  final String? createdDate;
  final int lateComerCount;
  final int earlyLeaverCount;

  Attendance({
    required this.count,
    required this.attendanceStatus,
    required this.createdDate,
    required this.lateComerCount,
    required this.earlyLeaverCount,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      count: json['count'] ?? 0,
      attendanceStatus: json['attendanceStatus'] ?? 'Unknown',
      createdDate: json['createdDate'] ?? 'N/A',
      lateComerCount: json['lateComerCount'] ?? 0,
      earlyLeaverCount: json['earlyLeaverCount'] ?? 0,
    );
  }
}

class ShiftTiming {
  final int id;
  final String commonRefKey;
  final String commonRefValue;

  ShiftTiming({
    required this.id,
    required this.commonRefKey,
    required this.commonRefValue,
  });

  factory ShiftTiming.fromJson(Map<String, dynamic> json) {
    return ShiftTiming(
      id: json['id'],
      commonRefKey: json['commonRefKey'],
      commonRefValue: json['commonRefValue'],
    );
  }
}

class Location {
  final int id;
  final String location;

  Location({required this.id, required this.location});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'],
      location: json['location'],
    );
  }
}

class AttendanceRecord {
  final int attendanceId;
  final int userId;
  final String userName;
  final DateTime? attendanceInDate; // Nullable to handle missing data
  final DateTime? attendanceOutDate; // Nullable to handle missing data
  final String? attendanceInTime; // Nullable to handle missing data
  final String? attendanceOutTime; // Nullable to handle missing data
  final int? logInLocationId;
  final int? logOutLocationId;
  final String? logInLocationName;
  final String? logOutLocationName;

  final String attendanceStatus;
  final int shiftId;
  final String commonRefKey;
  final String commonRefValue;
  final int employeeId;

  AttendanceRecord({
    required this.attendanceId,
    required this.userId,
    required this.userName,
    this.attendanceInDate,
    this.attendanceOutDate,
    this.attendanceInTime,
    this.attendanceOutTime,
    this.logInLocationId,
    this.logOutLocationId,
    this.logInLocationName,
    this.logOutLocationName,
    required this.attendanceStatus,
    required this.shiftId,
    required this.commonRefKey,
    required this.commonRefValue,
    required this.employeeId,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      attendanceId: json['attendanceId'],
      userId: json['userId'],
      userName: json['userName'],
      attendanceInDate: json['attendanceInDate'] != null
          ? DateTime.parse(json['attendanceInDate'])
          : null,
      attendanceOutDate: json['attendanceOutDate'] != null
          ? DateTime.parse(json['attendanceOutDate'])
          : null,
      attendanceInTime: json['attendanceInTime'],
      attendanceOutTime: json['attendanceOutTime'],
      logInLocationId: json['logInLocationId'],
      logOutLocationId: json['logOutLocationId'],
      logInLocationName: json['logInLocationName'],
      logOutLocationName: json['logOutLocationName'],
      attendanceStatus: json['attendanceStatus'],
      shiftId: json['shiftId'],
      commonRefKey: json['commonRefKey'],
      commonRefValue: json['commonRefValue'],
      employeeId: json['employeeId'],
    );
  }
}

class AttendanceReportScreen extends StatefulWidget {
  @override
  _AttendanceReportScreenState createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  bool isLoading = true;
  List<Attendance> attendanceRecords = [];
  List<AttendanceRecord> attendaceReportDetails = [];
  String selectedDateRange = '0';
  int? organizationId;
  int? userId;
  List<Location> locations = [];
  List<ShiftTiming> shifts = [];
  String selectedLocation = '0';
  String selectedShift = '0';
  String attendanceStatus = '';
  String searchQuery = '';

  String page = '0';
  int size = 10;
  final ScrollController _scrollController = ScrollController();
  late int _itemCount;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      organizationId = await Util.getOrganizationId();
      userId = await Util.getUserId();
      fetchAttendanceDashboard();
      fetchShiftData();
      fetchAttendanceLocation(organizationId!);
    } catch (error) {
      ErrorHandler.handleError(
        context,
        'Failed to initialize data. Please try again later.',
        'Initialization error: $error',
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      setState(() {
        size += 10; // Increase the size by 10 each time
      });

      // Check if the list has records to get the last attendance status
      String statusToFetch = attendaceReportDetails.isNotEmpty
          ? attendaceReportDetails
              .last.attendanceStatus // Get the last record's attendance status
          : "Present"; // Default status if the list is empty

      fetchAttendanceDetails(statusToFetch, '');
    }
  }

  Future<void> fetchShiftData() async {
    try {
      final response = await ApiService.fetchshiftData();
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          shifts = jsonData
              .map<ShiftTiming>((json) => ShiftTiming.fromJson(json))
              .toList();
        });
      } else {
        throw Exception('Failed to load shifts');
      }
    } catch (error) {
      ErrorHandler.handleError(
        context,
        'Failed to load shift data.',
        'Shift data error: $error',
      );
    }
  }

  Future<void> fetchAttendanceLocation(int organizationId) async {
    try {
      final response = await ApiService.fetchAttendanceLocation(organizationId);
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          locations = jsonData
              .map<Location>((json) => Location.fromJson(json))
              .toList();
        });
      } else {
        throw Exception('Failed to load locations');
      }
    } catch (error) {
      ErrorHandler.handleError(
        context,
        'Failed to load location data.',
        'Location data error: $error',
      );
    }
  }

  Future<void> fetchAttendanceDashboard() async {
    if (organizationId == null || userId == null) return;

    // Reset attendance details before fetching new dashboard data
    setState(() {
      attendaceReportDetails = [];
    });

    try {
      var response = await ApiService.fetchAttendanceReport(
        userId!,
        organizationId!,
        selectedLocation,
        selectedShift,
        selectedDateRange,
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          List<dynamic> jsonData = jsonDecode(response.body);
          print('Decoded JSON data: $jsonData'); // Logs decoded data structure

          // Convert JSON data to attendance records
          setState(() {
            attendanceRecords =
                jsonData.map((json) => Attendance.fromJson(json)).toList();
          });
        } catch (parsingError) {
          ErrorHandler.handleError(
            context,
            'Error parsing attendance data. Please check the data format.',
            'Parsing error: $parsingError, Response: ${response.body}',
          );
        }
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to fetch attendance data. Status code: ${response.statusCode}',
          'Response body: ${response.body}',
        );
      }
    } catch (error) {
      ErrorHandler.handleError(
        context,
        'Failed to fetch attendance data. Please try again later.',
        'General error: $error',
      );
    }
  }

  Future<void> fetchAttendanceDetails(
      String attendanceStatus, String? userName) async {
    if (userId == null) return;

    try {
      var response = await ApiService.fetchAttendanceDetails(
        userId!,
        userName ?? '',
        attendanceStatus,
        selectedLocation,
        selectedShift,
        selectedDateRange,
        page,
        size,
      );

      if (response.statusCode == 200) {
        try {
          // Attempt to decode the JSON response
          Map<String, dynamic> jsonData = jsonDecode(response.body);
          print('Decoded JSON data: $jsonData'); // Logs decoded data structure

          // Check if "records" key exists and extract data
          if (jsonData.containsKey('records') && jsonData['records'] is List) {
            setState(() {
              // Map the records and filter out nulls, ensuring non-null type
              attendaceReportDetails = (jsonData['records'] as List)
                  .map<AttendanceRecord?>((record) {
                    try {
                      return AttendanceRecord.fromJson(record);
                    } catch (e) {
                      print('Error parsing record: $record\nError: $e');
                      return null; // Return null if parsing fails
                    }
                  })
                  .where((record) => record != null) // Filter out nulls
                  .cast<AttendanceRecord>() // Cast to List<AttendanceRecord>
                  .toList();

              // You can also access pagination data here if needed
              int totalRecords = jsonData['totalRecords'] ?? 0;
              print('Total Records: $totalRecords'); // Use this as needed
            });
          } else {
            ErrorHandler.handleError(
              context,
              'No attendance records found or incorrect data format.',
              'Response body: ${response.body}',
            );
          }
        } catch (parsingError) {
          print('Parsing error: $parsingError');
          ErrorHandler.handleError(
            context,
            'Error parsing attendance details. Please check the data format.',
            'Parsing error: $parsingError, Response: ${response.body}',
          );
        }
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to fetch attendance details. Status code: ${response.statusCode}',
          'Response body: ${response.body}',
        );
      }
    } catch (error) {
      ErrorHandler.handleError(
        context,
        'Failed to fetch attendance details. Please try again later.',
        'General error: $error',
      );
    } finally {}
  }

  void _onDateRangeSelected(
      DateTime startDate, DateTime endDate, String range) {
    setState(() {
      selectedDateRange = range;
      isLoading = true;
    });

    fetchAttendanceDashboard().catchError((error) {
      ErrorHandler.handleError(
        context,
        'Failed to fetch attendance data.',
        'Error fetching data: $error',
      );
    }).whenComplete(() {
      setState(() => isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: Text(
          'Attendance Report',
          style: TextStyle(
            fontSize: screenWidth > 600 ? 22 : 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 30, 10, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        children: [
                          // Location Dropdown
                          Expanded(
                            child: DropdownButtonFormField2<String>(
                              decoration: InputDecoration(
                                labelText: 'Location',
                                labelStyle: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: Icon(
                                  Icons.location_on,
                                  color: Color.fromARGB(255, 23, 158, 142),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                  horizontal: 12.0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color.fromARGB(255, 41, 221, 200),
                                    width: 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color.fromARGB(255, 23, 158, 142),
                                    width: 2.0,
                                  ),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              alignment: AlignmentDirectional.bottomStart,
                              value: selectedLocation != '0'
                                  ? selectedLocation
                                  : null,
                              items: locations.map((location) {
                                return DropdownMenuItem<String>(
                                  value: location.id.toString(),
                                  child: Text(
                                    location.location,
                                    style: TextStyle(color: Colors.black87),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedLocation = value!;
                                });
                                fetchAttendanceDashboard();
                              },
                              isExpanded: true,
                              dropdownStyleData: DropdownStyleData(
                                maxHeight: 250,
                                width: MediaQuery.of(context).size.width / 2 -
                                    20, // Adjust width here
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.0),
                                  color: Colors.white,
                                  boxShadow: [
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
                          const SizedBox(width: 16),
                          // Shift Timing Dropdown
                          Expanded(
                            child: DropdownButtonFormField2<String>(
                              decoration: InputDecoration(
                                labelText: 'Shift',
                                labelStyle: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: Icon(
                                  Icons.access_time,
                                  color: Color.fromARGB(255, 23, 158, 142),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                  horizontal: 12.0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color.fromARGB(255, 41, 221, 200),
                                    width: 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color.fromARGB(255, 23, 158, 142),
                                    width: 2.0,
                                  ),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              alignment: AlignmentDirectional.bottomStart,
                              value:
                                  selectedShift != '0' ? selectedShift : null,
                              items: shifts.map((shift) {
                                return DropdownMenuItem<String>(
                                  value: shift.id.toString(),
                                  child: Text(
                                    '${shift.commonRefKey} - ${shift.commonRefValue}',
                                    style: TextStyle(color: Colors.black87),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedShift = value!;
                                });
                                fetchAttendanceDashboard();
                              },
                              isExpanded: true,
                              dropdownStyleData: DropdownStyleData(
                                maxHeight: 250,
                                width: MediaQuery.of(context).size.width / 2 -
                                    20, // Adjust width here
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),
                    CustomDateRangePicker(
                      onDateRangeSelected: _onDateRangeSelected,
                      selectedDateRange: selectedDateRange,
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              fetchAttendanceDetails("Logged_In", '');
                            },
                            child: Card(
                              color: Colors.green.shade100,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Present',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${attendanceRecords.firstWhere((element) => element.attendanceStatus == 'Logged_In', orElse: () => Attendance(count: 0, attendanceStatus: 'Logged_In', createdDate: null, lateComerCount: 0, earlyLeaverCount: 0)).count}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              fetchAttendanceDetails('Not_Logged_In', '');
                            },
                            child: Card(
                              color: Colors.red.shade100,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Absent',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${attendanceRecords.firstWhere((element) => element.attendanceStatus == 'Not_Logged_In', orElse: () => Attendance(count: 0, attendanceStatus: 'Not_Logged_In', createdDate: null, lateComerCount: 0, earlyLeaverCount: 0)).count}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search by name...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 10),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  searchQuery =
                                      value; // Update the search query
                                });
                                fetchAttendanceDetails(
                                    attendaceReportDetails
                                        .first.attendanceStatus,
                                    searchQuery); // Call API with search query
                              },
                            ),
                          ),
                          const SizedBox(
                              width:
                                  8.0), // Space between the TextField and Button
                          ElevatedButton(
                            onPressed: () {
                              fetchAttendanceDetails('', '');
                            },
                            child: Text('All Attendance'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                        height:
                            16.0), // Space between the search row and the list
                    // Flexible ListView to adapt to available space
                    Container(
                      height: screenHeight - 400, // Adjust height as needed
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: attendaceReportDetails.length,
                        itemBuilder: (context, index) {
                          final record = attendaceReportDetails[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 16.0),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        record.userName,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        record.attendanceStatus,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: record.attendanceStatus ==
                                                  "Logged_In"
                                              ? Colors.green
                                              : Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6.0),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.login,
                                              color: Colors.blueAccent,
                                              size: 18),
                                          const SizedBox(width: 2),
                                          Text(
                                            'In: ${record.attendanceInTime} (${record.logInLocationName})',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.black54),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.logout,
                                              color: Colors.redAccent,
                                              size: 18),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Out: ${record.attendanceOutTime} (${record.logOutLocationName})',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.black54),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6.0),
                                  Divider(color: Colors.grey[300]),
                                  const SizedBox(height: 6.0),
                                  Text(
                                    'In Date: ${record.attendanceInDate != null ? DateFormat('yyyy-MM-dd').format(record.attendanceInDate!) : "Not Available"}',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.black54),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    'Out Date: ${record.attendanceOutDate != null ? DateFormat('yyyy-MM-dd').format(record.attendanceOutDate!) : "Not Available"}',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
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
              color: Colors.white,
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
