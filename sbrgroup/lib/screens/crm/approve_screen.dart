import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ajna/screens/app_bar.dart';
import 'package:ajna/screens/crm/fancy_spinner.dart';
import 'package:ajna/screens/util.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class InApproveWidget extends StatefulWidget {
  const InApproveWidget({super.key});

  @override
  _MyDataTableWidgetState createState() => _MyDataTableWidgetState();
}

GlobalKey<_MyDataTableWidgetState> inapproveScreenKey = GlobalKey();

class _MyDataTableWidgetState extends State<InApproveWidget> {
  List<dynamic> _data = [];
  int? intRoleId;
  int? intuserId; // Declare roleId as nullable

  bool _isLoading = false;
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
    intuserId = await Util.getUserId(); // Use a default value if roleId is null
    // intRoleId = Util.convertStringtoInt(roleId ?? ''); // Convert roleId to int

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
        _remarksControllers =
            List.generate(data.length, (_) => TextEditingController());
      });
    });
  }

  Future<List<dynamic>> fetchData({String? ticketNumber}) async {
    final url = ticketNumber != null && ticketNumber.isNotEmpty
        ? 'https://crm.corenuts.com/api/mob/issueassignment/ticketNumber?userId=$intuserId&ticketNumber=$ticketNumber&issueStatus=W'
        : 'https://crm.corenuts.com/api/mob/issueassignment/issueassignments/$intuserId/W/0';
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

  void _logout() async {
    // Navigator.of(context).pushNamed('/main');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Navigate to the main route (in this case, HomePage)
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  void navigateToInApproveWidget() async {
    bool needsRefresh = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InApproveWidget()),
    );

    if (needsRefresh) {
      // Refresh the data
      setState(() {
        _initializeData();
      });
    }
  }

  void _reloadData() {
    fetchData().then((data) {
      setState(() {
        _data = data;
        _isLoading = false;
        _remarksControllers =
            List.generate(data.length, (_) => TextEditingController());
      });
    }).catchError((error) {
      // Handle errors here if necessary
      print("Error reloading data: $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: <Widget>[
            //const MarqueeBanner(),
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
                        fontSize: 14.0,
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
                            'No issues Waiting for Approval',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _data.length,
                          itemBuilder: (context, index) {
                            final item = _data[index];
                            int assignedToId =
                                int.tryParse(item['assignedTo'].toString()) ??
                                    0;
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
                                            'Description:',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          Expanded(
                                            child: Text(
                                              item['issueDescription']
                                                  .toString(),
                                              style:
                                                  const TextStyle(fontSize: 14),
                                              softWrap: true,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 3,
                                              textAlign: TextAlign.right,
                                            ),
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
                                      child: Text(
                                        'Enter Approve/Reject Reason*:',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    TextFormField(
                                      controller: _remarksControllers[
                                          index], // Assign the controller
                                      maxLines: 1,
                                      //maxLength: 100,
                                      decoration: const InputDecoration(
                                        filled: true,
                                        fillColor: Color(
                                            0xFFFFFFFF), // Choose your desired background color
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 10, horizontal: 10),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        try {
                                          final List<dynamic> responseData =
                                              await fetchData();
                                          final String issueNumberToFind = item[
                                              'issueNumber']; // Get the issueNumber of the current item as a string
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
                                      child: const Text(
                                        'View History',
                                        style: TextStyle(
                                            color: Color.fromARGB(
                                                255, 41, 83, 137)),
                                      ),
                                    ),
                                    if ((intuserId != assignedToId) ||
                                        (item['singleSuperviosr'] == "Y"))
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  return AlertDialog(
                                                    title: const Text(
                                                        "Confirmation"),
                                                    content: const Text(
                                                      "Are you sure you want to Reject this issue?",
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop(); // Close the confirmation dialog

                                                          int issueAssignmentId =
                                                              0;
                                                          try {
                                                            issueAssignmentId =
                                                                int.parse(item[
                                                                        'issueAssignmentId']
                                                                    .toString());
                                                          } catch (e) {
                                                            print(
                                                                "Error parsing issueAssignmentId: $e");
                                                            return; // Exit if the parsing fails
                                                          }
                                                          String remarks =
                                                              _remarksControllers[
                                                                      index]
                                                                  .text;
                                                          _remarksControllers[
                                                                      index]
                                                                  .text =
                                                              ''; // Clear the text field immediately after reading the text

                                                          String url =
                                                              'https://crm.corenuts.com/api/issueassignment/reject/$issueAssignmentId/$intuserId';
                                                          http
                                                              .post(
                                                            Uri.parse(url),
                                                            headers: <String,
                                                                String>{
                                                              'Content-Type':
                                                                  'application/json; charset=UTF-8',
                                                            },
                                                            body: remarks,
                                                          )
                                                              .then((response) {
                                                            if (response
                                                                    .statusCode ==
                                                                200) {
                                                              fetchData()
                                                                  .then((data) {
                                                                setState(() {
                                                                  _data = data;
                                                                });
                                                              });
                                                            } else {
                                                              showDialog(
                                                                context:
                                                                    context,
                                                                builder:
                                                                    (BuildContext
                                                                        context) {
                                                                  return AlertDialog(
                                                                    title: const Text(
                                                                        "Error"),
                                                                    content: Text(
                                                                        "Failed to Reject the issue. Please try again. Status code: ${response.statusCode}"),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed:
                                                                            () {
                                                                          Navigator.of(context)
                                                                              .pop();
                                                                        },
                                                                        child: const Text(
                                                                            'OK'),
                                                                      ),
                                                                    ],
                                                                  );
                                                                },
                                                              );
                                                            }
                                                          }).catchError(
                                                                  (error) {
                                                            showDialog(
                                                              context: context,
                                                              builder:
                                                                  (BuildContext
                                                                      context) {
                                                                return AlertDialog(
                                                                  title: const Text(
                                                                      "Error"),
                                                                  content: Text(
                                                                      "An error occurred: $error"),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed:
                                                                          () {
                                                                        Navigator.of(context)
                                                                            .pop();
                                                                      },
                                                                      child: const Text(
                                                                          'OK'),
                                                                    ),
                                                                  ],
                                                                );
                                                              },
                                                            );
                                                          });
                                                        },
                                                        child: const Text('OK'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop(); // Close the confirmation dialog
                                                        },
                                                        child: const Text(
                                                            'Cancel'),
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
                                                SizedBox(width: 4),
                                                Text(
                                                  'Reject',
                                                  style: TextStyle(
                                                      color: Color.fromARGB(
                                                          255, 41, 83, 137)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  return AlertDialog(
                                                    title: const Text(
                                                        "Confirmation"),
                                                    content: const Text(
                                                      "Are you sure you want to Approve this issue?",
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop(); // Close the confirmation dialog

                                                          int issueAssignmentId =
                                                              0;
                                                          try {
                                                            issueAssignmentId =
                                                                int.parse(item[
                                                                        'issueAssignmentId']
                                                                    .toString());
                                                          } catch (e) {
                                                            print(
                                                                "Error parsing issueAssignmentId: $e");
                                                            return; // Exit if the parsing fails
                                                          }
                                                          String remarks =
                                                              _remarksControllers[
                                                                      index]
                                                                  .text;
                                                          _remarksControllers[
                                                                      index]
                                                                  .text =
                                                              ''; // Clear the text field immediately after reading the text

                                                          String url =
                                                              'https://crm.corenuts.com/api/issueassignment/approve/$issueAssignmentId/$intuserId';
                                                          http
                                                              .post(
                                                            Uri.parse(url),
                                                            headers: <String,
                                                                String>{
                                                              'Content-Type':
                                                                  'application/json; charset=UTF-8',
                                                            },
                                                            body: remarks,
                                                          )
                                                              .then((response) {
                                                            if (response
                                                                    .statusCode ==
                                                                200) {
                                                              fetchData()
                                                                  .then((data) {
                                                                setState(() {
                                                                  _data = data;
                                                                });
                                                              });
                                                            } else {
                                                              showDialog(
                                                                context:
                                                                    context,
                                                                builder:
                                                                    (BuildContext
                                                                        context) {
                                                                  return AlertDialog(
                                                                    title: const Text(
                                                                        "Error"),
                                                                    content: Text(
                                                                        "Failed to Approve the issue. Please try again. Status code: ${response.statusCode}"),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed:
                                                                            () {
                                                                          Navigator.of(context)
                                                                              .pop();
                                                                        },
                                                                        child: const Text(
                                                                            'OK'),
                                                                      ),
                                                                    ],
                                                                  );
                                                                },
                                                              );
                                                            }
                                                          }).catchError(
                                                                  (error) {
                                                            showDialog(
                                                              context: context,
                                                              builder:
                                                                  (BuildContext
                                                                      context) {
                                                                return AlertDialog(
                                                                  title: const Text(
                                                                      "Error"),
                                                                  content: Text(
                                                                      "An error occurred: $error"),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed:
                                                                          () {
                                                                        Navigator.of(context)
                                                                            .pop();
                                                                      },
                                                                      child: const Text(
                                                                          'OK'),
                                                                    ),
                                                                  ],
                                                                );
                                                              },
                                                            );
                                                          });
                                                        },
                                                        child: const Text('OK'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop(); // Close the confirmation dialog
                                                        },
                                                        child: const Text(
                                                            'Cancel'),
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
                                                SizedBox(width: 4),
                                                Text(
                                                  'Approve',
                                                  style: TextStyle(
                                                      color: Color.fromARGB(
                                                          255, 41, 83, 137)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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
