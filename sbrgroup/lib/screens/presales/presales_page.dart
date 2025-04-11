import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/util.dart';

class PresalesPage extends StatefulWidget {
  @override
  _PresalesPageState createState() => _PresalesPageState();
}

class _PresalesPageState extends State<PresalesPage> {
  List<Map<String, dynamic>> dateRangeOptions = [];
  Map<String, dynamic>? selectedOption;
  bool isLoading = true;

  int totalClosedLeads = 0;
  int totalAssignedLeads = 0;
  int totalVisitsCompleted = 0;
  int totalVisitsConfirmed = 0;
  int totalFollowUps = 0;
  int totalLeadsLost = 0;

  List<Project> projects = [];

  int userId = 0; // Placeholder for userId
  int roleId = 0; // Placeholder for roleId

  @override
  void initState() {
    super.initState();
    initUserAndRole();
    fetchDateRangeOptions(); // Fetch dropdown options
  }

  Future<void> initUserAndRole() async {
    // Simulate fetching userId and roleId, replace with actual implementation
    // userId = 1; // Replace with actual userId fetching logic
    // roleId = 1; // Replace with actual roleId fetching logic
    userId = await Util.getUserId() ?? 0; // Assign default value if null
    roleId = await Util.getRoleId() ?? 0;
  }

  Future<void> fetchDateRangeOptions() async {
   
    try {
      //final response = await http.get(Uri.parse(url));

      final response = await ApiService.fetchFilterDays();

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          dateRangeOptions = List<Map<String, dynamic>>.from(data);
          isLoading = false;

          // Set default selected option to "Today"
          for (var option in dateRangeOptions) {
            if (option['commonRefValue'] == 'Today') {
              selectedOption = option;
              // Fetch data for the default selected option
              fetchDashboardData(option['commonRefKey'], userId, roleId);
              fetchFollowUpData(option['commonRefKey'], userId, roleId);
              break;
            }
          }
        });
      } else {
        // Handle error
        // print('Failed to load date range options');
        ErrorHandler.handleError(
          context,
          'Failed to load date range options. Please try again later.',
          'Error fetching date range options: ${response.body}',
        );
        // You might want to show an error message or retry option here
      }
    } catch (e) {
      // Handle network errors or other exceptions
      // print('Error fetching date range options: $e');
      ErrorHandler.handleError(
        context,
        'Failed to load date range options. Please try again later.',
        'Error fetching date range options: $e',
      );
    }
  }

  Future<void> fetchDashboardData(String range, int userId, int roleId) async {
   
    try {
      //final response = await http.get(Uri.parse(url));
      final response =
          await ApiService.fetchDashboardData(range, userId, roleId);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        num sumAssignedLeads = 0;

        if (data != null && data is List) {
          for (var item in data) {
            if (item.containsKey('value')) {
              sumAssignedLeads += item['value'];
            }
          }
        }

        setState(() {
          totalAssignedLeads =
              sumAssignedLeads.toInt(); // Convert num to int if needed
          // Update other state variables if needed
        });
      } else {
        // Handle HTTP error status
        // print('Failed to load dashboard data: ${response.statusCode}');
        ErrorHandler.handleError(
          context,
          'Failed to load dashboard data. Please try again later.',
          'Error fetching dashboard data: ${response.body}',
        );
        // Show an error message to the user or retry option
      }
    } catch (e) {
      // Handle network errors or JSON decoding errors
      // print('Error fetching dashboard data: $e');
      ErrorHandler.handleError(
        context,
        'Failed to load  dashboard data. Please try again later.',
        'Error fetching dashboard data: $e',
      );
      // Show an error message to the user or retry option
    }
  }

  Future<void> fetchFollowUpData(String range, int userId, int roleId) async {
    
    // Show loading indicator
    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiService.fetchFollowups(range, userId, roleId);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        int calculatedTotalVisitsCompleted = 0;
        int calculatedTotalVisitsConfirmed = 0;
        num sumtotalFollowUps = 0;

        if (data != null && data is List) {
          for (var item in data) {
            String status = item['status']?.trim() ?? '';
            int value = item['value'] as int? ?? 0;

            if (status == 'Site Visit Done') {
              calculatedTotalVisitsCompleted += value;
            } else if (status == 'Site Visit Confirmed') {
              calculatedTotalVisitsConfirmed += value;
            }

            sumtotalFollowUps += value;
          }
        }

        setState(() {
          totalVisitsCompleted = calculatedTotalVisitsCompleted;
          totalVisitsConfirmed = calculatedTotalVisitsConfirmed;
          totalFollowUps = sumtotalFollowUps.toInt();
          projects = (data['projects'] as List<dynamic>)
              .map((project) => Project.fromJson(project))
              .toList();
          isLoading = false; // Hide loading indicator
        });
      } else {
        // Handle error
        print('Failed to load dashboard data');
        setState(() {
          isLoading = false; // Hide loading indicator
        });
        // You might want to show an error message or retry option here
      }
    } catch (e) {
      // Handle network errors or other exceptions
      // print('Error fetching dashboard data: $e');
      ErrorHandler.handleError(
        context,
        'Failed to fetching dashboard data. Please try again later.',
        'Error fetching dashboard data: $e',
      );
      setState(() {
        isLoading = false; // Hide loading indicator
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue.shade400, Colors.blue.shade900],
                ),
              ),
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.filter_list, color: Colors.white),
                            const SizedBox(width: 16),
                            DropdownButton<Map<String, dynamic>>(
                              value: selectedOption,
                              dropdownColor: Colors.blue.shade900,
                              items: dateRangeOptions.map((option) {
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: option,
                                  child: Text(
                                    option['commonRefValue'],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              }).toList(),
                              onChanged: (Map<String, dynamic>? newValue) {
                                if (newValue != null) {
                                  var commonRefKey = newValue['commonRefKey'];
                                  fetchDashboardData(
                                      commonRefKey.toString(), userId, roleId);
                                  fetchFollowUpData(
                                      commonRefKey.toString(), userId, roleId);
                                  setState(() {
                                    selectedOption = newValue;
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    PresalesDataWidget(
                      projects: projects,
                      label: 'Closed Leads',
                      totalCount: totalClosedLeads,
                      individualCounts: projects
                          .map((p) => '${p.name}: ${p.closedLeads}')
                          .toList(),
                      color: Colors.green,
                      icon: Icons.check_circle,
                    ),
                    PresalesDataWidget(
                      projects: projects,
                      label: 'Assigned Leads', // Added label for assigned leads
                      totalCount: totalAssignedLeads,
                      individualCounts: projects
                          .map((p) => '${p.name}: ${p.assignedLeads}')
                          .toList(),
                      color: Colors.amber,
                      icon: Icons.assignment, // Corrected icon
                    ),
                    PresalesDataWidget(
                      projects: projects,
                      label: 'Visits Completed',
                      totalCount: totalVisitsCompleted,
                      individualCounts: projects
                          .map((p) => '${p.name}: ${p.visitsCompleted}')
                          .toList(),
                      color: Colors.orange,
                      icon: Icons.place,
                    ),
                    PresalesDataWidget(
                      projects: projects,
                      label: 'Visits Confirmed',
                      totalCount: totalVisitsConfirmed,
                      individualCounts: projects
                          .map((p) => '${p.name}: ${p.visitsConfirmed}')
                          .toList(),
                      color: Colors.blue,
                      icon: Icons.check,
                    ),
                    PresalesDataWidget(
                      projects: projects,
                      label: 'Follow-ups',
                      totalCount: totalFollowUps,
                      individualCounts: projects
                          .map((p) => '${p.name}: ${p.followUps}')
                          .toList(),
                      color: Colors.purple,
                      icon: Icons.people,
                    ),
                    PresalesDataWidget(
                      projects: projects,
                      label: 'Leads Lost',
                      totalCount: totalLeadsLost,
                      individualCounts: projects
                          .map((p) => '${p.name}: ${p.leadsLost}')
                          .toList(),
                      color: Colors.red,
                      icon: Icons.close,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class PresalesDataWidget extends StatelessWidget {
  final String label;
  final int totalCount;
  final List<String> individualCounts;
  final Color color;
  final IconData icon;
  final List<Project> projects;

  const PresalesDataWidget({
    Key? key,
    required this.label,
    required this.totalCount,
    required this.individualCounts,
    required this.color,
    required this.icon,
    required this.projects,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 30,
                  color: color,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalCount.toString(),
                      style: TextStyle(fontSize: 20, color: color),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: projects.map((project) {
                return GestureDetector(
                  onTap: () {},
                  child: Card(
                    color: Colors.blue.shade50,
                    child: ListTile(
                      title: Text(
                        '${project.name}: ${label == 'Closed Leads' ? project.assignedLeads : label == 'Assined Leads' ? project.closedLeads : label == 'Visits Completed' ? project.visitsCompleted : label == 'Visits Confirmed' ? project.visitsConfirmed : label == 'Follow-ups' ? project.followUps : project.leadsLost}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      trailing: Icon(Icons.arrow_forward, color: color),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class Project {
  final String name;
  final int closedLeads;
  final int assignedLeads;
  final int visitsCompleted;
  final int visitsConfirmed;
  final int followUps;
  final int leadsLost;
  final String sourceFileData;

  Project({
    required this.name,
    required this.closedLeads,
    required this.assignedLeads,
    required this.visitsCompleted,
    required this.visitsConfirmed,
    required this.followUps,
    required this.leadsLost,
    required this.sourceFileData,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      name: json['name'],
      closedLeads: json['closedLeads'],
      assignedLeads: json['assignedLeads'],
      visitsCompleted: json['visitsCompleted'],
      visitsConfirmed: json['visitsConfirmed'],
      followUps: json['followUps'],
      leadsLost: json['leadsLost'],
      sourceFileData: json['sourceFileData'],
    );
  }
}

class ProjectDetailsPage extends StatelessWidget {
  final Project project;
  final String label;
  final int count;

  const ProjectDetailsPage({
    Key? key,
    required this.project,
    required this.label,
    required this.count,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Project Details for ${project.name}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Icon(
                            Icons.folder,
                            color: Colors.blue,
                            size: 28,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Source File Data:',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          project.sourceFileData,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.bar_chart,
                            color: Colors.green,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$label: $count',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Additional Information',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Project Name: ${project.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Closed Leads: ${project.closedLeads}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Assined Leads: ${project.assignedLeads}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Visits Completed: ${project.visitsCompleted}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Visits Confirmed: ${project.visitsConfirmed}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Follow-ups: ${project.followUps}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Leads Lost: ${project.leadsLost}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
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
