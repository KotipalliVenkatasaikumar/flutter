import 'dart:convert';
import 'package:ajna/screens/connectivity_handler.dart';
import 'package:ajna/screens/facility_management/reports_projects.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

//import 'package:local_auth/local_auth.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
//import 'package:pattern_lock/pattern_lock.dart';
import 'package:permission_handler/permission_handler.dart';
//import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/home_screen.dart';
import 'package:ajna/screens/profile/forgot_password.dart';
import 'package:ajna/screens/util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens/notification/notification_service.dart';
import 'package:ajna/theme/responsive.dart';

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  NotificationService().initialize(navigatorKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final ConnectivityHandler connectivityHandler = ConnectivityHandler();
    return MaterialApp(
      title: 'AJNA',
      // Root theme seeded from the Ajna logo's azure chevron, so every Material
      // default (ripples, selection handles, spinners, cursors) lands on-brand
      // instead of the old lilac fallback. Screen-level colours come from
      // AppColors — see lib/theme/app_colors.dart.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: AppColors.primary),
      ),
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: Builder(
        builder: (context) {
          // Check for connectivity as soon as the app launches
          connectivityHandler.checkConnectivity(context);
          return const LoginPage(); // Your initial screen
        },
      ),
      routes: appRoutes,
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        );
      },
    );
  }
}

// Define routes in a separate constant map for scalability
final Map<String, WidgetBuilder> appRoutes = {
  '/login': (context) => const LoginPage(),
  '/main': (context) => const HomeScreen(),
  '/qrreport': (context) => const ReportsHomeScreen(),
};

class LoginForm extends StatelessWidget {
  const LoginForm({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login Form',
      theme: ThemeData(
          //primarySwatch: const Color.fromARGB(255, 22, 107, 135),
          ),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  //final PatternAuth _patternAuth = PatternAuth();
  bool _isObscured = true;

  String _currentVersion = '';

  String _errorMessage = '';
  final logger = Logger();
  //final LocalAuthentication _localAuthentication = LocalAuthentication();

  String? androidId;

  @override
  void initState() {
    super.initState();
    _getAndroidId();
    _loadAppVersion();
    _checkSession();
    _checkLoginStatus();
    _requestPermissions();
  }

  /// Reads the installed version straight from the package for the "Version:"
  /// label at the bottom of the login screen. Previously this was a side effect
  /// of the in-app update check; the app now updates through the App Store /
  /// Play Store, so the version is read locally.
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentVersion = packageInfo.version;
        });
      }
    } catch (e) {
      debugPrint('Error reading app version: $e');
    }
  }

  Future<String?> getAndroidId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.id; // This provides the unique device ID
  }

  Future<void> _getAndroidId() async {
    String? id = await getAndroidId();
    if (id != null) {
      await Util.saveSystemAndroidId(id);
    }
    setState(() {
      androidId = id; // Update androidId state
    });
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      _navigateToHomeScreen(); // Navigate to home screen if logged in
    }
  }

  /// Validates the stored session on launch.
  ///
  /// This call used to double as the in-app APK update check. The app now ships
  /// through the App Store / Play Store, so the version comparison and APK
  /// download were removed — but the 401 branch is unrelated to updating and is
  /// still load-bearing: it clears a stale session and pushes the user back to
  /// login. Only that behaviour remains.
  Future<void> _checkSession() async {
    try {
      final response = await ApiService.checkForUpdate();

      if (response.statusCode == 401) {
        // Clear preferences and show session expired dialog
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Show session expired dialog
        showDialog(
          context: context,
          barrierDismissible: false, // Prevent dismissing dialog without action
          builder: (context) => AlertDialog(
            title: const Text('Session Expired'),
            content: const Text(
                'Your session has expired. Please log in again to continue.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginPage(), // Login Page
                    ),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );

        // Automatically navigate to login after 5 seconds if no action
        Future.delayed(const Duration(seconds: 5), () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context); // Close dialog if still open
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginPage(), // Login Page
            ),
          );
        });

        return; // Early return since session expired
      }
    } catch (e) {
      debugPrint('Error checking session: $e');
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
  }

  Future<void> _login() async {
    if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      final email = _emailController.text;
      final password = _passwordController.text;

      final response = await ApiService.login(email, password, androidId!);
      // final response = await ApiService.login(email, password);

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        if (jsonResponse != null) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          int roleId = jsonResponse['userDto']['roleId'];
          await Util.saveUserData(jsonResponse);
          await _fetchAdditionalData(roleId);
          await prefs.setBool('isLoggedIn', true);
          await prefs.setBool('isLoggedInAfterUpdate', true);

          _navigateToHomeScreen();
        } else {
          setState(() {
            _errorMessage = 'Invalid email or password';
          });
        }
      } else {
        setState(() {
          _errorMessage =
              'Login failed. Please enter correct username and password.';
        });
      }
    }
  }

  void _navigateToHomeScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  static Future<void> _fetchAdditionalData(int roleId) async {
    try {
      final response = await ApiService.fetchAdditionalData(roleId);
      if (response.statusCode == 200) {
        var additionalData = json.decode(response.body);
        print('Decoded additionalData: $additionalData');

        if (additionalData is List<dynamic>) {
          List<String>? iconsAndLabels = additionalData.cast<String>();
          if (iconsAndLabels != null) {
            await Util.saveIconsAndLabels(iconsAndLabels);
            print('Saved Icons and Labels: $iconsAndLabels');
          } else {
            print('Failed to cast additional data to List<String>.');
          }
        } else {
          print(
              'Additional data is not in the expected format: ${additionalData.runtimeType}');
        }
      } else {
        print(
            'Failed to fetch additional data. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 403) {
          print(
              '403 Forbidden: Access denied. Check your permissions or token.');
        } else if (response.statusCode == 401) {
          print('401 Unauthorized: Invalid or expired token.');
        } else {
          print('Unhandled status code: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error fetching additional data: $e');
    }
  }

  void _navigateToForgetPasswordScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("lib/assets/images/loginbg.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          // Was a bare Center>Column: in landscape, on a tablet, or with the
          // keyboard up it had nowhere to go and overflowed. The minHeight
          // keeps the form vertically centred when there IS room — a plain
          // scroll view would pin it to the top on a tall tablet screen.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: ContentWidthLimit(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 100,
                          child: Image.asset('lib/assets/images/ajna.png'),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'AJNA',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.normal,
                            color: Color.fromARGB(255, 252, 252, 252),
                          ),
                        ),
                        // Text(
                        //   androidId ?? 'Fetching Android ID...',
                        //   style: TextStyle(
                        //     fontSize: 22,
                        //     fontWeight: FontWeight.normal,
                        //     color: Color.fromARGB(255, 252, 252, 252),
                        //   ),
                        // ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 30, horizontal: 60),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                TextFormField(
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.black.withOpacity(0.7),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                      borderSide: const BorderSide(
                                        color:
                                            Color.fromARGB(255, 255, 255, 255),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                      borderSide: const BorderSide(
                                        color:
                                            Color.fromARGB(255, 255, 255, 255),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                      borderSide: const BorderSide(
                                        color:
                                            Color.fromARGB(255, 255, 255, 255),
                                        width: 2.0,
                                      ),
                                    ),
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.mail,
                                            color: Color.fromARGB(255, 193, 190,
                                                190), // icon color
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            '|',
                                            style: TextStyle(
                                              color: Color.fromARGB(
                                                  255,
                                                  193,
                                                  190,
                                                  190), // pipe symbol color
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    labelText: 'Email',
                                    labelStyle: const TextStyle(
                                      color: Color.fromARGB(255, 193, 190, 190),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 0,
                                      horizontal: 50,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white, // entered text color
                                  ),
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      logger.w('Email field is empty');
                                      return 'Please enter your email';
                                    }
                                    return null;
                                  },
                                ),
                                Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                ),
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.black.withOpacity(0.6),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                      borderSide: const BorderSide(
                                        color:
                                            Color.fromARGB(255, 255, 255, 255),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                      borderSide: const BorderSide(
                                        color:
                                            Color.fromARGB(255, 255, 255, 255),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                      borderSide: const BorderSide(
                                        color:
                                            Color.fromARGB(255, 255, 255, 255),
                                        width: 2.0,
                                      ),
                                    ),
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.password,
                                            color: Color.fromARGB(255, 193, 190,
                                                190), // icon color
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            '|',
                                            style: TextStyle(
                                              color: Color.fromARGB(
                                                  255,
                                                  193,
                                                  190,
                                                  190), // pipe symbol color
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isObscured
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: const Color.fromARGB(
                                            255, 193, 190, 190),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isObscured =
                                              !_isObscured; // Toggle password visibility
                                        });
                                      },
                                    ),
                                    labelText: 'Password',
                                    labelStyle: const TextStyle(
                                      color: Color.fromARGB(255, 193, 190, 190),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 0,
                                      horizontal: 10,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white, // entered text color
                                  ),
                                  obscureText:
                                      _isObscured, // Control whether to obscure text
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      logger.w('Password field is empty');
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(
                                  height: 20.0,
                                ),
                                InkWell(
                                  onTap: _navigateToForgetPasswordScreen,
                                  child: const Text(
                                    'Forgot Password',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color.fromARGB(255, 255, 255, 255),
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                const SizedBox(
                                  height: 20.0,
                                ),
                                ElevatedButton(
                                  onPressed: _login,
                                  style: ButtonStyle(
                                    backgroundColor: WidgetStateProperty.all(
                                        AppColors.primary),
                                  ),
                                  child: const Text(
                                    'Login',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                if (_errorMessage.isNotEmpty)
                                  Text(
                                    _errorMessage,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 100),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Powered by ',
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 186, 183, 183),
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
                                    color: Color.fromARGB(255, 186, 183,
                                        183), // Choose a suitable color
                                    fontSize: 12,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Version: $_currentVersion',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PatternAuth {
  Future<bool> isPatternSet() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedPattern = prefs.getString('pattern');
    return storedPattern != null && storedPattern.isNotEmpty;
  }

  Future<String?> getPattern() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('pattern');
  }

  Future<void> setPattern(String pattern) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('pattern', pattern);
  }
}
