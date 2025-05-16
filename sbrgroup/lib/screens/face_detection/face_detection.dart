import 'dart:io';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/face_detection/embedding_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class AttendanceScreen extends StatefulWidget {
  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
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
    print("Initializing model...");
    _faceEmbeddingService = FaceEmbeddingService();
    await _faceEmbeddingService.init();
    print("Model ready: ${_faceEmbeddingService.isReady}");
  }

  Future<void> _speak(String message) async {
    await _flutterTts.stop();
    await _flutterTts.speak(message);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || _faceDetected || _isLoading || _isProcessingAPI) return;

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
      await _sendAttendanceToAPI(imageFile);
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

  Future<void> _sendAttendanceToAPI(File imageFile) async {
    try {
      final response =
          await ApiService.submitCaptureFace(imageFile, _generatedEmbeddings);

      String message;
      bool isSuccess;

      if (response.statusCode == 200) {
        message = response.body.toString();
        isSuccess = true;
      } else {
        message = response.body.toString();
        isSuccess = false;
      }

      await _showResponseDialog(message, isSuccess);
    } catch (e) {
      print("API Error: $e");
      await _showResponseDialog(
          "Something went wrong. Please try again later.", false);
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
              'Face Capture',
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
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildFaceFrame(),
          if (_isLoading) _buildLoadingOverlay(),
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
