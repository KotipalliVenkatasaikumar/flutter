import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:ajna/main.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/app_bar.dart';
import 'package:ajna/screens/profile/auth_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajna/theme/app_colors.dart';

class ProfileResetPassword extends StatelessWidget {
  ProfileResetPassword({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // NOTE: this nested MaterialApp is pre-existing (SBR WorkHub has the same
    // shape). It is kept so navigation behaviour is unchanged, but its theme is
    // now seeded from the brand colour instead of a stray light blue, so it no
    // longer overrides the app-wide look.
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
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Password Reset",
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700)),
          content: Text("Your password has been reset successfully.",
              style: TextStyle(color: AppColors.textSecondary)),
          actions: <Widget>[
            TextButton(
              child: const Text("OK",
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
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
      backgroundColor: AppColors.bg,
      appBar: const CustomAppBar(showBackButton: true),
      body: AuthCard(
        title: 'Reset Password',
        subtitle: 'Choose a new password for your account.',
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
