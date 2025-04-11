import 'package:ajna/main.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/profile/otp_validation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:ajna/screens/app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForgotPassword extends StatelessWidget {
  ForgotPassword({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AJNA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 41, 83, 137),
        ),
        useMaterial3: true,
      ),
      home: ForgotPasswordScreen(),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  String _errorMessage = '';

  final logger = Logger();

  Future<void> _generateotp() async {
    logger.i('Login button pressed');

    if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      final email = _emailController.text;

      
      final response = await ApiService.generateOtp(email);
      if (response.statusCode == 200) {
        logger.d('Email successful');

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('email', email);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OtpValidation(),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Email is not Found. Please provide correct Email.';
        });
        logger.e('Email not found in the response');
      }
    }
  }

  void _navigateToLoginFormScreen(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
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
              'Forgot Password',
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
                  controller: _emailController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Email',
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter your email';
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
              onPressed: _generateotp,
              child:
                  const Text('Continue', style: TextStyle(color: Colors.white)),
            ),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: const Color.fromRGBO(6, 73, 105, 1),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(40, 30),
              ),
              onPressed: () => _navigateToLoginFormScreen(context),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.arrow_back, size: 16),
                  SizedBox(width: 4),
                  Text('Back to Login', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
