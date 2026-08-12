import 'dart:convert';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/parking/parking_context.dart';
import 'package:ajna/screens/parking/parking_lane_select_screen.dart';
import 'package:ajna/screens/parking/parking_models.dart';
import 'package:ajna/screens/parking/parking_scan_screen.dart';
import 'package:ajna/screens/parking/parking_shift_screen.dart';
import 'package:ajna/screens/parking/parking_widgets.dart';
import 'package:ajna/screens/util.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Vehicle exit — the POS. Quote the stay, take payment, release.
///
/// Mirrors the web `pos-exit` component. Two calls on purpose:
/// `GET /parking/exit/lookup` prices the stay and releases nothing, then
/// `POST /parking/exit/confirm` settles — "the operator reads the amount to the
/// driver, takes the money, and only then commits. Collapsing it into one
/// action would charge on every speculative scan."
enum _ExitStage { lookup, review, receipt }

class ParkingExitScreen extends StatefulWidget {
  const ParkingExitScreen({super.key});

  @override
  State<ParkingExitScreen> createState() => _ParkingExitScreenState();
}

class _ParkingExitScreenState extends State<ParkingExitScreen> {
  final _lookupKey = GlobalKey<FormState>();
  final TextEditingController _credentialController = TextEditingController();
  final TextEditingController _tenderedController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _waiveReasonController = TextEditingController();
  final TextEditingController _waiveAmountController = TextEditingController();
  final FocusNode _credentialFocus = FocusNode();

  _ExitStage _stage = _ExitStage.lookup;
  String _credentialType = ParkingConstants.channelTicket;
  String _paymentMode = ParkingConstants.payCash;
  bool _waiving = false;
  bool _busy = false;
  String? _error;

  ExitLookupResponse? _stay;
  ExitConfirmResponse? _receipt;

  // ── Shop validation, applied here at the barrier.
  //
  // The stamped bill is handed over HERE, with a queue behind it. Sending the
  // cashier to a separate screen to look the same ticket up again is how a
  // validation gets skipped and the customer charged in full — the shop gave
  // the discount and the site kept the money.
  final TextEditingController _billNumberController = TextEditingController();
  final TextEditingController _billAmountController = TextEditingController();
  List<ParkingMerchant> _merchants = [];
  int? _validationMerchantId;
  bool _showValidation = false;
  bool _validating = false;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    // A cashier without an open drawer cannot take money — refresh so the gate
    // below reflects reality rather than a stale flag.
    _refreshShift();
    _loadMerchants();
  }

  Future<void> _loadMerchants() async {
    if (ParkingContext.siteId == null) return;
    try {
      final response =
          await ApiService.getParkingMerchantsBySite(ParkingContext.siteId!);
      if (!mounted) return;
      if (ApiService.isSuccess(response.statusCode)) {
        final decoded = jsonDecode(response.body);
        final list = (decoded is List) ? decoded : (decoded['data'] ?? []);
        setState(() {
          _merchants = (list as List)
              .map((e) => ParkingMerchant.fromJson(e as Map<String, dynamic>))
              .where((m) => m.isActive)
              .toList();
        });
      } else {
        debugPrint('Merchants failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      // Validation is optional — never block the exit on it.
      debugPrint('Merchants error: $e');
    }
  }

  double get _validationDiscount => _stay?.validationDiscount ?? 0;

  bool get _canApplyValidation =>
      _validationMerchantId != null &&
      (_stay?.ticketNumber ?? '').isNotEmpty &&
      !_validating;

  /// Applies the shop's validation and re-quotes.
  ///
  /// Re-quoting rather than adjusting the figure on screen: the discount a shop
  /// gives is capped by its own rules and by what the stay actually came to, so
  /// only the server knows the real answer.
  Future<void> _applyValidation() async {
    if (!_canApplyValidation || ParkingContext.siteId == null) return;
    setState(() {
      _validating = true;
      _validationMessage = null;
    });
    try {
      final int? userId = await Util.getUserId();
      final response = await ApiService.parkingApplyValidation(
        siteId: ParkingContext.siteId!,
        merchantId: _validationMerchantId!,
        ticketNumber: _stay!.ticketNumber!,
        billNumber: _billNumberController.text,
        billAmount: double.tryParse(_billAmountController.text.trim()),
        validatedBy: userId,
      );
      if (!mounted) return;

      String message = 'Validation applied.';
      if (ApiService.isSuccess(response.statusCode)) {
        try {
          final v = ValidationResponse.fromJson(
              jsonDecode(response.body) as Map<String, dynamic>);
          message = v.message ?? message;
        } catch (_) {}
        setState(() {
          _validating = false;
          _showValidation = false;
          _validationMessage = message;
          _billNumberController.clear();
          _billAmountController.clear();
        });
        // The charge has changed, so the quote on screen is stale.
        _lookup();
      } else {
        debugPrint('Validation failed: HTTP ${response.statusCode} '
            '${response.body}');
        setState(() {
          _validating = false;
          _validationMessage = 'Could not apply the validation.';
        });
      }
    } catch (e) {
      debugPrint('Validation error: $e');
      if (!mounted) return;
      setState(() {
        _validating = false;
        _validationMessage = 'Could not apply the validation.';
      });
    }
  }

  @override
  void dispose() {
    _credentialController.dispose();
    _tenderedController.dispose();
    _referenceController.dispose();
    _waiveReasonController.dispose();
    _waiveAmountController.dispose();
    _billNumberController.dispose();
    _billAmountController.dispose();
    _credentialFocus.dispose();
    super.dispose();
  }

  Future<void> _refreshShift() async {
    await ParkingContext.refreshOpenShift();
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------- money ------

  double get _due => _stay?.netAmount ?? 0;

  /// Decided by the amount, as the web does — the freeExit / alreadyPaid flags
  /// are shown as banners but a zero bill is what skips payment.
  bool get _nothingToCollect => _due <= 0;

  double get _tendered => double.tryParse(_tenderedController.text.trim()) ?? 0;

  double? get _waiveAmount {
    final raw = _waiveAmountController.text.trim();
    if (raw.isEmpty) return null; // absent means the whole charge
    return double.tryParse(raw);
  }

  /// What is still owed once the waiver is applied — zero for a full waiver.
  double get _remainingAfterWaiver {
    if (!_waiving) return _due;
    final waived = _waiveAmount ?? _due;
    final left = _due - waived;
    return left > 0 ? double.parse(left.toStringAsFixed(2)) : 0;
  }

  /// Waiving more than the stay came to would hand back money never charged.
  bool get _waiverTooLarge => _waiving && (_waiveAmount ?? 0) > _due;

  double get _change {
    if (_paymentMode != ParkingConstants.payCash) return 0;
    final owed = _waiving ? _remainingAfterWaiver : _due;
    final diff = _tendered - owed;
    return diff > 0 ? diff : 0;
  }

  bool get _hasOpenShift => ParkingContext.hasOpenShift;

  /// The web's `canSettle`, ported exactly.
  bool get _canSettle {
    final stay = _stay;
    if (stay == null || !stay.found || _busy) return false;

    // Money must land in an open drawer. A free exit still closes the stay, so
    // it is allowed — nothing is being collected.
    if (!_hasOpenShift && !_nothingToCollect) return false;

    if (_waiving) {
      if (_waiveReasonController.text.trim().isEmpty) return false;
      final waived = _waiveAmount ?? _due;
      if (waived <= 0 || waived > _due) return false;
      // A partial waiver still leaves money to collect, so it needs a drawer
      // and enough tendered.
      if (_remainingAfterWaiver > 0) {
        return _hasOpenShift && _tendered >= _remainingAfterWaiver;
      }
      return true;
    }
    if (_nothingToCollect) return true;
    return _tendered >= _due;
  }

  /// Quick cash buttons — the notes an Indian customer actually hands over.
  List<double> get _quickTenders {
    final owed = _waiving ? _remainingAfterWaiver : _due;
    final notes = <double>[owed, 50, 100, 200, 500, 2000];
    final seen = <String>{};
    final out = <double>[];
    for (final n in notes) {
      if (n < owed) continue;
      final key = n.toStringAsFixed(2);
      if (seen.add(key)) out.add(n);
      if (out.length == 5) break;
    }
    return out;
  }

  // ------------------------------------------------------------ actions -----

  Future<void> _changeLane() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ParkingLaneSelectScreen(
            requiredDirection: ParkingConstants.laneDirectionOut),
      ),
    );
    if (changed == true && mounted) setState(() {});
  }

  Future<void> _openShiftScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ParkingShiftScreen()),
    );
    await _refreshShift();
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ParkingScanScreen()),
    );
    if (code != null && code.isNotEmpty && mounted) {
      _credentialController.text = code;
      setState(() => _credentialType = ParkingConstants.channelTicket);
      _lookup();
    }
  }

  Future<void> _lookup() async {
    if (!(_lookupKey.currentState?.validate() ?? false)) return;
    if (ParkingContext.siteId == null) {
      setState(() => _error = 'Select the lane you are working first.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _receipt = null;
    });

    try {
      final response = await ApiService.parkingExitLookup(
        siteId: ParkingContext.siteId!,
        credentialType: _credentialType,
        credentialValue: _credentialController.text.trim(),
      );
      if (!mounted) return;

      if (ApiService.isSuccess(response.statusCode)) {
        final stay = ExitLookupResponse.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
        if (!stay.found) {
          setState(() {
            _busy = false;
            _error = stay.message ?? 'No open stay found for that ticket.';
          });
          return;
        }
        setState(() {
          _busy = false;
          _stay = stay;
          _stage = _ExitStage.review;
          _paymentMode = ParkingConstants.payCash;
          _waiving = false;
          _waiveReasonController.clear();
          _waiveAmountController.clear();
          _referenceController.clear();
          // Pre-fill the exact amount so a card or UPI payment needs no typing;
          // cash is the only mode where the operator changes it.
          final net = stay.netAmount ?? 0;
          _tenderedController.text = net <= 0 ? '' : net.toStringAsFixed(2);
        });
      } else {
        debugPrint(
            'Exit lookup failed: HTTP ${response.statusCode} ${response.body}');
        setState(() {
          _busy = false;
          _error = 'Could not look that stay up. Please try again.';
        });
      }
    } catch (e) {
      debugPrint('Exit lookup error: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not reach the server. Please check your connection.';
      });
    }
  }

  Future<void> _settle() async {
    final stay = _stay;
    if (stay?.sessionId == null || !_canSettle) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final int? operatorId = await Util.getUserId();
      final response = await ApiService.parkingExitConfirm(
        sessionId: stay!.sessionId!,
        exitLaneId: ParkingContext.laneId,
        operatorId: operatorId,
        // Binds the payment to this operator's drawer so it can be reconciled
        // at shift close.
        shiftId: ParkingContext.openShift?.shiftId,
        paymentMode: _nothingToCollect ? null : _paymentMode,
        tenderedAmount: _nothingToCollect ? null : _tendered,
        referenceNo: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        waive: _waiving,
        waiveReason: _waiving ? _waiveReasonController.text.trim() : null,
        // Absent means the whole charge, which is what most waivers are.
        waiveAmount: _waiving ? _waiveAmount : null,
        approvedBy: _waiving ? operatorId : null,
      );
      if (!mounted) return;

      if (ApiService.isSuccess(response.statusCode)) {
        final receipt = ExitConfirmResponse.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
        setState(() {
          _busy = false;
          if (receipt.released) {
            _receipt = receipt;
            _stay = null;
            _stage = _ExitStage.receipt;
          } else {
            _error = receipt.message ?? 'The vehicle was not released.';
          }
        });
        await _refreshShift();
      } else {
        debugPrint(
            'Exit confirm failed: HTTP ${response.statusCode} ${response.body}');
        setState(() {
          _busy = false;
          _error = 'Could not settle that stay. Please try again.';
        });
      }
    } catch (e) {
      debugPrint('Exit confirm error: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not reach the server. Please check your connection.';
      });
    }
  }

  void _nextVehicle() {
    _credentialController.clear();
    _tenderedController.clear();
    _referenceController.clear();
    _waiveReasonController.clear();
    _waiveAmountController.clear();
    setState(() {
      _stage = _ExitStage.lookup;
      _stay = null;
      _receipt = null;
      _error = null;
      _waiving = false;
      _paymentMode = ParkingConstants.payCash;
      _credentialType = ParkingConstants.channelTicket;
      _showValidation = false;
      _validationMerchantId = null;
      _validationMessage = null;
    });
    _billNumberController.clear();
    _billAmountController.clear();
    _credentialFocus.requestFocus();
  }

  // -------------------------------------------------------------- build -----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: parkingAppBar('Vehicle Exit'),
      body: ContentWidthLimit(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: switch (_stage) {
            _ExitStage.lookup => _lookupForm(),
            _ExitStage.review => AnimatedEntry(
                key: ValueKey('review-${_stay!.sessionId}'),
                child: _reviewView(_stay!)),
            _ExitStage.receipt => AnimatedEntry(
                key: ValueKey('receipt-${_receipt!.receiptNumber}'),
                child: _receiptView(_receipt!)),
          },
        ),
      ),
    );
  }

  /// The drawer warning. Shown on both stages — an operator should know before
  /// they quote, not after the driver is waiting.
  Widget _shiftGate() {
    if (_hasOpenShift) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openShiftScreen,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'No shift open — you can quote, but not take money. '
                    'Tap to open your drawer.',
                    style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 13, color: AppColors.warning),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lookupForm() {
    return Form(
      key: _lookupKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LanePostingChip(onChange: _changeLane),
          const SizedBox(height: 14),
          _shiftGate(),
          SizedBox(
            height: 58,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _scan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.qr_code_scanner, size: 24),
              label: const Text('Scan Ticket',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: Divider(color: AppColors.divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('or enter manually',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
            Expanded(child: Divider(color: AppColors.divider)),
          ]),
          const SizedBox(height: 14),
          ParkingCard(
            title: 'Find the stay',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChoiceChipRow(
                  values: ParkingConstants.exitChannels,
                  selected: _credentialType,
                  onChanged: (v) => setState(() {
                    _credentialType = v;
                    _credentialController.clear();
                    _error = null;
                  }),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _credentialController,
                  focusNode: _credentialFocus,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _busy ? null : _lookup(),
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                    LengthLimitingTextInputFormatter(32),
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                  cursorColor: AppColors.primary,
                  decoration: parkingFieldDecoration(_credentialLabel),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter the ${_credentialLabel.toLowerCase()}'
                      : null,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            ParkingBanner(
                text: _error!,
                color: AppColors.danger,
                icon: Icons.error_outline),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _lookup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.45),
                disabledForegroundColor: AppColors.onPrimary.withOpacity(0.8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onPrimary))
                  : const Icon(Icons.search),
              label: Text(_busy ? 'Looking up…' : 'Look Up',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  String get _credentialLabel {
    switch (_credentialType) {
      case ParkingConstants.channelManual:
        return 'Vehicle number';
      case ParkingConstants.channelPass:
        return 'Pass number';
      case ParkingConstants.channelFastag:
        return 'FASTag / tag id';
      default:
        return 'Ticket number';
    }
  }

  // ------------------------------------------------------------- review -----

  Widget _reviewView(ExitLookupResponse s) {
    final df = DateFormat('dd MMM, hh:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _shiftGate(),

        // ── The amount, big. This is the number read out to the driver.
        Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.heroGradient,
              stops: AppColors.heroStops,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.heroShadow.withOpacity(0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(vehicleIcon(s.vehicleType),
                  color: AppColors.onPrimary.withOpacity(0.9), size: 30),
              const SizedBox(height: 8),
              Text(
                s.displayPlateNumber ?? s.plateNumber ?? '—',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${ParkingConstants.label(s.vehicleType)} · '
                '${durationLabel(s.durationMinutes)}',
                style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.onPrimary.withOpacity(0.85)),
              ),
              const SizedBox(height: 14),
              Text(
                _nothingToCollect ? 'No charge' : money(s.netAmount),
                style: TextStyle(
                  fontSize: 40,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        ParkingCard(
          title: 'Stay',
          child: Column(
            children: [
              KeyValueRow(label: 'Ticket', value: s.ticketNumber ?? '—'),
              KeyValueRow(
                  label: 'Category',
                  value: ParkingConstants.label(s.sessionType)),
              KeyValueRow(label: 'Level', value: s.zoneName ?? '—'),
              KeyValueRow(
                  label: 'Entry',
                  value: s.entryTime == null ? '—' : df.format(s.entryTime!)),
              KeyValueRow(
                  label: 'Exit',
                  value: s.exitTime == null ? '—' : df.format(s.exitTime!)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        ParkingCard(
          title: 'Charge${s.tariffName == null ? "" : " · ${s.tariffName}"}',
          child: Column(
            children: [
              ...s.breakdown.map((b) => KeyValueRow(
                    label: b.description ?? '—',
                    value: money(b.amount),
                  )),
              if (s.breakdown.isNotEmpty)
                Divider(color: AppColors.divider, height: 18),
              KeyValueRow(label: 'Gross', value: money(s.grossAmount)),
              if ((s.validationDiscount ?? 0) > 0)
                KeyValueRow(
                    label: 'Merchant discount',
                    value: '- ${money(s.validationDiscount)}',
                    valueColor: AppColors.success),
              if ((s.penaltyAmount ?? 0) > 0)
                KeyValueRow(
                    label: 'Penalty',
                    value: money(s.penaltyAmount),
                    valueColor: AppColors.danger),
              if ((s.taxAmount ?? 0) > 0)
                KeyValueRow(
                    label:
                        'Tax${s.taxRate == null ? "" : " (${s.taxRate!.toStringAsFixed(0)}%)"}',
                    value: money(s.taxAmount)),
              Divider(color: AppColors.divider, height: 18),
              KeyValueRow(
                label: 'Amount due',
                value: _nothingToCollect ? 'No charge' : money(s.netAmount),
                emphasise: true,
                valueColor:
                    _nothingToCollect ? AppColors.success : AppColors.primary,
              ),
            ],
          ),
        ),

        if (s.alreadyPaid) ...[
          const SizedBox(height: 12),
          const ParkingBanner(
              text: 'Already paid — nothing to collect.',
              color: AppColors.success,
              icon: Icons.verified),
        ],
        // WHY this stay costs nothing. Three reasons are correct; the fourth —
        // no tariff covering the stay — is the mall giving the stay away by
        // accident, and must not look like a benefit.
        if (s.freeReason.isNotEmpty) ...[
          const SizedBox(height: 12),
          ParkingBanner(
            text: s.freeReason,
            color:
                s.freeForTheWrongReason ? AppColors.danger : AppColors.success,
            icon: s.freeForTheWrongReason
                ? Icons.report_problem
                : (s.withinGrace ? Icons.timer : Icons.verified),
          ),
        ],
        if (s.withinGrace && s.graceRemainingMinutes != null) ...[
          const SizedBox(height: 10),
          ParkingBanner(
              text: '${s.graceRemainingMinutes} min of grace left.',
              color: AppColors.primary,
              icon: Icons.timer_outlined),
        ],
        ...s.warnings.map((w) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ParkingBanner(
                  text: w,
                  color: AppColors.warning,
                  icon: Icons.warning_amber_rounded),
            )),

        // Nothing left to validate once the money has been taken — offering it
        // there only invites a discount that can no longer be applied.
        if (_merchants.isNotEmpty && !s.alreadyPaid) ...[
          const SizedBox(height: 14),
          _validationCard(),
        ],
        if (!_nothingToCollect) ...[
          const SizedBox(height: 14),
          _paymentCard(),
        ],

        if (_error != null) ...[
          const SizedBox(height: 14),
          ParkingBanner(
              text: _error!,
              color: AppColors.danger,
              icon: Icons.error_outline),
        ],

        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: _busy ? null : _nextVehicle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: (_busy || !_canSettle) ? null : _settle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.onPrimary,
                    disabledBackgroundColor:
                        AppColors.success.withOpacity(0.35),
                    disabledForegroundColor:
                        AppColors.onPrimary.withOpacity(0.7),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.onPrimary))
                      : const Icon(Icons.logout),
                  label: Text(
                    _busy
                        ? 'Releasing…'
                        : (_nothingToCollect || _remainingAfterWaiver <= 0
                            ? 'RELEASE'
                            : 'COLLECT & RELEASE'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (!_canSettle && !_busy) ...[
          const SizedBox(height: 8),
          Text(
            _settleBlockedReason(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.danger),
          ),
        ],
      ],
    );
  }

  String _settleBlockedReason() {
    if (!_hasOpenShift && !_nothingToCollect) {
      return 'Open a shift before taking money.';
    }
    if (_waiving) {
      if (_waiveReasonController.text.trim().isEmpty) {
        return 'A waiver needs a reason.';
      }
      if (_waiverTooLarge) {
        return 'Cannot waive more than ${money(_due)}.';
      }
      if ((_waiveAmount ?? _due) <= 0) return 'Enter the amount to waive.';
      if (_remainingAfterWaiver > 0 && _tendered < _remainingAfterWaiver) {
        return 'Still ${money(_remainingAfterWaiver)} to collect.';
      }
      return '';
    }
    if (!_nothingToCollect && _tendered < _due) {
      return 'Cash received is less than ${money(_due)}.';
    }
    return '';
  }

  Widget _validationCard() {
    return ParkingCard(
      title: 'Shop validation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_validationDiscount > 0)
            KeyValueRow(
              label: 'Already applied',
              value: '- ${money(_validationDiscount)}',
              valueColor: AppColors.success,
            ),
          if (_validationMessage != null) ...[
            const SizedBox(height: 8),
            ParkingBanner(
                text: _validationMessage!,
                color: AppColors.success,
                icon: Icons.verified),
          ],
          if (!_showValidation) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => setState(() => _showValidation = true),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.local_offer_outlined, size: 18),
              label: const Text('Apply a shop validation'),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text('Validating shop',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _merchants.map((m) {
                final bool on = m.merchantId == _validationMerchantId;
                return InkWell(
                  onTap: () =>
                      setState(() => _validationMerchantId = m.merchantId),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: on
                          ? AppColors.primary
                          : AppColors.tint(AppColors.primary, 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: on ? AppColors.primary : AppColors.divider),
                    ),
                    child: Text(m.shopName ?? 'Shop ${m.merchantId}',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: on
                                ? AppColors.onPrimary
                                : AppColors.textPrimary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _billNumberController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [UpperCaseTextFormatter()],
                    style: TextStyle(color: AppColors.textPrimary),
                    cursorColor: AppColors.primary,
                    decoration: parkingFieldDecoration('Bill no.'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _billAmountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: AppColors.textPrimary),
                    cursorColor: AppColors.primary,
                    decoration: parkingFieldDecoration('Bill amount'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _validating
                        ? null
                        : () => setState(() => _showValidation = false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_canApplyValidation && !_validating)
                        ? _applyValidation
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      disabledBackgroundColor:
                          AppColors.primary.withOpacity(0.35),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(_validating ? 'Applying…' : 'Apply'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentCard() {
    final bool cash = _paymentMode == ParkingConstants.payCash;
    final double owed = _waiving ? _remainingAfterWaiver : _due;

    return ParkingCard(
      title: 'Payment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoiceChipRow(
            values: ParkingConstants.paymentModes,
            selected: _paymentMode,
            onChanged: (v) => setState(() {
              _paymentMode = v;
              // Card/UPI take the exact amount; only cash gets edited.
              if (v != ParkingConstants.payCash) {
                _tenderedController.text = owed.toStringAsFixed(2);
              }
              _error = null;
            }),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _tenderedController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w700),
            cursorColor: AppColors.primary,
            decoration: parkingFieldDecoration(
                cash ? 'Cash received' : 'Amount charged'),
          ),
          if (cash) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickTenders
                  .map((t) => InkWell(
                        onTap: () => setState(() =>
                            _tenderedController.text = t.toStringAsFixed(2)),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.tint(AppColors.primary, 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Text('₹${t.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            KeyValueRow(
              label: 'Change to return',
              value: money(_change),
              emphasise: true,
              valueColor:
                  _change > 0 ? AppColors.amount : AppColors.textSecondary,
            ),
          ],
          if (!cash) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _referenceController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              style: TextStyle(color: AppColors.textPrimary),
              cursorColor: AppColors.primary,
              decoration: parkingFieldDecoration(
                  ParkingConstants.referenceLabel(_paymentMode)),
            ),
          ],
          Divider(color: AppColors.divider, height: 26),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _waiving,
            activeColor: AppColors.warning,
            onChanged: (v) => setState(() {
              _waiving = v;
              _error = null;
              if (!v) {
                _waiveReasonController.clear();
                _waiveAmountController.clear();
                _tenderedController.text = _due.toStringAsFixed(2);
              }
            }),
            title: Text('Waive part or all of the charge',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            subtitle: Text(
                'Leave the amount blank to waive the whole ${money(_due)}',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          if (_waiving) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _waiveAmountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: AppColors.textPrimary),
                    cursorColor: AppColors.primary,
                    decoration:
                        parkingFieldDecoration('Amount to waive (optional)'),
                  ),
                ),
                const SizedBox(width: 10),
                // "All" fills the whole charge — the common case, and faster
                // than typing it while a driver waits.
                SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: () => setState(() =>
                        _waiveAmountController.text = _due.toStringAsFixed(2)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('All',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            if (_waiverTooLarge) ...[
              const SizedBox(height: 8),
              Text('Cannot waive more than ${money(_due)}.',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger)),
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: _waiveReasonController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: AppColors.textPrimary),
              cursorColor: AppColors.primary,
              decoration: parkingFieldDecoration('Reason for waiver'),
            ),
            const SizedBox(height: 10),
            KeyValueRow(
              label: 'Still to collect',
              value: money(_remainingAfterWaiver),
              emphasise: true,
              valueColor: _remainingAfterWaiver > 0
                  ? AppColors.amount
                  : AppColors.success,
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------ receipt -----

  Widget _receiptView(ExitConfirmResponse r) {
    final df = DateFormat('dd MMM, hh:mm a');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ParkingBanner(
            text: 'Vehicle released',
            color: AppColors.success,
            icon: Icons.check_circle),
        const SizedBox(height: 14),
        if ((r.changeAmount ?? 0) > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.amount, 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.amount.withOpacity(0.4)),
            ),
            child: Column(
              children: [
                Text('RETURN CHANGE',
                    style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amount)),
                const SizedBox(height: 4),
                Text(money(r.changeAmount),
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.amount)),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        ParkingCard(
          title: 'Receipt',
          child: Column(
            children: [
              Text(r.receiptNumber ?? '—',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(height: 12),
              KeyValueRow(label: 'Vehicle', value: r.plateNumber ?? '—'),
              KeyValueRow(label: 'Ticket', value: r.ticketNumber ?? '—'),
              KeyValueRow(
                  label: 'Entry',
                  value: r.entryTime == null ? '—' : df.format(r.entryTime!)),
              KeyValueRow(
                  label: 'Exit',
                  value: r.exitTime == null ? '—' : df.format(r.exitTime!)),
              KeyValueRow(
                  label: 'Duration', value: durationLabel(r.durationMinutes)),
              Divider(color: AppColors.divider, height: 18),
              KeyValueRow(
                  label: 'Mode', value: ParkingConstants.label(r.paymentMode)),
              if ((r.taxAmount ?? 0) > 0)
                KeyValueRow(label: 'Tax', value: money(r.taxAmount)),
              KeyValueRow(
                  label: 'Paid', value: money(r.netAmount), emphasise: true),
              if ((r.waivedAmount ?? 0) > 0)
                KeyValueRow(
                    label: 'Waived',
                    value: money(r.waivedAmount),
                    valueColor: AppColors.warning),
              if ((r.tenderedAmount ?? 0) > 0)
                KeyValueRow(label: 'Tendered', value: money(r.tenderedAmount)),
              if ((r.gstin ?? '').isNotEmpty)
                KeyValueRow(label: 'GSTIN', value: r.gstin!),
            ],
          ),
        ),
        if (r.exitGraceMinutes != null) ...[
          const SizedBox(height: 12),
          ParkingBanner(
              text: 'Vehicle must leave within ${r.exitGraceMinutes} minutes.',
              color: AppColors.primary,
              icon: Icons.timer_outlined),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _nextVehicle,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Next vehicle',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
