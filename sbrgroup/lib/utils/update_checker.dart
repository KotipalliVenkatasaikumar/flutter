import 'dart:convert';
import 'dart:io';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Store-based update prompt.
///
/// Ajna used to download and install an APK from inside the app. That is gone —
/// iOS cannot do it at all, and on Android it violates Google Play's Device and
/// Network Abuse policy. This replaces it with the same approach used by SBR
/// WorkHub: keep the backend version check, but send the user to the store.
///
/// The backend contract is unchanged — `ApiService.checkForUpdate()` returns
/// `{"commonRefValue": "<latest version>"}` (refKey `ajna_version`), the same
/// endpoint and field the old APK flow read.
class UpdateChecker {
  // ===========================================================================
  // ⚠️ PLACEHOLDER STORE LINKS — REPLACE BEFORE RELEASE
  // ---------------------------------------------------------------------------
  // These are dummy values so the flow can be built and tested now. Swap all
  // three once the listings exist:
  //
  //   1. appStoreLink    — copy the real URL from App Store Connect. The
  //                        `id...` number is Apple's, assigned when you create
  //                        the app record. `id0000000000` below is NOT real.
  //   2. playStoreLink   — must match the Android `applicationId` exactly.
  //   3. playStoreWebLink— same package name as (2).
  //
  // The Android `applicationId` is `com.corenuts.ajna` and the two Play links
  // below already match it. Only the App Store ID is still a placeholder — it
  // is issued when the app record is created in App Store Connect.
  // ===========================================================================

  /// App Store link — dummy ID, replace with the real one.
  static const String appStoreLink =
      "https://apps.apple.com/us/app/ajna/id0000000000";

  /// Play Store link — opens the Play Store app directly.
  static const String playStoreLink = "market://details?id=com.corenuts.ajna";

  /// Fallback web URL for when the Play Store app is unavailable.
  static const String playStoreWebLink =
      "https://play.google.com/store/apps/details?id=com.corenuts.ajna";

  /// Numeric-aware version compare, so 1.10.0 correctly beats 1.9.0
  /// (a plain string `!=` would have fired on every mismatch).
  static bool _isVersionLower(String current, String latest) {
    try {
      final cur = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final lat = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (int i = 0; i < lat.length; i++) {
        final c = i < cur.length ? cur[i] : 0;
        if (c < lat[i]) return true;
        if (c > lat[i]) return false;
      }
      return false;
    } catch (e) {
      debugPrint('Error comparing versions: $e');
      return false;
    }
  }

  static Future<void> _openStore() async {
    final String primary = Platform.isIOS ? appStoreLink : playStoreLink;
    final String fallback = Platform.isIOS ? appStoreLink : playStoreWebLink;
    try {
      if (await canLaunchUrl(Uri.parse(primary))) {
        await launchUrl(Uri.parse(primary),
            mode: LaunchMode.externalApplication);
      } else {
        // The Play Store app may be absent (emulators, some OEM builds).
        await launchUrl(Uri.parse(fallback),
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching store: $e');
    }
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required bool forceUpdate,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => PopScope(
        // A forced update cannot be dismissed with the back gesture.
        canPop: !forceUpdate,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            forceUpdate ? 'Update Required' : 'Update Available',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
          content:
              Text(message, style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Maybe Later',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            TextButton(
              onPressed: () async {
                await _openStore();
                // NOTE: WorkHub calls exit(0) here on a forced update. Ajna does
                // not — Apple's review guidelines treat programmatic termination
                // as a crash and reject for it. The dialog simply stays up and
                // undismissable instead, which blocks use just as effectively.
                if (!forceUpdate && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Update Now',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  /// Asks the backend for the latest published version and, if this build is
  /// older, offers to open the store. Never throws — a failed check must not
  /// block the app from loading.
  static Future<void> checkForUpdate(BuildContext context,
      {bool forceUpdate = false}) async {
    if (kIsWeb) return;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      final response = await ApiService.checkForUpdate();
      if (response.statusCode != 200) {
        debugPrint('Update check failed: ${response.statusCode}');
        return;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final latest = data['commonRefValue']?.toString();
      if (latest == null || latest.isEmpty) {
        debugPrint('Update check: commonRefValue missing');
        return;
      }

      if (_isVersionLower(currentVersion, latest) && context.mounted) {
        _showUpdateDialog(
          context,
          forceUpdate: forceUpdate,
          message:
              'A new version ($latest) is available. Please update to continue '
              'getting the latest features and fixes.',
        );
      }
    } catch (e) {
      debugPrint('Error checking for update: $e');
    }
  }
}
