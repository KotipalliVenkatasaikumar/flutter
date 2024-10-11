import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:marquee/marquee.dart' show Marquee;
import 'package:package_info_plus/package_info_plus.dart';

class MarqueeBanner extends StatefulWidget {
  const MarqueeBanner({Key? key}) : super(key: key);

  @override
  _MarqueeBannerState createState() => _MarqueeBannerState();
}

class _MarqueeBannerState extends State<MarqueeBanner> {
  String? _latestVersion;
  String? _currentVersion;

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();

    _getCurrentVersion();
    _getLatestVersion();
  }

  Future<void> _getCurrentVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
/*
String appName = packageInfo.appName;
String packageName = packageInfo.packageName;
String version = packageInfo.version;
String buildNumber = packageInfo.buildNumber;
*/
    setState(() {
      _currentVersion = packageInfo.version;
      print("_currentVersion");
      print(_currentVersion);
    });
  }

  Future<String?> _fetchBannerMessage() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://crm.corenuts.com/api/commonRefData/getbyRefName/mobileBannerMessage'),
      );
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as List;
        if (jsonData.isNotEmpty) {
          return jsonData[0]
              as String; // Return the first message from the response
        }
      }
      // Return null if there's no message or if the response is not successful
      return null;
    } catch (e) {
      // Return null in case of any errors during the HTTP request
      return null;
    }
  }

  Future<void> _getLatestVersion() async {
    final response = await http.get(
      Uri.parse(
          'https://crm.corenuts.com/api/commonRefData/getbyRefName/mobileVersion'),
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List;
      if (jsonData.isNotEmpty) {
        setState(() {
          _latestVersion = jsonData[0];
          print('latest version');
          print(_latestVersion);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _latestVersion != null &&
            _currentVersion != null &&
            _latestVersion != _currentVersion
        ? _buildMarqueeWithMessage()
        : _buildMarqueeWithoutMessage();
  }

  Widget _buildMarqueeWithMessage() {
    return FutureBuilder(
      future: _fetchBannerMessage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(); // Display a loading indicator while fetching data
        } else if (snapshot.hasError) {
          return Text(
              'Error: ${snapshot.error}'); // Display an error message if fetching data fails
        } else {
          return Container(
            height: 40,
            color: const Color.fromARGB(255, 17, 17, 17),
            child: Marquee(
              text: snapshot.data ??
                  '', // Use the fetched message or empty string if null
              style: const TextStyle(color: Colors.white, fontSize: 16),
              blankSpace: 100,
              velocity: 50,
              crossAxisAlignment: CrossAxisAlignment.center,
              pauseAfterRound: const Duration(seconds: 1),
              showFadingOnlyWhenScrolling: true,
              fadingEdgeStartFraction: 0.1,
              fadingEdgeEndFraction: 0.1,
            ),
          );
        }
      },
    );
  }

  Widget _buildMarqueeWithoutMessage() {
    return Container();
  }
}
