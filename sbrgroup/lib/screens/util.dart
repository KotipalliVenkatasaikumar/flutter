import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Util {
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', userData['accessToken']);
    print('Access token saved: ${userData['accessToken']}');
    await prefs.setString('token', userData['token']);
    await prefs.setInt('userId', userData['userDto']['userId']);
    await prefs.setString('userName', userData['userDto']['userName']);
    await prefs.setString('email', userData['userDto']['email']);
    await prefs.setInt('roleId', userData['userDto']['roleId']);
    await prefs.setInt('organizationId', userData['userDto']['organizationId']);
    await prefs.setString('androidId', userData['userDto']['androidId']);
    await prefs.setString('roleName', userData['userDto']['roleName']);
  }

  static Future<void> saveSystemAndroidId(String systemAndroidId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('systemAndroidId', systemAndroidId);
  }

  static Future<String?> getSystemAndroidId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('systemAndroidId');
  }

  static Future<String?> getUserAndroidId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('androidId');
  }

  static Future<void> saveScanDetails(
      List<Map<String, dynamic>> scanDetails) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> scanDetailsStrings =
        scanDetails.map((detail) => jsonEncode(detail)).toList();
    await prefs.setStringList('userScanDetails', scanDetailsStrings);
  }

  static Future<void> saveIconsAndLabels(List<String> iconsAndLabels) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('iconsAndLabels', iconsAndLabels);
      print('Saved Icons and Labels: $iconsAndLabels'); // Debug print
    } catch (e) {
      print('Error saving icons and labels: $e');
      // Handle the error as needed
    }
  }

  static Future<String?> getAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('Retrieveeed accessToken: $token');
    return token;
  }

  static Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<int?> getRoleId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('roleId');
  }

  static Future<int?> getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  static Future<String?> getUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('userName');
  }

  static Future<String?> getRoleName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('roleName');
  }

  static Future<String?> getEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }

  static Future<int?> getOrganizationId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('organizationId');
  }

  static Future<List<Map<String, dynamic>>?> getUserScanDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? scanDetailsStrings = prefs.getStringList('userScanDetails');
    if (scanDetailsStrings != null) {
      return scanDetailsStrings
          .map((str) => jsonDecode(str) as Map<String, dynamic>)
          .toList();
    } else {
      return null;
    }
  }

  

  static Future<List<String>?> getIconsAndLabels() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? iconsAndLabels = prefs.getStringList('iconsAndLabels');
    print('Retrieved Icons and Labels: $iconsAndLabels'); // Debug print
    return iconsAndLabels;
  }

  static int convertStringtoInt(String stringVar) {
    int intId = 0;
    try {
      intId = int.parse(stringVar);
    } catch (e) {
      // Handle parsing failure
    }
    return intId;
  }
}
