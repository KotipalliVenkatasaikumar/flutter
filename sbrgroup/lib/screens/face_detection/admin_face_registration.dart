import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/util.dart';
import 'package:camera/camera.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'package:permission_handler/permission_handler.dart';

class UserModel {
  final int userId;
  final String userName;

  UserModel({required this.userId, required this.userName});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] ?? 0,
      userName: json['userName'] ?? '',
    );
  }
}


class AdminFaceRegisterScreen extends StatefulWidget {
  @override
  _AdminFaceRegisterScreenState createState() =>
      _AdminFaceRegisterScreenState();
}

class _AdminFaceRegisterScreenState extends State<AdminFaceRegisterScreen> with WidgetsBindingObserver {
  final ScrollController _dropdownScrollController = ScrollController();
  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;
  XFile? _capturedImage;
  File? _selectedImage;
  List<UserModel> _userList = [];
  UserModel? _selectedUser;
  bool _isUploading = false;
  bool _isCapturing = false;

  final ImagePicker _picker = ImagePicker();

  int? orgId;
  // late FaceEmbeddingService _faceEmbeddingService;
  // List<double> _generatedEmbeddings = [];

  CameraLensDirection _currentDirection = CameraLensDirection.back;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print("11111111111 Model is ready ");
    print("222222222222222222222222222222222222 Model is ready ");
    // _initializeModel();
    print("33333333333333333333333333333 Model is ready ");
    _setup();
    print("4444444444444444444444444444 Model is ready ");
  }

  // Future<void> _initializeModel() async {
  //   print("Initializing model...");
  //   _faceEmbeddingService = FaceEmbeddingService();
  //   await _faceEmbeddingService.init();
  //   print("Model ready: ${_faceEmbeddingService.isReady}");
  // }

  Future<void> _setup() async {
    orgId = await Util.getOrganizationId();
    final hasPermission = await _ensureCameraPermission();
    if (!hasPermission) {
      return;
    }
    await _initializeCamera();
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      return true;
    }
    if (status.isPermanentlyDenied) {
      await _showSettingsDialog(
        'Camera Permission Permanently Denied',
        'Please grant camera permission in your device settings to use this feature.',
      );
    }
    return false;
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == _currentDirection,
      );

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _cameraInitFuture = _cameraController!.initialize();
      await _cameraInitFuture; // Wait for initialization to complete
      if (mounted) setState(() {}); // Force rebuild after camera is ready
    } catch (e) {
      print('Error initializing camera: $e');
    }
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
      _selectedImage = null;
      _capturedImage = null;
      // _generatedEmbeddings.clear();
    });
    await _initializeCamera();
    // Instead of setState after await, call setState inside _initializeCamera after initialization
  }

  Future<void> _captureSelfie() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      await _cameraInitFuture;
      final XFile image = await _cameraController!.takePicture();
      File imageFile = File(image.path);

      List<int> imageBytes = await imageFile.readAsBytes();
      Uint8List uint8ImageBytes = Uint8List.fromList(imageBytes);
      img.Image decodedImage = img.decodeImage(uint8ImageBytes)!;
      img.Image flipped = img.flipHorizontal(decodedImage);
      File correctedFile = File(imageFile.path)
        ..writeAsBytesSync(img.encodeJpg(flipped));

      setState(() {
        _selectedImage = correctedFile;
        _capturedImage = image;
        // _generatedEmbeddings.clear();
      });
      // await _generateEmbedding(_selectedImage!);
    } catch (e) {
      print("Capture error: $e");
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false, // Important for Android 13+ scoped storage
      );
      
      if (picked != null) {
        setState(() {
          _capturedImage = null;
          _selectedImage = File(picked.path);
        });
      }
    } on PlatformException catch (e) {
      if (e.code == 'photo_access_denied') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo access permission denied')),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to pick image: ${e.message}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Future<void> _generateEmbedding(File imageFile) async {
  //   if (!_faceEmbeddingService.isReady) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Model not loaded yet.")),
  //     );
  //     return;
  //   }

  //   try {
  //     final img.Image image = img.decodeImage(await imageFile.readAsBytes())!;
  //     final List<double> embeddings =
  //         await _faceEmbeddingService.getEmbedding(image);

  //     setState(() {
  //       _generatedEmbeddings = embeddings;
  //     });

  //     print('Embedding result: $_generatedEmbeddings');

  //     if (_generatedEmbeddings.every((e) => e == 0.0)) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('⚠️ Embedding is all zeros!')),
  //       );
  //     }
  //   } catch (e) {
  //     print('Error during embedding: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('❌ Failed to generate embedding.')),
  //     );
  //   }
  // }

  Future<void> _uploadImage() async {
    if (_selectedImage == null ||
        _selectedUser == null ) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please select a user and capture/select an image.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final response = await ApiService.submitRegisterFace(
        _selectedUser!.userId.toString(),
        _selectedImage!,
        // _generatedEmbeddings,
      );

      if (response.statusCode == 200) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Success'),
            content: Text('Face has been registered successfully.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _capturedImage = null;
                    _selectedImage = null;
                    _selectedUser = null;
                    // _generatedEmbeddings.clear();
                  });
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      } else {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Registration Failed'),
            content: Text('We could not register the face. Please try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Upload error: $e');
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content:
              Text('Something went wrong during the upload. Please try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<List<UserModel>> _searchUsers(String? filter) async {
    final response =
        await ApiService.fetchUsersForFace(orgId.toString(), filter!);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<UserModel>.from(data.map((e) => UserModel.fromJson(e)));
    } else {
      throw Exception('User fetch failed');
    }
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CameraPreview(_cameraController!),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: Icon(Icons.switch_camera,
                color: const Color.fromARGB(255, 255, 255, 255), size: 28),
            onPressed: _toggleCamera,
            tooltip: 'Switch Camera',
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewArea(double width) {
    final aspectRatio = 3 / 4;
    final previewHeight = width / aspectRatio;
    final isPreview = _selectedImage != null;

    return Column(
      children: [
        Container(
          width: width,
          height: previewHeight,
          child: isPreview
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_selectedImage!,
                      fit: BoxFit.cover, width: width, height: previewHeight),
                )
              : (_cameraController == null ||
                      !_cameraController!.value.isInitialized)
                  ? Center(child: CircularProgressIndicator())
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CameraPreview(_cameraController!),
                    ),
        ),
        SizedBox(height: 12),
        _buildBottomBar(context),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final isPreview = _selectedImage != null;
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 350;

    if (!isPreview) {
      // Camera mode
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: Color(0xFF064969).withOpacity(0.85),
                shape: CircleBorder(),
                child: IconButton(
                  icon: Icon(Icons.switch_camera,
                      size: isNarrow ? 22 : 28, color: Colors.white),
                  onPressed: _toggleCamera,
                  tooltip: 'Switch Camera',
                  iconSize: isNarrow ? 36 : 48,
                  padding: EdgeInsets.all(isNarrow ? 8 : 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: _captureSelfie,
                style: ElevatedButton.styleFrom(
                  shape: CircleBorder(),
                  padding: EdgeInsets.all(isNarrow ? 10 : 18),
                  backgroundColor: Color(0xFF179E8E),
                  foregroundColor: Colors.white,
                  elevation: 6,
                  minimumSize: Size(isNarrow ? 44 : 56, isNarrow ? 44 : 56),
                ),
                child: Icon(Icons.camera_alt, size: isNarrow ? 26 : 32),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: Color(0xFF6C63FF).withOpacity(0.85),
                shape: CircleBorder(),
                child: IconButton(
                  icon: Icon(Icons.photo_library,
                      size: isNarrow ? 22 : 28, color: Colors.white),
                  onPressed: _pickImageFromGallery,
                  tooltip: 'Pick from Gallery',
                  iconSize: isNarrow ? 36 : 48,
                  padding: EdgeInsets.all(isNarrow ? 8 : 12),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Preview mode
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedImage = null;
                    _capturedImage = null;
                    // _generatedEmbeddings.clear();
                  });
                },
                icon: Icon(Icons.refresh,
                    color: Colors.white, size: isNarrow ? 20 : 24),
                label: Text('Retake',
                    style: TextStyle(
                        color: Colors.white, fontSize: isNarrow ? 13 : 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 10 : 28,
                      vertical: isNarrow ? 8 : 14),
                  minimumSize: Size(isNarrow ? 44 : 56, isNarrow ? 44 : 56),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton.icon(
                onPressed: _isUploading || _selectedImage == null || _selectedUser == null
                    ? null
                    : _uploadImage,
                icon: _isUploading
                    ? SizedBox(
                        width: isNarrow ? 14 : 18,
                        height: isNarrow ? 14 : 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(Icons.upload,
                        color: Colors.white, size: isNarrow ? 20 : 24),
                label: Text(_isUploading ? 'Uploading...' : 'Upload',
                    style: TextStyle(
                        color: Colors.white, fontSize: isNarrow ? 13 : 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF064969),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 10 : 28,
                      vertical: isNarrow ? 8 : 14),
                  minimumSize: Size(isNarrow ? 44 : 56, isNarrow ? 44 : 56),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    // _faceEmbeddingService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Re-check permission and re-init camera on resume
      _setup();
    }
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
              'Face Registration',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_search, color: Color(0xFF064969)),
                        SizedBox(width: 8),
                        Text("Select User",
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 12),
                    DropdownSearch<UserModel>(
                      asyncItems: _searchUsers,
                      itemAsString: (u) => u.userName,
                      selectedItem: _selectedUser,
                      onChanged: (u) => setState(() => _selectedUser = u),
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          decoration: InputDecoration(
                            labelText: "Search user",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      dropdownDecoratorProps: DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: "User",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            if (_selectedUser != null) ...[
              _buildPreviewArea(width),
              SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showSettingsDialog(String title, String content) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () async {
              await openAppSettings();
              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
