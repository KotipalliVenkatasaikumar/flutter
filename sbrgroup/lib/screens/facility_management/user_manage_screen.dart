import 'dart:convert';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/util.dart';
import 'package:url_launcher/url_launcher.dart';

class UserManageScreen extends StatefulWidget {
  const UserManageScreen({super.key});

  @override
  _UserManageScreenState createState() => _UserManageScreenState();
}

class _UserManageScreenState extends State<UserManageScreen> {
  final _formKey = GlobalKey<FormState>();

  List<dynamic> _projects = [];
  List<dynamic> _qrGenerators = [];
  List<dynamic> _users = [];
  String _selectedProjectId = '';
  String _selectedQrGeneratorId = '';
  String _selectedUserId = '';
  int? intOrganizationId;
  @override
  void initState() {
    super.initState();
    initializeData();
  }

  Future<void> initializeData() async {
    intOrganizationId = await Util.getOrganizationId();
    _fetchProjects();
    _fetchUsers();
  }

  Future<void> _fetchProjects() async {
    
    final response =
        await ApiService.fetchProjectsUserManage(intOrganizationId!);
    if (response.statusCode == 200) {
      setState(() {
        _projects = json.decode(response.body);
      });
    } else {
      // throw Exception('Failed to load projects');
      ErrorHandler.handleError(
        context,
        'Failed to load projects. Please try again later.',
        'Error loading projects: ${response.statusCode}',
      );
    }
  }

  Future<void> _fetchQrGenerators(String projectId) async {
   
    final response = await ApiService.fetchQrLocations(projectId);
    if (response.statusCode == 200) {
      setState(() {
        _qrGenerators = json.decode(response.body);
      });
    } else {
      // throw Exception('Failed to load QR Generators');
      ErrorHandler.handleError(
        context,
        'Failed to load QR Generator locations. Please try again later.',
        'Error loading QR Generator locations: ${response.statusCode}',
      );
    }
  }

  Future<void> _fetchUsers() async {
   
    final response = await ApiService.fetchOrgUsers(intOrganizationId!);
    if (response.statusCode == 200) {
      setState(() {
        _users = json.decode(response.body);
      });
    } else {
      // throw Exception('Failed to load users');
      ErrorHandler.handleError(
        context,
        'Failed to load users. Please try again later.',
        'Error loading users: ${response.statusCode}',
      );
    }
  }

  void _submit() async {
    try {
      

      final response = await ApiService.addUserManagementDetails(
        int.parse(_selectedProjectId),
        int.parse(_selectedQrGeneratorId),
        int.parse(_selectedUserId),
      );

      if (response.statusCode == 200) {
        // Show a success message
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     backgroundColor: Colors.green,
        //     content: Text(
        //       'QR Assigned successfully!',
        //       style: TextStyle(color: Colors.white),
        //     ),
        //     duration: Duration(seconds: 2),
        //   ),
        // );
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Center(
                child: Icon(Icons.check_circle, color: Colors.green, size: 50),
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Text(
                      'Success!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 10),
                  Center(
                    child: Text('QR Assigned Successfully!'),
                  ),
                ],
              ),
              actions: <Widget>[
                Center(
                  child: TextButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                          const Color.fromRGBO(6, 73, 105, 1)),
                      foregroundColor:
                          MaterialStateProperty.all<Color>(Colors.white),
                    ),
                    child: Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                    },
                  ),
                ),
              ],
            );
          },
        );
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to assign QR. Please try again later.',
          'Error assigning QR: ${response.statusCode}',
        );
      }
    } catch (e) {
      ErrorHandler.handleError(
        context,
        'Failed to assign QR. Please try again later.',
        'Error sending data to backend: $e',
      );
    }
  }

  Future<void> refreshData() async {
    await initializeData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: const Text(
          'User Manage Screen',
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
        onRefresh: refreshData,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 15),
                const Text(
                  'Assign QR Location to User',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color.fromARGB(255, 125, 125, 124),
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      DropdownButtonFormField2<String>(
                        decoration: InputDecoration(
                          labelText: 'Select Project',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 41, 221, 200),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 23, 158, 142),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        value: _selectedProjectId.isNotEmpty
                            ? _selectedProjectId
                            : null,
                        items: _projects.isNotEmpty
                            ? _projects
                                .map<DropdownMenuItem<String>>((project) {
                                return DropdownMenuItem<String>(
                                  value: project['projectId'].toString(),
                                  child: Text(project['projectName']),
                                );
                              }).toList()
                            : [
                                const DropdownMenuItem<String>(
                                    value: '',
                                    child: Text('No Projects Available'))
                              ],
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedProjectId = newValue ?? '';
                          });
                          _fetchQrGenerators(_selectedProjectId);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a project';
                          }
                          return null;
                        },
                        isExpanded: true,
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 300,
                          width: MediaQuery.of(context).size.width - 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      DropdownButtonFormField2<String>(
                        decoration: InputDecoration(
                          labelText: 'Select QR Location',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 41, 221, 200),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 23, 158, 142),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        value: _selectedQrGeneratorId.isNotEmpty
                            ? _selectedQrGeneratorId
                            : null,
                        items: _qrGenerators.isNotEmpty
                            ? _qrGenerators
                                .map<DropdownMenuItem<String>>((qrGenerator) {
                                return DropdownMenuItem<String>(
                                  value: qrGenerator['scheduleId'].toString(),
                                  child:
                                      Text(qrGenerator['securityPatrolName']),
                                );
                              }).toList()
                            : [
                                const DropdownMenuItem<String>(
                                  value: '',
                                  child: Text('No QR Locations Available'),
                                ),
                              ],
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedQrGeneratorId = newValue ?? '';
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a QR Location';
                          }
                          return null;
                        },
                        isExpanded: true,
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 300,
                          width: MediaQuery.of(context).size.width - 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      DropdownButtonFormField2<String>(
                        decoration: InputDecoration(
                          labelText: 'Select User',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 41, 221, 200),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 23, 158, 142),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        value:
                            _selectedUserId.isNotEmpty ? _selectedUserId : null,
                        items: _users.isNotEmpty
                            ? _users.map<DropdownMenuItem<String>>((user) {
                                return DropdownMenuItem<String>(
                                  value: user['userId'].toString(),
                                  child: Text(user['userName']),
                                );
                              }).toList()
                            : [
                                const DropdownMenuItem<String>(
                                  value: '',
                                  child: Text('No Users Available'),
                                ),
                              ],
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedUserId = newValue ?? '';
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a user';
                          }
                          return null;
                        },
                        isExpanded: true,
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 300,
                          width: MediaQuery.of(context).size.width - 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _submit();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                              235, 23, 135, 182), // Custom background color
                          foregroundColor:
                              Colors.white, // Custom text colostom text color
                        ),
                        child: const Text('Submit'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                    //ignore: deprecated_member_use
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
                    //ignore: deprecated_member_use
                    launch('https://www.corenuts.com');
                  },
              ),
              const TextSpan(
                text: ' Technologies',
                style: TextStyle(
                  color: Color.fromARGB(
                      255, 230, 227, 227), // Choose a suitable color
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
