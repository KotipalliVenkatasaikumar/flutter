import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:ajna/screens/face_detection/embedding_service.dart';
import 'package:ajna/screens/util.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogOutFaceAttendanceScreen extends StatefulWidget {
  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<LogOutFaceAttendanceScreen> {
  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;
  bool _isDetecting = false;
  bool _faceDetected = false;
  bool _isLoading = false;
  bool _isProcessingAPI = false;

  double currentLatitude = 0.0;
  double currentLongitude = 0.0;

  // Countdown state
  int _countdown = 3;
  bool _isCountingDown = false;
  Timer? _countdownTimer;

  late CameraDescription _camera;
  late FlutterTts _flutterTts;
  List<double> _generatedEmbeddings = [];
  late FaceEmbeddingService _faceEmbeddingService;
  List<Map<String, dynamic>> _shifts = [];
  int? _selectedShiftId;
  int? _organizationId;

  int? _selectedLocationId;
  CameraLensDirection _currentDirection = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("en-IN");
    _flutterTts.setPitch(1.0);
    _flutterTts.setSpeechRate(0.5);
    _initializeModel();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      _camera = cameras.firstWhere(
        (camera) => camera.lensDirection == _currentDirection,
      );
      _cameraController = CameraController(
        _camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _cameraInitFuture = _cameraController!.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _initializeModel() async {
    _organizationId = await Util.getOrganizationId();
    final prefs = await SharedPreferences.getInstance();
    _selectedLocationId = prefs.getInt('selectedProjectId');
    if (_selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a project first.')),
      );
      Navigator.pop(context);
      return;
    }
    fetchShiftData();
    await _handleQrCodeScanned();
    print("Initializing model...");
    _faceEmbeddingService = FaceEmbeddingService();
    await _faceEmbeddingService.init();
    print("Model ready: ${_faceEmbeddingService.isReady}");
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
                    'refValue': shifts['refValue'] ?? '',
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


  Future<void> _speak(String message) async {
    await _flutterTts.stop();
    await _flutterTts.speak(message);
  }

   Future<void> _handleQrCodeScanned() async {
    try {
      Position position = await _getCurrentPosition(context);
      currentLatitude = position.latitude;
      currentLongitude = position.longitude;
      setState(() {});
    } catch (e) {
      print('Error parsing QR code data: $e');
    }
  }


  Future<Position> _getCurrentPosition(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Open system Location Services settings (iOS opens Settings > Privacy > Location Services)
      await Geolocator.openLocationSettings();
      await Future.delayed(const Duration(seconds: 2));
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _showDialog(
          context,
          'Location services are disabled',
          'Please enable location services in your device settings.',
          // Always show settings for location service disabled
          forceShowSettings: true,
        );
        throw 'Location services are disabled.';
      }
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await _showDialog(
          context,
          'Location permissions denied',
          'Please grant location permissions in your device settings.',
          forceShowSettings: true,
        );
        throw 'Location permissions are denied.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await _showDialog(
        context,
        'Location permissions permanently denied',
        'Please enable location permissions manually in your device settings.',
        forceShowSettings: true,
      );
      throw 'Location permissions are permanently denied.';
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      print('Error fetching location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error fetching location')),
        );
      }
      throw 'Error fetching location';
    }
  }



   Future<void> _showDialog(
    BuildContext context,
    String title,
    String content,
    {bool forceShowSettings = false}
  ) async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final bool showSettings = forceShowSettings || title.toLowerCase().contains('denied');
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            if (showSettings)
              TextButton(
                child: const Text('Open Settings'),
                onPressed: () async {
                  await openAppSettings();
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
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





  Future<void> _takePictureAndSendToAPI() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    setState(() {
      _isLoading = true;
      _isProcessingAPI = true;
    });

    try {
      final image = await _cameraController!.takePicture();
      File imageFile = File(image.path);
      // await _generateEmbedding(imageFile);
      await _sendAttendanceToAPI(imageFile, isLogin: false);
    } catch (e) {
      print("Error taking picture: $e");
    } finally {
      await Future.delayed(Duration(seconds: 2));
      setState(() {
        _isLoading = false;
        _isProcessingAPI = false;
      });
    }
  }

  Future<void> _generateEmbedding(File imageFile) async {
    if (!_faceEmbeddingService.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Model not loaded yet.")),
      );
      return;
    }

    try {
      final img.Image image = img.decodeImage(await imageFile.readAsBytes())!;
      final List<double> embeddings =
          await _faceEmbeddingService.getEmbedding(image);

      setState(() {
        _generatedEmbeddings = embeddings;
      });

      print('Embedding result: $_generatedEmbeddings');

      if (_generatedEmbeddings.every((e) => e == 0.0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Embedding is all zeros!')),
        );
      }
    } catch (e) {
      print('Error during embedding: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to generate embedding.')),
      );
    }
  }

  Future<void> _sendAttendanceToAPI(File imageFile,
      {required bool isLogin}) async {
    try {
      final response = await ApiService.submitCaptureFace(
        imageFile: imageFile,
        // embeddings: _generatedEmbeddings,
        shiftId: _selectedShiftId!,
        isLogin: isLogin,
        organizationId: _organizationId,
        locationId: _selectedLocationId,
        latitude: currentLatitude,
        longitude: currentLongitude,
      );

      String message = response.body.toString();
      bool isSuccess = response.statusCode == 200;

      await _showResponseDialog(message, isSuccess);
    } catch (e) {
      print("API Error: $e");
      await _showResponseDialog(
        "Something went wrong. Please try again later.",
        false,
      );
    }
  }

  Future<void> _showResponseDialog(String message, bool isSuccess) async {
    await _speak(message);

    // Determine icon and color based on message content
    IconData dialogIcon;
    Color dialogColor;
    String msgLower = message.toLowerCase();
    if (msgLower.contains('success') || msgLower.contains('successfully')) {
      dialogIcon = Icons.check_circle;
      dialogColor = Colors.green;
    } else if (msgLower.contains('already recorded')) {
      dialogIcon = Icons.warning;
      dialogColor = Colors.orange;
    } else if (msgLower.contains('no login record found') ||
        msgLower.contains('something went wrong') ||
        msgLower.contains('failed')) {
      dialogIcon = Icons.error;
      dialogColor = Colors.red;
    } else {
      dialogIcon = Icons.error;
      dialogColor = Colors.red;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 16,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                dialogIcon,
                color: dialogColor,
                size: 50,
              ),
              SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 6));

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    setState(() {
      _selectedShiftId = null;
    });
  }

  Future<void> _toggleCamera() async {
    if (_cameraController != null) {
      try {
        await _cameraController!.dispose();
      } catch (e) {
        print('Error disposing camera: $e');
      }
      _cameraController = null;
    }
    setState(() {
      _currentDirection = _currentDirection == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
    });
    await _initializeCamera();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    _flutterTts.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 3;
      _isCountingDown = true;
    });
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_countdown == 1) {
        timer.cancel();
        setState(() {
          _isCountingDown = false;
        });
        _onCountdownComplete();
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  void _onCountdownComplete() async {
    if (_isLoading || _isProcessingAPI) return;
    setState(() {
      _isDetecting = true;
      _faceDetected = true;
    });
    await _takePictureAndSendToAPI();
    setState(() {
      _isDetecting = false;
      _faceDetected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final loadingFontSize = width > 500 ? 20.0 : 16.0;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Out Face Capture',
              style: TextStyle(
                fontSize: width > 600 ? 22 : 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: (_selectedShiftId == null)
          ? Column(
                children: [
                  _buildShiftDropdown(),
                ],
              )
          : Stack(
              children: [
                _buildCameraPreview(),
                if (_isCountingDown) _buildCountdownOverlay(width, height),
                if (_isLoading) _buildLoadingOverlay(loadingFontSize),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: Icon(Icons.switch_camera,
                        color: Colors.white, size: 32),
                    onPressed: _toggleCamera,
                    tooltip: 'Switch Camera',
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final frameWidth = width * 0.7;
        final frameHeight = height * 0.5;
        return Center(
          child: SizedBox(
            width: frameWidth,
            height: frameHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: frameWidth,
                    height: frameHeight,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    width: frameWidth,
                    height: frameHeight,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent, width: 3),
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(frameWidth / 2, frameHeight / 2),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Center(
                    child: Text(
                      "Align your face here",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: width > 500 ? 18.0 : 14.0,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  Widget _buildCountdownOverlay(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.black45,
      child: Center(
        child: Text(
          '$_countdown',
          style: TextStyle(
            color: Colors.white,
            fontSize: width > 500 ? 80 : 48,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 8, color: Colors.black)],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(double fontSize) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              "Processing Attendance...",
              style: TextStyle(color: Colors.white, fontSize: fontSize),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftDropdown() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: DropdownButtonFormField2<int>(
          decoration: InputDecoration(
            labelText: 'Select Shift',
            prefixIcon: Icon(Icons.schedule, color: Color.fromARGB(255, 41, 221, 200)),
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
          value: _selectedShiftId,
          items: _shifts.map((shift) {
            return DropdownMenuItem<int>(
              value: shift['id'],
              child: Text(
                shift['refValue'] ?? 'Unknown Shift',
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width > 500 ? 18 : 16,
                  color: Color.fromARGB(255, 80, 79, 79),
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedShiftId = value;
            });
            if (_selectedShiftId != null && _cameraController != null && _cameraController!.value.isInitialized) {
              _startCountdown();
            }
          },
          validator: (value) {
            if (value == null) {
              return 'Please select a shift';
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
      ),
    );
  }



}
