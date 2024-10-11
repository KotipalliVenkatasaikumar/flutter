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
        onTap: () {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      const HomeScreen())); // Modify this line according to how your navigation is set up
        },
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }
}
