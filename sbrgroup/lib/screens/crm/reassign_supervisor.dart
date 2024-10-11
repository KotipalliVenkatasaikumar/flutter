import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ajna/screens/app_bar.dart';
import 'package:ajna/screens/util.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SupervisorReassign extends StatefulWidget {
  const SupervisorReassign({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyDataTableWidgetState createState() => _MyDataTableWidgetState();
}

class _MyDataTableWidgetState extends State<SupervisorReassign> {
  List<dynamic> _data = [];
  int? intRoleId;
  int? intuserId;
  // Declare roleId as nullable

  List<TextEditingController> _remarksControllers = [];
  List<dynamic> _supervisors = [];
  int? _supervisorId;

  bool _isLoading = false;
  bool _showNoIssuesMessage = false;

  int? _selectedSupervisorId;

  // final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
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

  Future<void> _initializeData() async {
    intRoleId = await Util.getRoleId();
    intuserId = await Util.getUserId();

    fetchIssueTypeData().then((data) {
      setState(() {
        _data = data;
        _remarksControllers =
            List.generate(data.length, (_) => TextEditingController());
        _supervisorId = data.isNotEmpty ? data[0]['supervisorId'] as int : null;
      });
    });
    fetchIssueTypeData().then((data) {
      setState(() {
        _remarksControllers =
            List.generate(data.length, (_) => TextEditingController());
      });
    });
    try {
      await _fetchIssueType();
    } catch (e) {
      //print('Error fetching assignedTo IDs: $e');
    }
  }

  Future<List<dynamic>> fetchIssueTypeData({String? ticketNumber}) async {
    final url = ticketNumber != null && ticketNumber.isNotEmpty
        ? 'https://crm.corenuts.com/api/mob/issueassignment/ticketNumber?userId=$intuserId&ticketNumber=$ticketNumber&issueStatus=I'
        : 'https://crm.corenuts.com/api/mob/issueassignment/issueassignments/$intuserId/I/0';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      if (data.isNotEmpty) {
        return data; // Return the entire list of issue assignment objects
      } else {
        throw Exception(
            'No issue assignments found for the provided criteria.');
      }
    } else {
      throw Exception(
          'Failed to load issue assignments. Status code: ${response.statusCode}');
    }
  }

  void _searchData(String ticketNumber) async {
    setState(() {
      _isLoading = true;
      _showNoIssuesMessage = false; // Reset flag
    });

    try {
      final data = await fetchIssueTypeData(ticketNumber: ticketNumber);

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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  Future<void> _fetchIssueType() async {
    try {
      //print('Fetching issue records...');
      await fetchIssueTypeData();
      //print('Fetched issue records: $issueRecords');

      //print('Fetching supervisors...');
      final response = await http.get(Uri.parse(
          'https://crm.corenuts.com/api/user/supervisors/$_supervisorId'));

      if (response.statusCode == 200) {
        final List<dynamic> supervisors = jsonDecode(response.body);
        //print('Fetched supervisors: $supervisors');
        setState(() {
          _supervisors = supervisors;
        });
        //print('Filtered supervisors based on assignedToIds: $supervisors');
      } else {
        throw Exception(
            'Failed to load supervisors. Status code: ${response.statusCode}');
      }
    } catch (error) {
      //print('Error fetching issue type: $error');
      // Handle error
    }
  }

  List<dynamic> filterSupervisors(List<dynamic> supervisors, int assignedTo) {
    // Filter out the supervisor who is currently assigned
    return supervisors
        .where((supervisor) => supervisor['userId'] != assignedTo)
        .toList();
  }

  // DropdownButtonFormField<int> _buildDropdownButtonFormField(int assignedTo) {
  //   List<dynamic> filteredSupervisors =
  //       filterSupervisors(_supervisors, assignedTo);

  //   return DropdownButtonFormField<int>(
  //     value: _selectedSupervisorId,
  //     decoration: InputDecoration(
  //       border: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(5.0),
  //       ),
  //       contentPadding: const EdgeInsets.only(left: 10, right: 10),
  //     ),
  //     hint: const Text('Select Re-assign To'),
  //     items: filteredSupervisors.map((supervisor) {
  //       return DropdownMenuItem<int>(
  //         value: supervisor['userId'] as int, // Ensure userId is of type int
  //         child: Text(supervisor['userName'] ?? ''),
  //       );
  //     }).toList(),
  //     onChanged: (int? newValue) {
  //       setState(() {
  //         _selectedSupervisorId = newValue;
  //         //print(_selectedSupervisorId);
  //         //_remarksControllers[index].text = _selectedSupervisorId.toString(); // Update controller text if needed
  //       });
  //     },
  //   );
  // }
  DropdownButtonFormField<int> _buildDropdownButtonFormField(int assignedTo) {
    List<dynamic> filteredSupervisors =
        filterSupervisors(_supervisors, assignedTo);
    return DropdownButtonFormField<int>(
      value: _selectedSupervisorId,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
        ),
        contentPadding: const EdgeInsets.only(left: 10, right: 10),
      ),
      hint: const Text('Select Re-assign To'),
      items: filteredSupervisors.map((supervisor) {
        return DropdownMenuItem<int>(
          value: supervisor['userId'] as int,
          child: Text(supervisor['userName'] ?? ''),
        );
      }).toList(),
      onChanged: (int? value) {
        _selectedSupervisorId = value;
        //print(_selectedSupervisorId);
      },
    );
  }

  void _reloadData() {
    fetchIssueTypeData().then((data) {
      setState(() {
        _data = data;
        // _supervisorId = data.isNotEmpty ? data[0]['supervisorId'] as int : null;
        // _assignedTo = data.isNotEmpty ? data[0]['assignedTo'] as int : null;
        //  _remarksControllers =
        //    List.generate(data.length, (_) => TextEditingController());
      });
    }).catchError((error) {
      // Handle errors here if necessary
      //print("Error reloading data: $error");
    });
  }

  void _reassignIssue(int issueAssignmentId, int index) async {
    String remarks = _remarksControllers[index].text;
    _remarksControllers[index].text = '';

    if (_selectedSupervisorId == null) {
      //print('No supervisor selected.');
      return;
    }
    //print(_selectedSupervisorId);
    String url =
        'https://crm.corenuts.com/api/issueassignment/reassignissue/$issueAssignmentId/$_selectedSupervisorId';
    //print('POST URL: $url');

    final response = await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: remarks,
    );

    if (response.statusCode == 200) {
      //print('Issue reassigned successfully.');
      //Navigator.of(context).pop();

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SupervisorReassign()),
      );

      //  _reloadData();//gopi
      // fetchIssueTypeData().then((data) {
      //print('data after ressaign: $data');
      // });
    } else {
      print('Failed to reassign issue: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: GestureDetector(
          onTap: () {
            // Call to reload data when the body of the scaffold is tapped
            _reloadData();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    'Reassign Issue',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
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
                child: Center(
                  child: _data.isEmpty
                      ? const Center(
                          child: Text(
                            'No Reassign issues',
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
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Color.fromRGBO(
                                                    6, 73, 105, 1)),
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
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            item['assignedToName'].toString(),
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold),
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
                                    _buildDropdownButtonFormField(
                                        item['assignedTo']),
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 5),
                                      child: Text(
                                        'Enter Reassign Reason*:',
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
                                              await fetchIssueTypeData();
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
                                              // ignore: use_build_context_synchronously
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
                                          //print('Error fetching remarks: $e');
                                          showDialog<String>(
                                            // ignore: use_build_context_synchronously
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
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: const Text(
                                                      "Confirmation"),
                                                  content: const Text(
                                                      "Are you sure you want to Reassign this issue?"),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .pop(); // Close dialog
                                                        int issueAssignmentId =
                                                            0;
                                                        try {
                                                          issueAssignmentId =
                                                              int.parse(item[
                                                                      'issueAssignmentId']
                                                                  .toString());
                                                        } catch (e) {
                                                          // Handle parsing failure
                                                        }
                                                        _reassignIssue(
                                                            issueAssignmentId,
                                                            index);
                                                        //   String remarks =
                                                        //       _remarksControllers[
                                                        //               index]
                                                        //           .text;
                                                        //   _remarksControllers[
                                                        //           index]
                                                        //       .text = '';

                                                        //   String url =
                                                        //       'https://crm.corenuts.com/api/issueassignment/reassignissue/$issueAssignmentId/$_selectedSupervisorId';
                                                        //   http
                                                        //       .post(
                                                        //     Uri.parse(url),
                                                        //     headers: <String,
                                                        //         String>{
                                                        //       'Content-Type':
                                                        //           'application/json; charset=UTF-8',
                                                        //     },
                                                        //     body: remarks,
                                                        //   )
                                                        //       .then((response) {
                                                        //     if (response
                                                        //             .statusCode ==
                                                        //         200) {
                                                        //       // Refresh data after assignment
                                                        //       fetchIssueTypeData()
                                                        //           .then((data) {
                                                        //         setState(() {
                                                        //           _data = data;
                                                        //         });
                                                        //       });
                                                        //     } else {
                                                        //       showDialog(
                                                        //         context: context,
                                                        //         builder:
                                                        //             (BuildContext
                                                        //                 context) {
                                                        //           return AlertDialog(
                                                        //             title: const Text(
                                                        //                 "Error"),
                                                        //             content:
                                                        //                 const Text(
                                                        //                     "Failed to perform the action. Please try again."),
                                                        //             actions: [
                                                        //               TextButton(
                                                        //                 onPressed:
                                                        //                     () {
                                                        //                   Navigator.of(context)
                                                        //                       .pop();
                                                        //                 },
                                                        //                 child: const Text(
                                                        //                     'OK'),
                                                        //               ),
                                                        //             ],
                                                        //           );
                                                        //         },
                                                        //       );
                                                        //     }
                                                        //   }).catchError((error) {
                                                        //     showDialog(
                                                        //       context: context,
                                                        //       builder:
                                                        //           (BuildContext
                                                        //               context) {
                                                        //         return AlertDialog(
                                                        //           title:
                                                        //               const Text(
                                                        //                   "Error"),
                                                        //           content: const Text(
                                                        //               "An error occurred. Please try again later."),
                                                        //           actions: [
                                                        //             TextButton(
                                                        //               onPressed:
                                                        //                   () {
                                                        //                 Navigator.of(
                                                        //                         context)
                                                        //                     .pop();
                                                        //               },
                                                        //               child:
                                                        //                   const Text(
                                                        //                       'OK'),
                                                        //             ),
                                                        //           ],
                                                        //         );
                                                        //       },
                                                        //     );
                                                        //   });
                                                      },
                                                      child: const Text('OK'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .pop(); // Close dialog
                                                      },
                                                      child:
                                                          const Text('Cancel'),
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
                                              Text('ReAssign'),
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
            ],
          ),
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
      bottomNavigationBar: Container(
        padding: EdgeInsets.zero,
        color: const Color.fromRGBO(6, 73, 105, 1),
        //height: 40, // Attempt to set a smaller height
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 16),
              onPressed: () {
                Navigator.of(context).pop();
              },
              padding: EdgeInsets.zero,
              //constraints: BoxConstraints(),  // Remove constraints
              color: Colors.white,
            ),
            const Text(
              'Back',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
