import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/util.dart';
import 'package:ajna/screens/face_detection/face_detection.dart';
import 'package:ajna/screens/face_detection/logout_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AttendanceDashboardScreen extends StatefulWidget {
  @override
  _AttendanceDashboardScreenState createState() => _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState extends State<AttendanceDashboardScreen> {
  List<dynamic> _projects = [];
  int? _selectedProjectId;
  String _selectedProjectName = '';
  
  bool _isLoading = true;
  int? _userId;
  int? _organizationId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _userId = await Util.getUserId();
    _organizationId = await Util.getOrganizationId();
    await _loadSelectedProject();
    await _fetchProjects();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadSelectedProject() async {
    final prefs = await SharedPreferences.getInstance();
    final projectId = prefs.getInt('selectedProjectId');
    final projectName = prefs.getString('selectedProjectName');
    if (projectId != null && projectName != null) {
      setState(() {
        _selectedProjectId = projectId;
        _selectedProjectName = projectName;
      });
    }
  }

  Future<void> _fetchProjects() async {
    try {
      final response = await ApiService.fetchOrgProjects(_organizationId!);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _projects = data; // Assume list of projects with id and name
        });
      }
    } catch (e) {
      print('Error fetching projects: $e');
    }
  }

  Future<void> _selectProject(dynamic project) async {
    final int? projectId = project['projectId'];
    final String projectName = project['projectName'] ?? 'Unknown';
    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid project selected.')),
      );
      return;
    }
    setState(() {
      _selectedProjectId = projectId;
      _selectedProjectName = projectName;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedProjectId', projectId);
    await prefs.setString('selectedProjectName', projectName);
  }

  

  Future<void> _markAttendance(bool isLogin) async {
    if (_selectedProjectId == null) return;
    // Navigate to face screen
    if (isLogin) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FaceAttendanceScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LogOutFaceAttendanceScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      // appBar: AppBar(
      //   title: Text('Attendance'),
      //   backgroundColor: Colors.blue,
      // ),

      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance',
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
          ? Center(child: CircularProgressIndicator())
          : _selectedProjectId != null
              ? Column(
                  children: [
                    // Logo section
                    Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Image.asset(
                            'lib/assets/images/ajna.png',
                            height: 100,
                            width: 100,
                          ),
                          
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Location: $_selectedProjectName',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _markAttendance(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text('Login', style: TextStyle(color: Colors.white, fontSize: 20)),
                            ),
                          ),
                          SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _markAttendance(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text('Logout', style: TextStyle(color: Colors.white, fontSize: 20)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : _projects.isEmpty
                  ? Center(child: Text('No projects available'))
                  : GridView.builder(
                      padding: EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _projects.length,
                      itemBuilder: (context, index) {
                        final project = _projects[index];
                        final isSelected = _selectedProjectId == project['projectId'];
                        return GestureDetector(
                          onTap: () => _selectProject(project),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: Center(
                              child: Text(
                                project['projectName'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
