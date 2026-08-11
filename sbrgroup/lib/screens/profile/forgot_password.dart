import 'package:ajna/main.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/profile/auth_card.dart';
import 'package:ajna/screens/profile/otp_validation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajna/theme/app_colors.dart';

class ForgotPassword extends StatelessWidget {
  ForgotPassword({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Pre-existing nested MaterialApp (kept so navigation is unchanged), now
    // seeded from the brand colour so it matches the rest of the app.
    return MaterialApp(
      title: 'AJNA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        scaffoldBackgroundColor: AppColors.bg,
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
        title: 'Forgot Password',
        subtitle:
            'Enter your registered email and we will send you a one-time code.',
        errorMessage: _errorMessage,
        onSubmit: _generateotp,
        field: Form(
          key: _formKey,
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: AppColors.textPrimary),
            cursorColor: AppColors.primary,
            decoration: authFieldDecoration('Email'),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter your email';
              }
              return null;
            },
          ),
        ),
      ),
      // bottomNavigationBar: Container(
      //   color: AppColors.primary,
      //   padding: const EdgeInsets.symmetric(vertical: 4),
      //   child: Row(
      //     mainAxisAlignment: MainAxisAlignment.start,
      //     children: <Widget>[
      //       TextButton(
      //         style: TextButton.styleFrom(
      //           foregroundColor: Colors.white,
      //           minimumSize: const Size(40, 30),
      //         ),
      //         onPressed: () => _navigateToLoginFormScreen(context),
      //         child: const Row(
      //           children: <Widget>[
      //             Icon(Icons.arrow_back, size: 16),
      //             SizedBox(width: 4),
      //             Text('Back to Login', style: TextStyle(fontSize: 12)),
      //           ],
      //         ),
      //       ),
      //     ],
      //   ),
      // ),
    );
  }
}
