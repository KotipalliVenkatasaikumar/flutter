import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/util.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:ajna/screens/home_screen.dart';
import 'package:ajna/screens/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({Key? key}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
      leading: GestureDetector(
        // onTap: () {
        //   Navigator.pushReplacement(
        //       context,
        //       MaterialPageRoute(
        //           builder: (context) =>
        //               const HomeScreen())); // Modify this line according to how your navigation is set up
        // },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Image.asset('lib/assets/images/ajna.png'),
        ),
      ),
      title: const Text('AJNA',
          style: TextStyle(color: Colors.white, fontSize: 18)),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () => _confirmLogout(context),
        ),
        IconButton(
          icon: const Icon(Icons.account_circle, color: Colors.white),
          onPressed: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()));
          },
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Logout"),
          content: const Text("Are you sure you want to logout?"),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pop(), // Dismiss the dialog but do not logout
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => _logout(context), // Proceed with logging out
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );
  }

  void _logout(BuildContext context) async {
    bool isDeleted = await _deleteDeviceTokenInDatabase();

    if (isDeleted) {
      print("Logout successful, device token deleted.");
    } else {
      print("Logout successful, but failed to delete device token.");
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Navigate to the login screen
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  Future<bool> _deleteDeviceTokenInDatabase() async {
    try {
      int? userId = await Util.getUserId();
      String? androidId = await Util.getUserAndroidId();
      int? organizationId = await Util.getOrganizationId();
      String? deviceToken = await Util.getDeviceToken();

      if (userId != null &&
          androidId != null &&
          organizationId != null &&
          deviceToken != null) {
        final response = await ApiService.deleteDeviceToken(
            userId, androidId, organizationId, deviceToken);

        if (response.statusCode == 200) {
          print("Device token deleted successfully.");
          bool isClearedLocally = await Util.clearDeviceToken();
          if (isClearedLocally) {
            print("Device token cleared from both server and local storage.");
          } else {
            print("Failed to clear the device token locally.");
          }
          return true;
        } else {
          print("Failed to delete device token: ${response.body}");
          return false;
        }
      } else {
        print("Required details are missing; cannot delete device token.");
        return false;
      }
    } catch (e) {
      print("Error while deleting device token: $e");
      return false;
    }
  }

  // Future<String?> getAndroidId() async {
  //   DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  //   AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
  //   return androidInfo.id; // This provides the unique device ID
  // }
}
