import 'dart:convert';

import 'package:ajna/main.dart';
import 'package:ajna/screens/connectivity_handler.dart';
import 'package:ajna/screens/util.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';

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
  final ConnectivityHandler connectivityHandler = ConnectivityHandler();

  int? selectedUserId;
  List<User> users = [];
  bool isLoading = true;

  // Search box inside the user dropdown menu.
  final TextEditingController _userSearchController = TextEditingController();

  @override
  void dispose() {
    _userSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // _getOrganizationId(); // Retrieve organizationId from utils
    // _checkSession();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    bool isConnected = await connectivityHandler.checkConnectivity(context);
    if (isConnected) {
      _checkSession();

      // Proceed with other initialization steps if connected
      _getOrganizationId(); // Retrieve organizationId from utils
    }
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
                        AppColors.primary),
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
    _checkSession();
    await _getOrganizationId();
  }

  Future<void> _checkSession() async {
    try {
      final response = await ApiService.checkForUpdate();

      if (response.statusCode == 401) {
        // Clear preferences and show session expired dialog
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Show session expired dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Session Expired'),
            content: const Text(
                'Your session has expired. Please log in again to continue.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );

        // Automatically navigate to login after 5 seconds if no action
        Future.delayed(const Duration(seconds: 5), () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context); // Close dialog if still open
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        });

        return; // Early exit due to session expiration
      }
    } catch (e) {
      debugPrint('Error checking session: $e');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      // appBar: AppBar(
      //   backgroundColor: AppColors.primary,
      //   title: const Text(
      //     'Reset Android ID',
      //     style: TextStyle(
      //       fontSize: 18,
      //       color: Colors.white,
      //     ),
      //   ),
      //   centerTitle: true,
      //   iconTheme: const IconThemeData(
      //     color: Colors.white,
      //   ),
      // ),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        // Brand hero gradient — matches CustomAppBar and the home header.
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.heroGradient,
              stops: AppColors.heroStops,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reset Android ID',
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
      body: RefreshIndicator(
        onRefresh: refreshData,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
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
                        // Size to the field, not to the widest item (overflow guard).
                        isExpanded: true,
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
                        // Type-to-filter the user list.
                        dropdownSearchData: DropdownSearchData<int>(
                          searchController: _userSearchController,
                          searchInnerWidgetHeight: 60,
                          searchInnerWidget: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                            // Rebuilds only the field so the clear button can
                            // follow the typed text inside the menu overlay.
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _userSearchController,
                              builder: (context, value, _) => TextFormField(
                                controller: _userSearchController,
                                textInputAction: TextInputAction.search,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                  hintText: 'Search user',
                                  hintStyle: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.searchHint),
                                  prefixIcon:
                                      const Icon(Icons.search, size: 20),
                                  suffixIcon: value.text.isEmpty
                                      ? null
                                      : IconButton(
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          onPressed:
                                              _userSearchController.clear,
                                        ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                        color:
                                            Color.fromARGB(255, 41, 221, 200),
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
                              ),
                            ),
                          ),
                          // Items hold userId as the value, so match on the
                          // displayed user name instead.
                          searchMatchFn: (item, searchValue) {
                            final name =
                                (item.child as Text).data?.toLowerCase() ?? '';
                            return name.contains(searchValue.toLowerCase().trim());
                          },
                        ),
                        // Clear the filter when the menu closes.
                        onMenuStateChange: (isOpen) {
                          if (!isOpen) _userSearchController.clear();
                        },
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
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        // Bottom padding clears the system navigation bar (SDK 36 is always
        // edge-to-edge), so the footer is not hidden underneath it.
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomBarInset(context)),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Powered by ',
                style: TextStyle(
                  color: AppColors.textSecondary,
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
              TextSpan(
                text: ' Technologies',
                style: TextStyle(
                  color: AppColors.textSecondary, // Choose a suitable color
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
