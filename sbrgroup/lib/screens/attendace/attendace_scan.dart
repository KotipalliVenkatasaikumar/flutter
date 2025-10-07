import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ajna/main.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/facility_management/selfie_capture_fo.dart';
import 'package:ajna/screens/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceScanScreen extends StatefulWidget {
  final bool isLoggedIn;

  const AttendanceScanScreen({Key? key, required this.isLoggedIn})
      : super(key: key);

  @override
  _AttendanceScanScreenState createState() => _AttendanceScanScreenState();
}

class _AttendanceScanScreenState extends State<AttendanceScanScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isLocationMatched = false;
  String errorMessage = '';
  int? roleId;
  int? userId;
  int? organizationId;
  Map<String, dynamic>? scannedQrData;

  Map<String, dynamic>? qrResponseData;

  double currentLatitude = 0.0;
  double currentLongitude = 0.0;

  String qrLatitude = '0.0';
  String qrLongitude = '0.0';
  String qrRadius = '0.0';

  double distance = 0.0;
  static const double earthRadius = 6371000;

  String _apkUrl = 'http://www.corenuts.com/ajna-app-release.apk';
  bool _isDownloading = false; // Add downloading state
  double _downloadProgress = 0.0; // Add download progress

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _checkForUpdate();
    initializeData();
  }

  Future<void> initializeData() async {
    roleId = await Util.getRoleId();
    userId = await Util.getUserId();
    organizationId = await Util.getOrganizationId();
    _loadQrResponse();
  }

  void _loadQrResponse() async {
    Map<String, dynamic>? storedData = await getStoredQrResponse();
    if (storedData != null) {
      setState(() {
        qrResponseData = storedData;
      });
    }
  }

  Future<void> _initializeLocation() async {
    try {
      Position position = await _getCurrentPosition(context);
      setState(() {
        currentLatitude = position.latitude;
        currentLongitude = position.longitude;
      });
    } catch (e) {
      print('Error fetching location: $e');

      if (mounted) {
        errorMessage =
            'Failed to fetch location. Please check GPS and try again.';
      }
    }
  }

  Future<Map<String, dynamic>?> getStoredQrResponse() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('qr_response');

    if (jsonString != null) {
      return jsonDecode(jsonString); // Convert back to JSON object (Map)
    }
    return null; // Return null if not found
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

      await Util.installApk(savePath);
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
    // Get screen size for responsiveness
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: Text(
          'Attendance Scanner',
          style: TextStyle(
            fontSize: screenSize.width * 0.045, // Dynamic font size
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Column(
        children: <Widget>[
          // Conditionally render QR View only when isLocationMatched is false
          if (!isLocationMatched)
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Container(
                    width: screenSize.width,
                    child: QRView(
                      key: qrKey,
                      onQRViewCreated: _onQRViewCreated,
                    ),
                  ),
                  // Custom QR Code Frame
                  Center(
                    child: Container(
                      width: screenSize.width * 0.8,
                      height: screenSize.width * 0.8,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color.fromARGB(
                              255, 76, 147, 175), // Frame color
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        // Optional shadow
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: Offset(0, 2), // changes position of shadow
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: Colors.transparent, // Background color
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // If location is matched, show confirmation and submit button
          if (isLocationMatched)
            Expanded(
              flex: 6,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'QR code scanned successfully!',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: screenSize.width * 0.045,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.02), // Added spacing
                    Text(
                      'Please submit the data.',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: screenSize.width * 0.04,
                      ),
                    ),
                    SizedBox(
                        height:
                            screenSize.height * 0.05), // Space before button
                    ElevatedButton(
                      onPressed: _submitData,
                      style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all<Color>(Colors.green),
                        padding: MaterialStateProperty.all<EdgeInsets>(
                          EdgeInsets.symmetric(
                            horizontal: screenSize.width * 0.25,
                            vertical: screenSize.height * 0.02,
                          ),
                        ),
                        shape:
                            MaterialStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25.0),
                          ),
                        ),
                      ),
                      child: Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: screenSize.width * 0.045,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Status section (if location not matched, showing status or error)
          if (!isLocationMatched)
            Expanded(
              flex: 1,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Show message depending on the location match status
                    errorMessage.isNotEmpty
                        ? Text(
                            errorMessage,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize:
                                  screenSize.width * 0.04, // Dynamic font size
                            ),
                          )
                        : Text(
                            'Scanning QR code...',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize:
                                  screenSize.width * 0.04, // Dynamic font size
                            ),
                          ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      await _handleQrCodeScanned(scanData.code);
    });
  }

  Future<void> _handleQrCodeScanned(String? data) async {
    if (data == null) return;

    try {
      Map<String, dynamic> qrData = jsonDecode(data);

      qrLatitude = (qrData['latitude'] as String?) ?? '0.0';
      qrLongitude = (qrData['longitude'] as String?) ?? '0.0';
      qrRadius = (qrData['radius'] as String?) ?? '0.0';

      String? systemAndroidId = await Util.getSystemAndroidId();
      String? userAndroidId = await Util.getUserAndroidId();

      print('System Android ID: $systemAndroidId');
      print('User Android ID: $userAndroidId');

      if (systemAndroidId == null ||
          userAndroidId == null ||
          systemAndroidId.trim() != userAndroidId.trim()) {
        setState(() {
          isLocationMatched = false;
          errorMessage =
              'Device ID mismatch. You are not authorized to scan this QR.';
        });
        return;
      }

      if (!widget.isLoggedIn) {
        if (qrResponseData == null ||
            qrResponseData!['location'] != qrData['location']) {
          setState(() {
            isLocationMatched = false;
            errorMessage =
                'You are not allowed to scan the QR code at this location.';
          });
          controller?.resumeCamera();
          return;
        }
      } else {
        controller?.resumeCamera();
      }

// Continue with your logic if the location is matched

      Position position;
      try {
        position = await _getCurrentPosition(context);
      } catch (e) {
        errorMessage = 'Failed to get current location. Please enable GPS.';
        return;
      }

      setState(() {
        currentLatitude = position.latitude;
        currentLongitude = position.longitude;
      });

      distance = _calculateHaversineDistance(
        currentLatitude,
        currentLongitude,
        double.parse(qrLatitude),
        double.parse(qrLongitude),
      );

      if (distance > double.parse(qrRadius)) {
        setState(() {
          isLocationMatched = false;
          errorMessage =
              "Your current location doesn't match the QR code location. Please check your location and try again.";
        });
        controller?.resumeCamera();
        return;
      }

      // qrData['roleId'] = roleId;
      qrData['userId'] = userId;
      // qrData['login'] = widget.isLoggedIn;

      qrData['status'] = widget.isLoggedIn ? "In" : "Out";
      qrData['orgId'] = organizationId;

      int? fieldOfficerPatrolId = qrResponseData?['fieldOfficerPatrolId'];

      if (!widget.isLoggedIn && fieldOfficerPatrolId != null) {
        qrData['fieldOfficerPatrolId'] = fieldOfficerPatrolId;
      }

      setState(() {
        scannedQrData = qrData;
        isLocationMatched = true;
        errorMessage = '';
      });
    } catch (e) {
      print('Error parsing QR code data');
    }
  }

  double _calculateHaversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double rLat1 = _toRadians(lat1);
    double rLat2 = _toRadians(lat2);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(rLat1) * cos(rLat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<Position> _getCurrentPosition(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      await Future.delayed(const Duration(seconds: 2));
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _showDialog(
          context,
          'Location services are disabled',
          'Please enable location services in your device settings.',
        );
        throw 'Location services are disabled. Please enable them in the settings.';
      }
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await Future.delayed(Duration(seconds: 2));
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          await _showDialog(
            context,
            'Location permissions denied',
            'Please grant location permissions in your device settings.',
          );
          throw 'Location permissions are denied. Please allow them in the settings.';
        }
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await _showDialog(
        context,
        'Location permissions permanently denied',
        'Please enable location permissions manually in your device settings.',
      );
      throw 'Location permissions are permanently denied. We cannot request permissions.';
    }

    try {
      // Ensures fresh location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 5),
      );
      return position;
    } catch (e) {
      print('Error fetching location');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching location')),
      );
      throw 'Error fetching location';
    }
  }

  Future<void> _showDialog(
    BuildContext context,
    String title,
    String content,
  ) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _submitData() async {
    if (scannedQrData == null) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();

    // if (!widget.isLoggedIn) {
    //   await prefs.remove('qr_response');
    // }
    try {
      // Navigate to SelfieCaptureScreen with the scanned data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoSelfieCaptureScreen(
            scannedData: scannedQrData!,
            isLoggedIn: widget.isLoggedIn,
          ),
        ),
      );
    } catch (e) {
      // Handle navigation errors or other exceptions
      ErrorHandler.handleError(
        context,
        'Failed to navigate to selfie capture screen. Please try again later.',
        'Error navigating to selfie capture screen: $e',
      );
    }
  }
}
