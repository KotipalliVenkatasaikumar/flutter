import 'package:flutter/material.dart';
import 'package:ajna/screens/app_bar.dart';
import 'package:ajna/screens/home_screen.dart';
import 'package:ajna/screens/profile/profile_reset_password.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _MyDataTableWidgetState createState() => _MyDataTableWidgetState();
}

class _MyDataTableWidgetState extends State<ProfileScreen> {
  static int? get index => null;

  void _logout() async {
    // Navigator.of(context).pushNamed('/main');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Navigate to the main route (in this case, HomePage)
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  void _navigateToResetPasswordScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileResetPassword()),
    );
  }

  Future<Map<String, String?>> getUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userName = prefs.getString('userName');
    String? email = prefs.getString('email');
    return {'userName': userName, 'email': email};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 100,
              child: Image.asset('lib/assets/images/ajna.png'),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: FutureBuilder<Map<String, String?>>(
                future: getUserDetails(),
                builder: (BuildContext context,
                    AsyncSnapshot<Map<String, String?>> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return const Center(
                        child: Text("Error fetching user details"));
                  } else if (snapshot.hasData) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize
                            .min, // To keep the column size to its contents
                        children: [
                          const Text("Hi",
                              style: TextStyle(
                                  fontSize: 30.0,
                                  color: Color.fromARGB(255, 132, 132, 139))),
                          Text(
                            snapshot.data?['userName'] ?? "No username found",
                            style: const TextStyle(
                                fontSize: 30.0,
                                color: Color.fromARGB(255, 23, 139, 171)),
                          ),
                          Text(
                            "Mail id: ${snapshot.data?['email'] ?? 'No email found'}",
                            style: const TextStyle(
                                fontSize: 22.0,
                                color: Color.fromARGB(255, 85, 86, 87)),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 20),
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(
                                  6, 73, 105, 1), // Light blue background color
                              borderRadius: BorderRadius.circular(6),
                              // Rounded corners
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: InkWell(
                                onTap: _navigateToResetPasswordScreen,
                                splashColor: Colors.blue.withOpacity(0.5),
                                child: const Text(
                                  'Reset Password',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color.fromARGB(255, 255, 255, 255),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return const Center(child: Text("No user details found"));
                  }
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.zero,
        color: const Color.fromRGBO(6, 73, 105, 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 16),
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
