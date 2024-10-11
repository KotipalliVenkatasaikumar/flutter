import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/facility_management/image_capture_screen.dart';
import 'package:ajna/screens/util.dart';

class QrScannerScreen extends StatefulWidget {
  final String scheduleTime;
  final int scheduleId;
  final String location;
  QrScannerScreen(
      {required this.scheduleTime,
      required this.scheduleId,
      required this.location}) {
    // Print scheduleTime in the constructor
    print('Navigating to QrScannerScreen with scheduleTime: $scheduleTime');
    print('Navigating to QrScannerScreen with scheduleId: $scheduleId');
    print('Navigating to QrScannerScreen with location: $location');
  }

  // QrScannerScreen({required this.scheduleTime}) {
  //   // Print scheduleTime in the constructor
  //   print('Navigating to QrScannerScreen with scheduleTime: $scheduleTime');
  // }
  @override
  _QrScannerScreenState createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isLocationMatched = false;
  String errorMessage = '';
  int? roleId;
  int? userId;
  Map<String, dynamic>? scannedQrData;

  double currentLatitude = 0.0; // Declare instance variable for latitude
  double currentLongitude = 0.0; // Declare instance variable for longitude

  String qrLatitude = '0.0';
  String qrLongitude = '0.0';
  String qrRadius = '0.0';

  double distance = 0.0; // Current distance from QR code location
  static const double earthRadius = 6371000; // Earth radius in meters

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  Future<void> initializeData() async {
    roleId = await Util.getRoleId();
    userId = await Util.getUserId();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsiveness
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: Text(
          'QR Code Scanner',
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
                        color: Colors.black54,
                        fontSize: screenSize.width * 0.045,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.02), // Added spacing

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

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenSize = MediaQuery.of(context).size;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25.0),
          ),
          contentPadding: EdgeInsets.all(16.0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Ensure that the children are in a list of Widgets
              Text(
                'QR code scanned successfully!',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: screenSize.width * 0.045,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: screenSize.height * 0.02), // Spacing
              ElevatedButton(
                onPressed: _submitData,
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(Colors.green),
                  padding: MaterialStateProperty.all<EdgeInsets>(
                    EdgeInsets.symmetric(
                      horizontal:
                          screenSize.width * 0.1, // Adjust width for popup
                      vertical: screenSize.height * 0.02,
                    ),
                  ),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
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
            ], // Use square brackets for the children
          ),
        );
      },
    );
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

      if (qrData['location'] != widget.location) {
        setState(() {
          isLocationMatched = false;
          errorMessage = 'You are not authorized to scan this QR.';
        });
        return;
      }

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
      qrData['scheduleTime'] = widget.scheduleTime;
      qrData['scheduleId'] = widget.scheduleId;

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
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _submitData() async {
    if (scannedQrData == null) return;

    try {
      // Navigate to SelfieCaptureScreen with the scanned data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SelfieCaptureScreen(
            scannedData: scannedQrData!,
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

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
