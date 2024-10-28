import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/attendace/attendace_scan.dart';
import 'package:ajna/screens/util.dart';
import 'package:url_launcher/url_launcher.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool isLoggedIn = false;
  bool isLoginButtonEnabled = false;
  bool isLogoutButtonEnabled = false;

  int? userId; // State to track login status

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  Future<void> initializeData() async {
    userId = await Util.getUserId();
    _handleLoginLogout(userId!);
  }

  Future<void> _handleLoginLogout(int userId) async {
    try {
      final response = await ApiService.checkLoginStatus(userId);

      if (response.statusCode == 200) {
        setState(() {
          isLoggedIn = !isLoggedIn;
          isLoginButtonEnabled = true;
          isLogoutButtonEnabled = false;
        });
      } else if (response.statusCode == 208) {
        setState(() {
          isLoggedIn = !isLoggedIn;
          isLoginButtonEnabled = false;
          isLogoutButtonEnabled = true;
        });
      }
    } catch (e) {
      ErrorHandler.handleError(
        context,
        'Error fetching LoginLogout Status. Please try again later.',
        'Error fetching LoginLogout: $e',
      );
    }
  }

  void _login() {
    setState(() {
      isLoggedIn = true;
    });

    // Navigate to AttendanceScanScreen with the login status
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceScanScreen(isLoggedIn: isLoggedIn),
      ),
    );
  }

  void _logout() {
    setState(() {
      isLoggedIn = false;
    });

    // Navigate to AttendanceScanScreen with the logout status
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceScanScreen(isLoggedIn: isLoggedIn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen width and height
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: const Text(
          'Attendance',
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 255, 255, 255),
              Color.fromARGB(255, 255, 255, 255).withOpacity(0.8),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.05), // Responsive padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // PNG Icon
              Image.asset(
                'lib/assets/images/ajna.png', // Ensure this path matches your asset path
                width: screenWidth * 0.3, // Responsive width
                // height: screenWidth * 0.3,
              ),
              const SizedBox(height: 30.0),

              // Login Button
              SizedBox(
                width: screenWidth * 0.6, // Responsive width
                child: ElevatedButton(
                  onPressed: isLoginButtonEnabled
                      ? _login
                      : null, // Enable/Disable based on state
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.green, // Button background color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15.0),
                    elevation: 5.0, // Button shadow
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FontAwesomeIcons.signInAlt,
                        size: 20.0, // Adjusted icon size
                      ),
                      SizedBox(width: 10.0),
                      Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20.0),

              // Logout Button
              SizedBox(
                width: screenWidth * 0.6, // Responsive width
                child: ElevatedButton(
                  onPressed: isLogoutButtonEnabled
                      ? _logout
                      : null, // Enable/Disable based on state
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red, // Button background color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15.0),
                    elevation: 5.0, // Button shadow
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FontAwesomeIcons.signOutAlt,
                        size: 20.0, // Adjusted icon size
                      ),
                      SizedBox(width: 10.0),
                      Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30.0),

              // Description
              // const Text(
              //   'Click Login to scan the QR code and mark your attendance. '
              //   'After that, you can Logout anytime.',
              //   textAlign: TextAlign.center,
              //   style: TextStyle(
              //     fontSize: 16.0,
              //     color: Colors.white70,
              //     height: 1.5,
              //   ),
              // ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
      bottomNavigationBar: Container(
        color: const Color.fromRGBO(6, 73, 105, 1),
        padding: EdgeInsets.symmetric(
            vertical: screenHeight * 0.02, horizontal: screenWidth * 0.05),
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
