import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajna/screens/attendace/attendace_scan.dart';
import 'package:url_launcher/url_launcher.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkStoredLoginData();
  }

  Future<void> _checkStoredLoginData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('qr_response');

    setState(() {
      isLoggedIn = jsonString != null;
    });
  }

  void _login() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceScanScreen(isLoggedIn: true),
      ),
    ).then((_) => _checkStoredLoginData());
  }

  void _logout() async {
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // await prefs.remove('qr_response');

    // Send isLoggedIn: false when logging out
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceScanScreen(isLoggedIn: false),
      ),
    ).then((_) => _checkStoredLoginData());
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: const Text(
          'FO Visit',
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
          padding: EdgeInsets.all(screenWidth * 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'lib/assets/images/ajna.png',
                width: screenWidth * 0.3,
              ),
              const SizedBox(height: 30.0),
              if (!isLoggedIn)
                SizedBox(
                  width: screenWidth * 0.6,
                  child: ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15.0),
                      elevation: 5.0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FontAwesomeIcons.signInAlt,
                          size: 20.0,
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
              if (isLoggedIn)
                SizedBox(
                  width: screenWidth * 0.6,
                  child: ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15.0),
                      elevation: 5.0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FontAwesomeIcons.signOutAlt,
                          size: 20.0,
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
                    launchUrl(Uri.parse('https://www.corenuts.com'));
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
                    launchUrl(Uri.parse('https://www.corenuts.com'));
                  },
              ),
              const TextSpan(
                text: ' Technologies',
                style: TextStyle(
                  color: Color.fromARGB(255, 230, 227, 227),
                  fontSize: 12,
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
