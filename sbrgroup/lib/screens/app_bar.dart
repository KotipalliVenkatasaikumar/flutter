import 'package:flutter/material.dart';
import 'package:ajna/screens/home_screen.dart';
import 'package:ajna/screens/profile/profile_screen.dart';
import 'package:ajna/theme/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final bool showProfileIcon;

  /// Swap the trailing profile icon for a Home icon.
  ///
  /// Set on the Profile screen itself, where tapping "profile" again would just
  /// push a second copy of the screen you are already on.
  final bool showHomeIcon;

  final VoidCallback? onBackPressed;

  const CustomAppBar(
      {Key? key,
      this.showBackButton = false,
      this.showProfileIcon = true,
      this.showHomeIcon = false,
      this.onBackPressed})
      : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.onPrimary,
      elevation: 0,
      // Brand hero: the logo's azure→emerald sweep, shared with the home header.
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.heroGradient,
            stops: AppColors.heroStops,
          ),
        ),
      ),
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.onPrimary),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
            )
          : GestureDetector(
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
          style: TextStyle(
            color: AppColors.onPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          )),
      // Logout deliberately lives on the Profile screen only (account icon →
      // Logout), not as a bare app-bar icon: unlabelled and next to the profile
      // button, it was an easy mis-tap that ended the session.
      actions: <Widget>[
        IconButton(
          tooltip: showHomeIcon ? 'Home' : 'Profile',
          icon: Icon(
            showHomeIcon ? Icons.home_rounded : Icons.account_circle,
            color: AppColors.onPrimary,
          ),
          onPressed: () {
            if (showHomeIcon) {
              // Replace rather than push, so repeated Profile → Home trips do
              // not stack duplicate Home screens on the navigator.
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            }
          },
        ),
      ],
    );
  }

  // Future<String?> getAndroidId() async {
  //   DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  //   AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
  //   return androidInfo.id; // This provides the unique device ID
  // }
}
