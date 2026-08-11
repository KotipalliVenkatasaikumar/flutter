import 'dart:convert';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/parking/parking_context.dart';
import 'package:ajna/screens/parking/parking_models.dart';
import 'package:ajna/screens/parking/parking_widgets.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The vehicle movement register.
///
/// Mirrors the web `vehicle-movement` component. Answers "which vehicles are
/// inside, and who came and went" — the question the dashboard's counts cannot
/// answer. It is what gets opened when a tenant asks whether their van was here
/// on Tuesday, or when a driver disputes what they were charged.
///
/// Defaults to vehicles currently inside, because that is what is asked at the
/// counter. The date range only appears once the operator switches to a
/// historical view, since a range means nothing for "right now".
class ParkingMovementScreen extends StatefulWidget {
  const ParkingMovementScreen({super.key});

  @override
  State<ParkingMovementScreen> createState() => _ParkingMovementScreenState();
}

class _ParkingMovementScreenState extends State<ParkingMovementScreen> {
  static const List<_StatusOption> _statuses = [
    _StatusOption('INSIDE', 'Inside now'),
    _StatusOption('EXITED', 'Already left'),
    _StatusOption('ALL', 'All'),
  ];

  final TextEditingController _plateController = TextEditingController();
  final ScrollController _scroll = ScrollController();

  String _status = 'INSIDE';
  String? _vehicleType;
  DateTime? _from;
  DateTime? _to;

  int _page = 0;
  static const int _pageSize = 25;

  bool _loading = false;
  bool _loadingMore = false;
  bool _hasSearched = false;
  String? _error;

  final List<VehicleMovement> _rows = [];
  int _totalMatching = 0;
  int _stillInsideCount = 0;
  double? _totalCollected;

  /// A date range is meaningless for "who is inside right now".
  bool get _showsDateRange => _status != 'INSIDE';

  bool get _canLoadMore => _rows.length < _totalMatching;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
          !_loading &&
          !_loadingMore &&
          _canLoadMore) {
        _loadMore();
      }
    });
    _search(reset: true);
  }

  @override
  void dispose() {
    _plateController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onStatusChange(String value) {
    setState(() {
      _status = value;
      // Moving to a historical view with no dates would sweep the entire
      // history of the site, so default to today. The operator can widen it
      // deliberately.
      if (_showsDateRange && _from == null && _to == null) {
        final now = DateTime.now();
        _from = DateTime(now.year, now.month, now.day);
        _to = _from;
      }
    });
    _search(reset: true);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = (isFrom ? _from : _to) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.onPrimary,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to != null && _to!.isBefore(picked)) _to = picked;
      } else {
        _to = picked;
        if (_from != null && _from!.isAfter(picked)) _from = picked;
      }
    });
    _search(reset: true);
  }

  Future<void> _search({bool reset = false}) async {
    if (ParkingContext.siteId == null) {
      setState(() {
        _error = 'Choose a site to see its vehicle movements.';
        _rows.clear();
      });
      return;
    }

    if (reset) {
      _page = 0;
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final df = DateFormat('yyyy-MM-dd');
      final response = await ApiService.parkingMovementSearch(
        siteId: ParkingContext.siteId!,
        status: _status,
        from: _showsDateRange && _from != null ? df.format(_from!) : null,
        to: _showsDateRange && _to != null ? df.format(_to!) : null,
        plate: _plateController.text.trim().isEmpty
            ? null
            : _plateController.text.trim(),
        vehicleType: _vehicleType,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted) return;

      if (ApiService.isSuccess(response.statusCode)) {
        final page = VehicleMovementPage.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
        setState(() {
          if (reset) _rows.clear();
          _rows.addAll(page.rows);
          _totalMatching = page.totalMatching;
          _stillInsideCount = page.stillInsideCount;
          _totalCollected = page.totalCollected;
          _loading = false;
          _loadingMore = false;
          _hasSearched = true;
        });
      } else {
        debugPrint('Movement search failed: HTTP ${response.statusCode} '
            '${response.body}');
        setState(() {
          _loading = false;
          _loadingMore = false;
          _hasSearched = true;
          _error = 'Could not load the vehicle movement register.';
        });
      }
    } catch (e) {
      debugPrint('Movement search error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _hasSearched = true;
        _error = 'Could not reach the server. Please check your connection.';
      });
    }
  }

  Future<void> _loadMore() async {
    _page++;
    await _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: parkingAppBar('Vehicle Movement'),
      body: ContentWidthLimit(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () => _search(reset: true),
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _filters(),
              const SizedBox(height: 14),
              if (_hasSearched && _error == null) _totals(),
              if (_error != null) ...[
                const SizedBox(height: 4),
                ParkingBanner(
                    text: _error!,
                    color: AppColors.danger,
                    icon: Icons.error_outline),
              ],
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (_rows.isEmpty && _hasSearched && _error == null)
                _empty()
              else
                ..._rows.asMap().entries.map(
                      (e) => AnimatedEntry(
                        key: ValueKey(e.value.sessionId ?? e.key),
                        index: e.key,
                        child: _movementCard(e.value),
                      ),
                    ),
              if (_loadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (_canLoadMore && _rows.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: _loadMore,
                    child: Text(
                        'Load more (${_rows.length} of $_totalMatching)',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters() {
    final df = DateFormat('dd MMM yyyy');
    return ParkingCard(
      title: 'Show',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoiceChipRow(
            values: _statuses.map((s) => s.value).toList(),
            selected: _status,
            onChanged: _onStatusChange,
            labels: {for (final s in _statuses) s.value: s.label},
          ),
          if (_showsDateRange) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _dateButton(
                      'From',
                      _from == null ? '—' : df.format(_from!),
                      () => _pickDate(isFrom: true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dateButton('To', _to == null ? '—' : df.format(_to!),
                      () => _pickDate(isFrom: false)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _plateController,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            inputFormatters: [UpperCaseTextFormatter()],
            onFieldSubmitted: (_) => _search(reset: true),
            style: TextStyle(color: AppColors.textPrimary),
            cursorColor: AppColors.primary,
            decoration: parkingFieldDecoration(
              'Vehicle or ticket',
              suffixIcon: IconButton(
                icon: Icon(Icons.search, color: AppColors.primary),
                onPressed: () => _search(reset: true),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Vehicle type',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _typeChip(null, 'All', Icons.apps),
              ...ParkingConstants.vehicleTypes.map((t) =>
                  _typeChip(t, ParkingConstants.label(t), vehicleIcon(t))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateButton(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 13, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String? value, String label, IconData icon) {
    final bool on = _vehicleType == value;
    return InkWell(
      onTap: () {
        setState(() => _vehicleType = value);
        _search(reset: true);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color:
              on ? AppColors.primary : AppColors.tint(AppColors.primary, 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? AppColors.primary : AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: on ? AppColors.onPrimary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: on ? AppColors.onPrimary : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _totals() {
    return Row(
      children: [
        Expanded(
          child: _statTile('Inside now', '$_stillInsideCount',
              AppColors.success, Icons.local_parking),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(
              'Matching', '$_totalMatching', AppColors.primary, Icons.list_alt),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile('Collected', money(_totalCollected),
              AppColors.amount, Icons.payments,
              numeric: _totalCollected ?? 0, isMoney: true),
        ),
      ],
    );
  }

  Widget _statTile(String label, String value, Color color, IconData icon,
      {double? numeric, bool isMoney = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          FittedBox(
            child: isMoney
                ? AnimatedCount(
                    value: numeric ?? 0,
                    format: (v) => money(v),
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  )
                : AnimatedCount(
                    value: numeric ?? 0,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
          ),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.directions_car_outlined,
                size: 44, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(
              _status == 'INSIDE'
                  ? 'No vehicles are inside right now.'
                  : 'No movements match these filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );

  Widget _movementCard(VehicleMovement r) {
    final df = DateFormat('dd MMM, hh:mm a');

    // Inside is green; a long stay is the row worth a second look; a
    // force-closed stay is a problem.
    final Color statusColor = r.stillInside
        ? (r.isLongStay ? AppColors.warning : AppColors.success)
        : (r.forceClosed ? AppColors.danger : AppColors.textSecondary);
    final String statusText = r.stillInside
        ? (r.isLongStay ? 'Long stay' : 'Inside')
        : (r.forceClosed ? 'Force closed' : 'Left');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: r.isLongStay
                  ? AppColors.warning.withOpacity(0.5)
                  : AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Silhouette first — shape is read before text when scanning.
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.tint(statusColor, 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(vehicleIcon(r.vehicleType),
                      color: statusColor, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: r.hasPlate ? 1.1 : 0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      // Ticket sits directly under the plate, as on the web —
                      // it is what the driver is holding and what a dispute is
                      // looked up by. Skipped when there is no plate, since the
                      // headline is already the ticket.
                      if (r.hasPlate && (r.ticketNumber ?? '').isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          r.ticketNumber!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        [
                          ParkingConstants.label(r.vehicleType),
                          if ((r.zoneName ?? '').isNotEmpty) r.zoneName!,
                          if (!r.hasPlate) 'ticket only',
                        ].where((e) => e.isNotEmpty).join(' · '),
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textFaint),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (r.stillInside) ...[
                        const LivePulse(color: AppColors.onPrimary, size: 6),
                        const SizedBox(width: 5),
                      ],
                      Text(statusText,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onPrimary)),
                    ],
                  ),
                ),
              ],
            ),
            Divider(color: AppColors.divider, height: 20),
            Row(
              children: [
                Expanded(
                  child: _stamp(
                      'In',
                      r.entryTime == null ? '—' : df.format(r.entryTime!),
                      r.entryLaneName,
                      Icons.login,
                      AppColors.primary),
                ),
                Expanded(
                  child: _stamp(
                      'Out',
                      r.exitTime != null
                          ? df.format(r.exitTime!)
                          // "still inside" says why there is no time; a dash
                          // reads as missing data.
                          : (r.stillInside ? 'still inside' : '—'),
                      r.exitLaneName,
                      Icons.logout,
                      AppColors.accent),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.timelapse, size: 14, color: AppColors.textFaint),
                const SizedBox(width: 5),
                Text(durationLabel(r.durationMinutes),
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: r.isLongStay
                            ? AppColors.warning
                            : AppColors.textPrimary)),
                const Spacer(),
                if ((r.amountPaid ?? 0) > 0) ...[
                  Text(money(r.amountPaid),
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.amount)),
                  if ((r.paymentMode ?? '').isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(ParkingConstants.label(r.paymentMode),
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ],
              ],
            ),
            if ((r.receiptNumber ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Receipt ${r.receiptNumber}',
                  style: TextStyle(fontSize: 11, color: AppColors.textFaint)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stamp(
      String label, String time, String? lane, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 3),
        Text(time,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        if ((lane ?? '').isNotEmpty)
          Text(lane!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _StatusOption {
  final String value;
  final String label;
  const _StatusOption(this.value, this.label);
}
