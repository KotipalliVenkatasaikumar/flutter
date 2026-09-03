import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:ajna/main.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/connectivity_handler.dart';
import 'package:ajna/screens/facility_management/ImageFullScreen%20.dart';
import 'package:ajna/screens/incident/incident_models.dart';
import 'package:ajna/screens/incident/incident_pickers.dart';
import 'package:ajna/screens/util.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class FieldOfficerPatrol {
  final int fieldOfficerPatrolId;
  final DateTime inTime;
  final DateTime? outTime;
  final int userId;
  final String userName;
  final String phoneNumber;
  final int locationId;
  final String location;
  final int projectId;
  final String projectName;
  final int orgId;
  final String organizationName;
  final String status;
  final int qrTypeId;
  final String qrType;
  final String inImageUrl;
  final String? outImageUrl;
  final DateTime createdDate;

  FieldOfficerPatrol({
    required this.fieldOfficerPatrolId,
    required this.inTime,
    this.outTime,
    required this.userId,
    required this.userName,
    required this.phoneNumber,
    required this.locationId,
    required this.location,
    required this.projectId,
    required this.projectName,
    required this.orgId,
    required this.organizationName,
    required this.status,
    required this.qrTypeId,
    required this.qrType,
    required this.inImageUrl,
    this.outImageUrl,
    required this.createdDate,
  });

  factory FieldOfficerPatrol.fromJson(Map<String, dynamic> json) {
    return FieldOfficerPatrol(
      fieldOfficerPatrolId: json['fieldOfficerPatrolId'] ?? 0,
      inTime: DateTime.parse(json['inTime']),
      outTime:
          json['outTime'] != null ? DateTime.tryParse(json['outTime']) : null,
      userId: json['userId'] ?? 0,
      userName: json['userName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      locationId: json['locationId'] ?? 0,
      location: json['location'] ?? '',
      projectId: json['projectId'] ?? 0,
      projectName: json['projectName'] ?? '',
      orgId: json['orgId'] ?? 0,
      organizationName: json['organizationName'] ?? '',
      status: json['status'] ?? '',
      qrTypeId: json['qrTypeId'] ?? 0,
      qrType: json['qrType'] ?? '',
      inImageUrl: json['inImageUrl'] ?? '',
      outImageUrl: json['outImageUrl'], // Nullable field
      createdDate: DateTime.parse(json['createdDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fieldOfficerPatrolId': fieldOfficerPatrolId,
      'inTime': inTime.toIso8601String(),
      'outTime': outTime?.toIso8601String(), // Handle nullable field
      'userId': userId,
      'userName': userName,
      'phoneNumber': phoneNumber,
      'locationId': locationId,
      'location': location,
      'projectId': projectId,
      'projectName': projectName,
      'orgId': orgId,
      'organizationName': organizationName,
      'status': status,
      'qrTypeId': qrTypeId,
      'qrType': qrType,
      'inImageUrl': inImageUrl,
      'outImageUrl': outImageUrl, // Nullable field
      'createdDate': createdDate.toIso8601String(),
    };
  }
}

class Project {
  final int projectId;
  final String projectName;

  Project({required this.projectId, required this.projectName});

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      projectId: json['projectId'],
      projectName: json['projectName'] ?? '', // Default value if null
    );
  }
}

// ---------------------------------------------------------------------------
// Analytics + missed-visit models (fieldOfficerPatrol/analytics, /missed)
// ---------------------------------------------------------------------------

int _asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _asIntOrNull(dynamic v) =>
    v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));

class FoSummary {
  final int totalVisits;
  final int completedVisits;
  final int openVisits;
  final int? avgDurationMinutes;
  final int activeOfficers;
  final int rosterOfficers;
  final bool rosterConfigured;
  final int expectedVisits;
  final int coveredVisits;
  final int missedVisits;
  final int pendingToday;
  final int? complianceRate;

  FoSummary({
    required this.totalVisits,
    required this.completedVisits,
    required this.openVisits,
    required this.avgDurationMinutes,
    required this.activeOfficers,
    required this.rosterOfficers,
    required this.rosterConfigured,
    required this.expectedVisits,
    required this.coveredVisits,
    required this.missedVisits,
    required this.pendingToday,
    required this.complianceRate,
  });

  factory FoSummary.fromJson(Map<String, dynamic> j) => FoSummary(
        totalVisits: _asInt(j['totalVisits']),
        completedVisits: _asInt(j['completedVisits']),
        openVisits: _asInt(j['openVisits']),
        avgDurationMinutes: _asIntOrNull(j['avgDurationMinutes']),
        activeOfficers: _asInt(j['activeOfficers']),
        rosterOfficers: _asInt(j['rosterOfficers']),
        rosterConfigured: j['rosterConfigured'] == true,
        expectedVisits: _asInt(j['expectedVisits']),
        coveredVisits: _asInt(j['coveredVisits']),
        missedVisits: _asInt(j['missedVisits']),
        pendingToday: _asInt(j['pendingToday']),
        complianceRate: _asIntOrNull(j['complianceRate']),
      );
}

class FoProjectStat {
  final int projectId;
  final String projectName;
  final int visits;
  final int completedVisits;
  final int expectedVisits;
  final int coveredVisits;
  final int missedVisits;
  final int pendingToday;
  final int? complianceRate;

  FoProjectStat.fromJson(Map<String, dynamic> j)
      : projectId = _asInt(j['projectId']),
        projectName = j['projectName'] ?? '',
        visits = _asInt(j['visits']),
        completedVisits = _asInt(j['completedVisits']),
        expectedVisits = _asInt(j['expectedVisits']),
        coveredVisits = _asInt(j['coveredVisits']),
        missedVisits = _asInt(j['missedVisits']),
        pendingToday = _asInt(j['pendingToday']),
        complianceRate = _asIntOrNull(j['complianceRate']);
}

class FoOfficerStat {
  final int userId;
  final String userName;
  final String phoneNumber;
  final int visits;
  final int completedVisits;
  final int? avgDurationMinutes;
  final int expectedVisits;
  final int coveredVisits;
  final int missedVisits;
  final int pendingToday;
  final int? complianceRate;

  FoOfficerStat.fromJson(Map<String, dynamic> j)
      : userId = _asInt(j['userId']),
        userName = j['userName'] ?? '',
        phoneNumber = j['phoneNumber'] ?? '',
        visits = _asInt(j['visits']),
        completedVisits = _asInt(j['completedVisits']),
        avgDurationMinutes = _asIntOrNull(j['avgDurationMinutes']),
        expectedVisits = _asInt(j['expectedVisits']),
        coveredVisits = _asInt(j['coveredVisits']),
        missedVisits = _asInt(j['missedVisits']),
        pendingToday = _asInt(j['pendingToday']),
        complianceRate = _asIntOrNull(j['complianceRate']);
}

class FoDayStat {
  final DateTime date;
  final int visits;
  final int completedVisits;
  final int expectedVisits;
  final int missedVisits;

  FoDayStat.fromJson(Map<String, dynamic> j)
      : date = DateTime.parse(j['date']),
        visits = _asInt(j['visits']),
        completedVisits = _asInt(j['completedVisits']),
        expectedVisits = _asInt(j['expectedVisits']),
        missedVisits = _asInt(j['missedVisits']);
}

class FoAnalytics {
  final DateTime? startDate;
  final DateTime? endDate;
  final FoSummary summary;
  final List<FoProjectStat> byProject;
  final List<FoOfficerStat> byOfficer;
  final List<FoDayStat> byDay;

  FoAnalytics({
    required this.startDate,
    required this.endDate,
    required this.summary,
    required this.byProject,
    required this.byOfficer,
    required this.byDay,
  });

  factory FoAnalytics.fromJson(Map<String, dynamic> j) => FoAnalytics(
        startDate: DateTime.tryParse('${j['startDate']}'),
        endDate: DateTime.tryParse('${j['endDate']}'),
        summary: FoSummary.fromJson(j['summary'] ?? {}),
        byProject: ((j['byProject'] ?? []) as List)
            .map((e) => FoProjectStat.fromJson(e))
            .toList(),
        byOfficer: ((j['byOfficer'] ?? []) as List)
            .map((e) => FoOfficerStat.fromJson(e))
            .toList(),
        byDay: ((j['byDay'] ?? []) as List)
            .map((e) => FoDayStat.fromJson(e))
            .toList(),
      );
}

class FoMissedVisit {
  final DateTime visitDate;
  final int projectId;
  final String projectName;
  final int userId;
  final String userName;
  final String phoneNumber;
  final String status; // Missed | Pending

  FoMissedVisit.fromJson(Map<String, dynamic> j)
      : visitDate = DateTime.parse(j['visitDate']),
        projectId = _asInt(j['projectId']),
        projectName = j['projectName'] ?? '',
        userId = _asInt(j['userId']),
        userName = j['userName'] ?? '',
        phoneNumber = j['phoneNumber'] ?? '',
        status = j['status'] ?? 'Missed';

  bool get isPending => status == 'Pending';
}

class FoReportsScreen extends StatefulWidget {
  @override
  _FoReportsScreenState createState() => _FoReportsScreenState();
}

class _FoReportsScreenState extends State<FoReportsScreen>
    with SingleTickerProviderStateMixin {
  final ConnectivityHandler connectivityHandler = ConnectivityHandler();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _missedScrollController = ScrollController();
  final TextEditingController _userName = TextEditingController();
  late final TabController _tabController;

  // Search is sent to the server only after the user pauses typing.
  Timer? _searchDebounce;
  // Every fetch gets a sequence number; a response from an older fetch
  // (e.g. a slower search) is dropped so it cannot overwrite newer data.
  int _requestSeq = 0;
  int _analyticsSeq = 0;
  int _missedSeq = 0;

  String searchQuery = '';
  List<Project> projects = [];

  // Visits tab
  List<FieldOfficerPatrol> schedules = [];
  Map<String, Map<String, List<FieldOfficerPatrol>>>
      groupedFieldOfficerPatrols = {};
  bool isLoading = true;
  bool isLoadingMore = false;
  bool _hasMore = true;
  bool _loadFailed = false;
  int? _visitsTotal;

  // Overview tab
  FoAnalytics? analytics;
  bool analyticsLoading = true;
  bool analyticsFailed = false;

  // Missed tab
  List<FoMissedVisit> missed = [];
  bool missedLoading = true;
  bool missedLoadingMore = false;
  bool missedHasMore = true;
  bool missedFailed = false;
  int? _missedTotal;
  int _missedPage = 0;

  bool _openingImage = false;

  int? intOrganizationId;
  String selectedDateRange = '0'; // Default to '0' for today
  String _selectedProjectId = ''; // '' = all projects
  DateTime? _customStart;
  DateTime? _customEnd;
  int _currentPage = 0;
  final int _pageSize = 14;
  final int _missedPageSize = 30;

  static const Map<String, String> _rangeLabels = {
    '0': 'Today',
    '1': 'Yesterday',
    '7': 'Last 7 days',
    '15': 'Last 15 days',
    '13': 'This month',
    '30': 'Last month',
    '130': 'Last 30 days',
    '90': 'Last 90 days',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _checkConnectivity();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _missedScrollController.dispose();
    _userName.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    bool isConnected = await connectivityHandler.checkConnectivity(context);
    if (isConnected) {
      intOrganizationId = await Util.getOrganizationId();

      _checkSession();
      _fetchProjects(intOrganizationId!);
      _scrollController.addListener(_scrollListener);
      _missedScrollController.addListener(_missedScrollListener);
      _loadAll();
    }
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  void _loadAll() {
    fetchReportData();
    _fetchAnalytics();
    _fetchMissed();
  }

  void _reload() {
    _currentPage = 0;
    _hasMore = true;
    _missedPage = 0;
    missedHasMore = true;
    _loadAll();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Start fetching a little before the very bottom so the next page is
    // usually ready by the time the user gets there.
    if (position.pixels >= position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        !isLoading &&
        _hasMore) {
      _loadMore();
    }
  }

  void _missedScrollListener() {
    if (!_missedScrollController.hasClients) return;
    final position = _missedScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200 &&
        !missedLoadingMore &&
        !missedLoading &&
        missedHasMore) {
      _loadMoreMissed();
    }
  }

  Future<void> _loadMore() async {
    if (isLoadingMore || !_hasMore) return;
    setState(() => isLoadingMore = true);
    _currentPage += 1;
    await fetchReportData(isLoadingMore: true);
    if (mounted) setState(() => isLoadingMore = false);
  }

  Future<void> _loadMoreMissed() async {
    if (missedLoadingMore || !missedHasMore) return;
    setState(() => missedLoadingMore = true);
    _missedPage += 1;
    await _fetchMissed(loadMore: true);
    if (mounted) setState(() => missedLoadingMore = false);
  }

  Future<void> _fetchProjects(int organizationId) async {
    try {
      final response = await ApiService.fetchOrgProjects(organizationId);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          projects = data.map((project) => Project.fromJson(project)).toList();
        });
      } else {
        debugPrint('FO report: projects failed ${response.statusCode}');
        _showMessage('Unable to load the project list. Please try again.',
            retry: () => _fetchProjects(organizationId));
      }
    } catch (e) {
      debugPrint('FO report: projects error $e');
      if (mounted) {
        _showMessage('Unable to load the project list. Please try again.',
            retry: () => _fetchProjects(organizationId));
      }
    }
  }

  Future<void> fetchReportData({bool isLoadingMore = false}) async {
    final int seq = ++_requestSeq;
    if (!isLoadingMore) {
      setState(() {
        isLoading = true;
        _loadFailed = false;
      });
    }

    try {
      final response = await ApiService.fetchFieldOfficerPatrolReports(
        intOrganizationId!,
        _selectedProjectId,
        selectedDateRange,
        _currentPage,
        _pageSize,
        searchQuery,
      );
      // A newer request superseded this one.
      if (seq != _requestSeq || !mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> reportData = _extractList(decoded);
        final items = reportData
            .map((item) => FieldOfficerPatrol.fromJson(item))
            .toList();
        final page = _pageInfo(decoded);

        setState(() {
          if (isLoadingMore) {
            schedules.addAll(items);
          } else {
            schedules = items;
          }
          _visitsTotal = page.total;
          // Prefer the server's own "last page" flag; fall back to a short page.
          _hasMore =
              page.last == null ? items.length >= _pageSize : !(page.last!);
          groupedFieldOfficerPatrols =
              _groupSchedulesByDateAndLocation(schedules);
          isLoading = false;
        });
      } else {
        debugPrint(
            'FO report: load failed ${response.statusCode} ${response.body}');
        _onLoadFailed(isLoadingMore);
      }
    } catch (e) {
      if (seq != _requestSeq || !mounted) return;
      debugPrint('FO report: load error $e');
      _onLoadFailed(isLoadingMore);
    }
  }

  Future<void> _fetchAnalytics() async {
    final int seq = ++_analyticsSeq;
    setState(() {
      analyticsLoading = true;
      analyticsFailed = false;
    });
    try {
      final response = await ApiService.fetchFieldOfficerAnalytics(
        intOrganizationId!,
        _selectedProjectId,
        selectedDateRange,
        searchQuery,
      );
      if (seq != _analyticsSeq || !mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          analytics = FoAnalytics.fromJson(
              decoded is Map<String, dynamic> ? decoded : <String, dynamic>{});
          analyticsLoading = false;
        });
      } else {
        debugPrint('FO report: analytics failed ${response.statusCode}');
        setState(() {
          analyticsLoading = false;
          analyticsFailed = true;
        });
      }
    } catch (e) {
      if (seq != _analyticsSeq || !mounted) return;
      debugPrint('FO report: analytics error $e');
      setState(() {
        analyticsLoading = false;
        analyticsFailed = true;
      });
    }
  }

  Future<void> _fetchMissed({bool loadMore = false}) async {
    final int seq = ++_missedSeq;
    if (!loadMore) {
      setState(() {
        missedLoading = true;
        missedFailed = false;
      });
    }
    try {
      final response = await ApiService.fetchFieldOfficerMissedVisits(
        intOrganizationId!,
        _selectedProjectId,
        selectedDateRange,
        _missedPage,
        _missedPageSize,
        searchQuery,
      );
      if (seq != _missedSeq || !mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final items = _extractList(decoded)
            .map((e) => FoMissedVisit.fromJson(e))
            .toList();
        final page = _pageInfo(decoded);
        setState(() {
          if (loadMore) {
            missed.addAll(items);
          } else {
            missed = items;
          }
          _missedTotal = page.total;
          missedHasMore = page.last == null
              ? items.length >= _missedPageSize
              : !(page.last!);
          missedLoading = false;
        });
      } else {
        debugPrint('FO report: missed failed ${response.statusCode}');
        _onMissedFailed(loadMore);
      }
    } catch (e) {
      if (seq != _missedSeq || !mounted) return;
      debugPrint('FO report: missed error $e');
      _onMissedFailed(loadMore);
    }
  }

  /// The list endpoints answer with a bare array or with a PageBean wrapping
  /// the array under `records` (older builds used `data`); accept all three.
  List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      if (decoded['records'] is List) return decoded['records'];
      if (decoded['data'] is List) return decoded['data'];
    }
    throw Exception('Unexpected report response format');
  }

  ({bool? last, int? total}) _pageInfo(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      return (
        last: decoded['last'] is bool ? decoded['last'] as bool : null,
        total: _asIntOrNull(decoded['totalRecords']),
      );
    }
    return (last: null, total: null);
  }

  void _onLoadFailed(bool wasLoadingMore) {
    if (!mounted) return;
    setState(() {
      isLoading = false;
      if (wasLoadingMore) {
        // Undo the page bump so a retry asks for the same page again.
        if (_currentPage > 0) _currentPage -= 1;
      } else {
        _loadFailed = true;
      }
    });
    _showMessage('Unable to load the report. Please try again.',
        retry: wasLoadingMore ? _loadMore : _reload);
  }

  void _onMissedFailed(bool wasLoadingMore) {
    if (!mounted) return;
    setState(() {
      missedLoading = false;
      if (wasLoadingMore) {
        if (_missedPage > 0) _missedPage -= 1;
      } else {
        missedFailed = true;
      }
    });
  }

  Map<String, Map<String, List<FieldOfficerPatrol>>>
      _groupSchedulesByDateAndLocation(List<FieldOfficerPatrol> schedules) {
    Map<String, Map<String, List<FieldOfficerPatrol>>> grouped = {};

    for (var schedule in schedules) {
      String date = DateFormat('yyyy-MM-dd').format(schedule.createdDate);
      String projectName = schedule.projectName;

      grouped.putIfAbsent(date, () => {});
      grouped[date]!.putIfAbsent(projectName, () => []);
      grouped[date]![projectName]!.add(schedule);
    }
    return grouped;
  }

  void _showMessage(String message, {VoidCallback? retry}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: retry == null
              ? null
              : SnackBarAction(label: 'RETRY', onPressed: retry),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------------
  //
  // Same shape as the incident list: search always in reach, the long list
  // (projects) behind a searchable sheet, and the common choice (date range)
  // as one-tap chips. No expand/collapse to discover.

  static const List<String> _quickRanges = [
    '0',
    '1',
    '7',
    '15',
    '13',
    '30',
    '130',
    '90',
  ];

  bool get _isCustomRange => !_rangeLabels.containsKey(selectedDateRange);

  String _customRangeLabel() {
    if (_customStart == null || _customEnd == null) return 'Custom';
    final f = DateFormat('dd MMM');
    return '${f.format(_customStart!)} – ${f.format(_customEnd!)}';
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: (_customStart != null && _customEnd != null)
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : null,
      helpText: 'Select date range',
      saveText: 'Apply',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: AppColors.onPrimary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _customStart = picked.start;
      _customEnd = picked.end;
      // Same wire format the old picker sent: rangeOfDays is left empty and
      // explicit bounds are appended to the query string.
      selectedDateRange =
          '&startDate=${DateFormat('yyyy-MM-ddT00:00:00').format(picked.start)}'
          '&endDate=${DateFormat('yyyy-MM-ddT23:59:59').format(picked.end)}';
    });
    _reload();
  }

  void _selectQuickRange(String code) {
    if (code == selectedDateRange) return;
    setState(() {
      selectedDateRange = code;
      _customStart = null;
      _customEnd = null;
    });
    _reload();
  }

  Future<void> _pickProject() async {
    final options = [
      const FilterOption(0, 'All projects'),
      ...projects.map((p) => FilterOption(p.projectId, p.projectName)),
    ];
    final currentId = int.tryParse(_selectedProjectId) ?? 0;
    FilterOption? selected;
    for (final o in options) {
      if (o.id == currentId) selected = o;
    }

    final picked = await showIncidentOptionPicker(
      context: context,
      title: 'Project',
      accent: AppColors.primary,
      icon: Icons.apartment_rounded,
      options: options,
      selected: selected,
    );
    if (picked == null || !mounted) return;

    final value = picked.id == 0 ? '' : picked.id.toString();
    if (value == _selectedProjectId) return;
    setState(() => _selectedProjectId = value);
    _reload();
  }

  void _resetFilters() {
    _searchDebounce?.cancel();
    _userName.clear();
    setState(() {
      searchQuery = '';
      _selectedProjectId = '';
      selectedDateRange = '0';
      _customStart = null;
      _customEnd = null;
    });
    _reload();
  }

  void _onSearchChanged(String value) {
    setState(() {}); // refresh the clear button
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final query = value.trim();
      if (query == searchQuery) return;
      searchQuery = query;
      _reload();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _userName.clear();
    if (searchQuery.isEmpty) {
      setState(() {});
      return;
    }
    searchQuery = '';
    _reload();
  }

  /// Jump to the Missed tab filtered to one officer (from the overview).
  void _focusOfficer(String name) {
    _searchDebounce?.cancel();
    _userName.text = name;
    searchQuery = name;
    _tabController.animateTo(2);
    _reload();
  }

  String _dateRangeLabel() => _rangeLabels[selectedDateRange] ?? 'Custom dates';

  String _projectLabel() {
    if (_selectedProjectId.isEmpty) return 'All projects';
    for (final p in projects) {
      if (p.projectId.toString() == _selectedProjectId) return p.projectName;
    }
    return 'Selected project';
  }

  int _activeFilterCount() {
    int n = 0;
    if (selectedDateRange != '0') n++;
    if (_selectedProjectId.isNotEmpty) n++;
    if (searchQuery.isNotEmpty) n++;
    return n;
  }

  // ---------------------------------------------------------------------------
  // Photos
  // ---------------------------------------------------------------------------

  Future<void> viewImage(FieldOfficerPatrol schedule, String imageType) async {
    if (_openingImage) return;
    final String? imageUrl =
        (imageType == 'in') ? schedule.inImageUrl : schedule.outImageUrl;
    final DateTime? date =
        (imageType == 'in') ? schedule.inTime : schedule.outTime;

    if (imageUrl == null || imageUrl.isEmpty || date == null) {
      _showMessage('This photo is not available.');
      return;
    }

    setState(() => _openingImage = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.onPrimary),
      ),
    );

    try {
      final imageResponse = await ApiService.FodownloadImage(
        projectName: schedule.projectName,
        date: date.toIso8601String(),
        userName: schedule.userName,
        phoneNumber: schedule.phoneNumber,
        imageUrl: imageUrl,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close the loader

      if (imageResponse.statusCode == 200 &&
          imageResponse.bodyBytes.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FullImageScreen(imageData: imageResponse.bodyBytes),
          ),
        );
      } else {
        debugPrint('FO report: photo failed ${imageResponse.statusCode}');
        _showMessage('Unable to open the photo. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      debugPrint('FO report: photo error $e');
      _showMessage(
          'Unable to open the photo. Please check your connection and try again.');
    } finally {
      if (mounted) setState(() => _openingImage = false);
    }
  }

  Future<void> _callOfficer(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) {
      _showMessage('No phone number on record for this officer.');
      return;
    }
    final uri = Uri(scheme: 'tel', path: digits);
    try {
      if (!await launchUrl(uri)) {
        _showMessage('Unable to open the dialler on this device.');
      }
    } catch (e) {
      debugPrint('FO report: dial error $e');
      _showMessage('Unable to open the dialler on this device.');
    }
  }

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

  Future<void> _refreshData() async {
    _checkSession();
    _reload();
    // Keep the indicator visible until the visible tab's data is back.
    await Future.delayed(const Duration(milliseconds: 600));
  }

  Future<void> _checkSession() async {
    try {
      final response = await ApiService.checkForUpdate();

      if (response.statusCode == 401) {
        // Clear preferences and show session expired dialog
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Show session expired dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Session Expired'),
            content: const Text(
                'Your session has expired. Please log in again to continue.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );

        // Automatically navigate to login after 5 seconds if no action
        Future.delayed(const Duration(seconds: 5), () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context); // Close dialog if still open
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        });

        return; // Early exit due to session expiration
      }
    } catch (e) {
      debugPrint('Error checking session: $e');
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  String _dateHeading(String ymd) {
    final d = DateTime.tryParse(ymd);
    if (d == null) return ymd;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
    final full = DateFormat('EEE, dd MMM yyyy').format(d);
    if (diff == 0) return 'Today  ·  $full';
    if (diff == 1) return 'Yesterday  ·  $full';
    return full;
  }

  /// Time of day only when it falls on the group's date; date + time otherwise
  /// so a scan that crossed midnight is never misread.
  String _timeLabel(DateTime t, String groupDate) {
    final local = t.toLocal();
    final sameDay = DateFormat('yyyy-MM-dd').format(local) == groupDate;
    return sameDay
        ? DateFormat('hh:mm a').format(local)
        : DateFormat('dd MMM, hh:mm a').format(local);
  }

  String? _durationLabel(FieldOfficerPatrol s) {
    final out = s.outTime;
    if (out == null) return null;
    final d = out.difference(s.inTime);
    if (d.isNegative) return null;
    return _minutesLabel(d.inMinutes);
  }

  String _minutesLabel(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  String _plural(int n, String one, [String? many]) =>
      n == 1 ? '1 $one' : '$n ${many ?? '${one}s'}';

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    final int attentionCount = analytics == null
        ? 0
        : analytics!.summary.missedVisits + analytics!.summary.pendingToday;
    final bool anyLoading = isLoading || analyticsLoading || missedLoading;
    final bool hasContent =
        schedules.isNotEmpty || analytics != null || missed.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        // Brand hero gradient — matches CustomAppBar and the home header.
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
          'FO Report',
          style: TextStyle(
            fontSize: screenWidth > 600 ? 22 : 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          tabs: [
            const Tab(text: 'Overview'),
            const Tab(text: 'Visits'),
            Tab(child: _tabLabelWithBadge('Missed', attentionCount)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: _filterBar(),
            ),
            // Thin progress line while a filter change is being applied over
            // already-visible content.
            SizedBox(
              height: 2,
              child: (anyLoading && hasContent)
                  ? const LinearProgressIndicator(
                      minHeight: 2, color: AppColors.primary)
                  : null,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  RefreshIndicator(
                    onRefresh: _refreshData,
                    color: AppColors.primary,
                    child: _overviewTab(),
                  ),
                  RefreshIndicator(
                    onRefresh: _refreshData,
                    color: AppColors.primary,
                    child: _buildList(),
                  ),
                  RefreshIndicator(
                    onRefresh: _refreshData,
                    color: AppColors.primary,
                    child: _missedTab(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabLabelWithBadge(String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---- Filters ---------------------------------------------------------------

  Widget _filterBar() {
    final bool projectActive = _selectedProjectId.isNotEmpty;
    final bool anyActive = _activeFilterCount() > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _searchField()),
              const SizedBox(width: 8),
              _projectButton(projectActive),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              children: [
                for (final code in _quickRanges)
                  _rangeChip(
                    _rangeLabels[code]!,
                    selected: selectedDateRange == code,
                    onTap: () => _selectQuickRange(code),
                  ),
                _rangeChip(
                  _customRangeLabel(),
                  selected: _isCustomRange,
                  icon: Icons.date_range_rounded,
                  onTap: _pickCustomRange,
                ),
                if (anyActive)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: TextButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                      label: const Text('Reset'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _userName,
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        cursorColor: AppColors.primary,
        style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search officer',
          hintStyle: const TextStyle(fontSize: 14, color: AppColors.searchHint),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.primary, size: 20),
          suffixIcon: _userName.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textSecondary),
                  onPressed: _clearSearch,
                ),
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _projectButton(bool active) {
    final Color fg = active ? AppColors.primary : AppColors.textSecondary;
    return Material(
      color: active
          ? AppColors.tint(AppColors.primary, 0.12)
          : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: projects.isEmpty ? null : _pickProject,
        child: Container(
          height: 44,
          padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
          constraints: const BoxConstraints(maxWidth: 150),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.apartment_rounded, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _projectLabel(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
              Icon(Icons.arrow_drop_down_rounded, size: 22, color: fg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rangeChip(String label,
      {required bool selected, required VoidCallback onTap, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        avatar: icon == null
            ? null
            : Icon(icon,
                size: 15,
                color:
                    selected ? AppColors.onPrimary : AppColors.textSecondary),
        selected: selected,
        showCheckmark: false,
        backgroundColor: AppColors.surfaceAlt,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? AppColors.onPrimary : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        side:
            BorderSide(color: selected ? AppColors.primary : AppColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        labelPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onSelected: (_) => onTap(),
      ),
    );
  }

  // ---- Shared pieces -----------------------------------------------------------

  Widget _placeholder(IconData icon, String text,
      {String? hint,
      VoidCallback? action,
      String? actionLabel,
      Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      child: Column(
        children: [
          Icon(icon, size: 44, color: iconColor ?? AppColors.textFaint),
          const SizedBox(height: 14),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
          if (action != null) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: action,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(actionLabel ?? 'Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _loadingList() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardTitle(String title, {String? trailing, Widget? trailingWidget}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (trailingWidget != null)
            trailingWidget
          else if (trailing != null)
            Text(trailing,
                style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
        ],
      ),
    );
  }

  Widget _statusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.tint(color, 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _avatar(String name, {Color? color, double radius = 18}) {
    final c = color ?? AppColors.primary;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.tint(c, 0.12),
      child: Text(
        _initials(name),
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.72,
        ),
      ),
    );
  }

  Widget _dateHeader(String date, String countLabel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _dateHeading(date),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            countLabel,
            style: TextStyle(fontSize: 12, color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }

  // ---- Overview tab -------------------------------------------------------------

  Widget _overviewTab() {
    if (analyticsLoading && analytics == null) return _loadingList();

    if (analytics == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _placeholder(
            Icons.cloud_off_outlined,
            'The overview could not be loaded.',
            hint: 'Check your connection and try again.',
            action: _fetchAnalytics,
          ),
        ],
      );
    }

    final a = analytics!;
    final s = a.summary;
    final bool nothing = s.totalVisits == 0 && !s.rosterConfigured;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        _kpiGrid(s),
        if (!s.rosterConfigured) _rosterNotice(),
        if (nothing)
          _placeholder(
            Icons.inbox_outlined,
            'No patrol activity for ${_dateRangeLabel().toLowerCase()}.',
            hint: 'Patrol scans will appear here as officers check in.',
          )
        else ...[
          if (a.byDay.length > 1) _trendCard(a.byDay),
          if (a.byProject.isNotEmpty) _projectsCard(a.byProject),
          _officersCard(a.byOfficer, s),
        ],
      ],
    );
  }

  /// True when the selected range covers today and nothing before it.
  ///
  /// Matters because "missed" only exists for finished days. On a today-only
  /// range it is always zero, which read as "all clear" while officers still
  /// had not patrolled. These two tiles therefore ask a different question
  /// depending on which range is selected.
  bool get _isTodayOnly {
    final a = analytics;
    if (a?.startDate == null || a?.endDate == null) {
      return selectedDateRange == '0';
    }
    final now = DateTime.now();
    return DateUtils.isSameDay(a!.startDate, now) &&
        DateUtils.isSameDay(a.endDate, now);
  }

  Widget _kpiGrid(FoSummary s) {
    final bool today = _isTodayOnly;

    // Today: what is still outstanding. Past ranges: what was actually missed.
    final int attentionValue = today ? s.pendingToday : s.missedVisits;
    final String attentionLabel = today ? 'Yet to visit' : 'Missed';
    final Color attentionColor = attentionValue > 0
        ? (today ? AppColors.warning : AppColors.danger)
        : AppColors.success;
    final String attentionSub = !s.rosterConfigured
        ? 'No field officers found'
        : today
            ? (attentionValue == 0
                ? 'All ${s.rosterOfficers} officers visited'
                : 'of ${s.expectedVisits} officers due today')
            : (s.pendingToday > 0
                ? '${s.pendingToday} still pending today'
                : 'of ${s.expectedVisits} officer-days expected');

    // Compliance is a finished-days measure, so on a today-only range it has
    // nothing to average. Show the day's own progress instead of a dash.
    final int? doneRate = s.expectedVisits == 0
        ? null
        : ((s.coveredVisits * 100) / s.expectedVisits).round();
    final int? rate = today ? doneRate : s.complianceRate;
    final String rateLabel = today ? 'Done today' : 'Compliance';
    final String rateSub = rate == null
        ? 'Nothing expected yet'
        : today
            ? '${s.coveredVisits} of ${s.expectedVisits} officers visited'
            : 'Days with a visit recorded';

    final tiles = <Widget>[
      _kpiTile(
        icon: Icons.directions_walk_rounded,
        color: AppColors.primary,
        value: '${s.totalVisits}',
        label: 'Visits',
        sub: '${s.completedVisits} completed · ${s.openVisits} on site',
        onTap: () => _tabController.animateTo(1),
      ),
      _kpiTile(
        icon: today ? Icons.pending_actions_rounded : Icons.event_busy_rounded,
        color: attentionColor,
        value: '$attentionValue',
        label: attentionLabel,
        sub: attentionSub,
        onTap: () => _tabController.animateTo(2),
      ),
      _kpiTile(
        icon: Icons.verified_rounded,
        color: rate == null
            ? AppColors.textFaint
            : rate >= 90
                ? AppColors.success
                : rate >= 70
                    ? AppColors.warning
                    : AppColors.danger,
        value: rate == null ? '—' : '$rate%',
        label: rateLabel,
        sub: rateSub,
        onTap: _showOfficerSheet,
      ),
      _kpiTile(
        icon: Icons.groups_rounded,
        color: AppColors.accent,
        value: '${s.activeOfficers}',
        label: 'Officers active',
        sub: s.rosterConfigured
            ? 'of ${s.rosterOfficers} field officers'
            : s.avgDurationMinutes == null
                ? 'No completed visits yet'
                : 'Avg visit ${_minutesLabel(s.avgDurationMinutes!)}',
        onTap: _showOfficerSheet,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tiles.map((t) => SizedBox(width: w, child: t)).toList(),
          );
        },
      ),
    );
  }

  Widget _kpiTile({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    required String sub,
    VoidCallback? onTap,
  }) {
    final tile = Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.tint(color, 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textFaint),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppColors.textFaint),
          ),
        ],
      ),
    );

    if (onTap == null) return tile;
    // Every figure on this row is a count of people, so each one should be
    // able to name them rather than leave the reader guessing.
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: tile),
    );
  }

  /// Names the people behind the officer figures.
  ///
  /// Opened from the "Done today" and "Officers active" tiles. Roster officers
  /// come first, sorted so anyone still outstanding is at the top. Anyone who
  /// recorded visits without holding the Field Officer role is listed
  /// separately, because they count towards visits but not towards the target.
  void _showOfficerSheet() {
    final a = analytics;
    if (a == null) return;

    final bool today = _isTodayOnly;
    final roster = a.byOfficer.where((o) => o.expectedVisits > 0).toList()
      ..sort((x, y) {
        final xOut = x.missedVisits + x.pendingToday;
        final yOut = y.missedVisits + y.pendingToday;
        if (xOut != yOut) return yOut.compareTo(xOut);
        return y.visits.compareTo(x.visits);
      });
    final others = a.byOfficer
        .where((o) => o.expectedVisits == 0 && o.visits > 0)
        .toList()
      ..sort((x, y) => y.visits.compareTo(x.visits));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Field officers',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          today
                              ? '${a.summary.coveredVisits} of ${a.summary.rosterOfficers} visited today'
                              : '${_dateRangeLabel()} · ${a.summary.rosterOfficers} on the roster',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(sheetContext),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                children: [
                  if (roster.isEmpty)
                    _placeholder(
                      Icons.badge_outlined,
                      'No field officers found.',
                      hint:
                          'Give a user the Field Officer role, and make sure their employee record is marked Working.',
                    )
                  else
                    ...roster.map((o) => _officerSheetRow(o, today)),
                  if (others.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                      child: Text(
                        'ALSO RECORDED VISITS',
                        style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        'Not on the Field Officer roster, so their visits count '
                        'but are not measured against a target.',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textFaint),
                      ),
                    ),
                    ...others.map((o) => _officerSheetRow(o, today)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _officerSheetRow(FoOfficerStat o, bool today) {
    final int outstanding = o.missedVisits + o.pendingToday;
    final bool onRoster = o.expectedVisits > 0;
    final Color accent = !onRoster
        ? AppColors.primary
        : outstanding == 0
            ? AppColors.success
            : today
                ? AppColors.warning
                : AppColors.danger;

    final String status = !onRoster
        ? 'Not on roster'
        : today
            ? (outstanding == 0 ? 'Visited' : 'Yet to visit')
            : '${o.coveredVisits}/${o.expectedVisits} days';

    final String detail = [
      _plural(o.visits, 'visit'),
      if (o.completedVisits != o.visits) '${o.completedVisits} completed',
      if (o.avgDurationMinutes != null)
        'avg ${_minutesLabel(o.avgDurationMinutes!)}',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          _avatar(o.userName, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.userName.isEmpty ? 'Unknown officer' : o.userName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusPill(status, accent),
          if (o.phoneNumber.isNotEmpty)
            IconButton(
              tooltip: 'Call ${o.userName}',
              onPressed: () => _callOfficer(o.phoneNumber),
              icon: const Icon(Icons.call_rounded, size: 19),
              color: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _rosterNotice() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.tint(AppColors.warning, 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.tint(AppColors.warning, 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Missed visits cannot be tracked yet: no one here holds the Field '
              'Officer role with an active employee record. Add the role, or mark '
              'the employee as working, to see who missed their rounds.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.35, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendCard(List<FoDayStat> days) {
    final int maxVisits = days.fold<int>(
        0, (m, d) => math.max(m, math.max(d.visits, d.expectedVisits)));
    final bool showMonth = days.length > 10;
    final int totalMissed = days.fold<int>(0, (m, d) => m + d.missedVisits);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            'Daily visits',
            trailingWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _legendDot(AppColors.primary, 'Visits'),
                const SizedBox(width: 10),
                _legendDot(AppColors.danger, 'Missed'),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const double chartHeight = 110;
              const double gap = 6;
              final int n = days.length;
              final double fit = (constraints.maxWidth - gap * (n - 1)) / n;
              final double barW = math.max(fit, 18);
              final bool scrolls = barW > fit + 0.5;

              final bars = Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 0; i < n; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: barW,
                      child: _dayBar(days[i], maxVisits, chartHeight,
                          showMonth:
                              showMonth && (i == 0 || days[i].date.day == 1)),
                    ),
                  ],
                ],
              );
              return scrolls
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: bars,
                    )
                  : bars;
            },
          ),
          if (totalMissed > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$totalMissed officer-${totalMissed == 1 ? 'day' : 'days'} with no visit in this period.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _dayBar(FoDayStat d, int maxVisits, double chartHeight,
      {bool showMonth = false}) {
    final double scale = maxVisits == 0 ? 0 : chartHeight / maxVisits;
    final double visitH = math.max(d.visits * scale, d.visits > 0 ? 3 : 0);
    final double missedH =
        math.max(d.missedVisits * scale, d.missedVisits > 0 ? 3 : 0);
    final bool isToday = DateUtils.isSameDay(d.date, DateTime.now());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 14,
          child: d.visits > 0
              ? Text('${d.visits}',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary))
              : null,
        ),
        SizedBox(
          height: chartHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Container(
                    height: visitH,
                    decoration: BoxDecoration(
                      color:
                          isToday ? AppColors.primaryLight : AppColors.primary,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                ),
                if (d.missedVisits > 0) ...[
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 5,
                    child: Container(
                      height: missedH,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          showMonth
              ? DateFormat('d MMM').format(d.date)
              : DateFormat('d').format(d.date),
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
            color: isToday ? AppColors.primary : AppColors.textFaint,
          ),
        ),
      ],
    );
  }

  Widget _projectsCard(List<FoProjectStat> rows) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('By project', trailing: _plural(rows.length, 'project')),
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 16, color: AppColors.divider),
            _projectRow(rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _projectRow(FoProjectStat p) {
    // Projects report activity only. The expectation is held per officer per
    // day, so there is no per-project target to compare against.
    return Row(
      children: [
        const Icon(Icons.location_on, size: 15, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.projectName.isEmpty ? 'Unassigned project' : p.projectName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_plural(p.completedVisits, 'completed visit')} of ${p.visits}',
                style:
                    TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${p.visits}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _officersCard(List<FoOfficerStat> officers, FoSummary s) {
    final attention = officers
        .where((o) => o.missedVisits > 0 || o.pendingToday > 0)
        .take(6)
        .toList();
    final top = officers.where((o) => o.visits > 0).toList()
      ..sort((a, b) => b.visits.compareTo(a.visits));

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            'Officers',
            trailingWidget: TextButton(
              onPressed: () => _tabController.animateTo(2),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              child: const Text('See missed'),
            ),
          ),
          if (attention.isNotEmpty) ...[
            _sectionLabel('Needs attention', AppColors.danger),
            for (final o in attention) _officerRow(o, attention: true),
            if (top.isNotEmpty) const SizedBox(height: 8),
          ] else if (s.rosterConfigured) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text('Every field officer recorded a visit.',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
          if (top.isNotEmpty) ...[
            _sectionLabel('Most active', AppColors.primary),
            for (final o in top.take(5)) _officerRow(o, attention: false),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _officerRow(FoOfficerStat o, {required bool attention}) {
    final Color accent = attention
        ? (o.missedVisits > 0 ? AppColors.danger : AppColors.warning)
        : AppColors.primary;
    final String detail = attention
        ? [
            if (o.missedVisits > 0) '${_plural(o.missedVisits, 'day')} missed',
            if (o.pendingToday > 0) 'pending today',
            _plural(o.visits, 'visit'),
          ].join(' · ')
        : [
            _plural(o.visits, 'visit'),
            '${o.completedVisits} completed',
            if (o.avgDurationMinutes != null)
              'avg ${_minutesLabel(o.avgDurationMinutes!)}',
          ].join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _focusOfficer(o.userName),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _avatar(o.userName, color: accent, radius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.userName.isEmpty ? 'Unknown officer' : o.userName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    detail,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (o.complianceRate != null) ...[
              const SizedBox(width: 8),
              Text(
                '${o.complianceRate}%',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: o.complianceRate! >= 90
                      ? AppColors.success
                      : o.complianceRate! >= 70
                          ? AppColors.warning
                          : AppColors.danger,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }

  // ---- Visits tab ---------------------------------------------------------------

  Widget _buildList() {
    if (isLoading && schedules.isEmpty) return _loadingList();

    if (schedules.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _loadFailed
              ? _placeholder(
                  Icons.cloud_off_outlined,
                  'The report could not be loaded.',
                  hint: 'Check your connection and try again.',
                  action: _reload,
                  actionLabel: 'Retry',
                )
              : _placeholder(
                  Icons.inbox_outlined,
                  'No patrols found for ${_dateRangeLabel().toLowerCase()}.',
                  hint: _activeFilterCount() > 0
                      ? 'Try a wider date range or a different project.'
                      : 'Patrol scans will appear here as officers check in.',
                ),
        ],
      );
    }

    final List<Widget> items = [];
    for (final dateEntry in groupedFieldOfficerPatrols.entries) {
      final String date = dateEntry.key;
      final int countForDate =
          dateEntry.value.values.fold(0, (n, list) => n + list.length);
      items.add(_dateHeader(date, _plural(countForDate, 'patrol')));

      for (final projectEntry in dateEntry.value.entries) {
        items.add(_projectHeader(projectEntry.key));
        for (final schedule in projectEntry.value) {
          items.add(_patrolCard(schedule, date));
        }
      }
    }

    if (isLoadingMore) {
      items.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ));
    } else if (!_hasMore) {
      final total = _visitsTotal;
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: Center(
          child: Text(
            total != null && total > schedules.length
                ? '${schedules.length} of $total patrols shown'
                : '${_plural(schedules.length, 'patrol')} shown  ·  end of results',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12),
          ),
        ),
      ));
    } else {
      items.add(const SizedBox(height: 24));
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  Widget _projectHeader(String projectName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              projectName.isEmpty ? 'Unassigned project' : projectName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _patrolCard(FieldOfficerPatrol schedule, String groupDate) {
    final bool onSite = schedule.outTime == null;
    final String? duration = _durationLabel(schedule);
    final bool hasInPhoto = schedule.inImageUrl.isNotEmpty;
    final bool hasOutPhoto =
        schedule.outImageUrl != null && schedule.outImageUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _avatar(schedule.userName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.userName.isEmpty
                          ? 'Unknown officer'
                          : schedule.userName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (schedule.location.isNotEmpty)
                      Text(
                        schedule.location,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusPill(
                onSite
                    ? 'On site'
                    : (duration == null
                        ? 'Completed'
                        : 'Completed · $duration'),
                onSite ? AppColors.warning : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.divider),
          _scanRow(
            icon: Icons.login,
            color: AppColors.success,
            label: 'In',
            time: _timeLabel(schedule.inTime, groupDate),
            hasPhoto: hasInPhoto,
            onViewPhoto: () => viewImage(schedule, 'in'),
          ),
          _scanRow(
            icon: Icons.logout,
            color: onSite ? AppColors.textFaint : AppColors.danger,
            label: 'Out',
            time: onSite
                ? 'Not yet checked out'
                : _timeLabel(schedule.outTime!, groupDate),
            muted: onSite,
            hasPhoto: hasOutPhoto,
            onViewPhoto: () => viewImage(schedule, 'out'),
          ),
        ],
      ),
    );
  }

  Widget _scanRow({
    required IconData icon,
    required Color color,
    required String label,
    required String time,
    required bool hasPhoto,
    required VoidCallback onViewPhoto,
    bool muted = false,
  }) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              time,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
                fontStyle: muted ? FontStyle.italic : FontStyle.normal,
                color: muted ? AppColors.textFaint : AppColors.textPrimary,
              ),
            ),
          ),
          if (hasPhoto)
            TextButton.icon(
              onPressed: _openingImage ? null : onViewPhoto,
              icon: const Icon(Icons.photo_outlined, size: 16),
              label: const Text('Photo'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  // ---- Missed tab ---------------------------------------------------------------

  Widget _missedTab() {
    if (missedLoading && missed.isEmpty) return _loadingList();

    if (missed.isEmpty) {
      final bool rosterKnown = analytics != null;
      final bool noRoster = rosterKnown && !analytics!.summary.rosterConfigured;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (missedFailed)
            _placeholder(
              Icons.cloud_off_outlined,
              'Missed visits could not be loaded.',
              hint: 'Check your connection and try again.',
              action: _reload,
              actionLabel: 'Retry',
            )
          else if (noRoster)
            _placeholder(
              Icons.badge_outlined,
              'No field officers found here.',
              hint:
                  'Give a user the Field Officer role, and make sure their employee record is marked Working.',
            )
          else
            _placeholder(
              Icons.task_alt_rounded,
              'No missed visits for ${_dateRangeLabel().toLowerCase()}.',
              hint: 'Every field officer recorded a visit.',
              iconColor: AppColors.success,
            ),
        ],
      );
    }

    // One row per officer per day, newest day first, as the server returns them.
    final Map<String, List<FoMissedVisit>> grouped = {};
    for (final m in missed) {
      final date = DateFormat('yyyy-MM-dd').format(m.visitDate);
      grouped.putIfAbsent(date, () => []).add(m);
    }

    final List<Widget> items = [];
    for (final dateEntry in grouped.entries) {
      final rows = dateEntry.value;
      final int missedCount = rows.where((r) => !r.isPending).length;
      final int pendingCount = rows.length - missedCount;
      items.add(_dateHeader(
        dateEntry.key,
        [
          if (missedCount > 0) '$missedCount missed',
          if (pendingCount > 0) '$pendingCount pending',
        ].join(' · '),
      ));
      for (final r in rows) {
        items.add(_missedCard(r));
      }
    }

    if (missedLoadingMore) {
      items.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ));
    } else if (!missedHasMore) {
      final total = _missedTotal;
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: Center(
          child: Text(
            total != null && total > missed.length
                ? '${missed.length} of $total shown'
                : '${missed.length} shown  ·  end of results',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12),
          ),
        ),
      ));
    } else {
      items.add(const SizedBox(height: 24));
    }

    return ListView.builder(
      controller: _missedScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  /// One officer who recorded no visit on a given day.
  Widget _missedCard(FoMissedVisit m) {
    final Color accent = m.isPending ? AppColors.warning : AppColors.danger;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _avatar(m.userName, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.userName.isEmpty ? 'Unknown officer' : m.userName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  m.isPending ? 'No visit yet today' : 'No visit recorded',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: accent),
                ),
                if (m.projectName.isNotEmpty)
                  Text(
                    m.projectName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _statusPill(m.isPending ? 'Pending' : 'Missed', accent),
          if (m.phoneNumber.isNotEmpty)
            IconButton(
              tooltip: 'Call ${m.userName}',
              onPressed: () => _callOfficer(m.phoneNumber),
              icon: const Icon(Icons.call_rounded, size: 20),
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }
}
