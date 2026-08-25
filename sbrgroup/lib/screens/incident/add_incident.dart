import 'dart:convert';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/incident/incident_models.dart';
import 'package:ajna/screens/incident/incident_pickers.dart';
import 'package:ajna/screens/util.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// Report builder for a new site incident.
///
/// Written as a guided report rather than a form: every field is a numbered
/// step with a control shaped like its answer, borrowing the filter panel's
/// language — accent-coded sections, visual tiles, searchable sheets — so the
/// two halves of the feature feel like one product.
///
/// Pops `true` when an incident was saved, which is the signal the list uses to
/// refresh. Pops nothing when the user backs out.
class AddIncidentScreen extends StatefulWidget {
  const AddIncidentScreen({Key? key}) : super(key: key);

  @override
  State<AddIncidentScreen> createState() => _AddIncidentScreenState();
}

class _AddIncidentScreenState extends State<AddIncidentScreen>
    with TickerProviderStateMixin {
  static const int _fallbackOrganizationId = 2;
  static const int _descriptionLimit = 500;

  static final DateFormat _dayNumber = DateFormat('dd');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');

  // -- section accents, matched to the filter panel ------------------------

  static const _siteAccent = Color(0xFF0E7490);
  static const _typeAccent = Color(0xFF7C3AED);
  static const _severityAccent = AppColors.danger;
  static const _dateAccent = AppColors.primary;
  static const _peopleAccent = Color(0xFF0284C7);
  static const _supervisorAccent = Color(0xFF7C3AED);
  static const _statementAccent = Color(0xFF0F766E);
  static const _statusAccent = AppColors.accent;

  // -- form state -----------------------------------------------------------

  FilterOption? _site;
  FilterOption? _type;
  FilterOption? _severity;
  DateTime? _incidentDate;

  /// Deliberately separate from [_supervisor]: the same person may hold both
  /// roles, but they are two different fields on the record.
  FilterOption? _employee;
  FilterOption? _supervisor;

  String _status = 'Open';

  final TextEditingController _description = TextEditingController();
  final TextEditingController _implication = TextEditingController();
  final TextEditingController _suggestion = TextEditingController();

  // -- master data ----------------------------------------------------------

  int _organizationId = _fallbackOrganizationId;
  int? _reportedById;

  List<FilterOption> _sites = const [];
  List<FilterOption> _types = const [];
  List<FilterOption> _severities = const [];
  List<FilterOption> _employees = const [];
  bool _mastersLoading = true;
  String? _mastersError;

  // -- submission -----------------------------------------------------------

  bool _saving = false;
  String? _saveError;

  /// Which field failed validation, so only that section shows an error and the
  /// scroll can land on it.
  String? _invalidKey;

  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _anchors = {
    'site': GlobalKey(),
    'type': GlobalKey(),
    'severity': GlobalKey(),
    'date': GlobalKey(),
    'employee': GlobalKey(),
    'supervisor': GlobalKey(),
    'description': GlobalKey(),
    'status': GlobalKey(),
  };

  late final AnimationController _headerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void initState() {
    super.initState();
    _headerCtrl.forward();
    _description.addListener(_onDescriptionChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _description.removeListener(_onDescriptionChanged);
    _description.dispose();
    _implication.dispose();
    _suggestion.dispose();
    _scroll.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  /// Only rebuilds for the counter, and only while it can change the UI —
  /// rebuilding the whole form on every keystroke would be wasteful.
  void _onDescriptionChanged() {
    if (_invalidKey == 'description' && _description.text.trim().isNotEmpty) {
      setState(() => _invalidKey = null);
    } else {
      setState(() {});
    }
  }

  // -- data -----------------------------------------------------------------

  Future<void> _bootstrap() async {
    _organizationId = await Util.getOrganizationId() ?? _fallbackOrganizationId;
    _reportedById = await Util.getUserId();
    if (!mounted) return;
    await _loadMasters();
  }

  Future<void> _loadMasters() async {
    setState(() {
      _mastersLoading = true;
      _mastersError = null;
    });
    try {
      final results = await Future.wait([
        ApiService.fetchAttendanceLocation(_organizationId),
        ApiService.getCommonReferenceDetails('Incident_Type'),
        ApiService.getCommonReferenceDetails('Incident_Severity'),
        ApiService.fetchOrgUsers(_organizationId),
      ]);
      if (!mounted) return;

      final sites = _optionsFrom(results[0], idKey: 'id', labelKey: 'location');
      final types = _optionsFrom(results[1],
          idKey: 'id', labelKey: 'commonRefKey', sortByLabel: true);
      final severities = _severityOptionsFrom(results[2]);
      final employees = _optionsFrom(results[3],
          idKey: 'userId', labelKey: 'userName', sortByLabel: true);

      setState(() {
        _sites = sites;
        _types = types;
        _severities = severities;
        _employees = employees;
        _mastersLoading = false;
        // Every selector depends on this data, so an empty sweep is reported
        // rather than left as silently unusable controls.
        _mastersError = (sites.isEmpty &&
                types.isEmpty &&
                severities.isEmpty &&
                employees.isEmpty)
            ? 'Could not load sites, types or people. Check your connection.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mastersLoading = false;
        _mastersError = 'Could not load the incident options.';
      });
    }
  }

  List<FilterOption> _optionsFrom(
    http.Response response, {
    required String idKey,
    required String labelKey,
    bool sortByLabel = false,
  }) {
    try {
      if (!ApiService.isSuccess(response.statusCode)) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];
      final options = decoded
          .whereType<Map<String, dynamic>>()
          .map((row) {
            final id = row[idKey];
            final label = row[labelKey];
            if (id == null || label == null) return null;
            final parsedId = id is int ? id : int.tryParse(id.toString());
            if (parsedId == null) return null;
            final text = label.toString().trim();
            if (text.isEmpty) return null;
            return FilterOption(parsedId, text);
          })
          .whereType<FilterOption>()
          .toList();
      if (sortByLabel) {
        options.sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      }
      return options;
    } catch (_) {
      return const [];
    }
  }

  /// Ordered by seriousness rather than alphabetically, so the ladder reads
  /// Critical down to Low.
  List<FilterOption> _severityOptionsFrom(http.Response response) {
    final options = List<FilterOption>.from(
        _optionsFrom(response, idKey: 'id', labelKey: 'commonRefKey'));
    const rank = {'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3};
    options.sort((a, b) => (rank[a.label.toUpperCase()] ?? 99)
        .compareTo(rank[b.label.toUpperCase()] ?? 99));
    return options;
  }

  // -- validation & save ----------------------------------------------------

  /// The first unmet requirement, in the order the form presents them, so the
  /// scroll always lands on the earliest gap rather than an arbitrary one.
  String? get _firstInvalid {
    if (_site == null) return 'site';
    if (_type == null) return 'type';
    if (_severity == null) return 'severity';
    if (_incidentDate == null) return 'date';
    if (_employee == null) return 'employee';
    if (_supervisor == null) return 'supervisor';
    if (_description.text.trim().isEmpty) return 'description';
    if (_status.isEmpty) return 'status';
    return null;
  }

  static const Map<String, String> _invalidMessages = {
    'site': 'Choose the site where the incident happened.',
    'type': 'Choose what kind of incident this was.',
    'severity': 'Set how serious the incident is.',
    'date': 'Set the date the incident happened.',
    'employee': 'Choose the responsible employee.',
    'supervisor': 'Choose the responsible supervisor.',
    'description': 'Describe what happened.',
    'status': 'Set the incident status.',
  };

  Future<void> _save() async {
    if (_saving) return;

    final invalid = _firstInvalid;
    if (invalid != null) {
      setState(() => _invalidKey = invalid);
      _scrollTo(invalid);
      _notify(_invalidMessages[invalid] ?? 'Complete the required fields.',
          isError: true);
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
      _invalidKey = null;
    });

    // Built fresh from the selections; nothing is retained from a failed
    // attempt beyond what the user typed, which stays in the controllers.
    final body = <String, dynamic>{
      'siteIncidentId': 0,
      'organizationId': _organizationId,
      'locationId': _site!.id,
      'incidentTypeId': _type!.id,
      'severityId': _severity!.id,
      // The contract carries a full timestamp, so the chosen day is sent as
      // UTC midnight-based ISO rather than a bare date.
      'incidentDate': _incidentDate!.toUtc().toIso8601String(),
      'incidentDescription': _description.text.trim(),
      'implication': _implication.text.trim(),
      'suggestionForFuture': _suggestion.text.trim(),
      'responsibleEmployeeId': _employee!.id,
      'supervisorId': _supervisor!.id,
      'reportedById': _reportedById,
      'reportedDate': null,
      'status': _status,
    };

    try {
      final response = await ApiService.saveSiteIncident(body);
      if (!mounted) return;

      if (ApiService.isSuccess(response.statusCode)) {
        _notify('Incident reported.');
        // true tells the list a refresh is warranted.
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _saving = false;
        _saveError = 'The server rejected the report (${response.statusCode}).';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Could not reach the server. Your entries are kept.';
      });
    }
  }

  void _scrollTo(String key) {
    final context = _anchors[key]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.15,
    );
  }

  void _notify(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_rounded,
                color: AppColors.onPrimary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: isError ? AppColors.danger : AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(14),
        ),
      );
  }

  // -- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: _mastersError != null && _sites.isEmpty && _types.isEmpty
                ? _masterFailure()
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
                    children: [
                      ContentWidthLimit(
                        maxWidth: 640,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionHeading('Incident details', 0),
                            const SizedBox(height: 12),
                            _siteSection(),
                            const SizedBox(height: 13),
                            _typeSection(),
                            const SizedBox(height: 13),
                            _severitySection(),
                            const SizedBox(height: 13),
                            _dateSection(),
                            const SizedBox(height: 13),
                            _employeeSection(),
                            const SizedBox(height: 13),
                            _supervisorSection(),
                            const SizedBox(height: 22),
                            _sectionHeading('Incident statement', 6),
                            const SizedBox(height: 12),
                            _descriptionSection(),
                            const SizedBox(height: 13),
                            _implicationSection(),
                            const SizedBox(height: 13),
                            _suggestionSection(),
                            const SizedBox(height: 22),
                            _sectionHeading('Disposition', 9),
                            const SizedBox(height: 12),
                            _statusSection(),
                            if (_saveError != null) ...[
                              const SizedBox(height: 16),
                              _errorBanner(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          _saveBar(),
        ],
      ),
    );
  }

  /// Group heading: a rule, a word, and nothing else — it separates the three
  /// acts of the report without competing with the numbered steps.
  Widget _sectionHeading(String text, int position) {
    return _Stagger(
      position: position,
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
              color: AppColors.textFaint,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: AppColors.divider)),
        ],
      ),
    );
  }

  Widget _header() {
    final fade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    final rise = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroDeep, AppColors.heroMid, AppColors.heroEdge],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: AppColors.heroShadow.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 16, 18),
          child: ContentWidthLimit(
            maxWidth: 720,
            child: FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: rise,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.onPrimary),
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                    ),
                    ScaleTransition(
                      scale: CurvedAnimation(
                          parent: _headerCtrl, curve: Curves.easeOutBack),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.onPrimary.withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_moderator_rounded,
                            color: AppColors.onPrimary, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Create Incident',
                            style: TextStyle(
                              color: AppColors.onPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Report and register a new site incident',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.onPrimary.withOpacity(0.82),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _masterFailure() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.tint(AppColors.danger, 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded,
                  size: 38, color: AppColors.danger),
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load the form',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _mastersError ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadMasters,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.tint(AppColors.danger, 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tint(AppColors.danger, 0.32)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _saveError!,
              style: TextStyle(
                  fontSize: 12.5, height: 1.4, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // -- 01 site --------------------------------------------------------------

  Widget _siteSection() {
    return _FormSection(
      anchorKey: _anchors['site']!,
      step: '01',
      position: 1,
      icon: Icons.place_rounded,
      title: 'Site',
      caption: 'Where it happened',
      accent: _siteAccent,
      required: true,
      filled: _site != null,
      invalid: _invalidKey == 'site',
      child: _ChooserTile(
        accent: _siteAccent,
        icon: Icons.apartment_rounded,
        loading: _mastersLoading,
        emptyLabel: 'Select site',
        emptyHint: 'Choose from the registered locations',
        valueLabel: _site?.label,
        valueHint: _site == null ? null : 'Location ID ${_site!.id}',
        onTap: () async {
          final picked = await showIncidentOptionPicker(
            context: context,
            title: 'Select site',
            accent: _siteAccent,
            icon: Icons.place_rounded,
            options: _sites,
            selected: _site,
          );
          if (picked != null && mounted) {
            setState(() {
              _site = picked;
              if (_invalidKey == 'site') _invalidKey = null;
            });
          }
        },
      ),
    );
  }

  // -- 02 incident type -----------------------------------------------------

  Widget _typeSection() {
    return _FormSection(
      anchorKey: _anchors['type']!,
      step: '02',
      position: 2,
      icon: Icons.category_rounded,
      title: 'Incident type',
      caption: 'What kind of incident',
      accent: _typeAccent,
      required: true,
      filled: _type != null,
      invalid: _invalidKey == 'type',
      child: _mastersLoading
          ? const _TilePlaceholder(count: 6, height: 68)
          : _types.isEmpty
              ? const _Unavailable(label: 'Incident types unavailable')
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 8.0;
                    final columns =
                        (constraints.maxWidth / 92).floor().clamp(3, 6);
                    final width =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                            columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: _types.map((option) {
                        return SizedBox(
                          width: width,
                          child: _TypeTile(
                            label: option.label,
                            icon: incidentTypeIcon(option.label),
                            accent: incidentTypeAccent(option.label),
                            selected: _type == option,
                            onTap: () => setState(() {
                              _type = option;
                              if (_invalidKey == 'type') _invalidKey = null;
                            }),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
    );
  }

  // -- 03 severity ----------------------------------------------------------

  Widget _severitySection() {
    return _FormSection(
      anchorKey: _anchors['severity']!,
      step: '03',
      position: 3,
      icon: Icons.speed_rounded,
      title: 'Severity',
      caption: 'How serious',
      accent: _severityAccent,
      required: true,
      filled: _severity != null,
      invalid: _invalidKey == 'severity',
      child: _mastersLoading
          ? const _TilePlaceholder(count: 4, height: 42, columns: 1)
          : _severities.isEmpty
              ? const _Unavailable(label: 'Severity levels unavailable')
              : Column(
                  children: [
                    for (var i = 0; i < _severities.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                            bottom: i == _severities.length - 1 ? 0 : 7),
                        child: _SeverityRow(
                          option: _severities[i],
                          selected: _severity == _severities[i],
                          onTap: () => setState(() {
                            _severity = _severities[i];
                            if (_invalidKey == 'severity') _invalidKey = null;
                          }),
                        ),
                      ),
                  ],
                ),
    );
  }

  // -- 04 incident date -----------------------------------------------------

  Widget _dateSection() {
    return _FormSection(
      anchorKey: _anchors['date']!,
      step: '04',
      position: 4,
      icon: Icons.event_rounded,
      title: 'Incident date',
      caption: 'When it happened',
      accent: _dateAccent,
      required: true,
      filled: _incidentDate != null,
      invalid: _invalidKey == 'date',
      child: _DateBlock(
        date: _incidentDate,
        dayFormat: _dayNumber,
        monthFormat: _monthYear,
        accent: _dateAccent,
        onPick: _pickDate,
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate ?? now,
      firstDate: DateTime(now.year - 5),
      // An incident cannot be reported before it happens, so the calendar
      // simply does not offer the future.
      lastDate: now,
      helpText: 'Incident date',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: _dateAccent,
                onPrimary: AppColors.onPrimary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _incidentDate = picked;
      if (_invalidKey == 'date') _invalidKey = null;
    });
  }

  // -- 05 / 06 people -------------------------------------------------------

  Widget _employeeSection() {
    return _FormSection(
      anchorKey: _anchors['employee']!,
      step: '05',
      position: 5,
      icon: Icons.engineering_rounded,
      title: 'Responsible employee',
      caption: 'Who owns the incident',
      accent: _peopleAccent,
      required: true,
      filled: _employee != null,
      invalid: _invalidKey == 'employee',
      child: _PersonTile(
        accent: _peopleAccent,
        emptyLabel: 'Select employee',
        person: _employee,
        loading: _mastersLoading,
        onTap: () async {
          final picked = await showIncidentOptionPicker(
            context: context,
            title: 'Select employee',
            accent: _peopleAccent,
            icon: Icons.person_rounded,
            options: _employees,
            selected: _employee,
            avatars: true,
          );
          if (picked != null && mounted) {
            setState(() {
              _employee = picked;
              if (_invalidKey == 'employee') _invalidKey = null;
            });
          }
        },
      ),
    );
  }

  Widget _supervisorSection() {
    return _FormSection(
      anchorKey: _anchors['supervisor']!,
      step: '06',
      position: 6,
      icon: Icons.supervisor_account_rounded,
      title: 'Responsible supervisor',
      caption: 'Who oversees it',
      accent: _supervisorAccent,
      required: true,
      filled: _supervisor != null,
      invalid: _invalidKey == 'supervisor',
      child: _PersonTile(
        accent: _supervisorAccent,
        emptyLabel: 'Select supervisor',
        person: _supervisor,
        loading: _mastersLoading,
        onTap: () async {
          final picked = await showIncidentOptionPicker(
            context: context,
            title: 'Select supervisor',
            accent: _supervisorAccent,
            icon: Icons.supervisor_account_rounded,
            options: _employees,
            selected: _supervisor,
            avatars: true,
          );
          if (picked != null && mounted) {
            setState(() {
              _supervisor = picked;
              if (_invalidKey == 'supervisor') _invalidKey = null;
            });
          }
        },
      ),
    );
  }

  // -- 07 / 08 / 09 statement ----------------------------------------------

  Widget _descriptionSection() {
    return _FormSection(
      anchorKey: _anchors['description']!,
      step: '07',
      position: 7,
      icon: Icons.description_rounded,
      title: 'Incident description',
      caption: 'What happened',
      accent: _statementAccent,
      required: true,
      filled: _description.text.trim().isNotEmpty,
      invalid: _invalidKey == 'description',
      child: _StatementField(
        controller: _description,
        accent: _statementAccent,
        hint: 'Describe what happened…',
        minLines: 4,
        maxLength: _descriptionLimit,
      ),
    );
  }

  Widget _implicationSection() {
    return _FormSection(
      step: '08',
      position: 8,
      icon: Icons.report_gmailerrorred_rounded,
      title: 'Implication',
      caption: 'Optional',
      accent: AppColors.warning,
      required: false,
      filled: _implication.text.trim().isNotEmpty,
      child: _StatementField(
        controller: _implication,
        accent: AppColors.warning,
        hint: 'Describe the impact, damage or consequence…',
        minLines: 3,
      ),
    );
  }

  Widget _suggestionSection() {
    return _FormSection(
      step: '09',
      position: 9,
      icon: Icons.lightbulb_outline_rounded,
      title: 'Suggestion for future',
      caption: 'Optional',
      accent: AppColors.success,
      required: false,
      filled: _suggestion.text.trim().isNotEmpty,
      child: _StatementField(
        controller: _suggestion,
        accent: AppColors.success,
        hint: 'Add preventive action or recommendation…',
        minLines: 3,
      ),
    );
  }

  // -- 10 status ------------------------------------------------------------

  Widget _statusSection() {
    return _FormSection(
      anchorKey: _anchors['status']!,
      step: '10',
      position: 10,
      icon: Icons.flag_rounded,
      title: 'Status',
      caption: 'Open or already resolved',
      accent: _statusAccent,
      required: true,
      filled: _status.isNotEmpty,
      invalid: _invalidKey == 'status',
      child: _StatusChoice(
        value: _status,
        onChanged: (value) => setState(() => _status = value),
      ),
    );
  }

  // -- save bar -------------------------------------------------------------

  Widget _saveBar() {
    final ready = _firstInvalid == null;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 14,
              offset: const Offset(0, -3)),
        ],
      ),
      child: ContentWidthLimit(
        maxWidth: 640,
        child: _SaveButton(
          saving: _saving,
          // Stays tappable while incomplete: pressing it is how the user asks
          // "what is missing?", and the answer is a scroll plus a message. A
          // dead button would leave them guessing.
          ready: ready,
          onPressed: _save,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section shell
// ---------------------------------------------------------------------------

/// One numbered step of the report.
///
/// Carries the step number, an accent-coded glyph, the required marker and the
/// filled/invalid state. The card lifts once answered and outlines in red when
/// it is the field blocking the save, so progress and problems are both visible
/// without reading a word.
class _FormSection extends StatelessWidget {
  final GlobalKey? anchorKey;
  final String step;
  final int position;
  final IconData icon;
  final String title;
  final String caption;
  final Color accent;
  final bool required;
  final bool filled;
  final bool invalid;
  final Widget child;

  const _FormSection({
    Key? key,
    required this.step,
    required this.position,
    required this.icon,
    required this.title,
    required this.caption,
    required this.accent,
    required this.required,
    required this.filled,
    required this.child,
    this.anchorKey,
    this.invalid = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final outline = invalid
        ? AppColors.danger
        : filled
            ? AppColors.tint(accent, 0.45)
            : AppColors.divider;

    return _Stagger(
      position: position,
      child: AnimatedContainer(
        key: anchorKey,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: outline,
            width: (invalid || filled) ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: invalid
                  ? AppColors.danger.withOpacity(0.18)
                  : filled
                      ? accent.withOpacity(0.14)
                      : AppColors.shadow,
              blurRadius: (invalid || filled) ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: filled ? accent : AppColors.tint(accent, 0.13),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: filled
                          ? [
                              BoxShadow(
                                color: accent.withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Icon(icon,
                        size: 17,
                        color: filled ? AppColors.onPrimary : accent),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              step,
                              style: TextStyle(
                                fontSize: 9.5,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textFaint,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (required)
                              Text(
                                ' *',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.danger,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          caption,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // A tick appears the moment the step is answered, which is
                  // what turns a long form into visible progress.
                  AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    scale: filled ? 1 : 0,
                    child: Icon(Icons.check_circle_rounded,
                        size: 18, color: accent),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Controls
// ---------------------------------------------------------------------------

/// Tappable tile that shows a chosen value, or invites one.
class _ChooserTile extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final bool loading;
  final String emptyLabel;
  final String emptyHint;
  final String? valueLabel;
  final String? valueHint;
  final VoidCallback onTap;

  const _ChooserTile({
    Key? key,
    required this.accent,
    required this.icon,
    required this.loading,
    required this.emptyLabel,
    required this.emptyHint,
    required this.valueLabel,
    required this.valueHint,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final has = valueLabel != null && valueLabel!.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: has ? AppColors.tint(accent, 0.09) : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: has ? AppColors.tint(accent, 0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: has ? accent : AppColors.tint(accent, 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    size: 19, color: has ? AppColors.onPrimary : accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loading ? 'Loading…' : (has ? valueLabel! : emptyLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      loading
                          ? 'Please wait'
                          : (has ? valueHint! : emptyHint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 11, color: AppColors.textFaint),
                    ),
                  ],
                ),
              ),
              Icon(has ? Icons.swap_horiz_rounded : Icons.chevron_right_rounded,
                  size: 20, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Person chooser — shows the chosen face, or an empty seat.
class _PersonTile extends StatelessWidget {
  final Color accent;
  final String emptyLabel;
  final FilterOption? person;
  final bool loading;
  final VoidCallback onTap;

  const _PersonTile({
    Key? key,
    required this.accent,
    required this.emptyLabel,
    required this.person,
    required this.loading,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final has = person != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: has ? AppColors.tint(accent, 0.09) : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: has ? AppColors.tint(accent, 0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              if (has)
                InitialsAvatar(name: person!.label, size: 40, selected: true)
              else
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.tint(accent, 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_add_alt_1_rounded,
                      size: 19, color: accent),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loading ? 'Loading…' : (has ? person!.label : emptyLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      has ? 'User ID ${person!.id}' : 'Search the directory',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 11, color: AppColors.textFaint),
                    ),
                  ],
                ),
              ),
              Icon(has ? Icons.swap_horiz_rounded : Icons.search_rounded,
                  size: 20, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Incident type tile — glyph in its own hue, label beneath.
class _TypeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTile({
    Key? key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.tint(accent, 0.14) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.26),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              scale: selected ? 1.12 : 1,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? accent : AppColors.tint(accent, 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    size: 15,
                    color: selected ? AppColors.onPrimary : accent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.2,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color:
                    selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Severity rung — glyph, label, weight meter, radio.
class _SeverityRow extends StatelessWidget {
  final FilterOption option;
  final bool selected;
  final VoidCallback onTap;

  const _SeverityRow({
    Key? key,
    required this.option,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final style = severityStyleFor(option.label);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.tint(style.color, 0.13)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? style.color : Colors.transparent,
            width: 1.4,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: style.color.withOpacity(0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    selected ? style.color : AppColors.tint(style.color, 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(style.icon,
                  size: 14,
                  color: selected ? AppColors.onPrimary : style.color),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 62,
              child: Text(
                style.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  height: 6,
                  color: AppColors.divider,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: style.weight,
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            style.color.withOpacity(selected ? 1 : 0.55),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? style.color : Colors.transparent,
                border: Border.all(
                  color: selected ? style.color : AppColors.divider,
                  width: 1.6,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 12, color: AppColors.onPrimary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The date, set as a torn calendar leaf rather than a text field.
class _DateBlock extends StatelessWidget {
  final DateTime? date;
  final DateFormat dayFormat;
  final DateFormat monthFormat;
  final Color accent;
  final VoidCallback onPick;

  const _DateBlock({
    Key? key,
    required this.date,
    required this.dayFormat,
    required this.monthFormat,
    required this.accent,
    required this.onPick,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final has = date != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onPick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: has ? AppColors.tint(accent, 0.09) : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: has ? AppColors.tint(accent, 0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // The leaf: a coloured header strip over the day number, the way
              // a desk calendar reads.
              Container(
                width: 54,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.tint(accent, 0.3)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 14,
                      color: has ? accent : AppColors.textFaint,
                      alignment: Alignment.center,
                      child: Icon(Icons.event_rounded,
                          size: 9, color: AppColors.onPrimary),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        has ? dayFormat.format(date!) : '--',
                        style: TextStyle(
                          fontSize: 22,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: has ? accent : AppColors.textFaint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      has
                          ? monthFormat.format(date!).toUpperCase()
                          : 'SELECT DATE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      has
                          ? 'Tap to change the incident date'
                          : 'Open the calendar',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.textFaint),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_calendar_rounded, size: 20, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// A written statement: ruled area, accent focus, optional counter.
class _StatementField extends StatefulWidget {
  final TextEditingController controller;
  final Color accent;
  final String hint;
  final int minLines;
  final int? maxLength;

  const _StatementField({
    Key? key,
    required this.controller,
    required this.accent,
    required this.hint,
    required this.minLines,
    this.maxLength,
  }) : super(key: key);

  @override
  State<_StatementField> createState() => _StatementFieldState();
}

class _StatementFieldState extends State<_StatementField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final length = widget.controller.text.characters.length;
    final over =
        widget.maxLength != null && length > widget.maxLength! * 0.9;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _focus.hasFocus
                  ? widget.accent
                  : AppColors.tint(widget.accent, 0.18),
              width: _focus.hasFocus ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            minLines: widget.minLines,
            maxLines: widget.minLines + 4,
            maxLength: widget.maxLength,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(fontSize: 13, color: AppColors.textFaint),
              border: InputBorder.none,
              // The built-in counter is replaced below so it can carry the
              // accent and sit outside the ruled area.
              counterText: '',
            ),
          ),
        ),
        if (widget.maxLength != null) ...[
          const SizedBox(height: 6),
          Text(
            '$length / ${widget.maxLength}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: over ? AppColors.warning : AppColors.textFaint,
            ),
          ),
        ],
      ],
    );
  }
}

/// Status as two claimable states rather than a dropdown.
class _StatusChoice extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _StatusChoice({
    Key? key,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _option(
            key: 'Open',
            label: 'Open',
            caption: 'Still active',
            icon: Icons.radio_button_checked_rounded,
            colour: AppColors.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _option(
            key: 'Closed',
            label: 'Closed',
            caption: 'Already resolved',
            icon: Icons.check_circle_rounded,
            colour: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _option({
    required String key,
    required String label,
    required String caption,
    required IconData icon,
    required Color colour,
  }) {
    final selected = value == key;
    return GestureDetector(
      onTap: () => onChanged(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.tint(colour, 0.13) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? colour : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colour.withOpacity(0.24),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 21, color: selected ? colour : AppColors.textFaint),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              caption,
              style: TextStyle(fontSize: 10, color: AppColors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sticky save control.
class _SaveButton extends StatefulWidget {
  final bool saving;
  final bool ready;
  final VoidCallback onPressed;

  const _SaveButton({
    Key? key,
    required this.saving,
    required this.ready,
    required this.onPressed,
  }) : super(key: key);

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colour = widget.ready ? AppColors.primary : AppColors.textFaint;

    return GestureDetector(
      onTapDown: widget.saving ? null : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      // Guarded here as well as in _save: a second tap must never reach the
      // endpoint while the first is still in flight.
      onTap: widget.saving ? null : widget.onPressed,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.97 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.saving ? AppColors.primaryDeep : colour,
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.ready && !widget.saving
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.34),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ]
                : null,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: widget.saving
                ? Row(
                    key: const ValueKey('saving'),
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.onPrimary),
                        ),
                      ),
                      SizedBox(width: 11),
                      Text(
                        'Saving incident…',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('idle'),
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.save_rounded,
                          size: 19, color: AppColors.onPrimary),
                      SizedBox(width: 9),
                      Text(
                        'Save incident',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared pieces
// ---------------------------------------------------------------------------

class _Unavailable extends StatelessWidget {
  final String label;

  const _Unavailable({Key? key, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.cloud_off_rounded, size: 14, color: AppColors.textFaint),
        const SizedBox(width: 7),
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
        ),
      ],
    );
  }
}

class _TilePlaceholder extends StatelessWidget {
  final int count;
  final double height;
  final int? columns;

  const _TilePlaceholder({
    Key? key,
    required this.count,
    required this.height,
    this.columns,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final cols =
            columns ?? (constraints.maxWidth / 92).floor().clamp(3, 6);
        final width = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(
            count,
            (i) => Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fade + rise entrance, staggered by [position].
///
/// Owns its controller and cancels the pending start on dispose, so leaving the
/// screen mid-animation cannot leave a timer running.
class _Stagger extends StatefulWidget {
  final int position;
  final Widget child;

  const _Stagger({Key? key, required this.position, required this.child})
      : super(key: key);

  @override
  State<_Stagger> createState() => _StaggerState();
}

class _StaggerState extends State<_Stagger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    // Capped so the last section does not sit blank for a noticeable beat.
    final delay = 45 * widget.position.clamp(0, 8);
    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}
