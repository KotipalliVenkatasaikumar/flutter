import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:ajna/screens/api_endpoints.dart';

class ErrorHandler {
  static void handleError(
      BuildContext context, String userMessage, String errorDetails) {
    // Show custom message to user via SnackBar
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(content: Text(userMessage)),
    // );

    // Show custom message to user via Dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 10),
              Text('Error'),
            ],
          ),
          content: Text(userMessage),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );

    // Send error details to the API and email
    // _sendErrorToApi(errorDetails);
    // _sendErrorEmail(errorDetails);
  }

  /// Static method to send error details to the API
  static Future<void> _sendErrorToApi(String errorDetails) async {
    // Replace with your API endpoint URL

    try {
      final response = await ApiService.sendError(errorDetails);

      if (response.statusCode == 200) {
        print('Error details sent to API successfully');
      } else {
        print('Failed to send error details to API: ${response.statusCode}');
        _sendErrorEmail(errorDetails); // Send email on API error
      }
    } catch (e) {
      print('Error sending error details to API: $e');
      _sendErrorEmail(errorDetails); // Send email on API error
    }
  }

  /// Static method to send error details via SMTP email using mailer package
  static Future<void> _sendErrorEmail(String errorMessage) async {
    const String senderEmail =
        'corenuts.externalprojects@gmail.com'; // Replace with your sender email
    const String senderPassword =
        'qvra ffkd cpdr vmis'; // Replace with your sender password

    final smtpServer = gmail(senderEmail, senderPassword);

    final message = Message()
      ..from = Address(senderEmail, 'Building Reality')
      ..recipients.add('kvs040899@gmail.com')
      ..subject = 'Error Report'
      ..text = errorMessage;

    try {
      final sendReport = await send(message, smtpServer);
      print('Email sent: $sendReport');
    } catch (e) {
      print('Error sending email: $e');
    }
  }
}
