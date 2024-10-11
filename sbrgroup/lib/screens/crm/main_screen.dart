import 'package:flutter/material.dart';
import 'package:ajna/screens/crm//approve_screen.dart';
import 'package:ajna/screens/crm//bottom_navigation.dart';
import 'package:ajna/screens/crm//inprogress_screen.dart';
import 'package:ajna/screens/crm//issues_screen.dart';
import 'package:ajna/screens/crm//reassign_main_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key, required this.initialIndex}) : super(key: key);

  final int initialIndex;
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    OpenIssuesTableWidget(key: issuesScreenKey),
    InProgressWidget(key: inprogressScreenKey),
    InApproveWidget(key: inapproveScreenKey),
    const ReassignMaiWidget(),
  ];

  void _onItemTapped(int index) {
    if (index == 0) {
      issuesScreenKey.currentState?.refreshData();
    } else if (index == 1) {
      inprogressScreenKey.currentState?.refreshData();
    } else if (index == 2) {
      inapproveScreenKey.currentState?.refreshData();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex; // Initialize from widget.initialIndex
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
