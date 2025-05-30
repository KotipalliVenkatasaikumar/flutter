import 'dart:convert';
import 'dart:io';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/face_detection/embedding_service.dart';
import 'package:ajna/screens/util.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

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

  late CameraDescription _camera;
  late final FaceDetector _faceDetector;
  late FlutterTts _flutterTts;
  List<double> _generatedEmbeddings = [];
  late FaceEmbeddingService _faceEmbeddingService;
  List<Map<String, dynamic>> _shifts = [];
  int? _selectedShiftId;
  int? _organizationId;

  int? _selectedLocationId;
  List<Map<String, dynamic>> _locations = [];

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("en-IN");
    _flutterTts.setPitch(1.0);
    _flutterTts.setSpeechRate(0.5);
    _initializeModel();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableClassification: false,
      ),
    );

    _initializeCamera();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      _camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      _cameraController = CameraController(
        _camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _cameraInitFuture = _cameraController!.initialize().then((_) {
        if (!mounted) return;
        _cameraController!.startImageStream(_processCameraImage);
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
                    'location': location['location'],
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

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting ||
        _faceDetected ||
        _isLoading ||
        _isProcessingAPI ||
        _selectedShiftId == null ||
        _selectedLocationId == null) return;
    _isDetecting = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize =
          Size(image.width.toDouble(), image.height.toDouble());
      final InputImageFormat inputFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
              InputImageFormat.nv21;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: InputImageRotation.rotation0deg,
          format: inputFormat,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty && !_faceDetected) {
        setState(() {
          _faceDetected = true;
        });
        _detectFaceAndSendToAPI();
      } else if (faces.isEmpty && _faceDetected) {
        setState(() {
          _faceDetected = false;
        });
      }
    } catch (e) {
      print("Face detection error: $e");
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _detectFaceAndSendToAPI() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    setState(() {
      _isLoading = true;
      _isProcessingAPI = true;
    });

    try {
      final image = await _cameraController!.takePicture();
      File imageFile = File(image.path);
      await _generateEmbedding(imageFile);
      await _sendAttendanceToAPI(imageFile, isLogin: false);
    } catch (e) {
      print("Error taking picture: $e");
    } finally {
      await Future.delayed(Duration(seconds: 2));
      setState(() {
        _faceDetected = false;
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
        embeddings: _generatedEmbeddings,
        shiftId: _selectedShiftId!,
        isLogin: isLogin,
        organizationId: _organizationId,
        locationId: _selectedLocationId,
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
    setState(() {
      _isDetecting = true;
    });

    await _speak(message);

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
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : Colors.red,
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

    await Future.delayed(Duration(seconds: 6));

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    setState(() {
      _isDetecting = false;
      _faceDetected = false;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
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
      body: _isLoading
          ? _buildLoadingOverlay()
          : (_selectedShiftId == null || _selectedLocationId == null)
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildShiftDropdown(),
                      _buildLocationDropdown(),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          if (_selectedShiftId != null &&
                              _selectedLocationId != null) {
                            setState(() {}); // trigger camera view
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    _buildCameraPreview(),
                    _buildFaceFrame(),
                  ],
                ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return SizedBox.expand(
      child: CameraPreview(_cameraController!),
    );
  }

  Widget _buildFaceFrame() {
    return Align(
      alignment: Alignment.center,
      child: ClipOval(
        child: Container(
          width: 250,
          height: 350,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.greenAccent, width: 3),
            color: Colors.transparent,
          ),
          child: const Center(
            child: Text(
              "Align your face here",
              style: TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShiftDropdown() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: DropdownButtonFormField<int>(
        decoration: InputDecoration(
          labelText: 'Select Shift',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(
              color: Color.fromARGB(255, 41, 221, 200),
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(8.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(
              color: Color.fromARGB(255, 23, 158, 142),
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        value: _selectedShiftId,
        items: _shifts.map((shift) {
          return DropdownMenuItem<int>(
            value: shift['id'],
            child: Text(
              shift['commonRefValue'],
              style: const TextStyle(
                fontSize: 16,
                color: Color.fromARGB(255, 80, 79, 79),
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedShiftId = value;
          });
        },
        validator: (value) {
          if (value == null) {
            return 'Please select a shift';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildLocationDropdown() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: DropdownButtonFormField<int>(
        decoration: InputDecoration(
          labelText: 'Select Location',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(
              color: Color.fromARGB(255, 41, 221, 200),
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(8.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(
              color: Color.fromARGB(255, 23, 158, 142),
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        value: _selectedLocationId,
        items: _locations.map((location) {
          return DropdownMenuItem<int>(
            value: location['id'],
            child: Text(
              location['location'],
              style: const TextStyle(
                fontSize: 16,
                color: Color.fromARGB(255, 80, 79, 79),
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedLocationId = value;
          });
        },
        validator: (value) {
          if (value == null) {
            return 'Please select a location';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              "Processing Attendance...",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
