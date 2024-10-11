import 'package:flutter/material.dart';
import 'package:ajna/screens/app_bar.dart';
import 'package:ajna/screens/crm/reassign_issue.dart';
import 'package:ajna/screens/crm/reassign_supervisor.dart';
import 'package:shared_preferences/shared_preferences.dart';

//import 'profile_screen.dart';

class ReassignMaiWidget extends StatefulWidget {
  const ReassignMaiWidget({super.key});

  @override
  _MyDataTableWidgetState createState() => _MyDataTableWidgetState();
}

class _MyDataTableWidgetState extends State<ReassignMaiWidget> {
  int? intRoleId; // Declare roleId as nullable

  void _logout() async {
    // Navigator.of(context).pushNamed('/main');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Navigate to the main route (in this case, HomePage)
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const IssueTypeReassign()),
                );
              },
              child: Container(
                  width: 250,
                  height: 150,
                  decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 255, 255, 255),
                      border: Border.all(
                          color: const Color.fromARGB(255, 169, 167, 167),
                          width: 0.3,
                          style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                            color: Color.fromARGB(221, 212, 209, 209),
                            spreadRadius: 3)
                      ]),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_add,
                        size: 30,
                        color: Color.fromARGB(255, 15, 109, 156),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 8.0),
                      ),
                      Text(
                        "Reassign Issue Type",
                        style: TextStyle(
                            color: Color.fromARGB(255, 16, 16, 16),
                            fontSize: 20),
                      )
                    ],
                  )),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 40.0),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SupervisorReassign()),
                );
              },
              child: Container(
                  width: 250,
                  height: 150,
                  decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 255, 255, 255),
                      border: Border.all(
                          color: const Color.fromARGB(255, 169, 167, 167),
                          width: 0.3,
                          style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                            color: Color.fromARGB(221, 212, 209, 209),
                            spreadRadius: 3)
                      ]),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.switch_account,
                        size: 30,
                        color: Color.fromARGB(255, 15, 109, 156),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 8.0),
                      ),
                      Text(
                        "Reassign Issue",
                        style: TextStyle(
                            color: Color.fromARGB(255, 16, 16, 16),
                            fontSize: 20),
                      )
                    ],
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
