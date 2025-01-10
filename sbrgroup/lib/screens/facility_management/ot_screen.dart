import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:ajna/main.dart';
import 'package:ajna/screens/connectivity_handler.dart';
import 'package:dio/dio.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/util.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'map_screen.dart';

class OtScreen extends StatefulWidget {
  const OtScreen({super.key});

  @override
  _OtScreenState createState() => _OtScreenState();
}

class _OtScreenState extends State<OtScreen> {
  final ConnectivityHandler connectivityHandler = ConnectivityHandler();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  int? intRoleId;
  int? intOraganizationId;
  int? userId;

  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _role = [];
  List<Map<String, dynamic>> _employee = [];
  List<Map<String, dynamic>> _shifts = [];

  int? _selectedProjectId;
  int? _selectedRelocationProjectId;
  int? _selectedRoleId;
  int? _selectedEmployeeId;
  String? _selectedShiftId;
  bool _isLoading = true;
  bool _isEmployeeDropdownEnabled = false;

  String _organizationName = '';

  String _apkUrl = 'http://www.corenuts.com/ajna-app-release.apk';
  bool _isDownloading = false; // Add downloading state
  double _downloadProgress = 0.0; // Add download progress

  @override
  void initState() {
    super.initState();
    // initializeData();
    // _checkForUpdate();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    bool isConnected = await connectivityHandler.checkConnectivity(context);
    if (isConnected) {
      // Proceed with other initialization steps if connected
      _checkForUpdate();
      initializeData();
    }
  }

  Future<void> initializeData() async {
    intOraganizationId = await Util.getOrganizationId();
    intRoleId = await Util.getRoleId();
    userId = await Util.getUserId();
    _fetchOrganizationDetails(intOraganizationId!);
    _fetchProjects(intOraganizationId!);
    _fetchRoles(intOraganizationId!);
    fetchShiftData();
    // _fetchEmployee(intOraganizationId!, _selectedProjectId!, _selectedRoleId!);
  }

  Future<void> _fetchOrganizationDetails(int organizationId) async {
    try {
      final response = await ApiService.fetchOrgDetails(organizationId);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _organizationName = data['organizationName'];
        });
      } else {
        // throw Exception('Failed to load organization details');
        ErrorHandler.handleError(
          context,
          'Failed to load organization details. Please try again later.',
          'Error sending organization details: ${response.statusCode}',
        );
      }
    } catch (e) {
      // print('Error fetching organization details: $e');
      ErrorHandler.handleError(
        context,
        'Failed to fetching organization details. Please try again later.',
        'Error fetching organization details: $e',
      );
    }
  }

  Future<void> _fetchProjects(int organizationId) async {
    try {
      final response =
          await ApiService.fetchOrgProjectsInOtScreen(organizationId);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _projects = data
              .map((project) =>
                  {'id': project['projectId'], 'name': project['projectName']})
              .toList();
          if (_projects.isNotEmpty) {
            // _selectedProjectId = _projects.first['id'];
            _fetchEmployee(
                intOraganizationId!, _selectedProjectId!, _selectedRoleId!);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      // print('Error fetching projects: $e');

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchRoles(int organizationId) async {
    try {
      final response = await ApiService.fetchOrgRoleInOtScreen(organizationId);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _role = data
              .map((role) =>
                  {'roleId': role['roleId'], 'roleName': role['roleName']})
              .toList();
          if (_role.isNotEmpty) {
            // _selectedRoleId = _role.first['roleId'];
            _fetchEmployee(
                intOraganizationId!, _selectedProjectId!, _selectedRoleId!);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchEmployee(
      int organizationId, int projectAssigned, int employeeRoleId) async {
    try {
      final response = await ApiService.fetchOrgEmployeeInOtScreen(
          organizationId, projectAssigned, employeeRoleId);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _employee = data
              .map((employee) =>
                  {'id': employee['id'], 'firstName': employee['firstName']})
              .toList();
          if (_employee.isNotEmpty) {
            // _selectedEmployeeId = _employee.first['id'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      // print('Error fetching projects: $e');

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> fetchShiftData() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      final response = await ApiService.fetchshiftData();

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          _shifts = data
              .map((shifts) => {
                    'id': shifts['id'],
                    'commonRefValue': shifts['commonRefValue'],
                  })
              .toList();

          _isLoading = false; // Stop loading
        });
      }
    } catch (error) {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }

  Future<void> refreshData() async {
    _checkForUpdate();
    await initializeData();
  }

  Future<void> _checkForUpdate() async {
    try {
      final response = await ApiService.checkForUpdate();

      if (response.statusCode == 401) {
        // Clear preferences and show session expired dialog
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Show session expired dialog
        showDialog(
          context: context,
          barrierDismissible: false,
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
                    MaterialPageRoute(builder: (context) => const LoginPage()),
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
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        });

        return; // Early exit due to session expiration
      }

      if (response.statusCode == 200) {
        final latestVersion = jsonDecode(response.body)['commonRefValue'];
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (latestVersion != currentVersion) {
          final apkUrlResponse = await ApiService.getApkDownloadUrl();
          if (apkUrlResponse.statusCode == 200) {
            _apkUrl = jsonDecode(apkUrlResponse.body)['commonRefValue'];
            setState(() {});
            // bool isDeleted = await Util.deleteDeviceTokenInDatabase();

            // if (isDeleted) {
            //   print("Logout successful, device token deleted.");
            // } else {
            //   print("Logout successful, but failed to delete device token.");
            // }

            // // Clear user session data
            // SharedPreferences prefs = await SharedPreferences.getInstance();
            // await prefs.clear();

            // Show update dialog
            _showUpdateDialog(_apkUrl);
          } else {
            print(
                'Failed to fetch APK download URL: ${apkUrlResponse.statusCode}');
          }
        } else {
          setState(() {}); // Update state if no update required
        }
      } else {
        print('Failed to fetch latest app version: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking for update: $e');
      setState(() {});
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
          // Navigator.pushAndRemoveUntil(
          //   context,
          //   MaterialPageRoute(builder: (context) => const LoginPage()),
          //   (Route<dynamic> route) => false,
          // );
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

  Future<String> getFilePath(String fileName) async {
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;
    return '$tempPath/$fileName';
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ot Screen',
              style: TextStyle(
                fontSize: screenWidth > 600 ? 22 : 18,
                color: Colors.white,
              ),
            ),
            if (_isDownloading)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
      bottomNavigationBar: Container(
        color: const Color.fromRGBO(6, 73, 105, 1),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'Powered by ',
                style: TextStyle(
                  color: Color.fromARGB(255, 230, 227, 227),
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
                      255, 230, 227, 227), // Choose a suitable color
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: refreshData,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(), // Enables pull-to-refresh
                child: _buildForm(),
              ),
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 15),
              Text(
                'Organization: $_organizationName',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 125, 125, 124),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField2<int>(
                decoration: InputDecoration(
                  labelText: 'Current Working Location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                value: _selectedProjectId,
                items: _projects.isNotEmpty
                    ? _projects.map<DropdownMenuItem<int>>(
                        (Map<String, dynamic> project) {
                        return DropdownMenuItem<int>(
                          value: project['id'],
                          child: Text(project['name'],
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: Color.fromARGB(255, 80, 79, 79))),
                        );
                      }).toList()
                    : [
                        const DropdownMenuItem<int>(
                          value: -1,
                          child: Text('No Projects Available'),
                        )
                      ],
                onChanged: (int? value) {
                  if (value != null) {
                    setState(() {
                      _selectedProjectId = value;
                      _selectedRoleId = null; // Reset the role selection
                      _selectedEmployeeId = null;
                      _isEmployeeDropdownEnabled = true;
                      // _fetchEmployee(intOraganizationId!, _selectedProjectId!,
                      //     _selectedRoleId!);
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value == -1) {
                    return 'Please select a project';
                  }
                  return null;
                },
                isExpanded: true,
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 300,
                  width: MediaQuery.of(context).size.width - 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField2<int>(
                decoration: InputDecoration(
                  labelText: 'Select Role',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                value: _selectedRoleId,
                items: _role.isNotEmpty
                    ? _role.map<DropdownMenuItem<int>>(
                        (Map<String, dynamic> role) {
                        return DropdownMenuItem<int>(
                          value: role['roleId'],
                          child: Text(role['roleName'],
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: Color.fromARGB(255, 80, 79, 79))),
                        );
                      }).toList()
                    : [
                        const DropdownMenuItem<int>(
                          value: -1,
                          child: Text('No Role Available'),
                        )
                      ],
                onChanged: (int? value) {
                  if (value != null) {
                    setState(() {
                      _selectedRoleId = value;
                      _selectedEmployeeId = null;
                      _isEmployeeDropdownEnabled = true;
                      _fetchEmployee(intOraganizationId!, _selectedProjectId!,
                          _selectedRoleId!);
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value == -1) {
                    return 'Please select a Role';
                  }
                  return null;
                },
                isExpanded: true,
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 300,
                  width: MediaQuery.of(context).size.width - 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField2<int>(
                decoration: InputDecoration(
                  labelText: 'Select Employee',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                value: _selectedEmployeeId,
                items: _employee.isNotEmpty
                    ? _employee.map<DropdownMenuItem<int>>(
                        (Map<String, dynamic> employee) {
                        return DropdownMenuItem<int>(
                          value: employee['id'],
                          child: Text(employee['firstName'],
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: Color.fromARGB(255, 80, 79, 79))),
                        );
                      }).toList()
                    : [
                        const DropdownMenuItem<int>(
                          value: -1,
                          child: Text('No Employee Available'),
                        )
                      ],
                onChanged: _isEmployeeDropdownEnabled
                    ? (int? value) {
                        if (value != null) {
                          setState(() {
                            _selectedEmployeeId = value;
                          });
                        }
                      }
                    : null, // Disable the dropdown if not enabled
                validator: (value) {
                  if (value == null || value == -1) {
                    return 'Please select an Employee';
                  }
                  return null;
                },
                isExpanded: true,
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 300,
                  width: MediaQuery.of(context).size.width - 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField2<int>(
                decoration: InputDecoration(
                  labelText: 'Select New Work Location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                value: _selectedRelocationProjectId,
                items: _projects.isNotEmpty
                    ? _projects.map<DropdownMenuItem<int>>(
                        (Map<String, dynamic> project) {
                        return DropdownMenuItem<int>(
                          value: project['id'],
                          child: Text(project['name'],
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: Color.fromARGB(255, 80, 79, 79))),
                        );
                      }).toList()
                    : [
                        const DropdownMenuItem<int>(
                          value: -1,
                          child: Text('No new work location  Available'),
                        )
                      ],
                onChanged: (int? value) {
                  if (value != null) {
                    setState(() {
                      _selectedRelocationProjectId = value;
                      // _fetchEmployee(intOraganizationId!, _selectedProjectId!,
                      //     _selectedRoleId!);
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value == -1) {
                    return 'Please select a new work location';
                  }
                  return null;
                },
                isExpanded: true,
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 300,
                  width: MediaQuery.of(context).size.width - 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField2<String>(
                decoration: InputDecoration(
                  labelText: 'Select Shift',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                value:
                    _selectedShiftId, // This should be the selected value variable
                items: const [
                  DropdownMenuItem<String>(
                    value: 'Day Shift',
                    child: Text('Day Shift',
                        style: TextStyle(
                            fontSize: 16,
                            color: Color.fromARGB(255, 80, 79, 79))),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Night Shift',
                    child: Text('Night Shift',
                        style: TextStyle(
                            fontSize: 16,
                            color: Color.fromARGB(255, 80, 79, 79))),
                  ),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedShiftId = value; // Assign the selected value
                    });
                  }
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a QR type';
                  }
                  return null;
                },
                isExpanded: true,
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 300,
                  width: MediaQuery.of(context).size.width - 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitFormData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(226, 251, 251, 252),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 32,
                  ),
                ),
                child: const Text(
                  'Submit',
                  style: TextStyle(
                      fontSize: 18, color: Color.fromRGBO(6, 73, 105, 1)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitFormData() async {
    if (!_formKey.currentState!.validate()) {
      // Form is invalid, return early
      return;
    }

    // Collect form data
    Map<String, dynamic> employeeOT = {
      'projectId': _selectedProjectId,
      'roleId': _selectedRoleId,
      'employeeId': _selectedEmployeeId,
      'shiftTime': _selectedShiftId,
      'toLocation': _selectedRelocationProjectId
    };

    try {
      final response = await ApiService.postOt(employeeOT);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _formKey.currentState!.reset();
        setState(() {
          _selectedProjectId = null;
          _selectedRoleId = null;
          _selectedEmployeeId = null;
          _selectedShiftId = null;
          _isEmployeeDropdownEnabled =
              false; // Disable the employee dropdown again if needed
        });
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Center(
                child: Icon(Icons.check_circle, color: Colors.green, size: 50),
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Text(
                      'Success!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 10),
                  Center(
                    child: Text('OT Successfully Submitted!'),
                  ),
                ],
              ),
              actions: <Widget>[
                Center(
                  child: TextButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                          const Color.fromRGBO(6, 73, 105, 1)),
                      foregroundColor:
                          MaterialStateProperty.all<Color>(Colors.white),
                    ),
                    child: const Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                    },
                  ),
                ),
              ],
            );
          },
        );
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to send QR data. Please try again later.',
          'Error sending QR data: ${response.statusCode}',
        );
      }
    } catch (e) {
      ErrorHandler.handleError(
        context,
        'Failed to send QR data. Please try again later.',
        'Error sending QR data: $e',
      );
    }
  }
}
