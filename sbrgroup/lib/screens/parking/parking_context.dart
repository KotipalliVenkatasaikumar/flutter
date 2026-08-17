import 'dart:convert';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/parking/parking_models.dart';
import 'package:ajna/screens/util.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The attendant's working context: which site/lane they are posted at, and
/// their open cash shift.
///
/// `laneId` is mandatory on every entry, so the app cannot admit a vehicle
/// until a lane is chosen. Sites and lanes are **configured on the web admin** —
/// this only reads them and remembers the attendant's pick, so they are not
/// re-selecting a lane for every vehicle at a busy barrier.
class ParkingContext {
  ParkingContext._();

  static const String _kProjectId = 'parking_project_id';
  static const String _kProjectName = 'parking_project_name';
  static const String _kSiteId = 'parking_site_id';
  static const String _kSiteName = 'parking_site_name';
  static const String _kLaneId = 'parking_lane_id';
  static const String _kLaneName = 'parking_lane_name';
  static const String _kLaneDirection = 'parking_lane_direction';
  static const String _kZoneId = 'parking_zone_id';
  static const String _kLaneVehicleType = 'parking_lane_vehicle_type';

  /// The dashboard's own site.
  ///
  /// Kept apart from the lane posting on purpose (the web does the same with
  /// `parking.dashboard.siteId`): a supervisor reviewing Earth & Sky should not
  /// have their barrier posting silently moved off Horizon.
  static const String _kDashboardSiteId = 'parking_dashboard_site_id';
  static const String _kLaneChannels = 'parking_lane_channels';

  static int? projectId;
  static String? projectName;
  static int? siteId;
  static String? siteName;
  static int? laneId;
  static String? laneName;
  static String? laneDirection;
  static int? zoneId;

  /// The lane's configured default vehicle type — used to preselect the entry
  /// form, since most lanes serve one kind of vehicle.
  static String? laneDefaultVehicleType;

  /// Comma-separated channels the lane accepts, so the entry screen offers only
  /// what the lane actually has hardware for.
  static String? laneChannelsEnabled;

  /// The open shift, if the operator has one. Null means "no shift open" —
  /// entry/exit still work (the backend does not require a shift) but the cash
  /// will not be tied to a shift for reconciliation.
  static ShiftSummary? openShift;

  static bool get hasLane => laneId != null;

  /// The lane serves the whole site, so the operator must choose the level —
  /// the backend only falls back to the request's zoneId when the lane has none.
  static bool get needsZoneChoice => zoneId == null;

  /// Entry channels this lane accepts (falls back to all when unset).
  static List<String> get entryChannels {
    final raw = (laneChannelsEnabled ?? '').trim();
    if (raw.isEmpty) return ParkingConstants.entryChannels;
    final allowed = raw
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final list = ParkingConstants.entryChannels
        .where((c) => allowed.contains(c))
        .toList();
    return list.isEmpty ? ParkingConstants.entryChannels : list;
  }

  static bool get hasOpenShift => openShift?.isOpen == true;

  /// Restore the saved posting. Call before showing the parking hub.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      projectId = prefs.getInt(_kProjectId);
      projectName = prefs.getString(_kProjectName);
      siteId = prefs.getInt(_kSiteId);
      siteName = prefs.getString(_kSiteName);
      laneId = prefs.getInt(_kLaneId);
      laneName = prefs.getString(_kLaneName);
      laneDirection = prefs.getString(_kLaneDirection);
      zoneId = prefs.getInt(_kZoneId);
      laneDefaultVehicleType = prefs.getString(_kLaneVehicleType);
      laneChannelsEnabled = prefs.getString(_kLaneChannels);
    } catch (e) {
      debugPrint('ParkingContext.load error: $e');
    }
  }

  /// Remember the project the operator is working, so the site list stays
  /// narrowed to it next time.
  static Future<void> saveProject(ParkingProject project) async {
    projectId = project.projectId;
    projectName = project.projectName;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (project.projectId != null) {
        await prefs.setInt(_kProjectId, project.projectId!);
      }
      if (project.projectName != null) {
        await prefs.setString(_kProjectName, project.projectName!);
      }
    } catch (e) {
      debugPrint('ParkingContext.saveProject error: $e');
    }
  }

  static Future<void> saveLane(ParkingSite site, ParkingLane lane) async {
    siteId = site.siteId;
    siteName = site.siteName;
    laneId = lane.laneId;
    laneName = lane.laneName;
    laneDirection = lane.direction;
    zoneId = lane.zoneId;
    laneDefaultVehicleType = lane.defaultVehicleType;
    laneChannelsEnabled = lane.channelsEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (site.siteId != null) await prefs.setInt(_kSiteId, site.siteId!);
      if (site.siteName != null) {
        await prefs.setString(_kSiteName, site.siteName!);
      }
      if (lane.laneId != null) await prefs.setInt(_kLaneId, lane.laneId!);
      if (lane.laneName != null) {
        await prefs.setString(_kLaneName, lane.laneName!);
      }
      if (lane.direction != null) {
        await prefs.setString(_kLaneDirection, lane.direction!);
      }
      if (lane.zoneId != null) await prefs.setInt(_kZoneId, lane.zoneId!);
      if (lane.defaultVehicleType != null) {
        await prefs.setString(_kLaneVehicleType, lane.defaultVehicleType!);
      }
      if (lane.channelsEnabled != null) {
        await prefs.setString(_kLaneChannels, lane.channelsEnabled!);
      } else {
        await prefs.remove(_kLaneChannels);
      }
      if (lane.zoneId == null) await prefs.remove(_kZoneId);
    } catch (e) {
      debugPrint('ParkingContext.saveLane error: $e');
    }
  }

  /// Ask the backend whether this operator already has a shift open, so a
  /// restarted app resumes it instead of opening a duplicate.
  static Future<void> refreshOpenShift() async {
    try {
      final int? userId = await Util.getUserId();
      if (userId == null) return;
      final response = await ApiService.getParkingOpenShift(userId);
      if (ApiService.isSuccess(response.statusCode) &&
          response.body.trim().isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final shift = ShiftSummary.fromJson(decoded);
          openShift = shift.isOpen ? shift : null;
          return;
        }
      }
      openShift = null;
    } catch (e) {
      debugPrint('ParkingContext.refreshOpenShift error: $e');
      openShift = null;
    }
  }

  static void clearShift() => openShift = null;

  static Future<int?> dashboardSiteId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_kDashboardSiteId);
    } catch (e) {
      debugPrint('ParkingContext.dashboardSiteId error: $e');
      return null;
    }
  }

  static Future<void> saveDashboardSiteId(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kDashboardSiteId, id);
    } catch (e) {
      debugPrint('ParkingContext.saveDashboardSiteId error: $e');
    }
  }
}
