import 'dart:convert';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/util.dart';
import 'package:url_launcher/url_launcher.dart';

class UserFormScreen extends StatefulWidget {
  @override
  _UserFormScreenState createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  String? _selectedRole;
  String? _selectedManager;

  List<dynamic> _roles = [];
  List<dynamic> _managers = [];
  int? intOraganizationId;

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  Future<void> initializeData() async {
    intOraganizationId = await Util.getOrganizationId();
    if (intOraganizationId != null) {
      _fetchRoles();
      _fetchManagers();
    } else {
      print('Organization ID is null or not available');
    }
  }

  Future<void> _fetchRoles() async {
    try {
      final response = await ApiService.fetchOrgRoles(intOraganizationId!);
      if (response.statusCode == 200) {
        setState(() {
          _roles = json.decode(response.body);
        });
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to load roles. Please try again later.',
          'Error loading roles: ${response.statusCode}',
        );
      }
    } catch (e) {
      ErrorHandler.handleError(
        context,
        'Failed to fetching organization details. Please try again later.',
        'Error fetching roles: $e',
      );
    }
  }

  Future<void> _fetchManagers() async {
    try {
      final response = await ApiService.fetchOrgManagers(intOraganizationId!);
      if (response.statusCode == 200) {
        setState(() {
          _managers = json.decode(response.body);
        });
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to load managers. Please try again later.',
          'Error loading managers: ${response.statusCode}',
        );
      }
    } catch (e) {
      ErrorHandler.handleError(
        context,
        'Failed to fetching managers. Please try again later.',
        'Error fetching managers: $e',
      );
    }
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      try {
        final response = await ApiService.signUp(
          _userNameController.text,
          _emailController.text,
          _passwordController.text,
          _phoneNumberController.text,
          _selectedRole!,
          _selectedManager!,
          intOraganizationId!,
        );

        if (response.statusCode == 201) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Center(
                  child:
                      Icon(Icons.check_circle, color: Colors.green, size: 50),
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
                      child: Text('User Added Successfully!'),
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
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              );
            },
          );

          _formKey.currentState!.reset();
          _userNameController.clear();
          _emailController.clear();
          _passwordController.clear();
          _phoneNumberController.clear();
          setState(() {
            _selectedRole = null;
            _selectedManager = null;
          });
        } else {
          ErrorHandler.handleError(
            context,
            'Failed to add user. Please try again later.',
            'Error adding user: ${response.statusCode}',
          );
        }
      } catch (e) {
        print('Error adding user: $e');
        ErrorHandler.handleError(
          context,
          'Failed to add user. Please try again later.',
          'Error adding user: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: const Text(
          'New User Registration',
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment
              .center, // Aligns children to the start of the column
          children: [
            const SizedBox(height: 15),
            const Text(
              'Enter New User Details',
              style: TextStyle(
                fontSize: 18,
                color: Color.fromARGB(255, 125, 125, 124),
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    TextFormField(
                      controller: _userNameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromARGB(255, 41, 221, 200),
                              width: 1.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 23, 158, 142),
                              width: 2.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a user name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 41, 221, 200),
                              width: 1.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 23, 158, 142),
                              width: 2.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 41, 221, 200),
                              width: 1.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 23, 158, 142),
                              width: 2.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _phoneNumberController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 41, 221, 200),
                              width: 1.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 23, 158, 142),
                              width: 2.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Role Dropdown
                    DropdownButtonFormField2<String>(
                      decoration: InputDecoration(
                        labelText: 'Role Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 41, 221, 200),
                              width: 1.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 23, 158, 142),
                              width: 2.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      value: _selectedRole,
                      items: _roles.isNotEmpty
                          ? _roles.map<DropdownMenuItem<String>>((role) {
                              return DropdownMenuItem<String>(
                                value: role['roleId'].toString(),
                                child: Text(role['roleName']),
                              );
                            }).toList()
                          : [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('No Roles Available'),
                              )
                            ],
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedRole = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a role';
                        }
                        return null;
                      },
                      isExpanded: true,
                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 300,
                        width: MediaQuery.of(context).size.width - 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Manager Dropdown
                    DropdownButtonFormField2<String>(
                      decoration: InputDecoration(
                        labelText: 'Manager Name',
                        // fillColor: Color.fromARGB(255, 204, 230, 237),
                        // filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 41, 221, 200),
                              width: 1.5),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 23, 158, 142),
                              width: 2),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      value: _selectedManager,
                      items: _managers.isNotEmpty
                          ? _managers.map<DropdownMenuItem<String>>((manager) {
                              return DropdownMenuItem<String>(
                                value: manager['userId'].toString(),
                                child: Text(manager['userName']),
                              );
                            }).toList()
                          : [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('No Managers Available'),
                              )
                            ],
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedManager = newValue;
                        });
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
                    const SizedBox(height: 20),
                    // Submit Button
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _save(); // Save user data
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(235, 23, 135, 182),
                        foregroundColor: Colors.white, // Custom text color
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 10, horizontal: 36),
                        child: Text(
                          'Submit',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

void main() {
  runApp(MaterialApp(
    home: UserFormScreen(),
  ));
}