import 'dart:async';
import 'dart:convert';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/parking/parking_context.dart';
import 'package:ajna/screens/parking/parking_models.dart';
import 'package:ajna/screens/parking/parking_movement_screen.dart';
import 'package:ajna/screens/parking/parking_widgets.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The supervisor's wall screen — occupancy, today's money, dead devices,
/// pending decisions.
///
/// Mirrors the web `parking-dashboard`. `GET /parking/report/dashboard/live/
/// {siteId}` returns the whole picture in one call, so this refreshes on a
/// timer: a wall screen that needs pulling to update is a wall screen nobody
/// trusts.
class ParkingDashboardScreen extends StatefulWidget {
  const ParkingDashboardScreen({super.key});

  @override
  State<ParkingDashboardScreen> createState() => _ParkingDashboardScreenState();
}

class _ParkingDashboardScreenState extends State<ParkingDashboardScreen> {
  /// Matches the web: "a wall screen nobody touches must not go stale; 30s is
  /// frequent enough to notice a barrier dying without hammering the API."
  static const Duration _refreshEvery = Duration(seconds: 30);

  Timer? _timer;
  bool _loading = true;
  String? _error;
  LiveDashboard? _data;
  DateTime? _lastRefreshed;

  /// The site being watched — the dashboard's own, not the lane posting. A
  /// supervisor covers several sites; changing which one they are LOOKING at
  /// must not move the barrier they are POSTED at.
  int? _siteId;
  List<ParkingSite> _sites = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _timer = Timer.periodic(_refreshEvery, (_) => _load(silent: true));
  }

  Future<void> _bootstrap() async {
    // Last site viewed here → else the lane posting → else the first site.
    _siteId = await ParkingContext.dashboardSiteId() ?? ParkingContext.siteId;
    await _loadSites();
    await _load();
  }

  Future<void> _loadSites() async {
    try {
      final response =
          await ApiService.getParkingSites(projectId: ParkingContext.projectId);
      if (!mounted) return;
      if (ApiService.isSuccess(response.statusCode)) {
        final decoded = jsonDecode(response.body);
        final list = (decoded is List) ? decoded : (decoded['data'] ?? []);
        final sites = (list as List)
            .map((e) => ParkingSite.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _sites = sites;
          _siteId ??= sites.isNotEmpty ? sites.first.siteId : null;
        });
      } else {
        debugPrint('Dashboard sites failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Dashboard sites error: $e');
    }
  }

  Future<void> _selectSite(int siteId) async {
    if (siteId == _siteId) return;
    await ParkingContext.saveDashboardSiteId(siteId);
    if (!mounted) return;
    setState(() {
      _siteId = siteId;
      // Drop the old site's picture rather than showing it under a new name.
      _data = null;
      _loading = true;
    });
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_siteId == null) {
      setState(() {
        _loading = false;
        _error = 'Choose a site first.';
      });
      return;
    }
    if (!silent) setState(() => _loading = true);
    try {
      final response = await ApiService.getParkingLiveDashboard(_siteId!);
      if (!mounted) return;
      if (ApiService.isSuccess(response.statusCode)) {
        setState(() {
          _data = LiveDashboard.fromJson(
              jsonDecode(response.body) as Map<String, dynamic>);
          _lastRefreshed = DateTime.now();
          _loading = false;
          _error = null;
        });
      } else {
        debugPrint('Dashboard failed: HTTP ${response.statusCode} '
            '${response.body}');
        setState(() {
          _loading = false;
          // Keep the last good picture on screen rather than blanking it —
          // stale numbers beat no numbers when someone is watching the gate.
          if (_data == null) _error = 'Could not load the dashboard.';
        });
      }
    } catch (e) {
      debugPrint('Dashboard error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_data == null) {
          _error = 'Could not reach the server. Please check your connection.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: parkingAppBar('Parking Operations', actions: [
        if (_sites.length > 1) _siteMenu(),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh, color: AppColors.onPrimary),
          onPressed: () => _load(),
        ),
      ]),
      body: ContentWidthLimit(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () => _load(),
          child: (_loading && d == null)
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    // Nobody should demo a "working" barrier without knowing
                    // it is simulated — so this leads, it does not trail.
                    if (d?.hardwareSimulated == true) ...[
                      const ParkingBanner(
                        text: 'Simulated hardware — barrier and printer '
                            'commands are logged, not executed.',
                        color: AppColors.warning,
                        icon: Icons.memory,
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_lastRefreshed != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const LivePulse(
                              color: AppColors.brandEmerald, size: 6),
                          const SizedBox(width: 6),
                          Text(
                            'updated ${DateFormat('HH:mm:ss').format(_lastRefreshed!)}',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_error != null && d == null)
                      ParkingBanner(
                          text: _error!,
                          color: AppColors.danger,
                          icon: Icons.error_outline)
                    else if (d != null) ...[
                      AnimatedEntry(index: 0, child: _occupancyHero(d)),
                      const SizedBox(height: 14),
                      AnimatedEntry(index: 1, child: _moneyToday(d)),
                      const SizedBox(height: 14),
                      AnimatedEntry(index: 2, child: _flowToday(d)),
                      if (d.needsAttention) ...[
                        const SizedBox(height: 14),
                        AnimatedEntry(index: 3, child: _attention(d)),
                      ],
                      if (d.zones.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        AnimatedEntry(index: 4, child: _levels(d)),
                      ],
                      const SizedBox(height: 18),
                      _openRegisterButton(),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  /// Site filter, in the app bar like the web's header dropdown — a filter
  /// belongs in the chrome, not eating a row of the wall screen.
  Widget _siteMenu() {
    final current = _sites.firstWhere(
      (x) => x.siteId == _siteId,
      orElse: () => ParkingSite(siteName: 'Site'),
    );
    return PopupMenuButton<int>(
      tooltip: 'Change site',
      color: AppColors.surface,
      onSelected: _selectSite,
      itemBuilder: (context) => _sites
          .where((x) => x.siteId != null)
          .map((x) => PopupMenuItem<int>(
                value: x.siteId!,
                child: Row(
                  children: [
                    Icon(
                      x.siteId == _siteId
                          ? Icons.check_circle
                          : Icons.location_city,
                      size: 18,
                      color: x.siteId == _siteId
                          ? AppColors.primary
                          : AppColors.textFaint,
                    ),
                    const SizedBox(width: 10),
                    Text(x.siteName ?? 'Site ${x.siteId}',
                        style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ))
          .toList(),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.onPrimary.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  current.siteName ?? 'Site',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onPrimary),
                ),
              ),
              const Icon(Icons.arrow_drop_down,
                  size: 20, color: AppColors.onPrimary),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- hero ----

  Widget _occupancyHero(LiveDashboard d) {
    final int pct = d.occupancyPercent ?? 0;
    final Color tone = d.anyZoneFull || pct >= 95
        ? AppColors.danger
        : pct >= 80
            ? AppColors.warning
            : AppColors.brandEmerald;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
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
              Expanded(
                child: Text(
                  d.siteName ?? 'Site',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
              if (d.asOf != null)
                Text(
                  'as of ${DateFormat('hh:mm a').format(d.asOf!)}',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.onPrimary.withOpacity(0.8)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${d.vehiclesInside ?? 0}',
                style: TextStyle(
                  fontSize: 52,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  d.totalCapacity == null
                      ? 'inside'
                      : 'of ${d.totalCapacity} bays',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.onPrimary.withOpacity(0.85)),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$pct%',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 9,
              backgroundColor: AppColors.onPrimary.withOpacity(0.22),
              valueColor: AlwaysStoppedAnimation<Color>(tone),
            ),
          ),
          if (d.anyZoneFull) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.report, size: 15, color: AppColors.onPrimary),
                const SizedBox(width: 6),
                Text('At least one level is full',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onPrimary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------- money ----

  Widget _moneyToday(LiveDashboard d) {
    return ParkingCard(
      title: 'Collected today',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedCount(
            value: d.collectedToday ?? 0,
            format: (v) => money(v),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.amount,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniStat('Cash', money(d.cashToday), AppColors.success,
                    Icons.payments_outlined),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniStat('Digital', money(d.digitalToday),
                    AppColors.primary, Icons.credit_card),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniStat('Txns', '${d.transactionsToday ?? 0}',
                    AppColors.textSecondary, Icons.receipt_long_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _flowToday(LiveDashboard d) {
    return Row(
      children: [
        Expanded(
          child: _bigStat('In today', '${d.vehiclesAdmittedToday ?? 0}',
              AppColors.primary, Icons.login),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _bigStat('Out today', '${d.vehiclesReleasedToday ?? 0}',
              AppColors.accent, Icons.logout),
        ),
      ],
    );
  }

  Widget _bigStat(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.tint(color, 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedCount(
                    value: double.tryParse(value) ?? 0,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                Text(label,
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 5),
          FittedBox(
            child: Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ),
          Text(label,
              style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- attention ----

  /// Only the things a supervisor must act on. A dashboard that lists
  /// everything equally is one where the dead barrier goes unnoticed.
  Widget _attention(LiveDashboard d) {
    final items = <Widget>[];

    if ((d.devicesOffline ?? 0) > 0) {
      items.add(_attentionRow(
        Icons.wifi_off,
        AppColors.danger,
        '${d.devicesOffline} device${d.devicesOffline == 1 ? "" : "s"} offline',
        d.offlineDeviceNames.isEmpty
            ? 'Barrier or reader not reporting'
            : d.offlineDeviceNames.join(', '),
      ));
    }
    if ((d.exceptionsAwaitingDecision ?? 0) > 0) {
      items.add(_attentionRow(
        Icons.gavel,
        AppColors.warning,
        '${d.exceptionsAwaitingDecision} exception'
            '${d.exceptionsAwaitingDecision == 1 ? "" : "s"} awaiting decision',
        'Lost tickets, disputes and overrides',
      ));
    }
    if ((d.shiftsAwaitingSignOff ?? 0) > 0) {
      items.add(_attentionRow(
        Icons.account_balance_wallet_outlined,
        AppColors.warning,
        '${d.shiftsAwaitingSignOff} shift'
            '${d.shiftsAwaitingSignOff == 1 ? "" : "s"} awaiting sign-off',
        'Cash counted but not verified',
      ));
    }
    if ((d.staleSessions ?? 0) > 0) {
      items.add(_attentionRow(
        Icons.hourglass_disabled,
        AppColors.warning,
        '${d.staleSessions} stale stay${d.staleSessions == 1 ? "" : "s"}',
        'Open far longer than expected — may never have exited',
      ));
    }

    return ParkingCard(
      title: 'Needs attention',
      child: Column(children: items),
    );
  }

  Widget _attentionRow(
      IconData icon, Color color, String title, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.tint(color, 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(detail,
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- levels ----

  /// Zones, in the web's shape: occupied / total, a badge that distinguishes
  /// PART FULL from FULL, then which bays are free — not just how many.
  Widget _levels(LiveDashboard d) {
    return ParkingCard(
      title: 'Zones',
      child: Column(
        children: d.zones.map((z) {
          final int pct = z.occupancyPercent ?? 0;
          final Color tone = !z.acceptingVehicles
              ? AppColors.danger
              : z.partlyFull
                  ? AppColors.warning
                  : AppColors.success;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
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
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: tone,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(z.badgeLabel,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: AppColors.onPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${z.occupiedCount ?? 0}',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary)),
                    Text(' / ${z.totalBays ?? 0}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: AppColors.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation<Color>(tone),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    '${z.availableCount ?? 0} free',
                    if ((z.reserveBufferPct ?? 0) > 0)
                      '(${z.reserveBufferPct}% held back)',
                  ].join(' '),
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                // Which bays are free, not just how many.
                if (z.byVehicleType.isNotEmpty) ...[
                  Divider(color: AppColors.divider, height: 18),
                  ...z.byVehicleType.map((t) {
                    final bool full = !t.acceptingVehicles;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(vehicleIcon(t.vehicleType),
                              size: 15, color: AppColors.textSecondary),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(ParkingConstants.label(t.vehicleType),
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textPrimary)),
                          ),
                          Text(
                            full ? 'FULL' : '${t.availableCount ?? 0} free',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color:
                                  full ? AppColors.danger : AppColors.success,
                            ),
                          ),
                          Text(' / ${t.totalBays ?? 0}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _openRegisterButton() {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ParkingMovementScreen()),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.list_alt),
        label: const Text('Vehicle movement register',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
