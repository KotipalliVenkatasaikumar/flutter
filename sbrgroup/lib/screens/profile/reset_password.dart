import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:ajna/main.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/app_bar.dart';
import 'package:ajna/screens/profile/auth_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajna/theme/app_colors.dart';

class ResetPassword extends StatelessWidget {
  ResetPassword({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Pre-existing nested MaterialApp (kept so navigation is unchanged), but
    // seeded from the brand colour instead of a near-white that made every
    // Material default render washed out.
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
      home: ResetPasswordScreen(),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();

  String _errorMessage = '';
  bool _isObscured = true;

  final logger = Logger();

  Future<void> _generatepassword() async {
    logger.i('Login button pressed');

    if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      final password = _passwordController.text;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? email = prefs.getString('email');
     
      final response = await ApiService.updatePassword(email!, password);
      if (response.statusCode == 200) {
        logger.d('password successful');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          ),
        );
      } else {
        setState(() {
          _errorMessage =
              'password is not Found. Please provide correct password.';
        });
        logger.e('password not found in the response');
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
      backgroundColor: AppColors.bg,
      appBar: const CustomAppBar(showProfileIcon: false),
      body: AuthCard(
        title: 'Reset Password',
        subtitle: 'Set a new password to finish signing back in.',
        errorMessage: _errorMessage,
        onSubmit: _generatepassword,
        field: Form(
          key: _formKey,
          child: TextFormField(
            controller: _passwordController,
            // Was plain text — a new password must not be shown on screen.
            obscureText: _isObscured,
            style: TextStyle(color: AppColors.textPrimary),
            cursorColor: AppColors.primary,
            decoration: authFieldDecoration(
              'Enter New Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _isObscured ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _isObscured = !_isObscured),
              ),
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
    );
  }
}
