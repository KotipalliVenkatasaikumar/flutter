import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ajna/screens/app_bar.dart';
import 'package:ajna/screens/crm/closed_issues.dart';
import 'package:ajna/screens/crm//fancy_spinner.dart';
import 'package:ajna/screens/crm//main_screen.dart';
import 'package:ajna/screens/util.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class CrmHomeScreen extends StatefulWidget {
  const CrmHomeScreen({super.key});

  @override
  _MyDataTableWidgetState createState() => _MyDataTableWidgetState();
}

class _MyDataTableWidgetState extends State<CrmHomeScreen> {
  List<dynamic> _data = [];
  int? intRoleId; // Declare roleId as nullable
  int? userId;
  bool _isLoading = false; // Add isLoading state

  final Map<String, int> statusOrder = {
    'OPEN': 1,
    'INPROGRESS': 2,
    'WAITING FOR APPROVAL': 3,
    'CLOSED': 4,
  };

  List<Map<String, dynamic>> defaultData = [
    {'issueStatusRefName': 'OPEN', 'issuesCount': 0},
    {'issueStatusRefName': 'INPROGRESS', 'issuesCount': 0},
    {'issueStatusRefName': 'WAITING FOR APPROVAL', 'issuesCount': 0},
    {'issueStatusRefName': 'CLOSED', 'issuesCount': 0},
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void refreshData() {
    setState(() {
      _isLoading = true;
    });
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      intRoleId = await Util.getRoleId();
      userId = await Util.getUserId();
      setState(() {
        _isLoading = true;
      });

      await fetchData().then((data) {
        Map<String, int> dataMap = {
          for (var item in data) item['issueStatusRefName']: item['issuesCount']
        };

        List<Map<String, dynamic>> mergedData = defaultData.map((item) {
          return {
            'issueStatusRefName': item['issueStatusRefName'],
            'issuesCount': dataMap[item['issueStatusRefName']] ?? 0
          };
        }).toList();

        mergedData.sort((a, b) {
          int orderA = statusOrder[a['issueStatusRefName']] ?? 5;
          int orderB = statusOrder[b['issueStatusRefName']] ?? 5;
          return orderA.compareTo(orderB);
        });

        setState(() {
          _data = mergedData;
          _isLoading = false;
        });
      });
    } catch (e) {
      print('Error initializing data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<dynamic>> fetchData() async {
    try {
      print("Fetching data...");
      print("RoleId: $intRoleId");
      final response = await http
          .get(Uri.parse('https://crm.corenuts.com/api/issue/count/$userId'));

      if (response.statusCode == 200) {
        print("HTTP call success");
        print(jsonDecode(response.body));
        return jsonDecode(response.body);
      } else {
        print("HTTP error ---");
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print('Error fetching data: $e');
      // Handle error, e.g., show an error message to the user
      throw e; // Rethrow the exception to propagate it up
    }
  }

  Future<void> _refreshData() async {
    await _initializeData();
  }

  Future<Map<String, String?>> getUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userName = prefs.getString('userName');
    return {'userName': userName};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Center(
          child: Column(
            children: <Widget>[
              //const MarqueeBanner(),

              Container(
                height: 90, // Fixed height for user details
                padding: const EdgeInsets.all(8.0),
                child: FutureBuilder<Map<String, String?>>(
                  future: getUserDetails(),
                  builder: (BuildContext context,
                      AsyncSnapshot<Map<String, String?>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return const Center(
                          child: Text("Error fetching user details"));
                    } else if (snapshot.hasData) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize
                              .min, // Keeps the column size to its contents
                          children: [
                            const Text("Hi! Welcome!",
                                style: TextStyle(
                                    fontSize: 18.0,
                                    color: Color.fromARGB(255, 132, 132, 139))),
                            Text(
                              snapshot.data?['userName'] ?? "No username found",
                              style: const TextStyle(
                                  fontSize: 22.0,
                                  color: Color.fromARGB(255, 23, 139, 171)),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return const Center(child: Text("No user details found"));
                    }
                  },
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: FancySpinner(
                    // Wrap ListView.builder with FancySpinner
                    isLoading: _isLoading,
                    // Wrap ListView.builder with FancySpinner
                    child: ListView.builder(
                      itemCount: _data.length,
                      itemBuilder: (context, index) {
                        final item = _data[index];
                        return GestureDetector(
                          onTap: () =>
                              navigateBasedOnStatus(item['issueStatusRefName']),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Card(
                              child: ListTile(
                                title: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Text(
                                    item['issueStatusRefName'].toString(),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        color:
                                            Color.fromARGB(255, 41, 83, 137)),
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Text(
                                    'Issues: ${item['issuesCount']}',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color.fromARGB(255, 13, 13, 13)),
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                              ),
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
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(
            bottom: 55, right: 0), // Adjust margins as needed
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
        color: const Color.fromRGBO(6, 73, 105, 1),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'Powered by ',
                style: TextStyle(
                  color: Color.fromARGB(255, 186, 183, 183),
                  fontSize: 12,
                ),
              ),
              TextSpan(
                text: 'CoreNuts Technologies',
                style: const TextStyle(
                  color: Color.fromARGB(
                      255, 255, 255, 255), // Choose a suitable color
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    // ignore: deprecated_member_use
                    launch('https://www.corenuts.com');
                  },
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void navigateBasedOnStatus(String status) {
    int tabIndex;
    switch (status) {
      case 'OPEN':
        tabIndex = 0; // Assuming this is the first tab in MainScreen
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => MainScreen(initialIndex: tabIndex)),
        );
        break;
      case 'INPROGRESS':
        tabIndex = 1; // Assuming InProgressWidget is the second tab
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => MainScreen(initialIndex: tabIndex)),
        );
        break;
      case 'WAITING FOR APPROVAL':
        tabIndex = 2; // Assuming InApproveWidget is the third tab
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => MainScreen(initialIndex: tabIndex)),
        );
        break;
      case 'CLOSED':
        // Navigate directly to the ClosedIssues screen for CLOSED status
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ClosedIssues()),
        );
        break;
      default:
        // Navigate to the default tab if the status is unknown
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MainScreen(initialIndex: 0)),
        );
        break;
    }
  }
}
