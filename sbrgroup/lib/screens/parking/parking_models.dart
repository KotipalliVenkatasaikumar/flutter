/// Models for the parking module.
///
/// Field names mirror the Java beans in
/// `facility-management-service/.../parking/bean` **verbatim** — do not "tidy"
/// them, the JSON keys must keep matching the backend.
///
/// Money fields arrive as Java `BigDecimal` (JSON number or string depending on
/// serialiser config), so every amount goes through [_toDouble] rather than a
/// bare cast.
library;

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

/// Row status across this backend is `CommonConstants.Active = "A"` /
/// `InActive = "I"` — **not** the word "ACTIVE". `ParkingSessionServiceImpl`
/// compares with `CommonConstants.Active.equals(lane.getStatus())`, so "A" is
/// the only value that admits a vehicle.
///
/// Both spellings are accepted here so a lane is never wrongly shown as
/// disabled if a row is written with the long form.
bool _isActiveStatus(String? status) {
  final s = (status ?? '').trim().toUpperCase();
  return s == 'A' || s == 'ACTIVE';
}

/// Allowed values, straight from `ParkingConstants`.
class ParkingConstants {
  ParkingConstants._();

  // Credential channels. TICKET is exit-only — at entry the ticket is *issued*
  // by the call, not read before it.
  static const String channelTicket = 'TICKET';
  static const String channelFastag = 'FASTAG';
  static const String channelRfid = 'RFID';
  static const String channelPass = 'PASS';
  static const String channelManual = 'MANUAL';
  static const String channelAnpr = 'ANPR';

  static const List<String> entryChannels = [
    channelManual,
    channelPass,
    channelFastag,
  ];
  static const List<String> exitChannels = [
    channelTicket,
    channelManual,
    channelPass,
    channelFastag,
  ];

  static const String vehicleFourWheeler = 'FOUR_WHEELER';
  static const String vehicleTwoWheeler = 'TWO_WHEELER';
  static const String vehicleCommercial = 'COMMERCIAL';
  static const String vehicleEv = 'EV';

  static const List<String> vehicleTypes = [
    vehicleFourWheeler,
    vehicleTwoWheeler,
    vehicleCommercial,
    vehicleEv,
  ];

  static const String payCash = 'CASH';
  static const String payUpi = 'UPI';
  static const String payCard = 'CARD';
  static const String payWallet = 'WALLET';
  static const String payPass = 'PASS';
  static const String payFree = 'FREE';

  /// Modes offered at the POS.
  ///
  /// WALLET / PASS / FREE exist backend-side and come back on responses, but the
  /// web POS deliberately offers only these three — a counter takes cash, UPI or
  /// a card, and PASS/FREE are decided by the stay, not by the operator.
  static const List<String> paymentModes = [payCash, payUpi, payCard];

  /// Modes that need a transaction reference rather than cash tendered.
  static const List<String> digitalModes = [payUpi, payCard];

  /// What the reference is actually called, per mode — "UPI Reference" and
  /// "Card Slip No." are different pieces of paper.
  static String referenceLabel(String mode) {
    switch (mode) {
      case payUpi:
        return 'UPI Reference';
      case payCard:
        return 'Card Slip No.';
      default:
        return 'Transaction reference';
    }
  }

  static const String laneDirectionIn = 'IN';
  static const String laneDirectionOut = 'OUT';
  static const String laneDirectionBidirectional = 'BIDIRECTIONAL';

  /// Human label for the SCREAMING_SNAKE values the API uses.
  static String label(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw
        .split('_')
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}

/// A project, from `api/project/project/org?organizationId=…`.
///
/// Not a parking entity — parking sites hang off it, so it is the first step
/// when an organisation runs more than one.
class ParkingProject {
  final int? projectId;
  final String? projectName;

  ParkingProject({this.projectId, this.projectName});

  factory ParkingProject.fromJson(Map<String, dynamic> json) => ParkingProject(
        projectId: _toInt(json['projectId']),
        projectName: json['projectName']?.toString(),
      );
}

class ParkingSite {
  final int? siteId;
  final String? siteCode;
  final String? siteName;
  final int? projectId;
  final String? gstin;
  final String? status;
  final int? postPaymentGraceMinutes;

  ParkingSite({
    this.siteId,
    this.siteCode,
    this.siteName,
    this.projectId,
    this.gstin,
    this.status,
    this.postPaymentGraceMinutes,
  });

  factory ParkingSite.fromJson(Map<String, dynamic> json) => ParkingSite(
        siteId: _toInt(json['siteId']),
        siteCode: json['siteCode'],
        siteName: json['siteName'],
        projectId: _toInt(json['projectId']),
        gstin: json['gstin'],
        status: json['status'],
        postPaymentGraceMinutes: _toInt(json['postPaymentGraceMinutes']),
      );
}

class ParkingLane {
  final int? laneId;
  final int? siteId;
  final int? zoneId;
  final String? laneName;
  final String? laneCode;

  /// IN / OUT / BIDIRECTIONAL — entry rejects an OUT lane, so the pickers
  /// filter on this.
  final String? direction;
  final String? defaultVehicleType;

  /// Comma-separated channels this lane accepts (MANUAL, FASTAG, PASS…).
  /// The web screen offers only these, so a two-wheeler lane with no tag reader
  /// never shows FASTag.
  final String? channelsEnabled;
  final String? status;
  final String? siteName;
  final String? zoneName;

  ParkingLane({
    this.laneId,
    this.siteId,
    this.zoneId,
    this.laneName,
    this.laneCode,
    this.direction,
    this.defaultVehicleType,
    this.channelsEnabled,
    this.status,
    this.siteName,
    this.zoneName,
  });

  factory ParkingLane.fromJson(Map<String, dynamic> json) => ParkingLane(
        laneId: _toInt(json['laneId']),
        siteId: _toInt(json['siteId']),
        zoneId: _toInt(json['zoneId']),
        laneName: json['laneName'],
        laneCode: json['laneCode'],
        direction: json['direction'],
        defaultVehicleType: json['defaultVehicleType'],
        channelsEnabled: json['channelsEnabled'],
        status: json['status'],
        siteName: json['siteName'],
        zoneName: json['zoneName'],
      );

  bool get allowsEntry =>
      direction == ParkingConstants.laneDirectionIn ||
      direction == ParkingConstants.laneDirectionBidirectional;

  bool get allowsExit =>
      direction == ParkingConstants.laneDirectionOut ||
      direction == ParkingConstants.laneDirectionBidirectional;

  bool get isActive => _isActiveStatus(status);

  /// True when the lane serves the whole site rather than one level, so the
  /// operator MUST pick a zone — `ParkingSessionServiceImpl` only falls back to
  /// the request's zoneId when the lane has none, and without it the stay is
  /// recorded against no zone and that zone's occupancy never moves.
  bool get needsZoneChoice => zoneId == null;

  /// Channels this lane accepts, falling back to all entry channels when the
  /// backend leaves it blank.
  List<String> entryChannels() {
    final raw = (channelsEnabled ?? '').trim();
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
}

/// Response of `POST /parking/session/entry`.
class SessionEntryResponse {
  final bool admitted;
  final String? rejectionReason;
  final int? sessionId;
  final String? ticketNumber;
  final String? barcodeValue;
  final DateTime? entryTime;
  final String? plateNumber;
  final String? displayPlateNumber;
  final String? vehicleType;
  final String? sessionType;
  final int? zoneId;
  final String? zoneName;
  final int? zoneOccupied;
  final int? zoneAvailable;
  final List<String> warnings;

  SessionEntryResponse({
    required this.admitted,
    this.rejectionReason,
    this.sessionId,
    this.ticketNumber,
    this.barcodeValue,
    this.entryTime,
    this.plateNumber,
    this.displayPlateNumber,
    this.vehicleType,
    this.sessionType,
    this.zoneId,
    this.zoneName,
    this.zoneOccupied,
    this.zoneAvailable,
    this.warnings = const [],
  });

  factory SessionEntryResponse.fromJson(Map<String, dynamic> json) =>
      SessionEntryResponse(
        admitted: json['admitted'] == true,
        rejectionReason: json['rejectionReason'],
        sessionId: _toInt(json['sessionId']),
        ticketNumber: json['ticketNumber'],
        barcodeValue: json['barcodeValue'],
        entryTime: _toDate(json['entryTime']),
        plateNumber: json['plateNumber'],
        displayPlateNumber: json['displayPlateNumber'],
        vehicleType: json['vehicleType'],
        sessionType: json['sessionType'],
        zoneId: _toInt(json['zoneId']),
        zoneName: json['zoneName'],
        zoneOccupied: _toInt(json['zoneOccupied']),
        zoneAvailable: _toInt(json['zoneAvailable']),
        warnings:
            (json['warnings'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
      );
}

/// One line of the tariff explanation shown to the attendant/customer.
class TariffBreakdownLine {
  final String? description;
  final int? fromMinutes;
  final int? toMinutes;
  final double? amount;

  TariffBreakdownLine({
    this.description,
    this.fromMinutes,
    this.toMinutes,
    this.amount,
  });

  factory TariffBreakdownLine.fromJson(Map<String, dynamic> json) =>
      TariffBreakdownLine(
        description: json['description'],
        fromMinutes: _toInt(json['fromMinutes']),
        toMinutes: _toInt(json['toMinutes']),
        amount: _toDouble(json['amount']),
      );
}

/// Response of `GET /parking/exit/lookup` — the priced stay, before payment.
class ExitLookupResponse {
  final bool found;
  final String? message;
  final int? sessionId;
  final String? ticketNumber;
  final String? plateNumber;
  final String? displayPlateNumber;
  final String? vehicleType;
  final String? sessionType;
  final String? zoneName;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final int? durationMinutes;
  final int? tariffId;
  final String? tariffName;
  final double? grossAmount;
  final double? validationDiscount;
  final double? penaltyAmount;
  final double? taxableAmount;
  final double? taxRate;
  final double? taxAmount;
  final double? netAmount;
  final bool freeExit;
  final List<TariffBreakdownLine> breakdown;
  final bool alreadyPaid;
  final int? graceRemainingMinutes;
  final List<String> warnings;

  ExitLookupResponse({
    required this.found,
    this.message,
    this.sessionId,
    this.ticketNumber,
    this.plateNumber,
    this.displayPlateNumber,
    this.vehicleType,
    this.sessionType,
    this.zoneName,
    this.entryTime,
    this.exitTime,
    this.durationMinutes,
    this.tariffId,
    this.tariffName,
    this.grossAmount,
    this.validationDiscount,
    this.penaltyAmount,
    this.taxableAmount,
    this.taxRate,
    this.taxAmount,
    this.netAmount,
    this.freeExit = false,
    this.breakdown = const [],
    this.alreadyPaid = false,
    this.graceRemainingMinutes,
    this.warnings = const [],
  });

  factory ExitLookupResponse.fromJson(Map<String, dynamic> json) =>
      ExitLookupResponse(
        found: json['found'] == true,
        message: json['message'],
        sessionId: _toInt(json['sessionId']),
        ticketNumber: json['ticketNumber'],
        plateNumber: json['plateNumber'],
        displayPlateNumber: json['displayPlateNumber'],
        vehicleType: json['vehicleType'],
        sessionType: json['sessionType'],
        zoneName: json['zoneName'],
        entryTime: _toDate(json['entryTime']),
        exitTime: _toDate(json['exitTime']),
        durationMinutes: _toInt(json['durationMinutes']),
        tariffId: _toInt(json['tariffId']),
        tariffName: json['tariffName'],
        grossAmount: _toDouble(json['grossAmount']),
        validationDiscount: _toDouble(json['validationDiscount']),
        penaltyAmount: _toDouble(json['penaltyAmount']),
        taxableAmount: _toDouble(json['taxableAmount']),
        taxRate: _toDouble(json['taxRate']),
        taxAmount: _toDouble(json['taxAmount']),
        netAmount: _toDouble(json['netAmount']),
        freeExit: json['freeExit'] == true,
        breakdown: (json['breakdown'] as List?)
                ?.map((e) =>
                    TariffBreakdownLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        alreadyPaid: json['alreadyPaid'] == true,
        graceRemainingMinutes: _toInt(json['graceRemainingMinutes']),
        warnings:
            (json['warnings'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
      );

  /// Nothing to collect — free exit, already settled, or a zero bill.
  bool get nothingToCollect => freeExit || alreadyPaid || (netAmount ?? 0) <= 0;
}

/// Response of `POST /parking/exit/confirm` — the receipt.
class ExitConfirmResponse {
  final bool released;
  final String? message;
  final int? sessionId;
  final int? chargeId;
  final int? paymentId;
  final String? receiptNumber;
  final String? ticketNumber;
  final String? plateNumber;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final int? durationMinutes;
  final String? paymentMode;
  final double? netAmount;
  final double? waivedAmount;
  final double? tenderedAmount;
  final double? changeAmount;
  final double? taxableAmount;
  final double? taxAmount;
  final String? gstin;
  final String? siteName;
  final int? exitGraceMinutes;

  ExitConfirmResponse({
    required this.released,
    this.message,
    this.sessionId,
    this.chargeId,
    this.paymentId,
    this.receiptNumber,
    this.ticketNumber,
    this.plateNumber,
    this.entryTime,
    this.exitTime,
    this.durationMinutes,
    this.paymentMode,
    this.netAmount,
    this.waivedAmount,
    this.tenderedAmount,
    this.changeAmount,
    this.taxableAmount,
    this.taxAmount,
    this.gstin,
    this.siteName,
    this.exitGraceMinutes,
  });

  factory ExitConfirmResponse.fromJson(Map<String, dynamic> json) =>
      ExitConfirmResponse(
        released: json['released'] == true,
        message: json['message'],
        sessionId: _toInt(json['sessionId']),
        chargeId: _toInt(json['chargeId']),
        paymentId: _toInt(json['paymentId']),
        receiptNumber: json['receiptNumber'],
        ticketNumber: json['ticketNumber'],
        plateNumber: json['plateNumber'],
        entryTime: _toDate(json['entryTime']),
        exitTime: _toDate(json['exitTime']),
        durationMinutes: _toInt(json['durationMinutes']),
        paymentMode: json['paymentMode'],
        netAmount: _toDouble(json['netAmount']),
        waivedAmount: _toDouble(json['waivedAmount']),
        tenderedAmount: _toDouble(json['tenderedAmount']),
        changeAmount: _toDouble(json['changeAmount']),
        taxableAmount: _toDouble(json['taxableAmount']),
        taxAmount: _toDouble(json['taxAmount']),
        gstin: json['gstin'],
        siteName: json['siteName'],
        exitGraceMinutes: _toInt(json['exitGraceMinutes']),
      );
}

/// How a zone stands for ONE vehicle type.
///
/// The zone's headline "free" figure is a sum across types, and that sum hides
/// the number that actually decides whether the barrier lifts: a level can show
/// "8 free" while holding nothing at all for the two-wheeler at the gate.
class VehicleTypeOccupancy {
  final String? vehicleType;
  final int? totalBays;
  final int? occupiedCount;
  final int? availableCount;
  final bool acceptingVehicles;
  final int? occupancyPercent;

  VehicleTypeOccupancy({
    this.vehicleType,
    this.totalBays,
    this.occupiedCount,
    this.availableCount,
    this.acceptingVehicles = true,
    this.occupancyPercent,
  });

  factory VehicleTypeOccupancy.fromJson(Map<String, dynamic> json) =>
      VehicleTypeOccupancy(
        vehicleType: json['vehicleType'],
        totalBays: _toInt(json['totalBays']),
        occupiedCount: _toInt(json['occupiedCount']),
        availableCount: _toInt(json['availableCount']),
        acceptingVehicles: json['acceptingVehicles'] != false,
        occupancyPercent: _toInt(json['occupancyPercent']),
      );
}

/// One zone's live occupancy — `GET /parking/occupancy/site/{siteId}`.
class ZoneOccupancy {
  final int? zoneId;
  final int? siteId;
  final String? zoneName;
  final String? displayName;
  final String? levelCode;
  final int? totalBays;
  final int? occupiedCount;
  final int? availableCount;
  final bool acceptingVehicles;
  final int? occupancyPercent;
  final int? reserveBufferPct;
  final List<VehicleTypeOccupancy> byVehicleType;

  ZoneOccupancy({
    this.zoneId,
    this.siteId,
    this.zoneName,
    this.displayName,
    this.levelCode,
    this.totalBays,
    this.occupiedCount,
    this.availableCount,
    this.acceptingVehicles = true,
    this.occupancyPercent,
    this.reserveBufferPct,
    this.byVehicleType = const [],
  });

  factory ZoneOccupancy.fromJson(Map<String, dynamic> json) => ZoneOccupancy(
        zoneId: _toInt(json['zoneId']),
        siteId: _toInt(json['siteId']),
        zoneName: json['zoneName'],
        displayName: json['displayName'],
        levelCode: json['levelCode'],
        totalBays: _toInt(json['totalBays']),
        occupiedCount: _toInt(json['occupiedCount']),
        availableCount: _toInt(json['availableCount']),
        acceptingVehicles: json['acceptingVehicles'] != false,
        occupancyPercent: _toInt(json['occupancyPercent']),
        reserveBufferPct: _toInt(json['reserveBufferPct']),
        byVehicleType: (json['byVehicleType'] as List?)
                ?.map((e) =>
                    VehicleTypeOccupancy.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  /// This zone's standing for [vehicleType], or null when bays are not
  /// allocated per type.
  VehicleTypeOccupancy? typeStatus(String vehicleType) {
    for (final t in byVehicleType) {
      if ((t.vehicleType ?? '').toUpperCase() == vehicleType.toUpperCase()) {
        return t;
      }
    }
    return null;
  }

  /// Free bays for [vehicleType] — or the zone total when no per-type
  /// allocation is configured (every bay is then interchangeable).
  int freeFor(String vehicleType) {
    final s = typeStatus(vehicleType);
    if (s != null) return s.availableCount ?? 0;
    return byVehicleType.isNotEmpty ? 0 : (availableCount ?? 0);
  }

  /// Whether this level will take [vehicleType] at all.
  bool takes(String vehicleType) {
    final s = typeStatus(vehicleType);
    if (s != null) return s.acceptingVehicles;
    return byVehicleType.isNotEmpty ? false : acceptingVehicles;
  }

  /// Some types full, others not.
  ///
  /// "A single OPEN/FULL badge is not enough once bays are held per vehicle
  /// type: a zone with its bike corner full and half its car bays empty is
  /// neither. PART FULL is what sends the duty manager to the breakdown below
  /// instead of trusting OPEN."
  bool get partlyFull {
    if (byVehicleType.isEmpty) return false;
    return byVehicleType.any((s) => !s.acceptingVehicles) &&
        byVehicleType.any((s) => s.acceptingVehicles);
  }

  String get badgeLabel {
    if (!acceptingVehicles) return 'FULL';
    return partlyFull ? 'PART FULL' : 'OPEN';
  }

  /// "not allowed here" reads differently from "FULL" — the operator's next
  /// action differs.
  String labelFor(String vehicleType) {
    final s = typeStatus(vehicleType);
    if (s == null) return byVehicleType.isNotEmpty ? 'not allowed here' : '';
    return s.acceptingVehicles ? '${s.availableCount ?? 0} free' : 'FULL';
  }
}

/// One row of the vehicle movement register.
class VehicleMovement {
  final int? sessionId;
  final String? ticketNumber;
  final String? plateNumber;
  final String? displayPlateNumber;
  final String? vehicleType;
  final String? sessionType;
  final String? zoneName;
  final String? entryLaneName;
  final DateTime? entryTime;
  final String? entryMode;
  final String? exitLaneName;
  final DateTime? exitTime;
  final String? exitMode;
  final int? durationMinutes;
  final bool stillInside;
  final String? sessionStatus;
  final double? amountPaid;
  final String? paymentMode;
  final String? receiptNumber;

  VehicleMovement({
    this.sessionId,
    this.ticketNumber,
    this.plateNumber,
    this.displayPlateNumber,
    this.vehicleType,
    this.sessionType,
    this.zoneName,
    this.entryLaneName,
    this.entryTime,
    this.entryMode,
    this.exitLaneName,
    this.exitTime,
    this.exitMode,
    this.durationMinutes,
    this.stillInside = false,
    this.sessionStatus,
    this.amountPaid,
    this.paymentMode,
    this.receiptNumber,
  });

  factory VehicleMovement.fromJson(Map<String, dynamic> json) =>
      VehicleMovement(
        sessionId: _toInt(json['sessionId']),
        ticketNumber: json['ticketNumber'],
        plateNumber: json['plateNumber'],
        displayPlateNumber: json['displayPlateNumber'],
        vehicleType: json['vehicleType'],
        sessionType: json['sessionType'],
        zoneName: json['zoneName'],
        entryLaneName: json['entryLaneName'],
        entryTime: _toDate(json['entryTime']),
        entryMode: json['entryMode'],
        exitLaneName: json['exitLaneName'],
        exitTime: _toDate(json['exitTime']),
        exitMode: json['exitMode'],
        durationMinutes: _toInt(json['durationMinutes']),
        stillInside: json['stillInside'] == true,
        sessionStatus: json['sessionStatus'],
        amountPaid: _toDouble(json['amountPaid']),
        paymentMode: json['paymentMode'],
        receiptNumber: json['receiptNumber'],
      );

  /// Most shoppers are anonymous — the ticket identifies the stay when no plate
  /// was read.
  String get label => displayPlateNumber ?? plateNumber ?? ticketNumber ?? '—';

  bool get hasPlate => (displayPlateNumber ?? plateNumber ?? '').isNotEmpty;

  /// A stay well past a normal shopping trip. Not an error — staff and
  /// overnight vehicles are legitimate — but it is the row worth a second look,
  /// and it is invisible in a count of how many cars are inside.
  bool get isLongStay => stillInside && (durationMinutes ?? 0) >= 12 * 60;

  bool get forceClosed => sessionStatus == 'FORCE_CLOSED';
}

/// A page of the movement register plus its totals.
class VehicleMovementPage {
  final List<VehicleMovement> rows;
  final int totalMatching;
  final int stillInsideCount;
  final double? totalCollected;
  final int page;
  final int pageSize;

  VehicleMovementPage({
    this.rows = const [],
    this.totalMatching = 0,
    this.stillInsideCount = 0,
    this.totalCollected,
    this.page = 0,
    this.pageSize = 50,
  });

  factory VehicleMovementPage.fromJson(Map<String, dynamic> json) =>
      VehicleMovementPage(
        rows: (json['rows'] as List?)
                ?.map(
                    (e) => VehicleMovement.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        totalMatching: _toInt(json['totalMatching']) ?? 0,
        stillInsideCount: _toInt(json['stillInsideCount']) ?? 0,
        totalCollected: _toDouble(json['totalCollected']),
        page: _toInt(json['page']) ?? 0,
        pageSize: _toInt(json['pageSize']) ?? 50,
      );
}

/// The supervisor's wall screen — `GET /parking/report/dashboard/live/{siteId}`.
class LiveDashboard {
  final int? siteId;
  final String? siteName;
  final DateTime? asOf;
  final int? vehiclesInside;
  final int? totalCapacity;
  final int? occupancyPercent;
  final List<ZoneOccupancy> zones;
  final bool anyZoneFull;
  final double? collectedToday;
  final double? cashToday;
  final double? digitalToday;
  final int? transactionsToday;
  final int? vehiclesAdmittedToday;
  final int? vehiclesReleasedToday;
  final int? shiftsAwaitingSignOff;
  final int? exceptionsAwaitingDecision;
  final int? devicesOffline;
  final List<String> offlineDeviceNames;
  final int? staleSessions;
  final bool hardwareSimulated;

  LiveDashboard({
    this.siteId,
    this.siteName,
    this.asOf,
    this.vehiclesInside,
    this.totalCapacity,
    this.occupancyPercent,
    this.zones = const [],
    this.anyZoneFull = false,
    this.collectedToday,
    this.cashToday,
    this.digitalToday,
    this.transactionsToday,
    this.vehiclesAdmittedToday,
    this.vehiclesReleasedToday,
    this.shiftsAwaitingSignOff,
    this.exceptionsAwaitingDecision,
    this.devicesOffline,
    this.offlineDeviceNames = const [],
    this.staleSessions,
    this.hardwareSimulated = false,
  });

  factory LiveDashboard.fromJson(Map<String, dynamic> json) => LiveDashboard(
        siteId: _toInt(json['siteId']),
        siteName: json['siteName'],
        asOf: _toDate(json['asOf']),
        vehiclesInside: _toInt(json['vehiclesInside']),
        totalCapacity: _toInt(json['totalCapacity']),
        occupancyPercent: _toInt(json['occupancyPercent']),
        zones: (json['zones'] as List?)
                ?.map((e) => ZoneOccupancy.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        anyZoneFull: json['anyZoneFull'] == true,
        collectedToday: _toDouble(json['collectedToday']),
        cashToday: _toDouble(json['cashToday']),
        digitalToday: _toDouble(json['digitalToday']),
        transactionsToday: _toInt(json['transactionsToday']),
        vehiclesAdmittedToday: _toInt(json['vehiclesAdmittedToday']),
        vehiclesReleasedToday: _toInt(json['vehiclesReleasedToday']),
        shiftsAwaitingSignOff: _toInt(json['shiftsAwaitingSignOff']),
        exceptionsAwaitingDecision: _toInt(json['exceptionsAwaitingDecision']),
        devicesOffline: _toInt(json['devicesOffline']),
        offlineDeviceNames: (json['offlineDeviceNames'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        staleSessions: _toInt(json['staleSessions']),
        hardwareSimulated: json['hardwareSimulated'] == true,
      );

  /// Anything a supervisor must act on rather than just read.
  bool get needsAttention =>
      (shiftsAwaitingSignOff ?? 0) > 0 ||
      (exceptionsAwaitingDecision ?? 0) > 0 ||
      (devicesOffline ?? 0) > 0 ||
      (staleSessions ?? 0) > 0;
}

/// One day of takings — `CollectionReportBean.DailyCollectionLine`.
class DailyCollectionLine {
  final DateTime? date;
  final double? collection;
  final int? transactions;
  final int? vehicles;

  DailyCollectionLine(
      {this.date, this.collection, this.transactions, this.vehicles});

  factory DailyCollectionLine.fromJson(Map<String, dynamic> json) =>
      DailyCollectionLine(
        date: _toDate(json['date']),
        collection: _toDouble(json['collection']),
        transactions: _toInt(json['transactions']),
        vehicles: _toInt(json['vehicles']),
      );
}

/// "What did we take" — `GET /parking/report/collection`.
class CollectionReport {
  final int? siteId;
  final String? siteName;
  final DateTime? fromDate;
  final DateTime? toDate;
  final double? grossCollection;
  final double? taxableAmount;
  final double? taxAmount;
  final double? reversedAmount;
  final double? netCollection;
  final int? transactionCount;
  final int? reversalCount;
  final int? freeExits;
  final double? validationDiscountGiven;
  final double? averageTicketValue;
  final Map<String, double> byPaymentMode;
  final Map<String, double> byVehicleType;
  final Map<String, double> byLane;
  final Map<String, double> byOperator;
  final List<DailyCollectionLine> dailyBreakdown;

  CollectionReport({
    this.siteId,
    this.siteName,
    this.fromDate,
    this.toDate,
    this.grossCollection,
    this.taxableAmount,
    this.taxAmount,
    this.reversedAmount,
    this.netCollection,
    this.transactionCount,
    this.reversalCount,
    this.freeExits,
    this.validationDiscountGiven,
    this.averageTicketValue,
    this.byPaymentMode = const {},
    this.byVehicleType = const {},
    this.byLane = const {},
    this.byOperator = const {},
    this.dailyBreakdown = const [],
  });

  static Map<String, double> _money(dynamic raw) {
    final out = <String, double>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final d = _toDouble(v);
        if (d != null) out[k.toString()] = d;
      });
    }
    return out;
  }

  factory CollectionReport.fromJson(Map<String, dynamic> json) =>
      CollectionReport(
        siteId: _toInt(json['siteId']),
        siteName: json['siteName'],
        fromDate: _toDate(json['fromDate']),
        toDate: _toDate(json['toDate']),
        grossCollection: _toDouble(json['grossCollection']),
        taxableAmount: _toDouble(json['taxableAmount']),
        taxAmount: _toDouble(json['taxAmount']),
        reversedAmount: _toDouble(json['reversedAmount']),
        netCollection: _toDouble(json['netCollection']),
        transactionCount: _toInt(json['transactionCount']),
        reversalCount: _toInt(json['reversalCount']),
        freeExits: _toInt(json['freeExits']),
        validationDiscountGiven: _toDouble(json['validationDiscountGiven']),
        averageTicketValue: _toDouble(json['averageTicketValue']),
        byPaymentMode: _money(json['byPaymentMode']),
        byVehicleType: _money(json['byVehicleType']),
        byLane: _money(json['byLane']),
        byOperator: _money(json['byOperator']),
        dailyBreakdown: (json['dailyBreakdown'] as List?)
                ?.map((e) =>
                    DailyCollectionLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// How hard one zone worked — `OperationsReportBean.ZoneUtilisationLine`.
class ZoneUtilisationLine {
  final int? zoneId;
  final String? zoneName;
  final int? totalBays;
  final int? totalStays;
  final int? peakOccupancy;
  final int? averageOccupancy;
  final double? turnoverPerBay;

  ZoneUtilisationLine({
    this.zoneId,
    this.zoneName,
    this.totalBays,
    this.totalStays,
    this.peakOccupancy,
    this.averageOccupancy,
    this.turnoverPerBay,
  });

  factory ZoneUtilisationLine.fromJson(Map<String, dynamic> json) =>
      ZoneUtilisationLine(
        zoneId: _toInt(json['zoneId']),
        zoneName: json['zoneName'],
        totalBays: _toInt(json['totalBays']),
        totalStays: _toInt(json['totalStays']),
        peakOccupancy: _toInt(json['peakOccupancy']),
        averageOccupancy: _toInt(json['averageOccupancy']),
        turnoverPerBay: _toDouble(json['turnoverPerBay']),
      );
}

/// "How did the car park behave" — `GET /parking/report/operations`.
class OperationsReport {
  final int? siteId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int? totalEntries;
  final int? totalExits;
  final int? averageDailyEntries;
  final int? peakDayEntries;
  final DateTime? peakDate;
  final Map<int, int> entriesByHour;
  final int? busiestHour;
  final int? averageDwellMinutes;
  final int? medianDwellMinutes;
  final Map<String, int> dwellDistribution;
  final int? totalCapacity;
  final double? revenuePerBayPerDay;
  final int? peakOccupancyPercent;
  final List<ZoneUtilisationLine> zoneUtilisation;

  OperationsReport({
    this.siteId,
    this.fromDate,
    this.toDate,
    this.totalEntries,
    this.totalExits,
    this.averageDailyEntries,
    this.peakDayEntries,
    this.peakDate,
    this.entriesByHour = const {},
    this.busiestHour,
    this.averageDwellMinutes,
    this.medianDwellMinutes,
    this.dwellDistribution = const {},
    this.totalCapacity,
    this.revenuePerBayPerDay,
    this.peakOccupancyPercent,
    this.zoneUtilisation = const [],
  });

  factory OperationsReport.fromJson(Map<String, dynamic> json) {
    final byHour = <int, int>{};
    final rawHour = json['entriesByHour'];
    if (rawHour is Map) {
      rawHour.forEach((k, v) {
        final h = int.tryParse(k.toString());
        final c = _toInt(v);
        if (h != null && c != null) byHour[h] = c;
      });
    }
    final dwell = <String, int>{};
    final rawDwell = json['dwellDistribution'];
    if (rawDwell is Map) {
      rawDwell.forEach((k, v) {
        final c = _toInt(v);
        if (c != null) dwell[k.toString()] = c;
      });
    }
    return OperationsReport(
      siteId: _toInt(json['siteId']),
      fromDate: _toDate(json['fromDate']),
      toDate: _toDate(json['toDate']),
      totalEntries: _toInt(json['totalEntries']),
      totalExits: _toInt(json['totalExits']),
      averageDailyEntries: _toInt(json['averageDailyEntries']),
      peakDayEntries: _toInt(json['peakDayEntries']),
      peakDate: _toDate(json['peakDate']),
      entriesByHour: byHour,
      busiestHour: _toInt(json['busiestHour']),
      averageDwellMinutes: _toInt(json['averageDwellMinutes']),
      medianDwellMinutes: _toInt(json['medianDwellMinutes']),
      dwellDistribution: dwell,
      totalCapacity: _toInt(json['totalCapacity']),
      revenuePerBayPerDay: _toDouble(json['revenuePerBayPerDay']),
      peakOccupancyPercent: _toInt(json['peakOccupancyPercent']),
      zoneUtilisation: (json['zoneUtilisation'] as List?)
              ?.map((e) =>
                  ZoneUtilisationLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Response of the `/parking/shift/*` endpoints.
class ShiftSummary {
  final int? shiftId;
  final int? siteId;
  final int? laneId;
  final String? laneName;
  final int? operatorUserId;
  final String? operatorName;
  final DateTime? shiftStart;
  final DateTime? shiftEnd;
  final String? shiftStatus;
  final double? openingFloat;
  final double? expectedCash;
  final double? declaredCash;
  final double? varianceAmount;
  final String? varianceReason;
  final bool varianceBeyondTolerance;
  final double? varianceTolerance;
  final Map<String, double> collectionByMode;
  final double? digitalCollection;
  final double? totalCollection;
  final int? paymentCount;
  final int? vehiclesAdmitted;
  final int? vehiclesReleased;
  final int? exceptionCount;

  ShiftSummary({
    this.shiftId,
    this.siteId,
    this.laneId,
    this.laneName,
    this.operatorUserId,
    this.operatorName,
    this.shiftStart,
    this.shiftEnd,
    this.shiftStatus,
    this.openingFloat,
    this.expectedCash,
    this.declaredCash,
    this.varianceAmount,
    this.varianceReason,
    this.varianceBeyondTolerance = false,
    this.varianceTolerance,
    this.collectionByMode = const {},
    this.digitalCollection,
    this.totalCollection,
    this.paymentCount,
    this.vehiclesAdmitted,
    this.vehiclesReleased,
    this.exceptionCount,
  });

  factory ShiftSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['collectionByMode'];
    final Map<String, double> byMode = {};
    if (raw is Map) {
      raw.forEach((k, v) {
        final d = _toDouble(v);
        if (d != null) byMode[k.toString()] = d;
      });
    }
    return ShiftSummary(
      shiftId: _toInt(json['shiftId']),
      siteId: _toInt(json['siteId']),
      laneId: _toInt(json['laneId']),
      laneName: json['laneName'],
      operatorUserId: _toInt(json['operatorUserId']),
      operatorName: json['operatorName'],
      shiftStart: _toDate(json['shiftStart']),
      shiftEnd: _toDate(json['shiftEnd']),
      shiftStatus: json['shiftStatus'],
      openingFloat: _toDouble(json['openingFloat']),
      expectedCash: _toDouble(json['expectedCash']),
      declaredCash: _toDouble(json['declaredCash']),
      varianceAmount: _toDouble(json['varianceAmount']),
      varianceReason: json['varianceReason'],
      varianceBeyondTolerance: json['varianceBeyondTolerance'] == true,
      varianceTolerance: _toDouble(json['varianceTolerance']),
      collectionByMode: byMode,
      digitalCollection: _toDouble(json['digitalCollection']),
      totalCollection: _toDouble(json['totalCollection']),
      paymentCount: _toInt(json['paymentCount']),
      vehiclesAdmitted: _toInt(json['vehiclesAdmitted']),
      vehiclesReleased: _toInt(json['vehiclesReleased']),
      exceptionCount: _toInt(json['exceptionCount']),
    );
  }

  bool get isOpen => (shiftStatus ?? '').toUpperCase() == 'OPEN';
}
