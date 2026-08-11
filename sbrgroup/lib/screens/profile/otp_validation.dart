import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/profile/auth_card.dart';
import 'package:ajna/screens/profile/reset_password.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajna/theme/app_colors.dart';

class OtpValidation extends StatelessWidget {
  OtpValidation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OtpValidationScreen();
  }
}

class OtpValidationScreen extends StatefulWidget {
  OtpValidationScreen({Key? key}) : super(key: key);

  @override
  _OtpValidationScreenState createState() => _OtpValidationScreenState();
}

class _OtpValidationScreenState extends State<OtpValidationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();

  String _errorMessage = '';

  final logger = Logger();

  Future<void> _generateotp() async {
    logger.i('Login button pressed');

    if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      final otp = _otpController.text;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? email = prefs.getString('email');
     
      final response = await ApiService.verifyOtp(email!, otp);
      if (response.statusCode == 200) {
        logger.d('OTP successful');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'otp is not Found. Please provide correct otp.';
        });
        logger.e('otp not found in the response');
      }
    }
  }

  void _navigateToLoginFormScreen(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ResetPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
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
              'Forgot Password',
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
      backgroundColor: AppColors.bg,
      body: AuthCard(
        title: 'Verify OTP',
        subtitle: 'Enter the one-time code sent to your registered email.',
        errorMessage: _errorMessage,
        onSubmit: _generateotp,
        field: Form(
          key: _formKey,
          child: TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
            ),
            cursorColor: AppColors.primary,
            decoration: authFieldDecoration('OTP'),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter your otp';
              }
              return null;
            },
          ),
        ),
      ),
    );
  }
}
