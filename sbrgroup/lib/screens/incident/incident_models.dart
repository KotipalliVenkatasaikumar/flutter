import 'package:ajna/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Models and presentation helpers for the Site Incident screen.
///
/// The styling helpers live here rather than in the screen so severity and
/// status are described **once**. A card, a badge, a summary chip and the
/// expanded detail view all read the same [SeverityStyle] / [StatusStyle],
/// which is what keeps a "Critical" incident looking identical everywhere.

// ---------------------------------------------------------------------------
// Domain models
// ---------------------------------------------------------------------------

/// One row from `getAllSiteIncidents`.
///
/// Every field is nullable on the wire — `implication` and `suggestionForFuture`
/// come back as empty strings on a freshly raised incident, and `extraData` is
/// null — so parsing never assumes presence and the UI hides what is missing.
class SiteIncident {
  final int siteIncidentId;
  final int? locationId;
  final String location;
  final int? incidentTypeId;
  final String incidentType;
  final int? severityId;
  final String severity;
  final DateTime? incidentDate;
  final String incidentDescription;
  final String implication;
  final String suggestionForFuture;
  final int? responsibleEmployeeId;
  final String responsibleEmployeeName;
  final int? supervisorId;
  final String supervisorName;
  final int? reportedById;
  final String reportedByName;
  final DateTime? reportedDate;
  final String status;

  const SiteIncident({
    required this.siteIncidentId,
    this.locationId,
    required this.location,
    this.incidentTypeId,
    required this.incidentType,
    this.severityId,
    required this.severity,
    this.incidentDate,
    required this.incidentDescription,
    required this.implication,
    required this.suggestionForFuture,
    this.responsibleEmployeeId,
    required this.responsibleEmployeeName,
    this.supervisorId,
    required this.supervisorName,
    this.reportedById,
    required this.reportedByName,
    this.reportedDate,
    required this.status,
  });

  factory SiteIncident.fromJson(Map<String, dynamic> json) {
    return SiteIncident(
      siteIncidentId: _asInt(json['siteIncidentId']) ?? 0,
      locationId: _asInt(json['locationId']),
      location: _asString(json['location']),
      incidentTypeId: _asInt(json['incidentTypeId']),
      incidentType: _asString(json['incidentType']),
      severityId: _asInt(json['severityId']),
      severity: _asString(json['severity']),
      incidentDate: _asDate(json['incidentDate']),
      incidentDescription: _asString(json['incidentDescription']),
      implication: _asString(json['implication']),
      suggestionForFuture: _asString(json['suggestionForFuture']),
      responsibleEmployeeId: _asInt(json['responsibleEmployeeId']),
      responsibleEmployeeName: _asString(json['responsibleEmployeeName']),
      supervisorId: _asInt(json['supervisorId']),
      supervisorName: _asString(json['supervisorName']),
      reportedById: _asInt(json['reportedById']),
      reportedByName: _asString(json['reportedByName']),
      reportedDate: _asDate(json['reportedDate']),
      status: _asString(json['status']),
    );
  }

  bool get isOpen => status.trim().toLowerCase() == 'open';

  bool get isCritical => severity.trim().toUpperCase().startsWith('CRIT');
}

/// The paged envelope wrapped around `records`.
///
/// [last] drives the infinite scroll stop condition — trusting it rather than
/// comparing page counters means one source of truth for "there is no more".
class IncidentPage {
  final int pageNo;
  final int pageSize;
  final bool last;
  final bool first;
  final int totalPages;
  final int totalRecords;
  final List<SiteIncident> records;

  const IncidentPage({
    required this.pageNo,
    required this.pageSize,
    required this.last,
    required this.first,
    required this.totalPages,
    required this.totalRecords,
    required this.records,
  });

  factory IncidentPage.fromJson(Map<String, dynamic> json) {
    final raw = json['records'];
    return IncidentPage(
      pageNo: _asInt(json['pageNo']) ?? 0,
      pageSize: _asInt(json['pageSize']) ?? 0,
      last: json['last'] == true,
      first: json['first'] == true,
      totalPages: _asInt(json['totalPages']) ?? 0,
      totalRecords: _asInt(json['totalRecords']) ?? 0,
      records: raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(SiteIncident.fromJson)
              .toList()
          : const <SiteIncident>[],
    );
  }
}

/// One selectable value in a filter dropdown.
///
/// Sites, incident types, severities and employees all reduce to the same
/// id + label pair, so the pickers are written once instead of four times.
class FilterOption {
  final int id;
  final String label;

  const FilterOption(this.id, this.label);

  @override
  bool operator ==(Object other) =>
      other is FilterOption && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// The filter selections currently applied to the list.
///
/// Held immutably so the sheet can edit a working copy and discard it if the
/// user backs out — only [IncidentFilters] handed back through "Apply" ever
/// reaches the list.
class IncidentFilters {
  final FilterOption? site;
  final FilterOption? incidentType;
  final FilterOption? severity;
  final FilterOption? employee;

  /// '' = any. The API takes the display word straight through: `Open`/`Close`.
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;

  const IncidentFilters({
    this.site,
    this.incidentType,
    this.severity,
    this.employee,
    this.status = '',
    this.startDate,
    this.endDate,
  });

  IncidentFilters copyWith({
    FilterOption? site,
    FilterOption? incidentType,
    FilterOption? severity,
    FilterOption? employee,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    bool clearSite = false,
    bool clearType = false,
    bool clearSeverity = false,
    bool clearEmployee = false,
    bool clearStart = false,
    bool clearEnd = false,
  }) {
    return IncidentFilters(
      site: clearSite ? null : (site ?? this.site),
      incidentType: clearType ? null : (incidentType ?? this.incidentType),
      severity: clearSeverity ? null : (severity ?? this.severity),
      employee: clearEmployee ? null : (employee ?? this.employee),
      status: status ?? this.status,
      startDate: clearStart ? null : (startDate ?? this.startDate),
      endDate: clearEnd ? null : (endDate ?? this.endDate),
    );
  }

  /// How many filters are narrowing the list — drives the "Filters 3" badge.
  int get activeCount {
    var n = 0;
    if (site != null) n++;
    if (incidentType != null) n++;
    if (severity != null) n++;
    if (employee != null) n++;
    if (status.isNotEmpty) n++;
    if (startDate != null) n++;
    if (endDate != null) n++;
    return n;
  }

  bool get isActive => activeCount > 0;
}

// ---------------------------------------------------------------------------
// Presentation helpers
// ---------------------------------------------------------------------------

/// How one severity level is drawn, everywhere it appears.
class SeverityStyle {
  final Color color;
  final IconData icon;
  final String label;

  /// 0..1 — how much of the severity rail is filled. A glanceable "how bad"
  /// signal that does not depend on reading the word.
  final double weight;

  const SeverityStyle({
    required this.color,
    required this.icon,
    required this.label,
    required this.weight,
  });
}

/// Severity colours run danger → warning → amber → success, so the eye sorts
/// the feed by heat before reading a single label.
SeverityStyle severityStyleFor(String? severity) {
  switch ((severity ?? '').trim().toUpperCase()) {
    case 'CRITICAL':
      return const SeverityStyle(
        color: AppColors.danger,
        icon: Icons.crisis_alert_rounded,
        label: 'Critical',
        weight: 1.0,
      );
    case 'HIGH':
      return const SeverityStyle(
        color: Color(0xFFEA580C),
        icon: Icons.priority_high_rounded,
        label: 'High',
        weight: 0.75,
      );
    case 'MEDIUM':
      return const SeverityStyle(
        color: AppColors.warning,
        icon: Icons.error_outline_rounded,
        label: 'Medium',
        weight: 0.5,
      );
    case 'LOW':
      return const SeverityStyle(
        color: AppColors.success,
        icon: Icons.info_outline_rounded,
        label: 'Low',
        weight: 0.28,
      );
    default:
      return SeverityStyle(
        color: AppColors.textFaint,
        icon: Icons.help_outline_rounded,
        label: (severity == null || severity.trim().isEmpty)
            ? 'Unspecified'
            : severity,
        weight: 0.2,
      );
  }
}

/// How one status is drawn.
class StatusStyle {
  final Color color;
  final IconData icon;
  final String label;

  const StatusStyle({
    required this.color,
    required this.icon,
    required this.label,
  });
}

StatusStyle statusStyleFor(String? status) {
  final normalised = (status ?? '').trim().toLowerCase();
  if (normalised == 'open') {
    return const StatusStyle(
      color: AppColors.warning,
      icon: Icons.radio_button_checked_rounded,
      label: 'Open',
    );
  }
  // The API sends `Close`; `Closed` is accepted too so a backend wording change
  // does not silently fall through to the unknown branch.
  if (normalised == 'close' || normalised == 'closed') {
    return const StatusStyle(
      color: AppColors.success,
      icon: Icons.check_circle_rounded,
      label: 'Closed',
    );
  }
  return StatusStyle(
    color: AppColors.textFaint,
    icon: Icons.help_outline_rounded,
    label: (status == null || status.trim().isEmpty) ? 'Unknown' : status,
  );
}

/// Icon for an incident type.
///
/// Matched on the reference **key** (ELECTRICAL, FIRE, …) but tolerant of the
/// display value the list API returns ("Electrical"), since the two differ only
/// in case for every type the backend currently defines.
IconData incidentTypeIcon(String? type) {
  final key = (type ?? '').trim().toUpperCase();
  if (key.startsWith('ELECTRIC')) return Icons.bolt_rounded;
  if (key.startsWith('EQUIP')) return Icons.precision_manufacturing_rounded;
  if (key.startsWith('FIRE')) return Icons.local_fire_department_rounded;
  if (key.startsWith('HOUSEKEEP')) return Icons.cleaning_services_rounded;
  if (key.startsWith('INJURY')) return Icons.personal_injury_rounded;
  if (key.startsWith('MISCONDUCT')) return Icons.gavel_rounded;
  if (key.startsWith('SAFETY')) return Icons.health_and_safety_rounded;
  if (key.startsWith('SECURITY')) return Icons.shield_rounded;
  if (key.startsWith('THEFT')) return Icons.no_encryption_gmailerrorred_rounded;
  return Icons.report_problem_rounded;
}

/// Accent colour for an incident type.
///
/// Each type carries its own hue so a grid of ten of them can be scanned by
/// colour rather than read word by word — fire reads as fire, safety as safety.
/// Matched leniently for the same reason as [incidentTypeIcon].
Color incidentTypeAccent(String? type) {
  final key = (type ?? '').trim().toUpperCase();
  if (key.startsWith('ELECTRIC')) return const Color(0xFFD97706); // amber
  if (key.startsWith('EQUIP')) return const Color(0xFF0E7490); // teal
  if (key.startsWith('FIRE')) return AppColors.danger; // red
  if (key.startsWith('HOUSEKEEP')) return const Color(0xFF0EA5E9); // sky
  if (key.startsWith('INJURY')) return const Color(0xFFE11D48); // rose
  if (key.startsWith('MISCONDUCT')) return const Color(0xFF9333EA); // purple
  if (key.startsWith('SAFETY')) return AppColors.accent; // emerald
  if (key.startsWith('SECURITY')) return const Color(0xFF4F46E5); // indigo
  if (key.startsWith('THEFT')) return const Color(0xFF7C3AED); // violet
  return AppColors.primary;
}

/// Initials chip standing in for a user photo.
///
/// There is no avatar endpoint for users, and initials read faster than the
/// same person glyph repeated down a list. The colour is derived from the name
/// so one person keeps one colour everywhere, with nothing stored.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;

  /// Draws a ring in the avatar's own colour — used to mark selection.
  final bool selected;

  const InitialsAvatar({
    Key? key,
    required this.name,
    this.size = 30,
    this.selected = false,
  }) : super(key: key);

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  Color get accent => AppColors.tileAccent(
      name.isEmpty ? 0 : name.codeUnits.fold<int>(0, (a, b) => a + b));

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.tint(accent, selected ? 0.26 : 0.16),
        shape: BoxShape.circle,
        border:
            selected ? Border.all(color: accent, width: 2) : null,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          color: accent,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lenient JSON coercion
// ---------------------------------------------------------------------------
//
// The incident payload mixes types across environments — ids have been seen as
// both `18` and `"18"`, and optional text fields arrive as null. Coercing here
// keeps every `fromJson` above free of defensive casts.

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String _asString(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
