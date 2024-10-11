import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ajna/screens/app_bar.dart';
import 'package:ajna/screens/crm/fancy_spinner.dart';
import 'package:ajna/screens/util.dart';
import 'package:http/http.dart' as http;

class OpenIssuesTableWidget extends StatefulWidget {
  const OpenIssuesTableWidget({super.key});

  @override
  _MyDataTableWidgetState createState() => _MyDataTableWidgetState();
}

GlobalKey<_MyDataTableWidgetState> issuesScreenKey = GlobalKey();

class _MyDataTableWidgetState extends State<OpenIssuesTableWidget> {
  List<dynamic> _data = [];
  int? intRoleId; // Declare roleId as nullable
  int? userId;
  bool _isLoading = false; // Add isLoading state
  bool _showNoIssuesMessage = false;

  List<TextEditingController> _remarksControllers =
      []; // List of TextEditingController instances
  final TextEditingController _searchController = TextEditingController();

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
    _searchController
        .addListener(_onSearchChanged); // Add listener to the search controller
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
    try {
      intRoleId =
          await Util.getRoleId(); // Use a default value if roleId is null
      userId = await Util.getUserId();
      setState(() {
        _isLoading = true; // Set isLoading to true when initializing data
      });

      await fetchData().then((data) {
        setState(() {
          _data = data;
          _isLoading = false; // Set isLoading to true when initializing data
        });
      });
    } catch (e) {
      print('Error initializing data: $e');
      // Handle error, e.g., show an error message to the user
    }
  }

  Future<List<dynamic>> fetchData({String? ticketNumber}) async {
    final url = ticketNumber != null && ticketNumber.isNotEmpty
        ? 'https://crm.corenuts.com/api/mob/issueassignment/ticketNumber?userId=$userId&ticketNumber=$ticketNumber&issueStatus=O'
        : 'https://crm.corenuts.com/api/mob/issueassignment/issueassignments/$userId/O/0';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load data');
    }
  }

  void _searchData(String ticketNumber) async {
    setState(() {
      _isLoading = true;
      _showNoIssuesMessage = false; // Reset flag
    });

    try {
      final data = await fetchData(ticketNumber: ticketNumber);

      setState(() {
        _data = data;
        _isLoading = false;

        if (_data.isEmpty) {
          _showNoIssuesMessage = true; // Set flag if no issues found
        }

        _remarksControllers =
            List.generate(data.length, (_) => TextEditingController());
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching data: $e');
    }
  }

  Future<void> _refreshData() async {
    await _initializeData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: <Widget>[
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
            if (_showNoIssuesMessage &&
                !_isLoading) // Display message when flag is true and not loading
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
                            'No open issues',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _data.length,
                          itemBuilder: (context, index) {
                            final item = _data[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
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
                                            'Tower & Flat No:',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          Text(
                                            '${item['towerName']} - ${item['flatNumber']}',
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
                                            'Customer Phone:',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          Text(
                                            item['customerPhNo'].toString(),
                                            style:
                                                const TextStyle(fontSize: 14),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 5),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Description:',
                                            style: TextStyle(fontSize: 14),
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
                                          Expanded(
                                            child: Text(
                                              item['issueDescription']
                                                  .toString(),
                                              style:
                                                  const TextStyle(fontSize: 14),
                                              softWrap: true,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 4,
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: const Text("Confirmation"),
                                              content: const Text(
                                                  "Are you sure you want to assign this issue?"),
                                              actions: [
                                                TextButton(
                                                  onPressed: () async {
                                                    Navigator.of(context).pop();
                                                    setState(() {
                                                      _isLoading =
                                                          true; // Show spinner when the user confirms the action
                                                    });
                                                    int issueAssignmentId = 0;
                                                    try {
                                                      issueAssignmentId =
                                                          int.parse(item[
                                                                  'issueAssignmentId']
                                                              .toString());
                                                    } catch (e) {
                                                      print(
                                                          'Parsing error: $e');
                                                      // Handle parsing failure, e.g., show an error message to the user
                                                    }
                                                    try {
                                                      http
                                                          .post(Uri.parse(
                                                              'https://crm.corenuts.com/api/issueassignment/assignme/$issueAssignmentId/$userId'))
                                                          .then((response) {
                                                        if (response
                                                                .statusCode ==
                                                            200) {
                                                          fetchData().then(
                                                              (data) async {
                                                            await Future.delayed(
                                                                const Duration(
                                                                    seconds:
                                                                        1));

                                                            setState(() {
                                                              print(
                                                                  'Data fetched successfully');
                                                              _data = data;

                                                              _isLoading =
                                                                  false; // Hide spinner after the HTTP request completes
                                                            });
                                                          });
                                                        } else {
                                                          showDialog(
                                                            context: context,
                                                            builder:
                                                                (BuildContext
                                                                    context) {
                                                              return AlertDialog(
                                                                title:
                                                                    const Text(
                                                                        "Error"),
                                                                content: const Text(
                                                                    "Failed to perform the action. Please try again."),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed:
                                                                        () {
                                                                      Navigator.of(
                                                                              context)
                                                                          .pop();
                                                                    },
                                                                    child:
                                                                        const Text(
                                                                            'OK'),
                                                                  ),
                                                                ],
                                                              );
                                                            },
                                                          );
                                                        }
                                                      }).catchError((error) {
                                                        showDialog(
                                                          context: context,
                                                          builder: (BuildContext
                                                              context) {
                                                            return AlertDialog(
                                                              title: const Text(
                                                                  "Error"),
                                                              content: const Text(
                                                                  "An error occurred. Please try again later."),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed:
                                                                      () {
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop();
                                                                  },
                                                                  child:
                                                                      const Text(
                                                                          'OK'),
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        );
                                                      });
                                                    } catch (e) {
                                                      print(
                                                          'HTTP post error: $e');
                                                      // Handle HTTP post error, e.g., show an error message to the user
                                                    }
                                                  },
                                                  child: const Text('OK'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: const Text('Cancel'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          //Icon(Icons.assignment_add),
                                          SizedBox(width: 4),
                                          Text('Assign Me'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ), // Pass isLoading state to FancySpinner
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(
            bottom: 20, right: 0), // Adjust margins as needed
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
    );
  }
}
