import 'dart:convert';
import 'dart:io';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/hrm/employee_models.dart';
import 'package:ajna/screens/util.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/form_fields.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Add or edit an employee — the mobile form of the web's
/// `employee/addemployee`, which serves both the same way.
///
/// EIGHT SECTIONS, ONE RECORD
///
/// Basic, Position, Address, Education, Bank, Family, Experience and Documents
/// are one save, not eight. Both write endpoints take the whole EmployeeSaveDto
/// and REPLACE what is stored with it — so an edit loads the full record first
/// and changes it in place. Building the payload from a blank form would wipe
/// every section the form did not fill.
///
/// The sections are collapsible rather than a wizard: a supervisor adding a
/// guard fills Basic and Position and saves, while HR correcting a bank account
/// opens one panel and leaves the rest alone. A wizard makes both walk the same
/// eight steps.
class EmployeeFormScreen extends StatefulWidget {
  /// The `id` of the row being edited, or null to add.
  final int? employeeRowId;

  const EmployeeFormScreen({Key? key, this.employeeRowId}) : super(key: key);

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();

  bool get _isEdit => widget.employeeRowId != null;

  late EmployeeSaveDto _dto;
  int? _organizationId;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  // Reference data for the dropdowns, all served rather than written here.
  List<RefOption> _departments = [];
  List<RefOption> _designations = [];
  List<RefOption> _shifts = [];
  List<RefOption> _divisions = [];
  List<RefOption> _costCentres = [];
  List<RefOption> _grades = [];
  List<RefOption> _qualifications = [];
  List<RefOption> _qualificationAreas = [];
  List<RefOption> _employeeStatuses = [];
  List<ManagerOption> _managers = [];
  List<RoleOption> _roles = [];
  List<ProjectOption> _projects = [];
  List<WorkLocationOption> _workLocations = [];

  /// Documents picked in this session, keyed by the field they belong to. The
  /// backend takes them as one unnamed `employeeDocuments` array, so the order
  /// they are added in is the order they are sent.
  final Map<String, File> _pickedDocuments = {};

  /// Which panels are open. Basic starts open; the rest are a tap away so the
  /// form does not open as a wall of ninety fields.
  final Set<String> _open = {'basic'};

  final Map<String, TextEditingController> _text = {};
  final Map<String, TextEditingController> _menuSearch = {};

  static const List<_DocumentSlot> _documentSlots = [
    _DocumentSlot('adharUrl', 'Aadhaar'),
    _DocumentSlot('panUrl', 'PAN'),
    _DocumentSlot('voterIdUrl', 'Voter ID'),
    _DocumentSlot('passPortUrl', 'Passport'),
    _DocumentSlot('rationCardUrl', 'Ration card'),
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    for (final controller in _menuSearch.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// A controller per field, created once and owned by the state.
  ///
  /// Built on demand rather than declared up front — ninety fields across eight
  /// sections, most of which a given edit never opens.
  TextEditingController _controller(String key, String initial) {
    return _text.putIfAbsent(key, () => TextEditingController(text: initial));
  }

  TextEditingController _searchController(String key) {
    return _menuSearch.putIfAbsent(key, () => TextEditingController());
  }

  // ------------------------------------------------------------------ load

  Future<void> _bootstrap() async {
    _organizationId = await Util.getOrganizationId();

    await _loadReferenceData();

    if (_isEdit) {
      await _loadEmployee();
    } else {
      _dto = EmployeeSaveDto.blank(organizationId: _organizationId ?? 0);
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadEmployee() async {
    try {
      final response = await ApiService.getEmployeeById(widget.employeeRowId!);
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          _dto = EmployeeSaveDto.fromJson(decoded);
          // Older records can come back without an organisation on them; the
          // save needs one, so the signed-in user's stands in.
          _dto.employeeBean.organizationId ??= _organizationId;
          return;
        }
      }
      debugPrint(
          'Employee form: load failed ${response.statusCode} ${response.body}');
      _dto = EmployeeSaveDto.blank(organizationId: _organizationId ?? 0);
      _loadError = 'Could not load this employee. Please go back and retry.';
    } catch (e) {
      debugPrint('Employee form: load error $e');
      _dto = EmployeeSaveDto.blank(organizationId: _organizationId ?? 0);
      _loadError = 'Could not reach the server. Please go back and retry.';
    }
  }

  Future<void> _loadReferenceData() async {
    Future<List<T>> fetchList<T>(
      Future<dynamic> Function() request,
      T Function(Map<String, dynamic>) parse,
      String what,
    ) async {
      try {
        final response = await request();
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is List) {
            return decoded
                .whereType<Map<String, dynamic>>()
                .map(parse)
                .toList();
          }
        }
        debugPrint('Employee form: $what failed ${response.statusCode}');
      } catch (e) {
        debugPrint('Employee form: $what error $e');
      }
      return <T>[];
    }

    Future<List<RefOption>> refs(String type) => fetchList(
        () => ApiService.getCommonReferenceDetails(type),
        RefOption.fromJson,
        type);

    final results = await Future.wait([
      refs('Department_Type'),
      refs('Designation_Type'),
      refs('Shift_Timings'),
      refs('Divisions'),
      refs('cost_center'),
      refs('Grades'),
      refs('Qualification_Type'),
      refs('Qualification_Area'),
      refs('Employee_Status'),
      fetchList(() => ApiService.fetchOrgManagers(_organizationId!),
          ManagerOption.fromJson, 'managers'),
      fetchList(() => ApiService.fetchOrgRoles(_organizationId!),
          RoleOption.fromJson, 'roles'),
      fetchList(() => ApiService.fetchOrgProjects(_organizationId!),
          ProjectOption.fromJson, 'projects'),
      fetchList(() => ApiService.fetchLocation(_organizationId!),
          WorkLocationOption.fromJson, 'work locations'),
    ]);

    if (!mounted) return;
    _departments = results[0] as List<RefOption>;
    _designations = results[1] as List<RefOption>;
    _shifts = results[2] as List<RefOption>;
    _divisions = results[3] as List<RefOption>;
    _costCentres = results[4] as List<RefOption>;
    _grades = results[5] as List<RefOption>;
    _qualifications = results[6] as List<RefOption>;
    _qualificationAreas = results[7] as List<RefOption>;
    _employeeStatuses = results[8] as List<RefOption>;
    _managers = results[9] as List<ManagerOption>;
    _roles = results[10] as List<RoleOption>;
    _projects = results[11] as List<ProjectOption>;
    _workLocations = results[12] as List<WorkLocationOption>;
  }

  // ------------------------------------------------------------------ save

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      // A failed field can be inside a collapsed panel, where the red outline
      // is invisible. Say which section rather than leaving the supervisor
      // opening all eight to find it.
      _toast(_firstInvalidSectionMessage(), error: true);
      return;
    }
    if (_dto.employeeBean.dateOfBirth == null) {
      _openSection('basic');
      _toast('Date of birth is required.', error: true);
      return;
    }
    if (_dto.employeeBean.dateOfJoining == null) {
      _openSection('position');
      _toast('Date of joining is required.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      _dto.employeeBean.organizationId = _organizationId;
      // The form-status id is reference data, not a constant: 'ews' marks a
      // newly submitted employee and 'esd' one that has been sent on. The web
      // resolves it the same way rather than hard-coding the number.
      final statusId = await _formStatusId(_isEdit ? 'esd' : 'ews');
      if (statusId != null) {
        _dto.employeeBean.formStatusOne = statusId;
      }

      final payload = jsonEncode(_dto.toJson());
      final documents = _pickedDocuments.values.toList();

      final response = _isEdit
          ? await ApiService.updateEmployee(payload, documents)
          : await ApiService.submitEmployee(payload, documents);

      if (ApiService.isSuccess(response.statusCode)) {
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      debugPrint(
          'Employee form: save failed ${response.statusCode} ${response.body}');
      _toast(
          _serverMessage(response.body) ?? 'Could not save. Please try again.',
          error: true);
    } catch (e) {
      debugPrint('Employee form: save error $e');
      _toast('Could not reach the server. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<int?> _formStatusId(String refKey) async {
    try {
      final response = await ApiService.getCommonReferenceByKey(refKey);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['id'] != null) {
          return int.tryParse('${decoded['id']}');
        }
      }
      debugPrint('Employee form: status $refKey failed ${response.statusCode}');
    } catch (e) {
      debugPrint('Employee form: status $refKey error $e');
    }
    // The save is still valid without it — the web treats this the same way.
    return null;
  }

  String? _serverMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      final message = decoded is Map ? decoded['message'] : null;
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    } catch (_) {
      // Not the JSON error shape — the friendly fallback stands.
    }
    return null;
  }

  String _firstInvalidSectionMessage() {
    final bean = _dto.employeeBean;
    if (bean.employeeId.trim().isEmpty ||
        bean.firstName.trim().isEmpty ||
        bean.email.trim().isEmpty ||
        bean.phoneNumber.trim().isEmpty ||
        bean.gender.trim().isEmpty ||
        bean.nationalId.trim().isEmpty) {
      _openSection('basic');
      return 'Basic details are incomplete.';
    }
    _openSection('position');
    return 'Position details are incomplete.';
  }

  void _openSection(String key) {
    if (!_open.contains(key)) {
      setState(() => _open.add(key));
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
  }

  // ------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.heroGradient,
              stops: AppColors.heroStops,
            ),
          ),
        ),
        title: Text(
          _isEdit ? 'Update Employee' : 'Add Employee',
          style: TextStyle(
            fontSize: screenWidth > 600 ? 22 : 18,
            color: AppColors.onPrimary,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.onPrimary),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ContentWidthLimit(
              maxWidth: 760,
              child: Column(
                children: [
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        children: [
                          if (_loadError != null) ...[
                            _banner(_loadError!),
                            const SizedBox(height: 12),
                          ],
                          _basicSection(),
                          _positionSection(),
                          _addressSection(),
                          _educationSection(),
                          _bankSection(),
                          _familySection(),
                          _experienceSection(),
                          _documentsSection(),
                        ],
                      ),
                    ),
                  ),
                  _footer(),
                ],
              ),
            ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.divider),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('CANCEL'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onPrimary),
                    )
                  : Text(_isEdit ? 'UPDATE' : 'SUBMIT',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- sections

  Widget _section({
    required String id,
    required String title,
    required IconData icon,
    String? subtitle,
    required List<Widget> children,
  }) {
    final expanded = _open.contains(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (expanded) {
                _open.remove(id);
              } else {
                _open.add(id);
              }
            }),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: TextStyle(
                                  color: AppColors.textFaint, fontSize: 11)),
                        ],
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
        ],
      ),
    );
  }

  Widget _basicSection() {
    final bean = _dto.employeeBean;
    return _section(
      id: 'basic',
      title: 'Basic Details',
      icon: Icons.badge_outlined,
      subtitle: 'Required',
      children: [
        _field('employeeId', 'Employee number', bean.employeeId,
            (v) => bean.employeeId = v,
            required: true),
        _row(
          _field('firstName', 'First name', bean.firstName,
              (v) => bean.firstName = v,
              required: true),
          _field(
              'lastName', 'Last name', bean.lastName, (v) => bean.lastName = v),
        ),
        _field('email', 'Email', bean.email, (v) => bean.email = v,
            required: true,
            keyboardType: TextInputType.emailAddress, validator: (value) {
          final text = (value ?? '').trim();
          if (text.isEmpty) return 'Required';
          final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
          return ok ? null : 'Enter a valid email';
        }),
        _field('phoneNumber', 'Phone number', bean.phoneNumber,
            (v) => bean.phoneNumber = v,
            required: true,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            digitsOnly: true, validator: (value) {
          final text = (value ?? '').trim();
          if (text.isEmpty) return 'Required';
          return RegExp(r'^[0-9]{10}$').hasMatch(text)
              ? null
              : 'Must be 10 digits';
        }),
        _dateField('Date of birth', bean.dateOfBirth,
            (d) => setState(() => bean.dateOfBirth = d),
            required: true, lastDate: DateTime.now()),
        _choice('Gender', bean.gender, const ['Male', 'Female', 'Other'],
            (v) => setState(() => bean.gender = v)),
        // Aadhaar (12 digits) or PAN (ABCDE1234F) — the same rule the web
        // applies, so a record entered on a phone is accepted by both.
        _field('nationalId', 'Aadhaar / PAN', bean.nationalId,
            (v) => bean.nationalId = v,
            required: true, validator: (value) {
          final text = (value ?? '').trim().toUpperCase();
          if (text.isEmpty) return 'Required';
          final ok =
              RegExp(r'^([0-9]{12}|[A-Z]{5}[0-9]{4}[A-Z])$').hasMatch(text);
          return ok ? null : '12-digit Aadhaar or a PAN like ABCDE1234F';
        }),
        _field('panId', 'PAN number', bean.panId, (v) => bean.panId = v),
        _row(
          _field('title', 'Title', bean.title, (v) => bean.title = v),
          _field('fatherName', "Father's name", bean.fatherName,
              (v) => bean.fatherName = v),
        ),
        _choice(
            'Marital status',
            bean.maritalStatus,
            const ['Single', 'Married', 'Divorced', 'Widowed'],
            (v) => setState(() => bean.maritalStatus = v)),
        _dateField('Marriage date', bean.marriageDate,
            (d) => setState(() => bean.marriageDate = d),
            lastDate: DateTime.now()),
        _field('spouseName', 'Spouse name', bean.spouseName,
            (v) => bean.spouseName = v),
        _row(
          _field(
              'religion', 'Religion', bean.religion, (v) => bean.religion = v),
          _field('cast', 'Caste', bean.cast, (v) => bean.cast = v),
        ),
        _row(
          _field('bloodGroup', 'Blood group', bean.bloodGroup,
              (v) => bean.bloodGroup = v),
          _field('identificationMark', 'Identification mark',
              bean.identificationMark, (v) => bean.identificationMark = v),
        ),
        _row(
          _field('height', 'Height', bean.height, (v) => bean.height = v),
          _field('weight', 'Weight', bean.weight, (v) => bean.weight = v),
        ),
        _row(
          _field('nationality', 'Nationality', bean.nationality,
              (v) => bean.nationality = v),
          _field('country', 'Country', bean.country, (v) => bean.country = v),
        ),
        _field('plcaeOfBirth', 'Place of birth', bean.plcaeOfBirth,
            (v) => bean.plcaeOfBirth = v),
        _choice(
            'Physically challenged',
            bean.physicallyChallenged,
            const ['Yes', 'No'],
            (v) => setState(() => bean.physicallyChallenged = v)),
        _field('personalEmail', 'Personal email', bean.personalEmail,
            (v) => bean.personalEmail = v,
            keyboardType: TextInputType.emailAddress),
        _field('address', 'Address', bean.address, (v) => bean.address = v,
            maxLines: 2),
        _row(
          _field('city', 'City', bean.city, (v) => bean.city = v),
          _field('state', 'State', bean.state, (v) => bean.state = v),
        ),
        _field('postalCode', 'Postal code', bean.postalCode?.toString() ?? '',
            (v) => bean.postalCode = int.tryParse(v.trim()),
            keyboardType: TextInputType.number, digitsOnly: true),
        _row(
          _field('emergencyContactName', 'Emergency contact',
              bean.emergencyContactName, (v) => bean.emergencyContactName = v),
          _field(
              'emergencyContactNumber',
              'Emergency number',
              bean.emergencyContactNumber,
              (v) => bean.emergencyContactNumber = v,
              keyboardType: TextInputType.phone,
              digitsOnly: true),
        ),
        _field('policeStationLimits', 'Police station limits',
            bean.policeStationLimits, (v) => bean.policeStationLimits = v),
        _row(
          _field('esiNumber', 'ESI number', bean.esiNumber,
              (v) => bean.esiNumber = v),
          _field('pfUanNo', 'PF UAN number', bean.pfUanNo,
              (v) => bean.pfUanNo = v),
        ),
        _choice(
            'Create a login for this employee',
            bean.isAddAsUserNeeded,
            const ['Yes', 'No'],
            (v) => setState(() => bean.isAddAsUserNeeded = v)),
      ],
    );
  }

  Widget _positionSection() {
    final bean = _dto.employeeBean;
    return _section(
      id: 'position',
      title: 'Position Details',
      icon: Icons.work_outline,
      subtitle: 'Required',
      children: [
        _dateField('Date of joining', bean.dateOfJoining,
            (d) => setState(() => bean.dateOfJoining = d),
            required: true),
        _searchableRefDropdown<ProjectOption>(
          key: 'projectAssigned',
          label: 'Project',
          value: bean.projectAssigned,
          items: _projects,
          idOf: (p) => p.projectId,
          labelOf: (p) => p.projectName,
          onChanged: (v) => setState(() => bean.projectAssigned = v),
          required: true,
        ),
        _searchableRefDropdown<ManagerOption>(
          key: 'reportingManager',
          label: 'Reporting manager',
          value: bean.reportingManager,
          items: _managers,
          idOf: (m) => m.userId,
          labelOf: (m) => m.userName,
          onChanged: (v) => setState(() => bean.reportingManager = v),
          required: true,
        ),
        _searchableRefDropdown<ManagerOption>(
          key: 'attendanceManager',
          label: 'Attendance manager',
          value: bean.attendanceManager,
          items: _managers,
          idOf: (m) => m.userId,
          labelOf: (m) => m.userName,
          onChanged: (v) => setState(() => bean.attendanceManager = v),
          required: true,
        ),
        _searchableRefDropdown<RoleOption>(
          key: 'employeeRoleId',
          label: 'Role',
          value: bean.employeeRoleId,
          items: _roles,
          idOf: (r) => r.roleId,
          labelOf: (r) => r.roleName,
          onChanged: (v) => setState(() => bean.employeeRoleId = v),
          required: true,
        ),
        _searchableRefDropdown<WorkLocationOption>(
          key: 'workLocation',
          label: 'Work location',
          value: bean.workLocation,
          items: _workLocations,
          idOf: (l) => l.id,
          labelOf: (l) => l.location,
          onChanged: (v) => setState(() => bean.workLocation = v),
          required: true,
        ),
        _refDropdown('Department', _departments, bean.department,
            (v) => setState(() => bean.department = v),
            required: true),
        _refDropdownByValue('Designation', _designations, bean.designation,
            (v) => setState(() => bean.designation = v),
            required: true),
        _refDropdown('Shift', _shifts, bean.shiftId,
            (v) => setState(() => bean.shiftId = v),
            required: true),
        // `shift` is a second, free-text column alongside shiftId. The web
        // requires both, so the chosen shift's label is mirrored into it.
        _field('shift', 'Shift label', bean.shift, (v) => bean.shift = v,
            required: true),
        _refDropdownByValue('Employee status', _employeeStatuses,
            bean.employeeStatus, (v) => setState(() => bean.employeeStatus = v),
            required: true),
        _choice('In probation', bean.isInProbation, const ['Yes', 'No'],
            (v) => setState(() => bean.isInProbation = v)),
        _field(
            'probationPeriod',
            'Probation period (months)',
            bean.probationPeriod?.toString() ?? '',
            (v) => bean.probationPeriod = int.tryParse(v.trim()),
            keyboardType: TextInputType.number,
            digitsOnly: true),
        _dateField('Confirmation date', bean.confirmationDate,
            (d) => setState(() => bean.confirmationDate = d)),
        _refDropdown('Division', _divisions, bean.divisionId,
            (v) => setState(() => bean.divisionId = v)),
        _refDropdown('Cost centre', _costCentres, bean.costCenterId,
            (v) => setState(() => bean.costCenterId = v)),
        _refDropdown('Grade', _grades, bean.gradeId,
            (v) => setState(() => bean.gradeId = v)),
        _field('company', 'Company', bean.company, (v) => bean.company = v),
        _choice('PMS eligible', bean.isPmsEligible, const ['Yes', 'No'],
            (v) => setState(() => bean.isPmsEligible = v)),
        const SizedBox(height: 6),
        Text('Exit',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _dateField('Date of resignation', bean.dateOfResignation,
            (d) => setState(() => bean.dateOfResignation = d)),
        _dateField('Notice period end', bean.noticePeriodEndDate,
            (d) => setState(() => bean.noticePeriodEndDate = d)),
        _dateField('Last working day', bean.lastWorkingDay,
            (d) => setState(() => bean.lastWorkingDay = d)),
      ],
    );
  }

  Widget _addressSection() {
    final permanent = _dto.addressBeanList[0];
    final temporary = _dto.addressBeanList[1];
    return _section(
      id: 'address',
      title: 'Address Details',
      icon: Icons.home_outlined,
      subtitle: 'Permanent and temporary',
      children: [
        ..._addressFields('perm', 'Permanent', permanent),
        const SizedBox(height: 12),
        Divider(color: AppColors.divider),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text('Temporary address',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(
              onPressed: () => _copyPermanentAddress(),
              icon: const Icon(Icons.copy_all, size: 16),
              label: const Text('Same as permanent'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        ..._addressFields('temp', null, temporary),
        const SizedBox(height: 12),
        Text('Point of contact',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _choiceRaw(
          permanent.isPointOfContact == 'Yes' ? 'Permanent' : 'Temporary',
          const ['Permanent', 'Temporary'],
          (v) => setState(() {
            final isPermanent = v == 'Permanent';
            permanent.isPointOfContact = isPermanent ? 'Yes' : 'No';
            temporary.isPointOfContact = isPermanent ? 'No' : 'Yes';
          }),
        ),
      ],
    );
  }

  List<Widget> _addressFields(
      String prefix, String? heading, EmployeeAddress address) {
    return [
      if (heading != null) ...[
        Text('$heading address',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
      ],
      _row(
        // Integer on the backend, so anything with a letter in it cannot be
        // stored — flagged here rather than silently dropped on save.
        _field('${prefix}DoorNo', 'Door no', address.doorNo?.toString() ?? '',
            (v) => address.doorNo = int.tryParse(v.trim()),
            keyboardType: TextInputType.number, digitsOnly: true),
        _field('${prefix}Owner', 'House owner', address.houseOwnerName,
            (v) => address.houseOwnerName = v),
      ),
      _field('${prefix}Street', 'Street or road', address.streetOrRoad,
          (v) => address.streetOrRoad = v),
      _row(
        _field('${prefix}Post', 'Post', address.post, (v) => address.post = v),
        _field('${prefix}City', 'City', address.city, (v) => address.city = v),
      ),
      _row(
        _field(
            '${prefix}State', 'State', address.state, (v) => address.state = v),
        _field('${prefix}Pincode', 'Pincode', address.pincode,
            (v) => address.pincode = v,
            keyboardType: TextInputType.number, digitsOnly: true),
      ),
      _field('${prefix}Police', 'Police station limits',
          address.policeStationLimits, (v) => address.policeStationLimits = v),
    ];
  }

  void _copyPermanentAddress() {
    final permanent = _dto.addressBeanList[0];
    final temporary = _dto.addressBeanList[1];
    setState(() {
      temporary
        ..doorNo = permanent.doorNo
        ..houseOwnerName = permanent.houseOwnerName
        ..streetOrRoad = permanent.streetOrRoad
        ..post = permanent.post
        ..city = permanent.city
        ..pincode = permanent.pincode
        ..state = permanent.state
        ..policeStationLimits = permanent.policeStationLimits;
      // The visible text lives in the controllers, so they have to be moved
      // across too — updating the model alone leaves the old text on screen.
      _setText('tempDoorNo', permanent.doorNo?.toString() ?? '');
      _setText('tempOwner', permanent.houseOwnerName);
      _setText('tempStreet', permanent.streetOrRoad);
      _setText('tempPost', permanent.post);
      _setText('tempCity', permanent.city);
      _setText('tempState', permanent.state);
      _setText('tempPincode', permanent.pincode);
      _setText('tempPolice', permanent.policeStationLimits);
    });
  }

  void _setText(String key, String value) {
    final controller = _text[key];
    if (controller != null) controller.text = value;
  }

  Widget _educationSection() {
    return _section(
      id: 'education',
      title: 'Education Details',
      icon: Icons.school_outlined,
      subtitle: '${_dto.employeeEducationBeanList.length} entered',
      children: [
        ..._dto.employeeEducationBeanList.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return _repeatable(
            title: 'Education ${index + 1}',
            onRemove: _dto.employeeEducationBeanList.length > 1
                ? () => setState(
                    () => _dto.employeeEducationBeanList.removeAt(index))
                : null,
            children: [
              _refDropdown('Qualification', _qualifications, row.qualification,
                  (v) => setState(() => row.qualification = v),
                  keySuffix: 'edu$index'),
              _refDropdown(
                  'Qualification area',
                  _qualificationAreas,
                  row.qualificationArea,
                  (v) => setState(() => row.qualificationArea = v),
                  keySuffix: 'edu$index'),
              _field('edu${index}Institute', 'Institute', row.institute,
                  (v) => row.institute = v),
              _row(
                _field('edu${index}Grade', 'Grade', row.grade,
                    (v) => row.grade = v),
                const SizedBox.shrink(),
              ),
              _row(
                _dateField('Start', row.startDate,
                    (d) => setState(() => row.startDate = d),
                    lastDate: DateTime.now()),
                _dateField(
                    'End', row.endDate, (d) => setState(() => row.endDate = d),
                    lastDate: DateTime.now()),
              ),
              _field('edu${index}Remarks', 'Remarks', row.remarks,
                  (v) => row.remarks = v),
            ],
          );
        }),
        _addRowButton(
            'Add education',
            () => setState(
                () => _dto.employeeEducationBeanList.add(EmployeeEducation()))),
      ],
    );
  }

  Widget _bankSection() {
    final bank = _dto.employeeBankDetails;
    return _section(
      id: 'bank',
      title: 'Bank Details',
      icon: Icons.account_balance_outlined,
      children: [
        _field(
            'bankName', 'Bank name', bank.bankName, (v) => bank.bankName = v),
        _field('bankAccountNumber', 'Account number', bank.bankAccountNumber,
            (v) => bank.bankAccountNumber = v,
            keyboardType: TextInputType.number, digitsOnly: true),
        _field('bankIfscCode', 'IFSC code', bank.bankIfscCode,
            (v) => bank.bankIfscCode = v.toUpperCase(),
            upperCase: true),
        _field('accountType', 'Account type', bank.accountType,
            (v) => bank.accountType = v),
        _dateField('Account opening date', bank.accountOpeningDate,
            (d) => setState(() => bank.accountOpeningDate = d),
            lastDate: DateTime.now()),
        _row(
          _field('bankAadhaar', 'Aadhaar number', bank.aadhaarNumber,
              (v) => bank.aadhaarNumber = v,
              keyboardType: TextInputType.number, digitsOnly: true),
          _field('bankPan', 'PAN number', bank.panNumber,
              (v) => bank.panNumber = v,
              upperCase: true),
        ),
        _field('mobileNumber', 'Mobile number', bank.mobileNumber,
            (v) => bank.mobileNumber = v,
            keyboardType: TextInputType.phone, digitsOnly: true),
        const SizedBox(height: 6),
        // Yes/No strings, not booleans — the columns are varchars and a real
        // boolean is rejected.
        _choice('ESIC', bank.esicInclude, const ['Yes', 'No'],
            (v) => setState(() => bank.esicInclude = v)),
        if (bank.esicInclude == 'Yes')
          _field('esicNumber', 'ESIC number', bank.esicNumber,
              (v) => bank.esicNumber = v),
        _choice('PF', bank.pfInclude, const ['Yes', 'No'],
            (v) => setState(() => bank.pfInclude = v)),
        if (bank.pfInclude == 'Yes') ...[
          _field(
              'pfNumber', 'PF number', bank.pfNumber, (v) => bank.pfNumber = v),
          _field('uanNumber', 'UAN number', bank.uanNumber,
              (v) => bank.uanNumber = v),
        ],
        _choice('LWF', bank.lwfInclude, const ['Yes', 'No'],
            (v) => setState(() => bank.lwfInclude = v)),
      ],
    );
  }

  Widget _familySection() {
    return _section(
      id: 'family',
      title: 'Family Details',
      icon: Icons.family_restroom_outlined,
      subtitle: '${_dto.employeeFamilyBeanList.length} entered',
      children: [
        ..._dto.employeeFamilyBeanList.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return _repeatable(
            title: 'Member ${index + 1}',
            onRemove: _dto.employeeFamilyBeanList.length > 1
                ? () =>
                    setState(() => _dto.employeeFamilyBeanList.removeAt(index))
                : null,
            children: [
              _field('fam${index}Name', 'Name', row.name, (v) => row.name = v),
              _row(
                _field('fam${index}Rel', 'Relationship', row.relationship,
                    (v) => row.relationship = v),
                _field('fam${index}Contact', 'Contact no', row.contactNo,
                    (v) => row.contactNo = v,
                    keyboardType: TextInputType.phone, digitsOnly: true),
              ),
              _row(
                _dateField('Date of birth', row.dateOfBirth,
                    (d) => setState(() => row.dateOfBirth = d),
                    lastDate: DateTime.now()),
                _field('fam${index}Age', 'Age', row.age?.toString() ?? '',
                    (v) => row.age = int.tryParse(v.trim()),
                    keyboardType: TextInputType.number, digitsOnly: true),
              ),
              _field(
                  'fam${index}Email', 'Email', row.email, (v) => row.email = v,
                  keyboardType: TextInputType.emailAddress),
              _field('fam${index}Address', 'Address', row.address,
                  (v) => row.address = v,
                  maxLines: 2),
              _row(
                _field(
                    'fam${index}City', 'City', row.city, (v) => row.city = v),
                _field('fam${index}Pin', 'Pincode', row.pincode,
                    (v) => row.pincode = v,
                    keyboardType: TextInputType.number, digitsOnly: true),
              ),
              _row(
                _field('fam${index}Country', 'Country', row.country,
                    (v) => row.country = v),
                _field('fam${index}MemberId', 'Family member id',
                    row.familyMemberId, (v) => row.familyMemberId = v),
              ),
              _field('fam${index}Remarks', 'Remarks', row.remarks,
                  (v) => row.remarks = v),
            ],
          );
        }),
        _addRowButton(
            'Add family member',
            () => setState(
                () => _dto.employeeFamilyBeanList.add(EmployeeFamily()))),
      ],
    );
  }

  Widget _experienceSection() {
    return _section(
      id: 'experience',
      title: 'Employee Experience',
      icon: Icons.history_edu_outlined,
      subtitle: '${_dto.employeeExperienceBeanList.length} entered',
      children: [
        ..._dto.employeeExperienceBeanList.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return _repeatable(
            title: 'Experience ${index + 1}',
            onRemove: _dto.employeeExperienceBeanList.length > 1
                ? () => setState(
                    () => _dto.employeeExperienceBeanList.removeAt(index))
                : null,
            children: [
              _field('exp${index}Company', 'Company', row.companyName,
                  (v) => row.companyName = v),
              _row(
                _field('exp${index}Title', 'Job title', row.jobTitle,
                    (v) => row.jobTitle = v),
                _field('exp${index}Desig', 'Designation', row.designation,
                    (v) => row.designation = v),
              ),
              _row(
                _dateField('Start', row.startDate,
                    (d) => setState(() => row.startDate = d),
                    lastDate: DateTime.now()),
                _dateField(
                    'End', row.endDate, (d) => setState(() => row.endDate = d),
                    lastDate: DateTime.now()),
              ),
              _field('exp${index}Desc', 'Job description', row.jobdescription,
                  (v) => row.jobdescription = v,
                  maxLines: 3),
            ],
          );
        }),
        _addRowButton(
            'Add experience',
            () => setState(() =>
                _dto.employeeExperienceBeanList.add(EmployeeExperience()))),
      ],
    );
  }

  Widget _documentsSection() {
    return _section(
      id: 'documents',
      title: 'Documents',
      icon: Icons.folder_outlined,
      subtitle: _pickedDocuments.isEmpty
          ? 'Aadhaar, PAN, Voter ID, Passport, Ration card'
          : '${_pickedDocuments.length} ready to upload',
      children: [
        for (final slot in _documentSlots) _documentRow(slot),
        const SizedBox(height: 8),
        Text(
          'Files are uploaded with the record when you save. A document already '
          'on the record stays there unless you pick a new one.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 11),
        ),
      ],
    );
  }

  Widget _documentRow(_DocumentSlot slot) {
    final picked = _pickedDocuments[slot.field];
    final stored = _storedDocument(slot.field);
    final hasStored = stored.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            picked != null
                ? Icons.check_circle
                : hasStored
                    ? Icons.description_outlined
                    : Icons.upload_file_outlined,
            size: 18,
            color: picked != null
                ? AppColors.success
                : hasStored
                    ? AppColors.primary
                    : AppColors.textFaint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.label,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(
                  picked != null
                      ? picked.path.split('/').last
                      : hasStored
                          ? 'On record'
                          : 'Not uploaded',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (picked != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
              onPressed: () =>
                  setState(() => _pickedDocuments.remove(slot.field)),
            ),
          TextButton(
            onPressed: () => _pickDocument(slot),
            child: Text(picked != null || hasStored ? 'Replace' : 'Upload',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _storedDocument(String field) {
    final bean = _dto.employeeBean;
    switch (field) {
      case 'adharUrl':
        return bean.adharUrl;
      case 'panUrl':
        return bean.panUrl;
      case 'voterIdUrl':
        return bean.voterIdUrl;
      case 'passPortUrl':
        return bean.passPortUrl;
      case 'rationCardUrl':
        return bean.rationCardUrl;
      default:
        return '';
    }
  }

  Future<void> _pickDocument(_DocumentSlot slot) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      setState(() => _pickedDocuments[slot.field] = File(path));
    } catch (e) {
      debugPrint('Employee form: document pick error $e');
      _toast('Could not open the file picker.', error: true);
    }
  }

  // ----------------------------------------------------------------- pieces

  Widget _row(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }

  Widget _field(
    String key,
    String label,
    String initial,
    ValueChanged<String> onChanged, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    bool digitsOnly = false,
    bool upperCase = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controller(key, initial),
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        textCapitalization:
            upperCase ? TextCapitalization.characters : TextCapitalization.none,
        inputFormatters: [
          if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
          if (upperCase) _UpperCaseFormatter(),
        ],
        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        cursorColor: AppColors.primary,
        decoration: fieldDecoration(required ? '$label *' : label)
            .copyWith(counterText: ''),
        onChanged: onChanged,
        validator: validator ??
            (required
                ? (value) => (value ?? '').trim().isEmpty ? 'Required' : null
                : null),
      ),
    );
  }

  Widget _dateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged, {
    bool required = false,
    DateTime? lastDate,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(1940),
            lastDate: lastDate ?? DateTime(2100),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: AppColors.primary,
                  onPrimary: AppColors.onPrimary,
                  onSurface: AppColors.textPrimary,
                ),
              ),
              child: child!,
            ),
          );
          if (picked != null) onChanged(picked);
        },
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: fieldDecoration(required ? '$label *' : label),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value == null ? '—' : DateFormat('dd MMM yyyy').format(value),
                  style: TextStyle(
                      color: value == null
                          ? AppColors.textFaint
                          : AppColors.textPrimary,
                      fontSize: 14),
                ),
              ),
              if (value != null)
                InkWell(
                  onTap: () => onChanged(null),
                  child:
                      Icon(Icons.close, size: 16, color: AppColors.textFaint),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.calendar_today,
                  size: 15, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  /// A short fixed list, as chips. Faster than a dropdown for two or three
  /// options and shows what was chosen without opening anything.
  Widget _choice(String label, String value, List<String> options,
      ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          _choiceRaw(value, options, onChanged),
        ],
      ),
    );
  }

  Widget _choiceRaw(
      String value, List<String> options, ValueChanged<String> onChanged) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final selected = value.toLowerCase() == option.toLowerCase();
        return ChoiceChip(
          label: Text(option),
          selected: selected,
          showCheckmark: false,
          backgroundColor: AppColors.surfaceAlt,
          selectedColor: AppColors.primary,
          side: BorderSide(color: AppColors.divider),
          labelStyle: TextStyle(
            color: selected ? AppColors.onPrimary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) => onChanged(option),
        );
      }).toList(),
    );
  }

  /// A reference dropdown that stores the row's id.
  Widget _refDropdown(String label, List<RefOption> options, int? value,
      ValueChanged<int?> onChanged,
      {bool required = false, String keySuffix = ''}) {
    // A value that is not in the list would throw rather than render — an
    // option that has since been deactivated shows as unset instead.
    final safe = options.any((o) => o.id == value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField2<int?>(
        key: ValueKey('$label$keySuffix'),
        isExpanded: true,
        value: safe,
        decoration: fieldDecoration(required ? '$label *' : label),
        dropdownStyleData: menuStyle(context),
        menuItemStyleData: kMenuItemStyle,
        items: options
            .map((o) => DropdownMenuItem<int?>(
                  value: o.id,
                  child: Text(o.value, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: onChanged,
        validator:
            required ? (value) => value == null ? 'Required' : null : null,
      ),
    );
  }

  /// A reference dropdown that stores the row's LABEL rather than its id —
  /// designation and employee status are varchar columns on the employee.
  Widget _refDropdownByValue(String label, List<RefOption> options,
      String value, ValueChanged<String> onChanged,
      {bool required = false}) {
    final safe = options.any((o) => o.value == value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField2<String?>(
        isExpanded: true,
        value: safe,
        decoration: fieldDecoration(required ? '$label *' : label),
        dropdownStyleData: menuStyle(context),
        menuItemStyleData: kMenuItemStyle,
        items: options
            .map((o) => DropdownMenuItem<String?>(
                  value: o.value,
                  child: Text(o.value, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (v) => onChanged(v ?? ''),
        validator: required
            ? (v) => (v ?? '').trim().isEmpty ? 'Required' : null
            : null,
      ),
    );
  }

  /// A dropdown with a search box, for the lists that run long — projects,
  /// managers, roles and work locations all do at this organisation.
  Widget _searchableRefDropdown<T>({
    required String key,
    required String label,
    required int? value,
    required List<T> items,
    required int Function(T) idOf,
    required String Function(T) labelOf,
    required ValueChanged<int?> onChanged,
    bool required = false,
  }) {
    final controller = _searchController(key);
    final safe = items.any((e) => idOf(e) == value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField2<int?>(
        isExpanded: true,
        value: safe,
        decoration: fieldDecoration(required ? '$label *' : label),
        dropdownStyleData: menuStyle(context, maxHeight: 340),
        menuItemStyleData: kMenuItemStyle,
        dropdownSearchData: DropdownSearchData<int?>(
          searchController: controller,
          searchInnerWidgetHeight: kMenuSearchHeight,
          searchInnerWidget: menuSearchField(controller, 'Search $label'),
          // Matches the label shown in the row. The default compares
          // item.value.toString(), which for an int id finds nothing.
          searchMatchFn: (item, query) {
            final needle = query.trim().toLowerCase();
            if (needle.isEmpty) return true;
            final match = items.where((e) => idOf(e) == item.value);
            if (match.isEmpty) return false;
            return labelOf(match.first).toLowerCase().contains(needle);
          },
        ),
        onMenuStateChange: (isOpen) {
          if (!isOpen) controller.clear();
        },
        items: items
            .map((e) => DropdownMenuItem<int?>(
                  value: idOf(e),
                  child: Text(labelOf(e), overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: onChanged,
        validator:
            required ? (value) => value == null ? 'Required' : null : null,
      ),
    );
  }

  Widget _repeatable({
    required String title,
    required List<Widget> children,
    VoidCallback? onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              if (onRemove != null)
                InkWell(
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline,
                        size: 18, color: AppColors.danger),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _addRowButton(String label, VoidCallback onTap) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
    );
  }

  Widget _banner(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _DocumentSlot {
  final String field;
  final String label;

  const _DocumentSlot(this.field, this.label);
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
