import 'dart:convert';
import 'dart:io';

import 'package:ajna/screens/sqflite/database_helper.dart';
import 'package:ajna/screens/sqflite/schedule.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
//import 'package:flutter/services.dart';
import 'package:install_plugin/install_plugin.dart';
//import 'package:local_auth/local_auth.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
//import 'package:pattern_lock/pattern_lock.dart';
import 'package:permission_handler/permission_handler.dart';
//import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/home_screen.dart';
import 'package:ajna/screens/profile/forgot_password.dart';
import 'package:ajna/screens/util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens/notification/notification_service.dart';

// const String taskName = "dailyApiTask";
// const int targetHour = 11; // Set to 11 AM
// const int targetMinute = 10; // Set to 10 minutes past the hour
// const int timeRange =
//     5; // Allowable time range in minutes (e.g., between 11:10 AM and 11:15 AM)

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // await NotificationService.instance.initialize();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // // Check network connectivity
  // var connectivityResult = await Connectivity().checkConnectivity();
  // if (connectivityResult == ConnectivityResult.none) {
  //   // No internet connection
  //   runApp(const MyApp()); // Start the app in offline mode or show an error
  // } else {
  //   int? userId = await Util.getUserId(); // Ensure this is async if needed
  //   // Fetch and store schedules only if userId is available and connected to the internet
  //   if (userId != null) {
  //     await deleteAllSchedules(); // Clear old schedules
  //     await fetchAndStoreSchedules(userId); // Fetch new schedules
  //   }

  //   runApp(const MyApp());
  // }
  runApp(const MyApp());
}

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');

  // Check if the payload contains a 'route' key
  String route = message.data.containsKey('route')
      ? message.data['route']
      : '/main'; // Default to '/main' if 'route' is not provided

  // Navigate to the desired route using the global navigator key
  navigatorKey.currentState?.pushNamed(route); // Navigate to the route
}

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   initializeWorkManager(); // Initialize WorkManager
//   runApp(MyApp());
// }

// void initializeWorkManager() {
//   Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
//   // Register a periodic task that runs every 24 hours
//   Workmanager().registerPeriodicTask(
//     "uniqueName", // Unique task name
//     taskName, // Task identifier
//     frequency: Duration(hours: 24), // Runs once every 24 hours
//     initialDelay:
//         Duration(hours: 24), // Delay to ensure it starts at 11:10 AM tomorrow
//     constraints: Constraints(
//       networkType: NetworkType.not_required, // Run offline or online
//       requiresBatteryNotLow: true, // Optional: Run only when battery is not low
//     ),
//   );
// }

// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) async {
//     if (task == taskName) {
//       DateTime now = DateTime.now();
//       if (isAround1110AM(now)) {
//         await performApiCall(); // Only call the API around 11:10 AM
//       }
//     }
//     return Future.value(true);
//   });
// }

// // Check if current time is around 11:10 AM
// bool isAround1110AM(DateTime currentTime) {
//   return currentTime.hour == targetHour &&
//       currentTime.minute >= targetMinute &&
//       currentTime.minute <= (targetMinute + timeRange);
// }

// // Example API call function
// Future<void> performApiCall() async {
//   int? userId = await Util.getUserId();
//   if (userId != null) {
//     await deleteAllSchedules(); // Clear old schedules
//     await fetchAndStoreSchedules(userId); // Fetch new schedules
//   }
// }

Future<void> deleteAllSchedules() async {
  try {
    await DatabaseHelper.instance.deleteAllSchedules();
  } catch (e) {
    print('Error deleting all schedules: $e');
  }
}

Future<void> fetchAndStoreSchedules(int userId) async {
  final response = await ApiService.fetchScanSchedules(userId);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data.isNotEmpty) {
      final schedules = data
          .map<ScanSchedule>((item) => ScanSchedule.fromJson(item))
          .toList();
      await processAndStoreSchedules(schedules);
    } else {
      print('No data found in the response.');
    }
  } else {
    print('Failed to fetch schedules: ${response.statusCode}');
    await retryTask(userId);
  }
}

Future<void> retryTask(int userId) async {
  for (int attempt = 1; attempt <= 2; attempt++) {
    print('Retry attempt $attempt...');
    await Future.delayed(const Duration(seconds: 5));
    final response = await ApiService.fetchScanSchedules(userId);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.isNotEmpty) {
        final schedules = data
            .map<ScanSchedule>((item) => ScanSchedule.fromJson(item))
            .toList();
        await processAndStoreSchedules(schedules);
        return;
      }
    }
    print(
        'Failed to fetch schedules on attempt $attempt: ${response.statusCode}');
  }
}

Future<void> processAndStoreSchedules(List<ScanSchedule> schedules) async {
  final db = await DatabaseHelper.instance.database;
  final batch = db.batch();
  try {
    for (final schedule in schedules) {
      batch.insert(
        'scan_schedules',
        schedule.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  } catch (e) {
    print('Error processing and storing schedules: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AJNA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(238, 244, 246, 1),
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
      routes: {
        '/main': (context) =>
            const HomeScreen(), // Navigate to MainScreen after login
      },
    );
  }
}

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
  bool _isUpdateAvailable = false;
  String _apkUrl = 'http://www.corenuts.com/ajna-app-release.apk';

  String _errorMessage = '';
  final logger = Logger();
  //final LocalAuthentication _localAuthentication = LocalAuthentication();

  bool _isDownloading = false; // Add downloading state
  double _downloadProgress = 0.0; // Add download progress

  String? androidId;

  @override
  void initState() {
    super.initState();
    _getAndroidId();
    _checkForUpdate();
    _checkLoginStatus();
    _requestPermissions();
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

  Future<void> _checkForUpdate() async {
    try {
      final response = await ApiService.checkForUpdate();
      if (response.statusCode == 200) {
        final latestVersion = jsonDecode(response.body)['commonRefValue'];
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        setState(() {
          _currentVersion = currentVersion; // Store current version
        });

        if (latestVersion != currentVersion) {
          final apkUrlResponse = await ApiService.getApkDownloadUrl();
          if (apkUrlResponse.statusCode == 200) {
            _apkUrl = jsonDecode(apkUrlResponse.body)['commonRefValue'];
            setState(() {
              _isUpdateAvailable = true;
            });

            // Clear user session data
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.clear();

            // Show update dialog
            _showUpdateDialog(_apkUrl);
          } else {
            print(
                'Failed to fetch APK download URL: ${apkUrlResponse.statusCode}');
          }
        } else {
          setState(() {
            _isUpdateAvailable = false;
          });
        }
      } else {
        print('Failed to fetch latest app version: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking for update: $e');
      setState(() {
        _isUpdateAvailable = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
  }

  Future<void> downloadAndInstallAPK(String url) async {
    Dio dio = Dio();
    String savePath = await getFilePath('ajna-app-release.apk');
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      setState(() {
        _isDownloading = false;
      });

      if (await Permission.requestInstallPackages.request().isGranted) {
        InstallPlugin.installApk(savePath, appId: 'com.example.ajna')
            .then((result) {
          print('Install result: $result');
          // After installation, navigate back to the login page
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
          );
        }).catchError((error) {
          print('Install error: $error');
        });
      } else {
        print('Install permission denied.');
      }
    } catch (e) {
      print('Download error: $e');
      setState(() {
        _isDownloading = false;
      });
    }
  }

  void _showUpdateDialog(String apkUrl) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dialog from closing on tap outside
        builder: (context) {
          return AlertDialog(
            title: const Text('Update Available'),
            content: const Text(
                'A new version of the app is available. Please update.'),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // Dismiss dialog
                  await downloadAndInstallAPK(apkUrl);
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      );
    });
  }

  Future<String> getFilePath(String fileName) async {
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;
    return '$tempPath/$fileName';
  }

  Future<void> _login() async {
    if (_isUpdateAvailable) {
      return;
    }

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
                padding:
                    const EdgeInsets.symmetric(vertical: 30, horizontal: 60),
                child: _isDownloading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(value: _downloadProgress),
                            const SizedBox(height: 16.0),
                            Text(
                              'Downloading update: ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      )
                    : Form(
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
                                    color: Color.fromARGB(255, 255, 255, 255),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  borderSide: const BorderSide(
                                    color: Color.fromARGB(255, 255, 255, 255),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  borderSide: const BorderSide(
                                    color: Color.fromARGB(255, 255, 255, 255),
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
                                        color: Color.fromARGB(
                                            255, 193, 190, 190), // icon color
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        '|',
                                        style: TextStyle(
                                          color: Color.fromARGB(255, 193, 190,
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
                                    color: Color.fromARGB(255, 255, 255, 255),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  borderSide: const BorderSide(
                                    color: Color.fromARGB(255, 255, 255, 255),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  borderSide: const BorderSide(
                                    color: Color.fromARGB(255, 255, 255, 255),
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
                                        color: Color.fromARGB(
                                            255, 193, 190, 190), // icon color
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        '|',
                                        style: TextStyle(
                                          color: Color.fromARGB(255, 193, 190,
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
                                    const Color.fromRGBO(6, 73, 105, 1)),
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
                          color: Color.fromARGB(
                              255, 186, 183, 183), // Choose a suitable color
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
