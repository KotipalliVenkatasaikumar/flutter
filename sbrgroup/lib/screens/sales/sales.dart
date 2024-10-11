import 'package:flutter/material.dart';

class Sales extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Dummy data for demonstration
    int totalLeadsLost = 5;
    int totalClosedLeads = 15;
    int todayVisitsCompleted = 10;
    int todayVisitsConfirmed = 8;
    int todayFollowUps = 20;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sales Dashboard'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade400, Colors.blue.shade900],
          ),
        ),
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.start, // Align children to the start
          crossAxisAlignment:
              CrossAxisAlignment.stretch, // Stretch children horizontally
          children: [
            Text(
              'Sales Performance',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            SalesDataWidget(
              label: 'Closed Leads',
              count: totalClosedLeads,
              color: Colors.green,
              icon: Icons.check_circle,
            ),
            SalesDataWidget(
              label: 'Visits Completed',
              count: todayVisitsCompleted,
              color: Colors.orange,
              icon: Icons.place,
            ),
            SalesDataWidget(
              label: 'Visits Confirmed',
              count: todayVisitsConfirmed,
              color: Colors.blue,
              icon: Icons.check,
            ),
            SalesDataWidget(
              label: 'Follow-ups',
              count: todayFollowUps,
              color: Colors.purple,
              icon: Icons.people,
            ),
            SalesDataWidget(
              label: 'Leads Lost',
              count: totalLeadsLost,
              color: Colors.red,
              icon: Icons.close,
            ),
          ],
        ),
      ),
    );
  }
}

class SalesDataWidget extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const SalesDataWidget({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      margin: EdgeInsets.symmetric(vertical: 8), // Add vertical margin
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 30,
            color: color,
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                count.toString(),
                style: TextStyle(fontSize: 20, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: Sales(),
  ));
}
