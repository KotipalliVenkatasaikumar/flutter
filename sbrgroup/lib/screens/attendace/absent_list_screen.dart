import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/attendace/attendace_report.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/util.dart';
import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dropdown_search/dropdown_search.dart';

// ShiftTiming model
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

class LocationModel {
  final int id;
  final String location;

  LocationModel({required this.id, required this.location});

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'],
      location: json['location'],
    );
  }
}

// User model
class UserModel {
  final int userId;
  final String userName;
  UserModel({required this.userId, required this.userName});
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'],
      userName: json['userName'],
    );
  }
}

class AbsentListScreen extends StatefulWidget {
  @override
  _AbsentListScreenState createState() => _AbsentListScreenState();
}

class _AbsentListScreenState extends State<AbsentListScreen> {
  int? organizationId;
  UserModel? _selectedUser;

  // Instance variables for state
  List<LocationModel> locations = [];
  List<ShiftTiming> shifts = [];
  List<UserModel> users = [];
  List<UserModel> allUsers = [];
  List<UserModel> selectedUsers = [];
  ShiftTiming? selectedShift;
  int? selectedShiftId;
  LocationModel? selectedLocation;

  // Add a search TextField and filtered user list with checkboxes
  String _userSearch = '';

  // Add a controller for the search field
  final TextEditingController _userSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
    // Replace with your org id
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    // Reset all state variables to ensure fresh state if needed
    locations = [];
    shifts = [];
    users = [];
    allUsers = [];
    selectedUsers = [];
    selectedShift = null;
    selectedShiftId = null;
    selectedLocation = null;
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      organizationId = await Util.getOrganizationId();
      fetchShiftData();
      fetchAttendanceLocation(organizationId!);

      // fetchRoles();
    } catch (error) {
      ErrorHandler.handleError(
        context,
        'Failed to initialize data. Please try again later.',
        'Initialization error: $error',
      );
    } finally {}
  }

  Future<void> fetchShiftData() async {
    try {
      final response = await ApiService.fetchshiftData();
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        setState(() {
          shifts = jsonData
              .map<ShiftTiming>((json) => ShiftTiming.fromJson(json))
              .toList();
        });
      } else {
        throw Exception('Failed to load shifts');
      }
    } catch (error) {
      print("Error loading shift data: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load shift data.')),
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
              .map<LocationModel>((json) => LocationModel.fromJson(json))
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

  Future<void> fetchUsersByLocation(int selectedLocation,
      {String userName = ''}) async {
    try {
      final response = await ApiService.fetchUsersForAbsent(
          organizationId.toString(), selectedLocation.toString(), userName);
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        setState(() {
          if (userName.isEmpty) {
            allUsers =
                jsonData.map((json) => UserModel.fromJson(json)).toList();
            users = List<UserModel>.from(allUsers);
          } else {
            users = jsonData.map((json) => UserModel.fromJson(json)).toList();
          }
          // Do NOT reset selectedUsers here, so old selections remain
        });
      } else {
        setState(() {
          users = [];
          // Do NOT reset selectedUsers here
        });
        print('Failed to load users');
      }
    } catch (error) {
      setState(() {
        users = [];
        // Do NOT reset selectedUsers here
      });
      print('Error loading users: $error');
    }
  }

  Future<void> submitAbsentList() async {
    try {
      final response = await ApiService.submitAbsentEmployees(
        shiftId: selectedShiftId!,
        organizationId: organizationId!,
        locationId: selectedLocation!.id,
        userIds: selectedUsers.map((user) => user.userId).toList(),
      );
      if (response.statusCode == 200) {
        // Success
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Attendance Marked'),
            content: Text(
                'The selected users have been marked as absent successfully.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Reset all filters and selections
                  setState(() {
                    selectedLocation = null;
                    selectedShift = null;
                    selectedShiftId = null;
                    selectedUsers = [];
                    users = [];
                    allUsers = [];
                    _userSearch = '';
                    _userSearchController.clear();
                  });
                  // Navigate to AttendanceReportScreen using direct navigation
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => AttendanceReportScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      } else {
        // Error
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error'),
            content: Text('Failed to submit absent list.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('An error occurred: \\${e.toString()}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

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
              'Add Absent List',
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mark Absent',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                )),
            SizedBox(height: 16),
            DropdownButtonFormField2<LocationModel>(
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Select Location',
                border: OutlineInputBorder(),
              ),
              dropdownStyleData: DropdownStyleData(
                maxHeight: 250,
                width: MediaQuery.of(context).size.width * 0.9,
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
              value: locations.contains(selectedLocation)
                  ? selectedLocation
                  : null,
              items: locations
                  .map((loc) => DropdownMenuItem(
                        value: loc,
                        child: Text(loc.location),
                      ))
                  .toList(),
              onChanged: (value) async {
                setState(() {
                  selectedLocation = value;
                });
                if (value != null) {
                  print(
                      'Selected location: \\${value.location} (id: \\${value.id})');
                  await fetchUsersByLocation(value.id);
                }
              },
            ),
            SizedBox(height: 12),
            DropdownButtonFormField2<ShiftTiming>(
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Select Shift',
                border: OutlineInputBorder(),
              ),
              dropdownStyleData: DropdownStyleData(
                maxHeight: 250,
                width: MediaQuery.of(context).size.width * 0.9,
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
              value: selectedShift != null && shifts.contains(selectedShift)
                  ? selectedShift
                  : null,
              items: shifts
                  .map((shift) => DropdownMenuItem(
                        value: shift,
                        child: Text(shift.commonRefValue),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedShift = value;
                  selectedShiftId = value?.id;
                });
                if (value != null) {
                  print(
                      'Selected shift: \\${value.commonRefKey} (id: \\${value.id})');
                }
              },
            ),
            SizedBox(height: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search and user list
                  TextField(
                    controller: _userSearchController,
                    decoration: InputDecoration(
                      labelText: "Search user",
                      border: OutlineInputBorder(),
                      suffixIcon: _userSearch.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _userSearch = '';
                                  _userSearchController.clear();
                                  users = List<UserModel>.from(allUsers);
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _userSearch = value;
                        if (_userSearch.isEmpty) {
                          users = List<UserModel>.from(allUsers);
                        } else {
                          users = allUsers
                              .where((user) => user.userName
                                  .toLowerCase()
                                  .contains(_userSearch.toLowerCase()))
                              .toList();
                        }
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: users
                          .map((user) => CheckboxListTile(
                                title: Text(user.userName),
                                value: selectedUsers.contains(user),
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      if (!selectedUsers.contains(user)) {
                                        selectedUsers.add(user);
                                      }
                                    } else {
                                      selectedUsers.remove(user);
                                    }
                                  });
                                },
                              ))
                          .toList(),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Selected users section with vertical scroll
                  Card(
                    elevation: 2,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people_alt, color: Colors.deepPurple),
                              SizedBox(width: 8),
                              Text(
                                'Selected Users',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          selectedUsers.isEmpty
                              ? Text(
                                  'No users selected.',
                                  style: TextStyle(color: Colors.grey),
                                )
                              : SizedBox(
                                  height: 150, // Adjust as needed
                                  child: ListView(
                                    children: selectedUsers.map((user) {
                                      return ListTile(
                                        title: Text(user.userName),
                                        trailing: IconButton(
                                          icon: Icon(Icons.close,
                                              color: Colors.red),
                                          onPressed: () {
                                            setState(() {
                                              selectedUsers.remove(user);
                                            });
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
                onPressed: (selectedLocation != null &&
                        selectedShiftId != null &&
                        selectedUsers.isNotEmpty)
                    ? () async {
                        await submitAbsentList();
                      }
                    : null,
                child: Text('Submit', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
