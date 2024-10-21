import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'success_screen.dart';

class SelfieCaptureScreen extends StatefulWidget {
  final Map<String, dynamic> scannedData;
  SelfieCaptureScreen({required this.scannedData});

  @override
  _SelfieCaptureScreenState createState() => _SelfieCaptureScreenState();
}

class _SelfieCaptureScreenState extends State<SelfieCaptureScreen> {
  File? _selfie;
  bool _isSubmitting = false;
  String _statusMessage = '';
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  bool _isCameraInitialized = false;
  bool _isPreviewing = false;
  bool _hasCameraPermission = false;
  CameraLensDirection _currentDirection = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final cameraStatus = await Permission.camera.status;
    switch (cameraStatus) {
      case PermissionStatus.granted:
        setState(() => _hasCameraPermission = true);
        _initializeCamera();
        break;
      case PermissionStatus.denied:
        final requestResult = await Permission.camera.request();
        if (requestResult == PermissionStatus.granted) {
          setState(() => _hasCameraPermission = true);
          _initializeCamera();
        } else {
          _showPermissionDialog();
        }
        break;
      case PermissionStatus.permanentlyDenied:
        openAppSettings();
        break;
      default:
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
            'Camera permission is required to capture selfies. Please grant permission in your device settings.'),
        actions: [
          TextButton(
            onPressed: () => openAppSettings(),
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeCamera() async {
    if (_cameraController == null && _hasCameraPermission) {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == _currentDirection,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _initializeControllerFuture = _cameraController!.initialize();
      await _initializeControllerFuture;
      setState(() {
        _isCameraInitialized = true;
        _isPreviewing = true; // Start the preview after initialization
      });
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
      _isCameraInitialized = false;
    }

    _currentDirection = _currentDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    _initializeCamera();
  }

  Future<void> _captureSelfie() async {
    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final XFile? image = await _cameraController!.takePicture();
        if (image != null) {
          File imageFile = File(image.path);
          List<int> imageBytes = await imageFile.readAsBytes();
          Uint8List uint8ImageBytes = Uint8List.fromList(imageBytes);
          img.Image decodedImage = img.decodeImage(uint8ImageBytes)!;
          img.Image nonMirroredImage = img.flipHorizontal(decodedImage);
          File correctedImageFile = File(imageFile.path)
            ..writeAsBytesSync(img.encodeJpg(nonMirroredImage));

          setState(() {
            _selfie = correctedImageFile;
            _statusMessage = '';
            _isPreviewing = false;
            _disposeCamera();
          });
        }
      }
    } catch (e) {
      ErrorHandler.handleError(
        context,
        'Failed to capture image. Please try again later.',
        'Error capturing image: $e',
      );
    }
  }

  Future<void> _submitSelfie() async {
    if (_selfie == null) {
      ErrorHandler.handleError(
        context,
        'No selfie to submit.',
        'No file to submit.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = '';
    });

    try {
      final scannedDataJson = jsonEncode(widget.scannedData);
      final response =
          await ApiService.submitQrTransactionData(scannedDataJson, _selfie!);

      if (response.statusCode == 201) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => SuccessScreen()),
        );
      } else if (response.statusCode == 417) {
        ErrorHandler.handleError(
          context,
          'It\'s too early. Please try again closer to your scheduled time.',
          'Expectation failed: ${response.statusCode}',
        );
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to upload selfie. Please try again later.',
          'Error uploading selfie: ${response.statusCode}',
        );
      }
    } catch (e) {
      ErrorHandler.handleError(
        context,
        'Error during upload. Please try again later.',
        'Error during upload: $e',
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _disposeCamera() {
    if (_cameraController != null) {
      _cameraController!.dispose();
      _cameraController = null;
      _isCameraInitialized = false;
    }
  }

  @override
  void dispose() {
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsiveness
    final screenSize = MediaQuery.of(context).size;

    Widget content;

    if (_isPreviewing && _isCameraInitialized) {
      content = Stack(
        alignment: Alignment.topCenter,
        children: [
          // Make CameraPreview take a responsive height
          SizedBox(
            height: screenSize.height * 0.75, // Take 75% of the screen height
            child: CameraPreview(_cameraController!),
          ),
          Padding(
            padding: EdgeInsets.all(screenSize.width * 0.05), // Dynamic padding
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  child: const Icon(Icons.camera_alt),
                  onPressed: _captureSelfie,
                ),
                SizedBox(height: screenSize.height * 0.02), // Dynamic spacing
                FloatingActionButton(
                  child: const Icon(Icons.switch_camera),
                  onPressed: _toggleCamera,
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (_selfie != null) ...[
            SizedBox(
              height: screenSize.height * 0.4, // Dynamic height for image
              child: Image.file(_selfie!),
            ),
            SizedBox(height: screenSize.height * 0.03), // Dynamic spacing
          ],
          ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () async {
                    await _initializeCamera();
                  },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.15,
                vertical: screenSize.height * 0.02,
              ),
            ),
            child: Text(
              _selfie == null ? 'Capture Image' : 'Retake Image',
              style: TextStyle(
                fontSize: screenSize.width * 0.045,
              ),
            ),
          ),
          SizedBox(height: screenSize.height * 0.03),
          ElevatedButton(
            onPressed: _isSubmitting || _selfie == null
                ? null
                : () async {
                    await _submitSelfie();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.15,
                vertical: screenSize.height * 0.02,
              ),
            ),
            child: _isSubmitting
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Color.fromARGB(255, 162, 158, 158)),
                  ) // Show spinner while submitting
                : Text(
                    'Submit Image',
                    style: TextStyle(
                      fontSize: screenSize.width * 0.045,
                      color: Colors.white,
                    ),
                  ),
          ),
          SizedBox(height: screenSize.height * 0.03), // Dynamic spacing
          if (_statusMessage.isNotEmpty) ...[
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: screenSize.width * 0.04, // Dynamic font size
                color: _statusMessage.contains('failed')
                    ? Colors.red
                    : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: Text(
          'Capture and Submit Image',
          style: TextStyle(
            fontSize: screenSize.width * 0.05, // Dynamic font size
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: screenSize.width * 0.05), // Dynamic padding
          child: content,
        ),
      ),
    );
  }
}
