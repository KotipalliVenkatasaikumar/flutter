import 'package:flutter/material.dart';

class AttendanceReportScreen extends StatefulWidget {
  @override
  _AttendanceReportScreenState createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  // Static attendance data
  List<Map<String, dynamic>> attendanceData = [
    {
      "userId": "123",
      "userName": "Sai",
      "attendanceDate": "2024-09-19",
      "checkInTime": "09:00 AM",
      "checkOutTime": "05:00 PM",
      "workingHours": "8 hours",
      "status": "Present"
    },
    {
      "userId": "124",
      "userName": "Uma",
      "attendanceDate": "2024-09-19",
      "checkInTime": "09:30 AM",
      "checkOutTime": "04:30 PM",
      "workingHours": "7 hours",
      "status": "Early Leaver"
    },
    {
      "userId": "125",
      "userName": "Ravi",
      "attendanceDate": "2024-09-19",
      "checkInTime": "10:00 AM",
      "checkOutTime": "06:00 PM",
      "workingHours": "7 hours",
      "status": "Absent"
    },
    {
      "userId": "126",
      "userName": "Chiru",
      "attendanceDate": "2024-09-19",
      "checkInTime": "09:30 AM",
      "checkOutTime": "04:30 PM",
      "workingHours": "7 hours",
      "status": "Early Leaver"
    },
    {
      "userId": "127",
      "userName": "Gopi",
      "attendanceDate": "2024-09-19",
      "checkInTime": "09:00 AM",
      "checkOutTime": "05:00 PM",
      "workingHours": "8 hours",
      "status": "Present"
    },
  ];

  List<String> selectedFilters = [];

  Color getStatusColor(String status) {
    switch (status) {
      case 'Present':
        return Colors.green;
      case 'Late':
        return Colors.orange;
      case 'Absent':
        return Colors.red;
      case 'Early Leaver':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'Present':
        return Icons.check_circle;
      case 'Late':
        return Icons.access_time;
      case 'Absent':
        return Icons.cancel;
      case 'Early Leaver':
        return Icons.access_alarm;
      default:
        return Icons.help_outline;
    }
  }

  List<Map<String, dynamic>> getFilteredData() {
    if (selectedFilters.isEmpty) {
      return attendanceData;
    }
    return attendanceData.where((item) {
      return selectedFilters.contains(item['status']);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen width
    double screenWidth = MediaQuery.of(context).size.width;

    // Determine number of columns based on screen width
    int gridColumns = screenWidth > 600 ? 3 : 2;

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
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: Colors.white,
              size: screenWidth > 600 ? 30 : 24,
            ),
            onPressed: () {
              // Add filter functionality here
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Padding(
            padding: EdgeInsets.all(screenWidth > 600 ? 16.0 : 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Present', 'Late', 'Absent', 'Early Leaver']
                    .map((status) => Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth > 600 ? 8.0 : 4.0,
                          ),
                          child: FilterChip(
                            label: Text(
                              status,
                              style: TextStyle(
                                color: selectedFilters.contains(status)
                                    ? Colors.white
                                    : Colors.black,
                                fontSize: screenWidth > 600 ? 16 : 14,
                              ),
                            ),
                            selected: selectedFilters.contains(status),
                            onSelected: (isSelected) {
                              setState(() {
                                if (isSelected) {
                                  selectedFilters.add(status);
                                } else {
                                  selectedFilters.remove(status);
                                }
                              });
                            },
                            backgroundColor: Colors.grey[300],
                            selectedColor: getStatusColor(status),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: selectedFilters.contains(status)
                                    ? Colors.transparent
                                    : Colors.grey,
                                width: 1.5,
                              ),
                            ),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          // Attendance List
          Expanded(
            child: getFilteredData().isEmpty
                ? Center(child: Text('No data available'))
                : Padding(
                    padding: EdgeInsets.all(screenWidth > 600 ? 16.0 : 8.0),
                    child: ListView.builder(
                      itemCount: getFilteredData().length,
                      itemBuilder: (context, index) {
                        final attendance = getFilteredData()[index];
                        return Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding:
                                EdgeInsets.all(screenWidth > 600 ? 16.0 : 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // User Name and Icon
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        attendance['userName'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: screenWidth > 600 ? 18 : 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      getStatusIcon(attendance['status']),
                                      color:
                                          getStatusColor(attendance['status']),
                                      size: screenWidth > 600 ? 32 : 28,
                                    ),
                                  ],
                                ),
                                SizedBox(height: screenWidth > 600 ? 12 : 8),
                                // Attendance Date
                                Text(
                                  'Date: ${attendance['attendanceDate']}',
                                  style: TextStyle(
                                    fontSize: screenWidth > 600 ? 16 : 14,
                                  ),
                                ),
                                SizedBox(height: screenWidth > 600 ? 12 : 8),
                                // Check-in and Check-out Times
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Check-In',
                                          style: TextStyle(
                                            fontSize:
                                                screenWidth > 600 ? 14 : 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          attendance['checkInTime'],
                                          style: TextStyle(
                                            fontSize:
                                                screenWidth > 600 ? 14 : 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Check-Out',
                                          style: TextStyle(
                                            fontSize:
                                                screenWidth > 600 ? 14 : 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          attendance['checkOutTime'],
                                          style: TextStyle(
                                            fontSize:
                                                screenWidth > 600 ? 14 : 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: screenWidth > 600 ? 12 : 8),
                                // Working Hours
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Working Hours:',
                                      style: TextStyle(
                                        fontSize: screenWidth > 600 ? 14 : 12,
                                      ),
                                    ),
                                    Text(
                                      attendance['workingHours'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: screenWidth > 600 ? 14 : 12,
                                      ),
                                    ),
                                  ],
                                ),
                                // Status Indicator
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    attendance['status'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          getStatusColor(attendance['status']),
                                      fontSize: screenWidth > 600 ? 16 : 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
