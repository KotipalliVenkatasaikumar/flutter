import 'dart:io';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';

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
  String? _uploadedImageFileName;

  @override
  void initState() {
    super.initState();
    fetchIssueTypes();
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
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching issue types: $e')));
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
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching sub-issue types: $e')));
    }
  }

  Future<void> saveIssue() async {
    if (!_formKey.currentState!.validate()) return;

    var request = http.MultipartRequest(
      'POST',
      Uri.parse(
          'http://15.207.212.144:9006/api/facility-management/issues/save'),
    );

    request.fields['issueTypeName'] = selectedIssueType ?? '';
    request.fields['issueSubTypeName'] = selectedIssueSubType ?? '';
    request.fields['issueDescription'] = _issueDescriptionController.text;

    if (_selectedImageFile != null) {
      try {
        // Ensure the file exists
        if (await _selectedImageFile!.exists()) {
          List<int> imageBytes = await _selectedImageFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'image',
              imageBytes,
              filename: _selectedImageFile!.path.split('/').last,
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        } else {
          throw Exception(
              'Selected file does not exist: ${_selectedImageFile!.path}');
        }
      } catch (e, stackTrace) {
        print('Error reading image file: $e');
        print('Stack trace: $stackTrace');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading image file: $e')),
        );
        return;
      }
    }

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue added successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to add issue: ${response.statusCode}')),
        );
      }
    } catch (e, stackTrace) {
      print('Error submitting issue: $e');
      print('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting issue: $e')),
      );
    }
  }

  // Select image from gallery
  Future<void> onFileSelect() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImageFile = File(pickedFile.path);
        _uploadedImageFileName = pickedFile.name; // Store the file name
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image selected')),
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
              DropdownButtonFormField2<String>(
                decoration: InputDecoration(
                  labelText: 'Issue Types',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0)),
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
              DropdownButtonFormField2<String>(
                decoration: InputDecoration(
                  labelText: 'Issue Subtypes',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0)),
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
                    value == null ? 'Please select an issue subtype' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Issue Description',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0)),
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
                controller: _issueDescriptionController,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a description'
                    : null,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: onFileSelect,
                    child: const Text('Upload Image'),
                  ),
                ],
              ),
              if (_uploadedImageFileName != null) ...[
                const SizedBox(height: 20),
                Text('Selected Image: $_uploadedImageFileName'),
              ],
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: saveIssue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(235, 23, 135, 182),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 26),
                    child: Text('Submit Issue',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
