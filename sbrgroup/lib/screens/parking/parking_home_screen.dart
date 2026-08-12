import 'dart:convert';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/parking/parking_context.dart';
import 'package:ajna/screens/parking/parking_dashboard_screen.dart';
import 'package:ajna/screens/parking/parking_entry_screen.dart';
import 'package:ajna/screens/parking/parking_exit_screen.dart';
import 'package:ajna/screens/parking/parking_lane_select_screen.dart';
import 'package:ajna/screens/parking/parking_models.dart';
import 'package:ajna/screens/parking/parking_movement_screen.dart';
import 'package:ajna/screens/parking/parking_reports_screen.dart';
import 'package:ajna/screens/parking/parking_shift_screen.dart';
import 'package:ajna/screens/parking/parking_widgets.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:flutter/material.dart';

/// Parking hub — the attendant's starting point.
///
/// Shows where they are posted and whether a cash shift is open, then hands off
/// to Entry or Exit. Setup (sites, zones, lanes, tariffs) lives on the web
/// admin; this only consumes it.
class ParkingHomeScreen extends StatefulWidget {
  const ParkingHomeScreen({Key? key}) : super(key: key);

  @override
  State<ParkingHomeScreen> createState() => _ParkingHomeScreenState();
}

class _ParkingHomeScreenState extends State<ParkingHomeScreen> {
  bool _loading = true;
  List<ZoneOccupancy> _zones = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    await ParkingContext.load();
    await ParkingContext.refreshOpenShift();
    await _loadOccupancy();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadOccupancy() async {
    if (ParkingContext.siteId == null) {
      _zones = [];
      return;
    }
    try {
      final response =
          await ApiService.getParkingOccupancyBySite(ParkingContext.siteId!);
      if (ApiService.isSuccess(response.statusCode)) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          _zones = decoded
              .map((e) => ZoneOccupancy.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      // Occupancy is informational — never block the hub on it.
      debugPrint('Occupancy error: $e');
      _zones = [];
    }
  }

  Future<void> _selectLane() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ParkingLaneSelectScreen()),
    );
    if (changed == true) _bootstrap();
  }

  /// Read-only screens need a site, not a lane — refusing them for want of a
  /// lane would block a supervisor who never works a barrier.
  Future<void> _open(Widget screen) async {
    if (ParkingContext.siteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warning,
          content: const Text('Choose a site first.',
              style: TextStyle(color: AppColors.onPrimary)),
        ),
      );
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _bootstrap();
  }

  Future<void> _go(Widget screen) async {
    if (!ParkingContext.hasLane) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warning,
          content: const Text('Select the lane you are working first.',
              style: TextStyle(color: AppColors.onPrimary)),
        ),
      );
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final shift = ParkingContext.openShift;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: parkingAppBar('Parking'),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _bootstrap,
        child: ContentWidthLimit(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              if (_zones.isNotEmpty) ...[
                _siteHero(),
                const SizedBox(height: 14),
              ],
              LanePostingChip(onChange: _selectLane),
              const SizedBox(height: 14),
              _shiftCard(shift),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _actionTile(
                      label: 'Entry',
                      caption: 'Admit a vehicle',
                      icon: Icons.login,
                      color: AppColors.primary,
                      onTap: () => _go(const ParkingEntryScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionTile(
                      label: 'Exit',
                      caption: 'Scan & release',
                      icon: Icons.logout,
                      color: AppColors.accent,
                      onTap: () => _go(const ParkingExitScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _actionTile(
                      label: 'Vehicle movement',
                      caption: 'Who is inside',
                      icon: Icons.list_alt,
                      color: AppColors.primaryLight,
                      // Read-only: needs a site, not a lane.
                      onTap: () => _open(const ParkingMovementScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionTile(
                      label: 'Dashboard',
                      caption: 'Live overview',
                      icon: Icons.insights,
                      color: AppColors.amount,
                      onTap: () => _open(const ParkingDashboardScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _wideTile(
                label: 'Reports',
                caption: 'Collection and operations, any date range',
                icon: Icons.bar_chart,
                color: AppColors.accent,
                onTap: () => _open(const ParkingReportsScreen()),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (_zones.isNotEmpty)
                ParkingCard(
                  title: 'Live occupancy',
                  child: Column(
                    children: _zones.map(_zoneRow).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Site-wide standing, above the actions.
  ///
  /// The attendant's first question on opening the app is "how full are we" —
  /// answering it here saves a trip into the dashboard.
  Widget _siteHero() {
    int occupied = 0;
    int free = 0;
    int bays = 0;
    for (final z in _zones) {
      occupied += z.occupiedCount ?? 0;
      free += z.availableCount ?? 0;
      bays += z.totalBays ?? 0;
    }
    final int pct = bays > 0 ? ((occupied / bays) * 100).round() : 0;
    final Color tone = pct >= 95
        ? AppColors.danger
        : pct >= 80
            ? AppColors.warning
            : AppColors.brandEmerald;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
          stops: AppColors.heroStops,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.heroShadow.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LivePulse(color: AppColors.brandEmerald, size: 7),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  ParkingContext.siteName ?? 'Site',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$pct%',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedCount(
                value: occupied.toDouble(),
                style: const TextStyle(
                  fontSize: 42,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(width: 7),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('inside',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onPrimary.withOpacity(0.85))),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedCount(
                    value: free.toDouble(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onPrimary,
                    ),
                  ),
                  Text('bays free',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.onPrimary.withOpacity(0.8))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.onPrimary.withOpacity(0.22),
              valueColor: AlwaysStoppedAnimation<Color>(tone),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shiftCard(ShiftSummary? shift) {
    final bool open = shift?.isOpen == true;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _go(const ParkingShiftScreen()),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.tint(
                      open ? AppColors.success : AppColors.warning, 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(open ? Icons.timelapse : Icons.pause_circle_outline,
                    color: open ? AppColors.success : AppColors.warning,
                    size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(open ? 'Shift open' : 'No shift open',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      // Counts only — never the expected cash. The drawer
                      // figure is revealed on the shift screen, and only after
                      // the operator has counted; showing it here would hand
                      // them the answer before they start.
                      open
                          ? '${shift!.vehiclesAdmitted ?? 0} in / '
                              '${shift.vehiclesReleased ?? 0} out · '
                              '${shift.paymentCount ?? 0} payments'
                          : 'Open one to tie cash to this shift',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
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

  /// A full-width row for a secondary destination — keeps the 2x2 grid of
  /// primary actions from becoming a wall of equal-weight tiles.
  Widget _wideTile({
    required String label,
    required String caption,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withOpacity(0.12),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.tint(color, 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )),
                    const SizedBox(height: 2),
                    Text(caption,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
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

  Widget _actionTile({
    required String label,
    required String caption,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withOpacity(0.12),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.tint(color, 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(height: 3),
              Text(caption,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zoneRow(ZoneOccupancy z) {
    final int pct = z.occupancyPercent ?? 0;
    final Color bar = pct >= 95
        ? AppColors.danger
        : pct >= 80
            ? AppColors.warning
            : AppColors.success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(z.displayName ?? z.zoneName ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              Text('${z.availableCount ?? 0} free',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: bar)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(bar),
            ),
          ),
        ],
      ),
    );
  }
}
