import 'dart:convert';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/parking/parking_context.dart';
import 'package:ajna/screens/parking/parking_lane_select_screen.dart';
import 'package:ajna/screens/parking/parking_models.dart';
import 'package:ajna/screens/parking/parking_widgets.dart';
import 'package:ajna/screens/util.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Cash shift for the attendant.
///
/// Every entry and exit carries the open `shiftId`, which is what ties the cash
/// taken at the barrier to a shift. Closing declares the cash counted; the
/// backend compares it against what it expected and flags a variance beyond the
/// site's tolerance.
class ParkingShiftScreen extends StatefulWidget {
  const ParkingShiftScreen({Key? key}) : super(key: key);

  @override
  State<ParkingShiftScreen> createState() => _ParkingShiftScreenState();
}

class _ParkingShiftScreenState extends State<ParkingShiftScreen> {
  final TextEditingController _floatController = TextEditingController();
  final TextEditingController _declaredController = TextEditingController();
  final TextEditingController _varianceReasonController =
      TextEditingController();

  bool _busy = true;

  /// Expected cash stays hidden until the operator has counted.
  ///
  /// A cashier who can see the figure can simply type it back, and the
  /// reconciliation then proves nothing. Revealing is a deliberate act.
  bool _revealExpected = false;
  String? _error;
  ShiftSummary? _shift;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _declaredController.dispose();
    _varianceReasonController.dispose();
    super.dispose();
  }

  Future<void> _changeLane() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ParkingLaneSelectScreen()),
    );
    if (changed == true && mounted) setState(() {});
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    await ParkingContext.refreshOpenShift();
    if (!mounted) return;
    setState(() {
      _shift = ParkingContext.openShift;
      _busy = false;
    });
  }

  Future<void> _open() async {
    if (ParkingContext.siteId == null) {
      setState(() => _error = 'Select the lane you are working first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final int? userId = await Util.getUserId();
      if (userId == null) {
        setState(() {
          _busy = false;
          _error = 'Could not identify the operator. Please log in again.';
        });
        return;
      }
      final response = await ApiService.parkingShiftOpen(
        siteId: ParkingContext.siteId!,
        operatorUserId: userId,
        laneId: ParkingContext.laneId,
        openingFloat: double.tryParse(_floatController.text.trim()),
      );
      if (!mounted) return;
      if (ApiService.isSuccess(response.statusCode)) {
        final shift = ShiftSummary.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
        ParkingContext.openShift = shift;
        setState(() {
          _shift = shift;
          _busy = false;
          _floatController.clear();
        });
      } else {
        setState(() {
          _busy = false;
          _error = 'Could not open the shift. Please try again.';
        });
        debugPrint(
            'Shift open failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Shift open error: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not reach the server. Please check your connection.';
      });
    }
  }

  Future<void> _close() async {
    final shift = _shift;
    if (shift?.shiftId == null) return;

    final declared = double.tryParse(_declaredController.text.trim());
    if (declared == null) {
      setState(() => _error = 'Enter the cash you counted.');
      return;
    }

    final expected = shift!.expectedCash ?? 0;

    final bool? go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Close shift?',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Declaring ${money(declared)} against ${money(expected)} expected.\n\n'
          'A closed shift cannot be reopened.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close shift',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (go != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await ApiService.parkingShiftClose(
        shiftId: shift.shiftId!,
        declaredCash: declared,
        varianceReason: _varianceReasonController.text.trim(),
      );
      if (!mounted) return;
      if (ApiService.isSuccess(response.statusCode)) {
        final closed = ShiftSummary.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
        ParkingContext.clearShift();
        setState(() {
          _shift = closed;
          _busy = false;
          _declaredController.clear();
          _varianceReasonController.clear();
          _revealExpected = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: const Text('Shift closed.',
                  style: TextStyle(color: AppColors.onPrimary)),
            ),
          );
        }
      } else {
        setState(() {
          _busy = false;
          _error = 'Could not close the shift. Please try again.';
        });
        debugPrint(
            'Shift close failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Shift close error: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not reach the server. Please check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: parkingAppBar('Cash Shift'),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _refresh,
        child: ContentWidthLimit(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              if (_busy && _shift == null)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (_shift?.isOpen == true)
                ..._openShiftViews(_shift!)
                    .asMap()
                    .entries
                    .map((e) => AnimatedEntry(index: e.key, child: e.value))
              else
                ..._noShiftViews()
                    .asMap()
                    .entries
                    .map((e) => AnimatedEntry(index: e.key, child: e.value)),
              if (_error != null) ...[
                const SizedBox(height: 14),
                ParkingBanner(
                    text: _error!,
                    color: AppColors.danger,
                    icon: Icons.error_outline),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _noShiftViews() {
    final closed = _shift;
    return [
      if (closed != null && closed.shiftStatus != null && !closed.isOpen) ...[
        ParkingCard(
          title: 'Last shift · ${ParkingConstants.label(closed.shiftStatus)}',
          child: Column(
            children: [
              KeyValueRow(label: 'Expected', value: money(closed.expectedCash)),
              KeyValueRow(label: 'Declared', value: money(closed.declaredCash)),
              KeyValueRow(
                label: 'Variance',
                value: money(closed.varianceAmount),
                valueColor: (closed.varianceAmount ?? 0).abs() > 0.009
                    ? AppColors.danger
                    : AppColors.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      ParkingBanner(
        text: 'No shift is open. Entry and exit still work, but the cash will '
            'not be tied to a shift.',
        color: AppColors.warning,
        icon: Icons.info_outline,
      ),
      const SizedBox(height: 14),
      LanePostingChip(onChange: _changeLane),
      const SizedBox(height: 14),
      ParkingCard(
        title: 'Open a shift',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _floatController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: AppColors.textPrimary),
              cursorColor: AppColors.primary,
              decoration: parkingFieldDecoration('Opening float (optional)'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _open,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor: AppColors.success.withOpacity(0.45),
                  disabledForegroundColor: AppColors.onPrimary.withOpacity(0.8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.play_arrow),
                label: Text(_busy ? 'Opening…' : 'Open Shift',
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onPrimary)),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: AppColors.onPrimary.withOpacity(0.8))),
        ],
      ),
    );
  }

  List<Widget> _openShiftViews(ShiftSummary s) {
    final df = DateFormat('dd MMM, hh:mm a');
    final declared = double.tryParse(_declaredController.text.trim());

    // Null check, NOT a falsy check. `expectedCash == 0` is a shift that took
    // no money — exactly the case where a surplus in the drawer matters most.
    // Hiding the line there would make an unrecorded collection invisible.
    final double? expected = s.expectedCash;
    final double? variance =
        (declared == null || expected == null) ? null : declared - expected;

    final bool canClose = declared != null && !_busy;

    return [
      // Counts only — no cash figure. The drawer total is what must be
      // arrived at independently.
      Container(
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
                    'Shift open since '
                    '${s.shiftStart == null ? "—" : df.format(s.shiftStart!)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _heroStat('Vehicles in', '${s.vehiclesAdmitted ?? 0}'),
                _heroStat('Vehicles out', '${s.vehiclesReleased ?? 0}'),
                _heroStat('Payments', '${s.paymentCount ?? 0}'),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      ParkingCard(
        title: 'End your shift',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeyValueRow(
                label: 'Started',
                value: s.shiftStart == null ? '—' : df.format(s.shiftStart!)),
            KeyValueRow(
                label: 'Lane', value: s.laneName ?? 'Not lane-specific'),
            KeyValueRow(label: 'Opening float', value: money(s.openingFloat)),
            KeyValueRow(
                label: 'Vehicles released',
                value: '${s.vehiclesReleased ?? 0}'),
            Divider(color: AppColors.divider, height: 24),

            Text('Cash counted in drawer',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _declaredController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
              cursorColor: AppColors.primary,
              decoration: parkingFieldDecoration('₹').copyWith(
                hintText: 'Count first, then enter',
                hintStyle: TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 14,
                    fontWeight: FontWeight.w400),
              ),
            ),
            const SizedBox(height: 12),

            // The expected figure stays hidden until asked for, so the count
            // is arrived at independently rather than copied.
            if (!_revealExpected)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _revealExpected = true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Show what the system expects'),
                  ),
                  const SizedBox(height: 6),
                  Text('Count the drawer before revealing this.',
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    KeyValueRow(
                        label: 'System expects', value: money(expected)),
                    if (variance != null)
                      KeyValueRow(
                        label: variance >= 0 ? 'Over by' : 'Short by',
                        value: money(variance.abs()),
                        emphasise: true,
                        valueColor: variance.abs() > 0.009
                            ? AppColors.danger
                            : AppColors.success,
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 14),
            TextFormField(
              controller: _varianceReasonController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: AppColors.textPrimary),
              cursorColor: AppColors.primary,
              decoration: parkingFieldDecoration('Reason for any difference'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: canClose ? _close : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor: AppColors.danger.withOpacity(0.35),
                  disabledForegroundColor: AppColors.onPrimary.withOpacity(0.7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(_busy ? 'Closing…' : 'Close Shift',
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
            ),
            if (declared == null && !_busy) ...[
              const SizedBox(height: 8),
              Text('Enter the cash you counted to close.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),

      ParkingCard(
        title: 'Collection so far',
        child: Column(
          children: [
            ...s.collectionByMode.entries.map((e) => KeyValueRow(
                  label: ParkingConstants.label(e.key),
                  value: money(e.value),
                )),
            if (s.collectionByMode.isNotEmpty)
              Divider(color: AppColors.divider, height: 18),
            KeyValueRow(label: 'Digital', value: money(s.digitalCollection)),
            KeyValueRow(label: 'Total', value: money(s.totalCollection)),
            KeyValueRow(label: 'Payments', value: '${s.paymentCount ?? 0}'),
            if ((s.exceptionCount ?? 0) > 0)
              KeyValueRow(
                  label: 'Exceptions',
                  value: '${s.exceptionCount}',
                  valueColor: AppColors.warning),
          ],
        ),
      ),
    ];
  }
}
