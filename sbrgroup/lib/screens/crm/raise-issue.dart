import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/facility_management/success_screen.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class RaiseIssue extends StatefulWidget {
  @override
  _RaiseIssueState createState() => _RaiseIssueState();
}

class _RaiseIssueState extends State<RaiseIssue> {
  final _formKey = GlobalKey<FormState>();
  List<dynamic> issuesTypeData = [];
  List<dynamic> issuesSubTypeData = [];

  String? selectedIssueType;
  String? selectedIssueTypeId;
  String? selectedIssueSubType;
  String? selectedIssueSubTypeId;

  final TextEditingController _issueDescriptionController =
      TextEditingController();
  File? _selectedImageFile;
  bool _isSubmitting = false;

  CameraDescription? _camera; // Store camera description

  @override
  void initState() {
    super.initState();
    fetchIssueTypes();
    initializeCamera();
  }

  // Initialize the camera
  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        setState(() {
          _camera = cameras.first; // Store the first camera for use
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No camera available')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing camera: $e')),
      );
    }
  }

  // Fetch issue types from the API
  Future<void> fetchIssueTypes() async {
    try {
      final response = await http.get(Uri.parse(
          'http://15.207.212.144:9000/api/user/commonreferencedetails/types/Issue_Type'));
      if (response.statusCode == 200) {
        setState(() {
          issuesTypeData = json.decode(response.body);
        });
      } else {
        throw Exception('Failed to load issue types');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching issue types: $e')),
      );
    }
  }

  // Fetch sub-issue types based on the selected issue type
  Future<void> fetchSubIssueTypes(String commonRefValue) async {
    try {
      final response = await http.get(Uri.parse(
          'http://15.207.212.144:9000/api/user/commonreferencedetails/types/$commonRefValue'));
      if (response.statusCode == 200) {
        setState(() {
          issuesSubTypeData = json.decode(response.body);
        });
      } else {
        throw Exception('Failed to load sub-issue types');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching sub-issue types: $e')),
      );
    }
  }

  // Save issue details
  Future<void> saveIssue() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture an image')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final dataToSend = {
      'issueTypeId': selectedIssueTypeId,
      'issueTypeName': selectedIssueType,
      'issueSubTypeId': selectedIssueSubTypeId,
      'issueDescription': _issueDescriptionController.text,
      // 'imagePath': _selectedImageFile?.path,
    };

    try {
      final issueDataJson = jsonEncode(dataToSend);
      final response =
          await ApiService.submitIssue(issueDataJson, _selectedImageFile!);

      if (response.statusCode == 201) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => SuccessScreen()),
        );
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to upload issue. Please try again later.',
          'Error uploading issue: ${response.statusCode}',
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

  // Open the camera screen
  void openCamera() async {
    if (_camera == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not available')),
      );
      return;
    }

    try {
      final image = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (context) => CaptureImageScreen(camera: _camera!),
        ),
      );

      if (image != null) {
        setState(() {
          _selectedImageFile = image;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image captured')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: const Text('Raise Issue',
            style: TextStyle(fontSize: 18, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dropdown for issue types
              DropdownButtonFormField2<String>(
                decoration: InputDecoration(
                  labelText: 'Issue Types',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                ),
                value: selectedIssueTypeId,
                items: issuesTypeData.map((issue) {
                  return DropdownMenuItem<String>(
                    value: issue['id'].toString(),
                    child: Text(issue['commonRefValue']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedIssueTypeId = value;
                    selectedIssueType = issuesTypeData.firstWhere((issue) =>
                        issue['id'].toString() == value)['commonRefValue'];
                    fetchSubIssueTypes(selectedIssueType!);
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select an issue type' : null,
              ),
              const SizedBox(height: 20),
              // Dropdown for sub-issue types
              DropdownButtonFormField2<String>(
                decoration: InputDecoration(
                  labelText: 'Sub Issue Types',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                ),
                value: selectedIssueSubTypeId,
                items: issuesSubTypeData.map((issue) {
                  return DropdownMenuItem<String>(
                    value: issue['id'].toString(),
                    child: Text(issue['commonRefValue']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedIssueSubTypeId = value;
                    selectedIssueSubType = issuesSubTypeData.firstWhere(
                        (issue) =>
                            issue['id'].toString() == value)['commonRefValue'];
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select a sub-issue type' : null,
              ),
              const SizedBox(height: 20),
              // Text field for issue description
              TextFormField(
                controller: _issueDescriptionController,
                decoration: InputDecoration(
                  labelText: 'Issue Description',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter an issue description' : null,
              ),
              const SizedBox(height: 20),
              // Button to open camera
              ElevatedButton(
                onPressed: openCamera,
                child: const Text('Capture Image'),
              ),
              // Display selected image
              if (_selectedImageFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Center(
                    child: Image.file(
                      _selectedImageFile!,
                      width: 150, // Adjust width for stamp size
                      height: 150, // Adjust height for stamp size
                      fit: BoxFit.cover, // Maintain aspect ratio
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              // Button to save the issue
              ElevatedButton(
                onPressed: _isSubmitting ? null : saveIssue,
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CaptureImageScreen extends StatefulWidget {
  final CameraDescription camera;

  const CaptureImageScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _CaptureImageScreenState createState() => _CaptureImageScreenState();
}

class _CaptureImageScreenState extends State<CaptureImageScreen> {
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _cameraController = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _cameraController.initialize();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _captureImage(BuildContext context) async {
    try {
      await _initializeControllerFuture;
      final image = await _cameraController.takePicture();
      Navigator.pop(context, File(image.path)); // Return the captured image
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Capture Image'),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_cameraController);
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera),
        onPressed: () => _captureImage(context),
      ),
    );
  }
}
