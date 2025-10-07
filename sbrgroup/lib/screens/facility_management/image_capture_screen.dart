import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:ajna/main.dart';
import 'package:ajna/screens/connectivity_handler.dart';
import 'package:ajna/screens/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'success_screen.dart';

class SelfieCaptureScreen extends StatefulWidget {
  final Map<String, dynamic> scannedData;
  SelfieCaptureScreen({required this.scannedData});

  @override
  _SelfieCaptureScreenState createState() => _SelfieCaptureScreenState();
}

class _SelfieCaptureScreenState extends State<SelfieCaptureScreen> {
  final ConnectivityHandler connectivityHandler = ConnectivityHandler();

  File? _selfie;
  bool _isSubmitting = false;
  String _statusMessage = '';
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  bool _isCameraInitialized = false;
  bool _isPreviewing = false;
  bool _hasCameraPermission = false;
  CameraLensDirection _currentDirection = CameraLensDirection.front;
  String _apkUrl = 'http://www.corenuts.com/ajna-app-release.apk';
  bool _isDownloading = false; // Add downloading state
  double _downloadProgress = 0.0; // Add download progress

  @override
  void initState() {
    super.initState();
    // _checkCameraPermission();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    bool isConnected = await connectivityHandler.checkConnectivity(context);
    if (isConnected) {
      // Proceed with other initialization steps if connected
      _checkCameraPermission();
      _checkForUpdate();
    }
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
      } else if (response.statusCode == 200) {
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
    double screenWidth = MediaQuery.of(context).size.width;

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
      // appBar: AppBar(
      //   backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
      //   title: Text(
      //     'Capture and Submit Image',
      //     style: TextStyle(
      //       fontSize: screenSize.width * 0.05, // Dynamic font size
      //       color: Colors.white,
      //     ),
      //   ),
      //   centerTitle: true,
      //   iconTheme: const IconThemeData(
      //     color: Colors.white,
      //   ),
      // ),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Capture and Submit Image',
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
