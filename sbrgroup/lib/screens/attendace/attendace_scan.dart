import 'dart:convert';
import 'dart:math';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/facility_management/success_screen.dart';
import 'package:ajna/screens/util.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';


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
  Map<String, dynamic>? scannedQrData;
  List<String> userLocations = [];

  double currentLatitude = 0.0;
  double currentLongitude = 0.0;

  String qrLatitude = '0.0';
  String qrLongitude = '0.0';
  String qrRadius = '0.0';

  double distance = 0.0;
  static const double earthRadius = 6371000;

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  Future<void> initializeData() async {
    roleId = await Util.getRoleId();
    userId = await Util.getUserId();
    if (userId != null) {
      try {
        userLocations = await fetchUserAttendaceLocations(userId!);
      } catch (e) {
        print('Error fetching locations: $e');
      }
    }
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

  Future<List<String>> fetchUserAttendaceLocations(int userId) async {
    final response = await ApiService.fetchUserAttendaceLocations(userId);

    if (response.statusCode == 200) {
      List<dynamic> jsonResponse = jsonDecode(response.body);
      return jsonResponse
          .map((item) => item['locationName'] as String)
          .toList();
    } else {
      throw Exception('Failed to load user attendance locations');
    }
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

      if (systemAndroidId != userAndroidId) {
        setState(() {
          isLocationMatched = false;
          errorMessage =
              'Device ID mismatch. You are not authorized to scan this QR.';
        });
        return;
      }

      if (!userLocations.contains(qrData['location'])) {
        setState(() {
          isLocationMatched = false;
          errorMessage =
              'You are not allowed to scan the QR code at this location.';
        });
        controller?.resumeCamera();
        return;
      }

// Continue with your logic if the location is matched

      Position position = await _getCurrentPosition(context);
      currentLatitude = position.latitude;
      currentLongitude = position.longitude;

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

      qrData['roleId'] = roleId;
      qrData['userId'] = userId;
      qrData['login'] = widget.isLoggedIn;

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
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
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

    try {
      final response = await ApiService.sendAttendace(scannedQrData!);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Handle successful response
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => SuccessScreen()),
        );
        // Optionally, navigate to another screen or update UI
      } else {
        // Handle error response
        ErrorHandler.handleError(
          context,
          'Failed to submit data. Please try again later.',
          'Error uploading selfie: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Handle exceptions
      ErrorHandler.handleError(
        context,
        'Failed to submit data. Please try again later.',
        'Error submitting data: $e',
      );
    }
  }
}
