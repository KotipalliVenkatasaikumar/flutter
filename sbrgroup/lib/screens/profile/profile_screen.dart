import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/app_bar.dart';
import 'package:ajna/screens/profile/profile_reset_password.dart';
import 'package:ajna/screens/util.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profile screen, restructured to match SBR WorkHub's.
///
/// Same shape as WorkHub: an animated profile card (gradient avatar ring with a
/// pulse, Active badge, title-cased name, detail rows) above a stack of action
/// cards. Two deliberate differences, both forced by what Ajna actually has:
///
///  * **No profile photo.** WorkHub fetches and uploads an avatar via
///    `fetchUserImageUrl` + `user/download-image`. Ajna's `ApiService` has no
///    such endpoints (its only `downloadImage` is the QR-report one), so the
///    avatar stays an icon. Adding photos needs backend work first.
///  * **Role instead of phone.** WorkHub shows `phoneNumber`; Ajna's
///    `Util.saveUserData` never stores one. It does store `roleName`, so that is
///    shown instead — real data rather than a permanently empty row.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final ValueNotifier<Map<String, String?>> _userDataNotifier = ValueNotifier({
    'userName': 'No username found',
    'email': 'No email found',
    'roleName': '',
  });

  late final AnimationController _mainController;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadUserDetails();
  }

  void _setupAnimations() {
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.6)),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _mainController, curve: const Interval(0.2, 0.8)));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.4, 1.0)),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _mainController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _userDataNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    _userDataNotifier.value = {
      'userName': prefs.getString('userName') ?? 'No username found',
      'email': prefs.getString('email') ?? 'No email found',
      'roleName': prefs.getString('roleName') ?? '',
    };
  }

  void _navigateToResetPasswordScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileResetPassword()),
    );
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.toLowerCase().split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  /// Confirm first. WorkHub's profile logs out on a single tap, but Ajna's own
  /// [CustomAppBar] already confirms before logging out — keeping that here
  /// avoids one stray tap destroying the session.
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm Logout',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to logout?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _logout();
            },
            child: const Text('Logout',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );

    try {
      // Drop the push token server-side first, so this device stops receiving
      // notifications for the account being signed out.
      final bool isDeleted = await _deleteDeviceTokenInDatabase();
      debugPrint(isDeleted
          ? 'Logout: device token deleted.'
          : 'Logout: failed to delete device token.');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('Error during logout cleanup: $e');
    }

    if (!mounted) return;
    // Wipe the whole stack — pushReplacement would leave the previous user's
    // Home underneath, and back would reveal it.
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
  }

  Future<bool> _deleteDeviceTokenInDatabase() async {
    try {
      final int? userId = await Util.getUserId();
      final String? androidId = await Util.getUserAndroidId();
      final int? organizationId = await Util.getOrganizationId();
      final String? deviceToken = await Util.getDeviceToken();

      if (userId != null &&
          androidId != null &&
          organizationId != null &&
          deviceToken != null) {
        final response = await ApiService.deleteDeviceToken(
            userId, androidId, organizationId, deviceToken);
        if (response.statusCode == 200) {
          await Util.clearDeviceToken();
          return true;
        }
        debugPrint('Failed to delete device token: ${response.statusCode}');
        return false;
      }
      debugPrint('Missing details; cannot delete device token.');
      return false;
    } catch (e) {
      debugPrint('Error while deleting device token: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      // Home icon instead of the profile icon — we are already on Profile.
      appBar: const CustomAppBar(showBackButton: true, showHomeIcon: true),
      body: ValueListenableBuilder<Map<String, String?>>(
        valueListenable: _userDataNotifier,
        builder: (context, userData, _) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProfileCard(userData),
                  const SizedBox(height: 20),
                  _buildActionCards(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(Map<String, String?> userData) {
    final String name = userData['userName'] ?? '';
    final bool isActive = name.isNotEmpty && name != 'No username found';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.divider, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Stack(
                children: [
                  Column(
                    children: [
                      _buildProfileAvatar(),
                      const SizedBox(height: 20),
                      _buildProfileInfo(userData),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.success
                            : AppColors.textSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: const TextStyle(
                          color: AppColors.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // The logo's two chevron colours, as the avatar ring.
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: AppColors.surface,
              child: Icon(
                Icons.person,
                size: 52,
                color: AppColors.primary,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileInfo(Map<String, String?> userData) {
    final String role = userData['roleName'] ?? '';

    return Column(
      children: [
        Text(
          _toTitleCase(userData['userName'] ?? ''),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.textPrimary,
            letterSpacing: 0.1,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              _infoRow(Icons.email_outlined, userData['email'] ?? ''),
              if (role.isNotEmpty) ...[
                const SizedBox(height: 8),
                _infoRow(Icons.badge_outlined, _toTitleCase(role)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCards() {
    final List<_ProfileActionItem> actionItems = [
      _ProfileActionItem(
        title: 'Reset Password',
        subtitle: 'Change your account password',
        icon: Icons.lock_reset_rounded,
        onTap: _navigateToResetPasswordScreen,
        iconColor: AppColors.primary,
      ),
      _ProfileActionItem(
        title: 'Logout',
        subtitle: 'Sign out from your account',
        icon: Icons.logout_rounded,
        onTap: _confirmLogout,
        iconColor: AppColors.danger,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: List.generate(actionItems.length, (index) {
          final start = 0.1 * index;
          final end = start + 0.5;
          final animation = CurvedAnimation(
            parent: _mainController,
            curve:
                Interval(start, end > 1.0 ? 1.0 : end, curve: Curves.easeOut),
          );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(animation),
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: index == actionItems.length - 1 ? 0 : 8),
                child: _ProfileActionCard(item: actionItems[index]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ProfileActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  const _ProfileActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.iconColor,
  });
}

class _ProfileActionCard extends StatelessWidget {
  final _ProfileActionItem item;
  const _ProfileActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        splashColor: item.iconColor.withOpacity(0.10),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.tint(item.iconColor, 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
