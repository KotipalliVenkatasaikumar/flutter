import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ajna/main.dart';
import 'package:ajna/screens/account_entry/account_entry.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/app_bar.dart';
import 'package:ajna/screens/crm/crm_home_screen.dart';
import 'package:ajna/screens/crm/raise-issue.dart';
import 'package:ajna/screens/facility_management/attendace_report.dart';
import 'package:ajna/screens/facility_management/attendance.dart';
import 'package:ajna/screens/facility_management/customer_consumption.dart';
import 'package:ajna/screens/facility_management/qr_generator.dart';
import 'package:ajna/screens/facility_management/qr_schedule.dart';
import 'package:ajna/screens/facility_management/qrregenerate.dart';
import 'package:ajna/screens/facility_management/reports_projects.dart';
import 'package:ajna/screens/facility_management/reset_android_id.dart';
import 'package:ajna/screens/facility_management/user_manage_screen.dart';
import 'package:ajna/screens/facility_management/user_registration.dart';
import 'package:ajna/screens/presales/add_lead.dart';
import 'package:ajna/screens/presales/presales_page.dart';
import 'package:ajna/screens/sales/site_visit_form.dart';
import 'package:ajna/screens/util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MaterialApp(
    home: HomeScreen(),
  ));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class IconButtonWidget extends StatelessWidget {
  final String? imagePath;
  final IconData? icon;
  final String label;
  final Function() onTap;
  final Color iconColor;
  final Color backgroundColor;

  const IconButtonWidget({
    Key? key,
    this.icon,
    this.imagePath,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.black,
    this.backgroundColor = Colors.white,
  })  : assert(imagePath != null || icon != null,
            'Either imagePath or icon must be provided'),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: imagePath != null
                ? Image.asset(imagePath!,
                    width: 50, height: 50) // Ensure this path is correct
                : Icon(icon, size: 25, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12), // Adjust font size here
          ),
        ],
      ),
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>>? _iconDetails;

  final Set<String> staticLabels = {
    'QR Generator',
    'Sales',
    'QR Scan',
    'Site Visit Form',
    'User Registration',
    'Scan Report',
    'Re Generate Qr',
    'QR Assign',
    'QR Schedule',
    'Consumption',
    'Reset Android Id',
    'CRM',
    'Raise Issue',
    'Add Lead',
    'Attendance',
    'Account Entry',
    'Attendance Report',
  };

  final List<Map<String, dynamic>> predefinedIcons = [
    {
      //'icon': Icons.qr_code,
      'icon': null,
      'imagePath': 'lib/assets/images/qrgenerate.png',
      'label': 'QR Generator',
      'onTap': () => const QrGeneratorScreen(),
    },
    {
      //'icon': Icons.business_center,
      'icon': null,
      'imagePath': 'lib/assets/images/sales.png',
      'label': 'Sales',
      'onTap': () => PresalesPage(),
    },
    {
      //'icon': Icons.visibility,
      'icon': null,
      'imagePath': 'lib/assets/images/site_visit.png',
      'label': 'Site Visit Form',
      'onTap': () => SiteVisitForm(),
    },
    {
      //'icon': Icons.app_registration,
      'icon': null,
      'imagePath': 'lib/assets/images/user_registration.png',
      'label': 'User Registration',
      'onTap': () => UserFormScreen(),
    },
    {
      //'icon': Icons.bar_chart,
      'icon': null,
      'imagePath': 'lib/assets/images/scan_report.png',
      'label': 'Scan Report',
      'onTap': () => ReportsHomeScreen(),
    },
    {
      //'icon': Icons.dataset_linked,
      'icon': null,
      'imagePath': 'lib/assets/images/qr_regenarate.png',
      'label': 'Re Generate Qr',
      'onTap': () => const QrRegenerate(),
    },
    {
      //'icon': Icons.assessment,
      'icon': null,
      'imagePath': 'lib/assets/images/qr_assign.png',
      'label': 'QR Assign',
      'onTap': () => const UserManageScreen(),
    },
    {
      //'icon': Icons.qr_code_scanner,
      'icon': null,
      'imagePath': 'lib/assets/images/qrscan.png',
      'label': 'QR Scan',
      'onTap': () => ScanScheduleScreen(),
    },
    {
      //'icon': Icons.construction,
      'icon': null,
      'imagePath': 'lib/assets/images/consumption.png',
      'label': 'Consumption',
      'onTap': () => CustomerConsumptionScreen(),
    },
    {
      //'icon': Icons.reset_tv,
      'icon': null,
      'imagePath': 'lib/assets/images/reset_andriod_id.png',
      'label': 'Reset Android Id',
      'onTap': () => ResetAndroidIdScreen(),
    },
    {
      //'icon': Icons.bar_chart,
      'icon': null,
      'imagePath': 'lib/assets/images/crm-icon.png',
      'label': 'CRM',
      'onTap': () => const CrmHomeScreen(),
    },
    {
      //'icon': Icons.bar_chart,
      'icon': null,
      'imagePath': 'lib/assets/images/issue.png',
      'label': 'Raise Issue',
      'onTap': () => RaiseIssue(),
    },
    {
      //'icon': Icons.bar_chart,
      'icon': null,
      'imagePath': 'lib/assets/images/lead.png',
      'label': 'Add Lead',
      'onTap': () => AddLeadScreen(),
    },
    {
      //'icon': Icons.bar_chart,
      'icon': null,
      'imagePath': 'lib/assets/images/attendace.png',
      'label': 'Attendance',
      'onTap': () => const AttendanceScreen(),
    },
    {
      //'icon': Icons.bar_chart,
      'icon': null,
      'imagePath': 'lib/assets/images/account.png',
      'label': 'Account Entry',
      'onTap': () => TransactionHistoryScreen(),
    },
    {
      //'icon': Icons.bar_chart,
      'icon': null,
      'imagePath': 'lib/assets/images/calendar.png',
      'label': 'Attendance Report',
      'onTap': () => AttendanceReportScreen(),
    },
  ];

  String _apkUrl = 'http://www.corenuts.com/ajna-app-release.apk';
  bool _isDownloading = false; // Add downloading state
  double _downloadProgress = 0.0; // Add download progress

  @override
  void initState() {
    super.initState();
    _initializeData();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      final response = await ApiService.checkForUpdate();
      if (response.statusCode == 200) {
        final latestVersion = jsonDecode(response.body)['commonRefValue'];
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (latestVersion != currentVersion) {
          final apkUrlResponse = await ApiService.getApkDownloadUrl();
          if (apkUrlResponse.statusCode == 200) {
            _apkUrl = jsonDecode(apkUrlResponse.body)['commonRefValue'];
            setState(() {});

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
          setState(() {});
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

  Future<String> getFilePath(String fileName) async {
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;
    return '$tempPath/$fileName';
  }

  Future<void> _initializeData() async {
    List<String>? iconLabels = await Util.getIconsAndLabels();
    List<Map<String, dynamic>> matchedIcons = [];

    if (iconLabels != null) {
      for (var predefinedIcon in predefinedIcons) {
        if (iconLabels.contains(predefinedIcon['label'])) {
          matchedIcons.add(predefinedIcon);
          print(matchedIcons);
        }
      }
    }

    setState(() {
      _iconDetails = matchedIcons;
    });
  }

  Future<void> _refreshData() async {
    await _initializeData();
  }

  Future<Map<String, String?>> getUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userName = prefs.getString('userName');
    String? designation = prefs.getString('designation');
    return {'userName': userName, 'designation': designation};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Center(
          child: Column(
            children: <Widget>[
              Container(
                height: 110,
                width: MediaQuery.of(context).size.width,
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: const DecorationImage(
                    image: AssetImage('lib/assets/images/image-background.png'),
                    fit: BoxFit.cover,
                  ),
                ),
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
                    : FutureBuilder<Map<String, String?>>(
                        future: getUserDetails(),
                        builder: (BuildContext context,
                            AsyncSnapshot<Map<String, String?>> snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return const Center(
                                child: Text("Error fetching user details"));
                          } else if (snapshot.hasData) {
                            String? profileImageUrl =
                                snapshot.data!['profileImageUrl'];
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                    backgroundImage: profileImageUrl != null
                                        ? NetworkImage(profileImageUrl)
                                        : const AssetImage(
                                                'lib/assets/images/avatar.png')
                                            as ImageProvider,
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          "Hi! Welcome.",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color.fromARGB(
                                                255, 231, 225, 225),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        snapshot.data!['userName'] ??
                                            "No username found",
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color.fromARGB(
                                              255, 255, 255, 255),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            );
                          } else {
                            return const Center(
                                child: Text("No user details found"));
                          }
                        },
                      ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: _iconDetails == null
                      ? const CircularProgressIndicator()
                      : GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 3,
                          crossAxisSpacing: 10.0,
                          mainAxisSpacing: 10.0,
                          children: _iconDetails!.map((iconDetail) {
                            return IconButtonWidget(
                              icon: iconDetail['icon'],
                              imagePath: iconDetail['imagePath'],
                              label: iconDetail['label'],
                              iconColor: Colors.white,
                              backgroundColor:
                                  const Color.fromRGBO(255, 255, 255, 255),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => iconDetail['onTap'](),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    );
  }
}
