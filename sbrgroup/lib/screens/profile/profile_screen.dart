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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: const CustomAppBar(showBackButton: true),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(6, 73, 105, 0.1),
              Color.fromRGBO(23, 139, 171, 0.1),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  height: screenHeight * 0.12,
                  child: Image.asset('lib/assets/images/ajna.png'),
                ),
                const SizedBox(height: 20),
                FutureBuilder<Map<String, String?>>(
                  future: getUserDetails(),
                  builder: (BuildContext context,
                      AsyncSnapshot<Map<String, String?>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return const Center(
                          child: Text("Error fetching user details"));
                    } else if (snapshot.hasData) {
                      return Card(
                        elevation: 12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color.fromRGBO(6, 73, 105, 1),
                                    width: 3,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: screenWidth * 0.15,
                                  backgroundColor: const Color.fromARGB(255, 23, 139, 171),
                                  child: Icon(
                                    Icons.person,
                                    size: screenWidth * 0.18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Welcome back!",
                                style: TextStyle(
                                  fontSize: 24.0,
                                  color: Color.fromARGB(255, 132, 132, 139),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.data?['userName'] ?? "No username found",
                                style: const TextStyle(
                                  fontSize: 32.0,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromRGBO(6, 73, 105, 1),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.data?['email'] ?? 'No email found',
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  color: Color.fromARGB(255, 85, 86, 87),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _navigateToResetPasswordScreen,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.lock_reset),
                                      SizedBox(width: 8),
                                      Text(
                                        'Reset Password',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      return const Center(child: Text("No user details found"));
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive ? Colors.red.withOpacity(0.3) : const Color.fromRGBO(6, 73, 105, 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : const Color.fromRGBO(6, 73, 105, 1),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? Colors.red : const Color.fromRGBO(6, 73, 105, 1),
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isDestructive ? Colors.red : const Color.fromRGBO(6, 73, 105, 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
