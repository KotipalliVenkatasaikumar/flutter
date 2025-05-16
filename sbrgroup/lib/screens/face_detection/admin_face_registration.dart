import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/face_detection/embedding_service.dart';
import 'package:ajna/screens/util.dart';
import 'package:camera/camera.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

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

class _AdminFaceRegisterScreenState extends State<AdminFaceRegisterScreen> {
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
  late FaceEmbeddingService _faceEmbeddingService;
  List<double> _generatedEmbeddings = [];

  @override
  void initState() {
    print("11111111111 Model is ready ");
    super.initState();
    print("222222222222222222222222222222222222 Model is ready ");
    _initializeModel();
    print("33333333333333333333333333333 Model is ready ");
    _setup();
    print("4444444444444444444444444444 Model is ready ");
  }

  Future<void> _initializeModel() async {
    print("Initializing model...");
    _faceEmbeddingService = FaceEmbeddingService();
    await _faceEmbeddingService.init();
    print("Model ready: ${_faceEmbeddingService.isReady}");
  }

  Future<void> _setup() async {
    orgId = await Util.getOrganizationId();
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _cameraInitFuture = _cameraController!.initialize();

      if (mounted) setState(() {});
    } catch (e) {
      print('Error initializing camera: $e');
    }
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
        _generatedEmbeddings.clear();
      });
      await _generateEmbedding(_selectedImage!);
    } catch (e) {
      print("Capture error: $e");
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _capturedImage = null;
          _selectedImage = File(picked.path);
          _generatedEmbeddings.clear();
        });
        await _generateEmbedding(_selectedImage!);
      }
    } catch (e) {
      print('Gallery pick error: $e');
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

  Future<void> _uploadImage() async {
    if (_selectedImage == null ||
        _selectedUser == null ||
        _generatedEmbeddings.isEmpty) {
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
        _generatedEmbeddings,
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
                    _generatedEmbeddings.clear();
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CameraPreview(_cameraController!),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceEmbeddingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Face Register',
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
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Select User",
                        style: Theme.of(context).textTheme.titleMedium),
                    SizedBox(height: 10),
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
            SizedBox(height: 20),
            if (_selectedUser != null) ...[
              Text("Camera", style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 10),
              Container(
                height: _selectedImage == null ? height * 0.5 : height * 0.4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildCameraPreview(),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _captureSelfie,
                      icon: Icon(Icons.camera_alt_outlined),
                      label: Text('Capture Selfie'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImageFromGallery,
                      icon: Icon(Icons.photo_library_outlined),
                      label: Text('Select from Gallery'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
            if (_selectedImage != null)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text("Preview",
                          style: Theme.of(context).textTheme.titleMedium),
                      SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_selectedImage!,
                            height: 200, fit: BoxFit.cover),
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isUploading || _generatedEmbeddings.isEmpty
                                  ? null
                                  : _uploadImage,
                          icon: Icon(Icons.upload),
                          label: _isUploading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Uploading...'),
                                  ],
                                )
                              : Text('Upload to Server'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
