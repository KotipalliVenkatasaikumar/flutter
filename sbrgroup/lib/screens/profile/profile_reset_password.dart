import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:ajna/main.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/app_bar.dart';
import 'package:ajna/screens/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileResetPassword extends StatelessWidget {
  ProfileResetPassword({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AJNA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 25, 174, 224),
        ),
        useMaterial3: true,
      ),
      home: ProfileResetPasswordScreen(),
    );
  }
}

class ProfileResetPasswordScreen extends StatefulWidget {
  ProfileResetPasswordScreen({Key? key}) : super(key: key);

  @override
  _ProfileResetPasswordScreenState createState() =>
      _ProfileResetPasswordScreenState();
}

class _ProfileResetPasswordScreenState
    extends State<ProfileResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';

  final logger = Logger();

  Future<void> _generatepassword() async {
    logger.i('Login button pressed');

    if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      final password = _passwordController.text;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? email = prefs.getString('email');
     
      final response = await ApiService.updatePassword(email!, password);
      if (response.statusCode == 200) {
        logger.d('Password update successful');
        _showPasswordResetDialog(); // Show the dialog after successful password reset
      } else {
        setState(() {
          _errorMessage = 'Password update failed. Please try again.';
        });
        logger.e('Failed to update password');
      }
    }
  }

  void _showPasswordResetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Password Reset"),
          content: const Text("Your password has been reset successfully."),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _navigateToLoginFormScreen(
                    context); // Navigate to the login screen
              },
            ),
          ],
        );
      },
    );
  }

  static int? get index => null;

  void _navigateToLoginFormScreen(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  void _logout() async {
    // Navigator.of(context).pushNamed('/main');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Navigate to the main route (in this case, HomePage)
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
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
            const SizedBox(height: 20),
            const Text(
              'Reset Password',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 60),
              child: Form(
                key: _formKey,
                child: TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Enter New Password',
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
              ),
            ),
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(
                    const Color.fromRGBO(6, 73, 105, 1)),
              ),
              onPressed: _generatepassword,
              child:
                  const Text('Continue', style: TextStyle(color: Colors.white)),
            ),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 10),
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
                          const ProfileScreen()), // Replace with your actual Profile Screen
                );
              },
              padding: EdgeInsets.zero,
              color: Colors.white,
            ),
            const Text(
              'Profile',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
