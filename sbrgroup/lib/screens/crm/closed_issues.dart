import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ajna/screens/app_bar.dart';
import 'package:ajna/screens/crm/crm_home_screen.dart';
import 'package:ajna/screens/crm/fancy_spinner.dart';
import 'package:ajna/screens/home_screen.dart';
import 'package:ajna/screens/util.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ClosedIssues extends StatefulWidget {
  const ClosedIssues({super.key});

  @override
  _MyDataTableWidgetState createState() => _MyDataTableWidgetState();
}

GlobalKey<_MyDataTableWidgetState> inprogressScreenKey = GlobalKey();

class _MyDataTableWidgetState extends State<ClosedIssues> {
  List<dynamic> _data = [];
  int? intRoleId;
  int? intuserId; // Declare roleId as nullable
  bool _isLoading = false;

  List<TextEditingController> _remarksControllers =
      []; // List of TextEditingController instances
  final TextEditingController _searchController =
      TextEditingController(); // Controller for the search box

  @override
  void dispose() {
    // Dispose all TextEditingController instances
    _remarksControllers.forEach((controller) => controller.dispose());
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _searchData(_searchController.text);
  }

  void refreshData() {
    setState(() {
      _isLoading = true;
    });
    _initializeData();
  }

  Future<void> _initializeData() async {
    intRoleId = await Util.getRoleId();
    intuserId = await Util.getUserId();

    setState(() {
      _isLoading = true; // Set isLoading to true when initializing data
    });
    await fetchData().then((data) {
      setState(() {
        _data = data;

        _isLoading = false; // Set isLoading to true when initializing data
      });
    });

    fetchData().then((data) {
      setState(() {
        _data = data;
        _isLoading = false;
        _remarksControllers =
            List.generate(data.length, (_) => TextEditingController());
      });
    });
  }

  Future<List<dynamic>> fetchData({String? ticketNumber}) async {
    final url = ticketNumber != null && ticketNumber.isNotEmpty
        ? 'https://crm.corenuts.com/api/mob/issueassignment/ticketNumber?userId=$intuserId&ticketNumber=$ticketNumber&issueStatus=C'
        : 'https://crm.corenuts.com/api/mob/issueassignment/issueassignments/$intuserId/C/0';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load data');
    }
  }

  Future<void> _refreshData() async {
    await _initializeData();
  }

  void _searchData(String ticketNumber) async {
    setState(() {
      _isLoading = true;
    });
    final data = await fetchData(ticketNumber: ticketNumber);
    setState(() {
      _data = data;
      _isLoading = false;
      _remarksControllers =
          List.generate(data.length, (_) => TextEditingController());
    });
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  void navigateToClosedIssues() async {
    bool needsRefresh = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ClosedIssues()),
    );

    if (needsRefresh) {
      setState(() {
        _initializeData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: <Widget>[
            // Add search box
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by Ticket Number',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 10.0),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            _searchData(_searchController.text);
                          },
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 14.0, // Adjust the font size as needed
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_data.isEmpty && !_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No Issues with this Ticket Number. Please Enter the correct Ticket Number!',
                  style: TextStyle(fontSize: 16.0),
                  textAlign: TextAlign.center,
                ),
              ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: FancySpinner(
                  isLoading: _isLoading,
                  child: _data.isEmpty
                      ? const Center(
                          child: Text(
                            'No Closed issues',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _data.length,
                          itemBuilder: (context, index) {
                            final item = _data[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 5),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Issue Number:',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          Text(
                                            item['issueNumber'].toString(),
                                            style:
                                                const TextStyle(fontSize: 14),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 5),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Issue Type:',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          Text(
                                            item['issueTypeName'].toString(),
                                            style:
                                                const TextStyle(fontSize: 14),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 5),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Assigned To:',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          Text(
                                            item['assignedToName'].toString(),
                                            style:
                                                const TextStyle(fontSize: 14),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 5),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Approved BY:',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          Text(
                                            item['approvedByName'].toString(),
                                            style:
                                                const TextStyle(fontSize: 14),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        try {
                                          final List<dynamic> responseData =
                                              await fetchData();
                                          final String issueNumberToFind = item[
                                                  'issueNumber']
                                              .toString(); // Get the issueNumber of the current item as a string
                                          final dynamic issueData =
                                              responseData.firstWhere(
                                                  (element) =>
                                                      element['issueNumber'] ==
                                                      issueNumberToFind,
                                                  orElse: () => null);
                                          if (issueData != null) {
                                            final remarks =
                                                issueData['remarks'].toString();
                                            showDialog<String>(
                                              context: context,
                                              builder: (BuildContext context) =>
                                                  AlertDialog(
                                                title: const Text(
                                                    'Remarks History'),
                                                content: Text(
                                                  remarks,
                                                  style: const TextStyle(
                                                      fontSize: 14),
                                                  textAlign: TextAlign.left,
                                                ),
                                                actions: <Widget>[
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context, 'OK'),
                                                    child: const Text('OK'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          } else {
                                            throw Exception(
                                                'Remarks not found for issueNumber: $issueNumberToFind');
                                          }
                                        } catch (e) {
                                          print('Error fetching remarks: $e');
                                          showDialog<String>(
                                            context: context,
                                            builder: (BuildContext context) =>
                                                AlertDialog(
                                              title: const Text('Error'),
                                              content: const Text(
                                                  'Failed to fetch remarks. Please try again later.'),
                                              actions: <Widget>[
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, 'OK'),
                                                  child: const Text('OK'),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('View History'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(
            bottom: 2, right: 0), // Adjust margins as needed
        child: FloatingActionButton(
          onPressed: _refreshData,
          backgroundColor:
              Colors.transparent, // Set background color to transparent
          elevation: 0, // Remove elevation
          mini: true,
          child: const Icon(
            Icons.refresh,
            color: Color.fromRGBO(6, 73, 105, 1), // Change the icon color here
          ), // Set mini to true for a smaller button
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: Container(
        padding: EdgeInsets.zero,
        color: const Color.fromRGBO(6, 73, 105, 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 16),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          const CrmHomeScreen()), // Replace with your actual Profile Screen
                );
              },
              padding: EdgeInsets.zero,
              color: Colors.white,
            ),
            const Text(
              'Home',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
