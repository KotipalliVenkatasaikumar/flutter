import 'package:ajna/screens/api_endpoints.dart';
import 'package:flutter/material.dart';

class NotificationSendingScreen extends StatefulWidget {
  const NotificationSendingScreen({super.key});

  @override
  _NotificationSendingScreenState createState() =>
      _NotificationSendingScreenState();
}

class _NotificationSendingScreenState extends State<NotificationSendingScreen> {
  bool _isLoading = false; // Flag to handle loading state

  // Handle Emergency Notification
  void _handleEmergency(BuildContext context) async {
    setState(() {
      _isLoading = true; // Show loading spinner
    });

    try {
      List<int> userIds = [116]; // Example userIds
      String title = 'Emergency';
      String body = 'This is an emergency notification';
      int organizationId = 2;

      // Send emergency notification
      var response = await ApiService.sendNotification(
        userIds: userIds,
        title: title,
        body: body,
        route: '',
        organizationId: organizationId,
      );

      setState(() {
        _isLoading = false; // Hide loading spinner after request
      });

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency notification sent!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to send emergency notification')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Handle Normal Notification
  void _handleNormal(BuildContext context) async {
    setState(() {
      _isLoading = true; // Show loading spinner
    });

    try {
      List<int> userIds = [116]; // Example userIds
      String title = 'Normal Notification';
      String body = 'This is a normal notification';
      int organizationId = 2;

      // Send normal notification
      var response = await ApiService.sendNotification(
        userIds: userIds,
        title: title,
        body: body,
        route: '',
        organizationId: organizationId,
      );

      setState(() {
        _isLoading = false; // Hide loading spinner after request
      });

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Normal notification sent!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send normal notification')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification',
              style: TextStyle(
                fontSize: screenWidth > 600 ? 20 : 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Custom Card Container
              Card(
                elevation: 8,
                shadowColor: Colors.black.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text(
                        'Send a Notification',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Emergency Button
                      ElevatedButton.icon(
                        onPressed:
                            _isLoading ? null : () => _handleEmergency(context),
                        icon: const Icon(Icons.warning_rounded,
                            color: Colors.white),
                        label: const Text('Emergency'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: const Size.fromHeight(55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: _isLoading ? 0 : 5,
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Normal Button
                      ElevatedButton.icon(
                        onPressed:
                            _isLoading ? null : () => _handleNormal(context),
                        icon: const Icon(Icons.notifications_active,
                            color: Colors.white),
                        label: const Text('Normal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size.fromHeight(55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: _isLoading ? 0 : 5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Loading indicator
                      if (_isLoading)
                        const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.teal),
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
