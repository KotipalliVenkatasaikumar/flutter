import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:ajna/screens/api_endpoints.dart';

class ErrorHandler {
  /// The message the backend sends with a failed response, or null.
  ///
  /// Most endpoints answer a failure with `{"message": "..."}` written for the
  /// person using the app — "It's too early.Please try again closer to your
  /// scheduled time" — and that wording is better than anything guessed on this
  /// side, so it is what we show.
  ///
  /// Returns null when the body carries nothing usable, so the caller falls
  /// back to its own wording. A body that is really a crash — a Java exception,
  /// a stack trace, a stray status line — is treated as unusable: those are for
  /// the log, never for the user.
  static String? serverMessage(String? body) {
    if (body == null || body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final message = decoded['message'];
      if (message is! String) return null;

      final trimmed = message.trim();
      if (trimmed.isEmpty || trimmed.length > 200) return null;

      // Anything that reads like a crash rather than a sentence for the user.
      final looksTechnical = RegExp(
        r'Exception|Error:|java\.|org\.springframework|\bat\s+com\.|nested',
        caseSensitive: false,
      ).hasMatch(trimmed);
      if (looksTechnical) return null;

      return trimmed;
    } catch (_) {
      // Not JSON — an HTML error page or a gateway response.
      return null;
    }
  }

  /// Shows the backend's own message for a failed response when it sends a
  /// usable one, otherwise [fallback].
  ///
  /// [logDetails] is only ever printed to the console — status codes and raw
  /// bodies must not reach the dialog.
  static void handleResponseError(
    BuildContext context,
    String? responseBody, {
    required String fallback,
    String? logDetails,
  }) {
    if (logDetails != null) debugPrint(logDetails);
    handleError(context, serverMessage(responseBody) ?? fallback,
        logDetails ?? '');
  }

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

  // /// Static method to send error details to the API
  // static Future<void> _sendErrorToApi(String errorDetails) async {
  //   // Replace with your API endpoint URL

  //   try {
  //     final response = await ApiService.sendError(errorDetails);

  //     if (response.statusCode == 200) {
  //       print('Error details sent to API successfully');
  //     } else {
  //       print('Failed to send error details to API: ${response.statusCode}');
  //       _sendErrorEmail(errorDetails); // Send email on API error
  //     }
  //   } catch (e) {
  //     print('Error sending error details to API: $e');
  //     _sendErrorEmail(errorDetails); // Send email on API error
  //   }
  // }

  // /// Static method to send error details via SMTP email using mailer package
  // static Future<void> _sendErrorEmail(String errorMessage) async {
  //   const String senderEmail =
  //       'corenuts.externalprojects@gmail.com'; // Replace with your sender email
  //   const String senderPassword =
  //       'qvra ffkd cpdr vmis'; // Replace with your sender password

  //   final smtpServer = gmail(senderEmail, senderPassword);

  //   final message = Message()
  //     ..from = Address(senderEmail, 'Building Reality')
  //     ..recipients.add('kvs040899@gmail.com')
  //     ..subject = 'Error Report'
  //     ..text = errorMessage;

  //   try {
  //     final sendReport = await send(message, smtpServer);
  //     print('Email sent: $sendReport');
  //   } catch (e) {
  //     print('Error sending email: $e');
  //   }
  // }
}
