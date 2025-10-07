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
import 'package:image/image.dart' as img;

class FaceAttendanceScreen extends StatefulWidget {
  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<FaceAttendanceScreen> {
  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;
  bool _isDetecting = false;
  bool _faceDetected = false;
  bool _isLoading = false;
  bool _isProcessingAPI = false;

  int _countdown = 3;
  Timer? _countdownTimer;
  bool _isCountingDown = false;




  late CameraDescription _camera;
  late FlutterTts _flutterTts;
  List<double> _generatedEmbeddings = [];
  late FaceEmbeddingService _faceEmbeddingService;
  List<Map<String, dynamic>> _shifts = [];
  int? _selectedShiftId;
  int? _selectedLocationId;
  List<Map<String, dynamic>> _locations = [];
  int? _organizationId;
  CameraLensDirection _currentDirection = CameraLensDirection.back;

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
    fetchShiftData();
    fetchLocationData(_organizationId);

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

  Future<void> fetchLocationData(int? organizationId) async {
    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      final response = await ApiService.fetchLocation(organizationId);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          _locations = data
              .map((location) => {
                    'id': location['id'],
                    'location': location['location'] ?? 'Unknown',
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
      await _sendAttendanceToAPI(imageFile, isLogin: true);
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
        organizationId: _organizationId,
        locationId: _selectedLocationId,
        isLogin: isLogin,
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
      _selectedLocationId = null;
    });
  }

  Future<void> _toggleCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
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
    _cameraController?.dispose();
    _countdownTimer?.cancel();
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
              'In Face Capture',
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
      body: (_selectedShiftId == null || _selectedLocationId == null)
          ? Column(
                children: [
                  _buildShiftDropdown(),
                  _buildLocationDropdown(),
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
                    icon: const Icon(Icons.switch_camera,
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
            if (_selectedShiftId != null && _selectedLocationId != null && _cameraController != null && _cameraController!.value.isInitialized) {
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

  Widget _buildLocationDropdown() {
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
            labelText: 'Select Location',
            prefixIcon: Icon(Icons.location_on, color: Color.fromARGB(255, 41, 221, 200)),
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
          value: _selectedLocationId,
          items: _locations.map((location) {
            return DropdownMenuItem<int>(
              value: location['id'],
              child: Text(
                location['location'] ?? 'Unknown Location',
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width > 500 ? 18 : 16,
                  color: Color.fromARGB(255, 80, 79, 79),
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedLocationId = value;
            });
            if (_selectedShiftId != null && _selectedLocationId != null && _cameraController != null && _cameraController!.value.isInitialized) {
              _startCountdown();
            }
          },
          validator: (value) {
            if (value == null) {
              return 'Please select a location';
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
