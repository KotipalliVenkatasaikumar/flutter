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
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Vehicle entry — admit a vehicle and issue its ticket.
///
/// Mirrors the web lane-entry screen (`building-reality-ui`
/// `Components/FacilityManagement/Parking/lane-entry`) feature for feature:
/// live level board, "send to level" choice, lane-filtered channels, capacity
/// override with a reason. Only the *setup* side (creating sites, zones, lanes,
/// tariffs) stays web-only.
///
/// `POST /parking/session/entry`. The lane is mandatory. For a normal public
/// vehicle the attendant types the plate (credentialType MANUAL) — the ticket is
/// *issued by* this call, so there is nothing to scan on the way in.
class ParkingEntryScreen extends StatefulWidget {
  const ParkingEntryScreen({super.key});

  @override
  State<ParkingEntryScreen> createState() => _ParkingEntryScreenState();
}

class _ParkingEntryScreenState extends State<ParkingEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _credentialController = TextEditingController();
  final TextEditingController _overrideReasonController =
      TextEditingController();

  /// The plate the guard is actually looking at.
  ///
  /// For a pass or tag the credential is the pass number, which says nothing
  /// about the car in front of them. Taking the plate as well is what ties the
  /// two together: a pass quoted for someone else's vehicle is still admitted,
  /// but charged as a normal visitor.
  final TextEditingController _vehicleNumberController =
      TextEditingController();

  /// A scanner types into whatever holds focus, so focus returns to the field
  /// after every vehicle — otherwise the operator must tap before each scan.
  final FocusNode _credentialFocus = FocusNode();

  String _credentialType = ParkingConstants.channelManual;
  String _vehicleType = ParkingConstants.vehicleFourWheeler;
  int? _selectedZoneId;

  bool _submitting = false;
  bool _loadingZones = true;

  /// Armed only after a capacity refusal — a blacklisted or duplicate vehicle
  /// is not something an attendant should be able to wave through.
  bool _showOverride = false;

  List<ZoneOccupancy> _zones = [];
  SessionEntryResponse? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Most lanes serve one kind of vehicle, so start on the lane's configured
    // default and let the attendant change it only when it differs.
    final String? laneDefault = ParkingContext.laneDefaultVehicleType;
    if (laneDefault != null &&
        ParkingConstants.vehicleTypes.contains(laneDefault)) {
      _vehicleType = laneDefault;
    }
    // Offer only channels the lane has hardware for.
    final channels = ParkingContext.entryChannels;
    if (!channels.contains(_credentialType)) {
      _credentialType = channels.contains(ParkingConstants.channelManual)
          ? ParkingConstants.channelManual
          : channels.first;
    }
    _loadOccupancy();
  }

  @override
  void dispose() {
    _credentialController.dispose();
    _overrideReasonController.dispose();
    _vehicleNumberController.dispose();
    _credentialFocus.dispose();
    super.dispose();
  }

  String get _credentialLabel {
    switch (_credentialType) {
      case ParkingConstants.channelPass:
        return 'Pass number';
      case ParkingConstants.channelFastag:
        return 'FASTag / tag id';
      default:
        return 'Registration number';
    }
  }

  /// The board on the wall changes as other lanes admit vehicles, so this is
  /// re-read after every admit rather than only on open.
  Future<void> _loadOccupancy() async {
    if (ParkingContext.siteId == null) {
      setState(() => _loadingZones = false);
      return;
    }
    try {
      final response =
          await ApiService.getParkingOccupancyBySite(ParkingContext.siteId!);
      if (!mounted) return;
      if (ApiService.isSuccess(response.statusCode)) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final zones = decoded
              .map((e) => ZoneOccupancy.fromJson(e as Map<String, dynamic>))
              .toList();
          setState(() {
            _zones = zones;
            _loadingZones = false;
            // Drop a level that no longer takes this vehicle type.
            if (_selectedZoneId != null &&
                !zones.any((z) =>
                    z.zoneId == _selectedZoneId && z.takes(_vehicleType))) {
              _selectedZoneId = null;
            }
          });
          return;
        }
      }
      debugPrint('Occupancy failed: HTTP ${response.statusCode}');
      setState(() => _loadingZones = false);
    } catch (e) {
      debugPrint('Occupancy error: $e');
      if (mounted) setState(() => _loadingZones = false);
    }
  }

  /// Free bays per vehicle type across the levels this lane can send to.
  ///
  /// When the lane owns a zone the count is that zone's; otherwise it is the
  /// whole site's, which is what the operator is choosing between.
  Map<String, String> _freeByType() {
    if (_zones.isEmpty) return const {};
    final List<ZoneOccupancy> scope = ParkingContext.needsZoneChoice
        ? _zones
        : _zones.where((z) => z.zoneId == ParkingContext.zoneId).toList();
    if (scope.isEmpty) return const {};

    final Map<String, String> out = {};
    for (final t in ParkingConstants.vehicleTypes) {
      int free = 0;
      bool anyKnown = false;
      for (final z in scope) {
        if (z.typeStatus(t) != null || z.byVehicleType.isEmpty) {
          anyKnown = true;
          free += z.freeFor(t);
        }
      }
      if (anyKnown) out[t] = free <= 0 ? 'full' : '$free free';
    }
    return out;
  }

  /// Levels that can still take the vehicle type currently selected.
  List<ZoneOccupancy> get _levelsWithRoom =>
      _zones.where((z) => z.takes(_vehicleType)).toList();

  /// The chosen level cannot take this vehicle.
  ///
  /// Reached two ways, and both matter: the guard picks a level that was
  /// already full, or the level they picked fills up while they are working.
  /// Nothing used to say so until the server refused the admission, by which
  /// point the driver is at the barrier.
  bool get _selectedLevelIsFull {
    if (_selectedZoneId == null) return false;
    for (final z in _zones) {
      if (z.zoneId == _selectedZoneId) return !z.takes(_vehicleType);
    }
    return false;
  }

  /// Redirects to a level that has space.
  void _sendTo(ZoneOccupancy zone) {
    setState(() {
      _selectedZoneId = zone.zoneId;
      _error = null;
    });
  }

  Future<void> _changeLane() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ParkingLaneSelectScreen(
            requiredDirection: ParkingConstants.laneDirectionIn),
      ),
    );
    if (changed == true && mounted) {
      setState(() {
        _selectedZoneId = null;
        _loadingZones = true;
      });
      _loadOccupancy();
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!ParkingContext.hasLane) {
      setState(() => _error = 'Select the lane you are working first.');
      return;
    }
    // Without a level the stay is recorded against no zone and that zone's
    // occupancy never moves — the same guard the web screen applies.
    if (ParkingContext.needsZoneChoice && _selectedZoneId == null) {
      setState(() => _error =
          'Choose the level first — this lane serves the whole site, so the '
              'stay would otherwise be recorded against no zone.');
      return;
    }
    // The override applies when the guard has been offered it — either after a
    // refusal, or because they deliberately chose a level with no room. Keying
    // it to the refusal alone meant a deliberate choice was refused, then had
    // to be repeated.
    final bool offered = _showOverride || _selectedLevelIsFull;
    final bool overriding =
        offered && _overrideReasonController.text.trim().isNotEmpty;
    if (offered && !overriding) {
      setState(() => _error = 'Give a reason before admitting over capacity.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final int? operatorId = await Util.getUserId();
      final response = await ApiService.parkingSessionEntry(
        laneId: ParkingContext.laneId!,
        // Sent only when the lane has no zone of its own; the server ignores
        // it otherwise (the lane's zone always wins).
        zoneId: ParkingContext.needsZoneChoice ? _selectedZoneId : null,
        credentialType: _credentialType,
        credentialValue: _credentialController.text.trim(),
        vehicleType: _vehicleType,
        // MANUAL already puts the plate in credentialValue — sending it twice
        // would just be the same string in two fields.
        vehicleNumber: _credentialType == ParkingConstants.channelManual
            ? null
            : _vehicleNumberController.text.trim(),
        operatorId: operatorId,
        shiftId: ParkingContext.openShift?.shiftId,
        overrideCapacity: overriding,
        overrideReason:
            overriding ? _overrideReasonController.text.trim() : null,
      );

      if (!mounted) return;

      if (ApiService.isSuccess(response.statusCode)) {
        final entry = SessionEntryResponse.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
        setState(() {
          _submitting = false;
          if (entry.admitted) {
            _result = entry;
            _showOverride = false;
            _overrideReasonController.clear();
          } else {
            _error = entry.rejectionReason ?? 'The vehicle was not admitted.';
            _showOverride =
                (entry.rejectionReason ?? '').toLowerCase().contains('full');
          }
        });
        _loadOccupancy();
      } else {
        debugPrint(
            'Entry failed: HTTP ${response.statusCode} ${response.body}');
        setState(() {
          _submitting = false;
          _error = 'Could not admit the vehicle. Please try again.';
        });
      }
    } catch (e) {
      debugPrint('Entry error: $e');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error =
            'Could not reach the server. Use the manual log and sync later.';
      });
    }
  }

  void _clear() {
    _credentialController.clear();
    _overrideReasonController.clear();
    _vehicleNumberController.clear();
    setState(() {
      _result = null;
      _error = null;
      _showOverride = false;
    });
    _credentialFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: parkingAppBar('Vehicle Entry', actions: [
        IconButton(
          tooltip: 'Refresh levels',
          icon: const Icon(Icons.refresh, color: AppColors.onPrimary),
          onPressed: _loadOccupancy,
        ),
      ]),
      body: ContentWidthLimit(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: _result != null ? _ticketView(_result!) : _entryForm(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- form ----

  Widget _entryForm() {
    final bool needsZone = ParkingContext.needsZoneChoice;
    final List<String> channels = ParkingContext.entryChannels;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LanePostingChip(onChange: _changeLane),
          const SizedBox(height: 14),

          // ── Live level board, same information as the web's B1/B2 panels.
          if (_loadingZones)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_zones.isNotEmpty) ...[
            ParkingCard(
              title: 'Levels · live',
              child: Column(
                children:
                    _zones.map((z) => _occupancyRow(z)).toList(growable: false),
              ),
            ),
            const SizedBox(height: 14),
          ],

          ParkingCard(
            title: 'Vehicle type',
            child: VehicleTypePicker(
              selected: _vehicleType,
              // Free counts are per type, so show them on the control that
              // picks the type rather than making the operator cross-reference
              // the board above.
              badges: _freeByType(),
              onChanged: (v) => setState(() {
                _vehicleType = v;
                // Free counts are per type, so a level chosen for a car may not
                // take the bike now in front of the barrier.
                _error = null;
              }),
            ),
          ),

          if (needsZone) ...[
            const SizedBox(height: 14),
            ParkingCard(
              title: 'Send to level',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_zones.isEmpty)
                    Text('No levels configured for this site.',
                        style: TextStyle(color: AppColors.textSecondary))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _zones.map(_levelChip).toList(),
                    ),
                  if (_selectedZoneId == null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Choose the level before admitting — otherwise this stay '
                      'counts against no zone.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                  // A full level stays selectable on purpose: sometimes the
                  // right answer is to put the car there anyway, and that is
                  // what the override is for. But the guard has to know before
                  // the driver is at the barrier, not after the server refuses.
                  if (_selectedLevelIsFull) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.warning.withOpacity(0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: AppColors.warning, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This level has no room for a '
                                  '${ParkingConstants.label(_vehicleType).toLowerCase()}.',
                                  style: const TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_levelsWithRoom.isNotEmpty) ...[
                            Text('Send them to:',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            // Every level with room, each with its free count —
                            // the guard picks, rather than being given one.
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _levelsWithRoom
                                  .map((z) => OutlinedButton(
                                        onPressed: () => _sendTo(z),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          side: const BorderSide(
                                              color: AppColors.primary),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          minimumSize: const Size(0, 36),
                                        ),
                                        child: Text(
                                          '${z.displayName ?? z.zoneName ?? "Level"} '
                                          '(${z.freeFor(_vehicleType)})',
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 6),
                            Text('…or admit here with a reason below.',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary)),
                          ] else
                            Text(
                              'No level can take this vehicle. Admitting needs '
                              'a reason below.',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          ParkingCard(
            title: 'Identify the vehicle',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (channels.length > 1) ...[
                  ChoiceChipRow(
                    values: channels,
                    selected: _credentialType,
                    onChanged: (v) => setState(() {
                      _credentialType = v;
                      _credentialController.clear();
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _credentialController,
                  focusNode: _credentialFocus,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submitting ? null : _submit(),
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                    LengthLimitingTextInputFormatter(24),
                  ],
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                  textAlign: TextAlign.center,
                  cursorColor: AppColors.primary,
                  decoration: parkingFieldDecoration(_credentialLabel).copyWith(
                    hintText: 'Scan or type, then press Enter',
                    hintStyle: TextStyle(
                        color: AppColors.textFaint,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter the ${_credentialLabel.toLowerCase()}'
                      : null,
                ),
                if (_credentialType != ParkingConstants.channelManual) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _vehicleNumberController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      UpperCaseTextFormatter(),
                      LengthLimitingTextInputFormatter(24),
                    ],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                    cursorColor: AppColors.primary,
                    decoration:
                        parkingFieldDecoration('Vehicle Number').copyWith(
                      hintText: 'The plate on the vehicle',
                      hintStyle: TextStyle(
                          color: AppColors.textFaint,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Checked against the plate the pass was issued to. A '
                    'mismatch is admitted but charged as a normal visitor.',
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            ParkingBanner(
              text: _error!,
              color: AppColors.danger,
              icon: Icons.error_outline,
            ),
          ],

          if (_showOverride || _selectedLevelIsFull) ...[
            const SizedBox(height: 12),
            ParkingCard(
              title: 'Admit over capacity',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'This level is full. Admitting anyway is recorded against '
                    'your name with the reason below.',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _overrideReasonController,
                    style: TextStyle(color: AppColors.textPrimary),
                    cursorColor: AppColors.primary,
                    decoration: parkingFieldDecoration('Reason'),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: (_showOverride || _selectedLevelIsFull)
                    ? AppColors.warning
                    : AppColors.success,
                foregroundColor: AppColors.onPrimary,
                disabledBackgroundColor: AppColors.success.withOpacity(0.45),
                disabledForegroundColor: AppColors.onPrimary.withOpacity(0.8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onPrimary))
                  : const Icon(Icons.login),
              label: Text(
                _submitting
                    ? 'Admitting…'
                    : ((_showOverride || _selectedLevelIsFull)
                        ? 'ADMIT ANYWAY'
                        : 'ADMIT'),
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _submitting ? null : _clear,
            child: Text('Clear',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// One level on the live board — headline free count plus the per-type
  /// breakdown, because the sum hides the number that decides the barrier.
  Widget _occupancyRow(ZoneOccupancy z) {
    final int pct = z.occupancyPercent ?? 0;
    final Color bar = !z.acceptingVehicles
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
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
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
          if (z.byVehicleType.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...z.byVehicleType.map((t) {
              final bool selected = (t.vehicleType ?? '').toUpperCase() ==
                  _vehicleType.toUpperCase();
              final bool full = !t.acceptingVehicles;
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ParkingConstants.label(t.vehicleType),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      full ? 'full' : '${t.availableCount ?? 0}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        color: full
                            ? AppColors.danger
                            : (selected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// A selectable level, disabled when it will not take the current vehicle
  /// type at all.
  Widget _levelChip(ZoneOccupancy z) {
    final bool takes = z.takes(_vehicleType);
    final bool on = _selectedZoneId == z.zoneId;
    final String badge = z.labelFor(_vehicleType);

    return Opacity(
      // Selectable even when full: the guard may deliberately choose it and
      // override. Refusing the tap meant the choice had to be made twice.
      opacity: takes ? 1 : 0.6,
      child: InkWell(
        onTap: () => setState(() {
          _selectedZoneId = z.zoneId;
          _error = null;
        }),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            // Selected-and-full is a warning state, not a normal selection.
            color: on
                ? (takes ? AppColors.primary : AppColors.danger)
                : AppColors.tint(
                    takes ? AppColors.primary : AppColors.danger, 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: on
                    ? (takes ? AppColors.primary : AppColors.danger)
                    : (takes ? AppColors.divider : AppColors.danger),
                width: on ? 1.6 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                z.displayName ?? z.zoneName ?? '—',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: on ? AppColors.onPrimary : AppColors.textPrimary,
                ),
              ),
              if (badge.isNotEmpty)
                Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: on
                        ? AppColors.onPrimary.withOpacity(0.9)
                        : (takes ? AppColors.textSecondary : AppColors.danger),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- ticket ----

  Widget _ticketView(SessionEntryResponse r) {
    return AnimatedEntry(
      key: ValueKey(r.sessionId ?? r.ticketNumber),
      child: _ticketBody(r),
    );
  }

  Widget _ticketBody(SessionEntryResponse r) {
    final time = r.entryTime == null
        ? ''
        : DateFormat('dd MMM yyyy, hh:mm a').format(r.entryTime!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ParkingBanner(
          text: 'Vehicle admitted',
          color: AppColors.success,
          icon: Icons.check_circle,
        ),
        const SizedBox(height: 14),
        ParkingCard(
          title: 'Ticket',
          child: Column(
            children: [
              if ((r.barcodeValue ?? '').isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: QrImageView(
                    data: r.barcodeValue!,
                    size: 168,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                r.ticketNumber ?? '—',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              KeyValueRow(
                  label: 'Vehicle',
                  value: r.displayPlateNumber ?? r.plateNumber ?? '—'),
              KeyValueRow(
                  label: 'Type', value: ParkingConstants.label(r.vehicleType)),
              KeyValueRow(
                  label: 'Category',
                  value: ParkingConstants.label(r.sessionType)),
              KeyValueRow(label: 'Entry time', value: time),
              KeyValueRow(label: 'Level', value: r.zoneName ?? '—'),
              if (r.zoneAvailable != null)
                KeyValueRow(
                  label: 'Bays free',
                  value: '${r.zoneAvailable}',
                  valueColor: (r.zoneAvailable ?? 0) <= 0
                      ? AppColors.danger
                      : AppColors.success,
                ),
            ],
          ),
        ),
        if (r.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...r.warnings.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ParkingBanner(
                  text: w,
                  color: AppColors.warning,
                  icon: Icons.warning_amber_rounded,
                ),
              )),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _clear,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Next vehicle',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
