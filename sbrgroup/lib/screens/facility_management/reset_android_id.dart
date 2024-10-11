import 'dart:convert';

import 'package:ajna/screens/util.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class User {
  final int userId;
  final String userName;

  User({required this.userId, required this.userName});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'] as int,
      userName: json['userName'] as String,
    );
  }
}

class ResetAndroidIdScreen extends StatefulWidget {
  @override
  _ResetAndroidIdScreenState createState() => _ResetAndroidIdScreenState();
}

class _ResetAndroidIdScreenState extends State<ResetAndroidIdScreen> {
  int? selectedUserId;
  List<User> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _getOrganizationId(); // Retrieve organizationId from utils
  }

  Future<void> _getOrganizationId() async {
    int? organizationId = await Util
        .getOrganizationId(); // Fetch organizationId from the utils file
    if (organizationId != null) {
      _fetchUsers(
          organizationId.toString()); // Fetch users based on the organizationId
    }
  }

  Future<void> _fetchUsers(String organizationId) async {
    // final response = await http.get(Uri.parse(
    //     'http://15.207.212.144:9000/api/user/user/fetchall?organizationId=$organizationId'));

    final response = await ApiService.fetchResetUsers(organizationId);

    if (response.statusCode == 200) {
      List<dynamic> userList = json.decode(response.body);
      setState(() {
        users = userList.map((json) => User.fromJson(json)).toList();
        isLoading = false;
      });
    } else {
      // Handle error
      setState(() {
        users = [];
        isLoading = false;
      });
      ErrorHandler.handleError(
        context,
        'Failed to load users. Please try again later.',
        'Error loading users: ${response.statusCode}',
      );
    }
  }

  Future<void> _resetAndroidId(int userId) async {
    // final response = await http.post(
    //   Uri.parse(
    //       'http://15.207.212.144:9000/api/user/user/mob/resetandroidid?userId=$userId'),
    //   headers: <String, String>{
    //     'Content-Type': 'application/json; charset=UTF-8',
    //   },
    //   body: jsonEncode({}), // Empty body or if needed, include additional data
    // );

    final response = await ApiService.resetAndroidId(userId);

    if (response.statusCode == 200) {
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
                  child: Text('Android ID reset successfully!'),
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
    } else if (response.statusCode == 400) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 10),
                Text('Error'),
              ],
            ),
            content: const Text(
              'Android ID already reset. Please try again later.',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
              ),
            ],
          );
        },
      );
    } else {
      ErrorHandler.handleError(
        context,
        'Error resetting Android ID. Please try again later.',
        'Error resetting Android ID: ${response.statusCode}',
      );
    }
  }

  Future<void> refreshData() async {
    await _getOrganizationId();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: const Text(
          'Reset Android ID',
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
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 15),
                    const Text(
                      'Select a User to Reset Android ID',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.normal,
                        color: Color.fromARGB(255, 125, 125, 124),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField2<int>(
                      value: selectedUserId,
                      hint: const Text('Select User',
                          style: TextStyle(
                              fontSize: 16,
                              color: Color.fromARGB(255, 80, 79, 79))),
                      items: users.map((User user) {
                        return DropdownMenuItem<int>(
                          value: user.userId,
                          child: Text(user.userName),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          selectedUserId = newValue;
                        });
                      },
                      decoration: InputDecoration(
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 15),
                      ),
                      //dropdownColor: Colors.white,
                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 400,
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
                        if (selectedUserId != null) {
                          _resetAndroidId(selectedUserId!).then((_) {
                            setState(() {
                              selectedUserId =
                                  null; // Reset the dropdown selection
                            });
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(235, 23, 135, 182),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: Text(
                          'Reset Android ID',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
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
