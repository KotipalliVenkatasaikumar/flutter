import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityHandler {
  final Connectivity _connectivity = Connectivity();

  // Method to check connectivity when the app starts
  Future<bool> checkConnectivity(BuildContext context) async {
    var connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showNoInternetAlert(context);
      return false; // No internet connection
    }
    return true; // Online
  }

  // Display alert dialog if there's no internet connection
  void _showNoInternetAlert(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('No Internet Connection'),
          content: const Text(
              'Please check your internet connection and try again.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Ok'),
            ),
          ],
        );
      },
    );
  }
}
