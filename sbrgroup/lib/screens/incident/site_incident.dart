import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/incident/add_incident.dart';
import 'package:ajna/screens/incident/incident_filter_sheet.dart';
import 'package:ajna/screens/incident/incident_models.dart';
import 'package:ajna/screens/util.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// Site Incident monitoring feed.
///
/// Built as a monitoring surface rather than a list screen: severity is read
/// off the colour rail before any text, the summary strip answers "how bad is
/// it right now", and filtering happens in a sheet so the feed itself stays
/// uninterrupted. Cards expand in place — following an incident should not cost
/// you your scroll position.
class SiteIncidentScreen extends StatefulWidget {
  const SiteIncidentScreen({Key? key}) : super(key: key);

  @override
  State<SiteIncidentScreen> createState() => _SiteIncidentScreenState();
}

class _SiteIncidentScreenState extends State<SiteIncidentScreen>
    with TickerProviderStateMixin {
  // -- constants ------------------------------------------------------------

  static const int _pageSize = 15;

  /// Used only if the session has no organisation stored — every screen in the
  /// app reads the logged-in user's org, and this app is deployed for org 2.
  static const int _fallbackOrganizationId = 2;

  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _stamp = DateFormat('dd MMM yyyy • hh:mm a');
  static final DateFormat _day = DateFormat('dd MMM yyyy');

  // -- feed state -----------------------------------------------------------

  final List<SiteIncident> _incidents = [];
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _last = true;
  int _page = 0;
  int _totalRecords = 0;
  String? _error;

  /// Guards against the scroll listener firing a second page request while the
  /// first is still in flight.
  bool _requestInFlight = false;

  /// Bumped on every filter change / refresh. A late response from a superseded
  /// request compares its token and drops itself instead of overwriting fresher
  /// data — the classic out-of-order response bug when filters change fast.
  int _requestToken = 0;

  int? _expandedId;

  // -- filters & master data ------------------------------------------------

  IncidentFilters _filters = const IncidentFilters();
  int _organizationId = _fallbackOrganizationId;

  List<FilterOption> _sites = const [];
  List<FilterOption> _types = const [];
  List<FilterOption> _severities = const [];
  List<FilterOption> _employees = const [];
  bool _mastersLoading = true;

  // -- controllers ----------------------------------------------------------

  final ScrollController _scroll = ScrollController();
  late final AnimationController _headerCtrl;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
    _scroll.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _headerCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // -- data -----------------------------------------------------------------

  Future<void> _bootstrap() async {
    _organizationId = await Util.getOrganizationId() ?? _fallbackOrganizationId;
    if (!mounted) return;
    _headerCtrl.forward();
    // Master data and the first page are independent — running them together
    // means the filter sheet is usable as soon as the feed paints.
    unawaited(_loadMasters());
    await _loadFirstPage();
  }

  /// Filter master data, fetched once per screen session and then cached in
  /// state. Reopening the filter sheet must not re-hit four endpoints.
  Future<void> _loadMasters() async {
    try {
      final results = await Future.wait([
        ApiService.fetchAttendanceLocation(_organizationId),
        ApiService.getCommonReferenceDetails('Incident_Type'),
        ApiService.getCommonReferenceDetails('Incident_Severity'),
        ApiService.fetchOrgUsers(_organizationId),
      ]);
      if (!mounted) return;

      setState(() {
        _sites = _optionsFrom(results[0], idKey: 'id', labelKey: 'location');
        _types = _optionsFrom(results[1],
            idKey: 'id', labelKey: 'commonRefKey', sortByLabel: true);
        _severities = _severityOptionsFrom(results[2]);
        _employees = _optionsFrom(results[3],
            idKey: 'userId', labelKey: 'userName', sortByLabel: true);
        _mastersLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // A master-data failure must not take the feed down with it: the list
      // still works, the sheet just shows the lists it managed to load.
      setState(() => _mastersLoading = false);
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
            final parsedId =
                id is int ? id : int.tryParse(id.toString());
            if (parsedId == null) return null;
            final text = label.toString().trim();
            if (text.isEmpty) return null;
            return FilterOption(parsedId, text);
          })
          .whereType<FilterOption>()
          .toList();
      if (sortByLabel) {
        options.sort((a, b) =>
            a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      }
      return options;
    } catch (_) {
      return const [];
    }
  }

  /// Severities are ordered by seriousness, not alphabetically — a filter row
  /// reading Critical → High → Medium → Low matches how the feed is scanned.
  List<FilterOption> _severityOptionsFrom(http.Response response) {
    // Copied into a growable list: _optionsFrom returns a const [] on failure,
    // and sorting an immutable list throws.
    final options = List<FilterOption>.from(
        _optionsFrom(response, idKey: 'id', labelKey: 'commonRefKey'));
    const rank = {'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3};
    options.sort((a, b) {
      final ra = rank[a.label.toUpperCase()] ?? 99;
      final rb = rank[b.label.toUpperCase()] ?? 99;
      return ra.compareTo(rb);
    });
    return options;
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _initialLoading = true;
      _error = null;
      _expandedId = null;
    });
    await _fetchPage(0, replace: true);
  }

  Future<void> _refresh() => _fetchPage(0, replace: true);

  Future<void> _fetchPage(int page, {required bool replace}) async {
    // Pagination waits its turn, but a filter change or refresh must never be
    // dropped: bailing out here would leave _initialLoading stuck true and the
    // skeleton on screen forever. It supersedes the in-flight request instead,
    // and the token check below discards whichever finishes second.
    if (!replace && _requestInFlight) return;
    _requestInFlight = true;
    final token = ++_requestToken;

    if (!replace) setState(() => _loadingMore = true);

    try {
      final response = await ApiService.getAllSiteIncidents(
        organizationId: _organizationId,
        page: page,
        size: _pageSize,
        locationId: _filters.site?.id ?? 0,
        incidentTypeId: _filters.incidentType?.id ?? 0,
        severityId: _filters.severity?.id ?? 0,
        responsibleEmployeeId: _filters.employee?.id ?? 0,
        status: _filters.status,
        startDate: _filters.startDate == null
            ? ''
            : _apiDate.format(_filters.startDate!),
        endDate:
            _filters.endDate == null ? '' : _apiDate.format(_filters.endDate!),
      );

      if (!mounted || token != _requestToken) return;

      if (!ApiService.isSuccess(response.statusCode)) {
        setState(() {
          _error = 'The server returned ${response.statusCode}.';
          _initialLoading = false;
          _loadingMore = false;
        });
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _error = 'Unexpected response from the server.';
          _initialLoading = false;
          _loadingMore = false;
        });
        return;
      }

      final result = IncidentPage.fromJson(decoded);
      setState(() {
        if (replace) _incidents.clear();
        _incidents.addAll(result.records);
        _page = result.pageNo;
        _last = result.last || result.records.isEmpty;
        _totalRecords = result.totalRecords;
        _initialLoading = false;
        _loadingMore = false;
        _error = null;
      });
    } on FormatException {
      if (!mounted || token != _requestToken) return;
      setState(() {
        _error = 'The server sent data this screen could not read.';
        _initialLoading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || token != _requestToken) return;
      setState(() {
        // Deliberately generic: the caught object is usually a SocketException
        // whose message is a host/port dump, which helps nobody on site.
        _error = 'Could not reach the server. Check your connection.';
        _initialLoading = false;
        _loadingMore = false;
      });
    } finally {
      // Only the newest request clears the flag — a superseded one finishing
      // late must not re-open the gate while its replacement is still running.
      if (token == _requestToken) _requestInFlight = false;
    }
  }

  void _onScroll() {
    if (_last || _loadingMore || _requestInFlight || _initialLoading) return;
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    // Prefetch before the very bottom so the next page is usually already in
    // by the time the user gets there.
    if (position.pixels >= position.maxScrollExtent - 320) {
      _fetchPage(_page + 1, replace: false);
    }
  }

  // -- filter interactions --------------------------------------------------

  Future<void> _openFilters() async {
    final applied = await showIncidentFilterSheet(
      context: context,
      current: _filters,
      sites: _sites,
      types: _types,
      severities: _severities,
      employees: _employees,
      mastersLoading: _mastersLoading,
    );
    if (applied == null || !mounted) return;
    setState(() => _filters = applied);
    await _loadFirstPage();
  }

  Future<void> _clearFilters() async {
    if (!_filters.isActive) return;
    setState(() => _filters = const IncidentFilters());
    await _loadFirstPage();
  }

  Future<void> _removeFilter(IncidentFilters next) async {
    setState(() => _filters = next);
    await _loadFirstPage();
  }

  // -- derived --------------------------------------------------------------

  /// Counts across the pages loaded so far.
  ///
  /// Total comes from `totalRecords` and so covers the whole filtered set; the
  /// breakdown can only reflect what has actually been fetched, since the API
  /// exposes no aggregate. They resolve upward as more pages load, which the
  /// summary bar shows directly by leaving the unloaded remainder unfilled.
  int get _openCount => _incidents.where((i) => i.isOpen).length;
  int get _criticalCount => _incidents.where((i) => i.isCritical).length;
  int get _closedCount => _incidents.where((i) => !i.isOpen).length;

  // -- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _Header(
            animation: _headerCtrl,
            total: _totalRecords,
            loading: _initialLoading,
            activeFilters: _filters.activeCount,
            onBack: () => Navigator.of(context).maybePop(),
            onFilter: _openFilters,
          ),
          Expanded(child: _body()),
        ],
      ),
      floatingActionButton: _AddIncidentButton(onTap: _openAddIncident),
    );
  }

  /// Opens the report builder and refreshes if it saved something.
  ///
  /// The builder pops `true` on success, which is the only signal that a
  /// refetch is warranted — backing out unchanged leaves the feed alone.
  Future<void> _openAddIncident() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddIncidentScreen()),
    );
    if (created == true && mounted) {
      await _loadFirstPage();
    }
  }

  Widget _body() {
    if (_initialLoading) {
      return _SkeletonFeed(shimmer: _shimmerCtrl);
    }
    if (_error != null && _incidents.isEmpty) {
      return _ErrorState(message: _error!, onRetry: _loadFirstPage);
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: ContentWidthLimit(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryStrip(),
                  if (_filters.isActive) _activeFilterStrip(),
                ],
              ),
            ),
          ),
          if (_incidents.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                filtersActive: _filters.isActive,
                onClear: _clearFilters,
              ),
            )
          else
            SliverPadding(
              // Top inset carries the whole gap below the summary (and below the
              // active-filter strip when one is showing), so the feed reads as
              // a separate block rather than running straight on from the HUD.
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final incident = _incidents[index];
                    return ContentWidthLimit(
                      maxWidth: 720,
                      child: _EntranceAnimation(
                        // Stagger restarts per page so an appended page animates
                        // in on its own rather than inheriting a long delay.
                        position: index % _pageSize,
                        child: _IncidentCard(
                          incident: incident,
                          expanded: _expandedId == incident.siteIncidentId,
                          stamp: _stamp,
                          onToggle: () => setState(() {
                            _expandedId =
                                _expandedId == incident.siteIncidentId
                                    ? null
                                    : incident.siteIncidentId;
                          }),
                          onOpenFull: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _IncidentDetailScreen(
                                incident: incident,
                                stamp: _stamp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _incidents.length,
                ),
              ),
            ),
          SliverToBoxAdapter(child: _footer()),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_loadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Loading more…',
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    // A late-page failure keeps the loaded feed and offers a retry inline,
    // rather than replacing everything already on screen with an error page.
    if (_error != null && _incidents.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _fetchPage(_page + 1, replace: false),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try again'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      );
    }
    if (_incidents.isNotEmpty && _last) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 26),
        child: Center(
          child: Text(
            'All ${_incidents.length} incidents shown',
            style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }

  Widget _summaryStrip() {
    // No outer padding: the band runs edge to edge and supplies its own inset,
    // which is what keeps it reading as a section rather than a card.
    return _IncidentHud(
      total: _totalRecords,
      open: _openCount,
      critical: _criticalCount,
      closed: _closedCount,
    );
  }

  /// Chips for what is currently narrowing the feed, each individually
  /// removable — resetting one filter should not mean reopening the sheet.
  ///
  /// Each chip is tinted by what it filters rather than a single house colour:
  /// a site reads azure, a type takes its own hue, a severity takes its heat.
  /// The row is then scannable as a set of categories, not a list of words.
  Widget _activeFilterStrip() {
    final chips = <Widget>[];

    void add(String text, IconData icon, Color accent, IncidentFilters cleared) {
      chips.add(_ActiveFilterChip(
        label: text,
        icon: icon,
        accent: accent,
        onRemove: () => _removeFilter(cleared),
      ));
    }

    if (_filters.site != null) {
      add(_filters.site!.label, Icons.place_rounded, AppColors.primary,
          _filters.copyWith(clearSite: true));
    }
    if (_filters.incidentType != null) {
      add(
          _filters.incidentType!.label,
          incidentTypeIcon(_filters.incidentType!.label),
          incidentTypeAccent(_filters.incidentType!.label),
          _filters.copyWith(clearType: true));
    }
    if (_filters.severity != null) {
      final style = severityStyleFor(_filters.severity!.label);
      add(style.label, style.icon, style.color,
          _filters.copyWith(clearSeverity: true));
    }
    if (_filters.employee != null) {
      add(_filters.employee!.label, Icons.person_rounded,
          const Color(0xFF0284C7), _filters.copyWith(clearEmployee: true));
    }
    if (_filters.status.isNotEmpty) {
      final style = statusStyleFor(_filters.status);
      add(style.label, style.icon, style.color, _filters.copyWith(status: ''));
    }
    if (_filters.startDate != null) {
      add('From ${_day.format(_filters.startDate!)}',
          Icons.event_available_rounded, AppColors.primary,
          _filters.copyWith(clearStart: true));
    }
    if (_filters.endDate != null) {
      add('To ${_day.format(_filters.endDate!)}', Icons.event_busy_rounded,
          AppColors.primary, _filters.copyWith(clearEnd: true));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 2),
            child: Text(
              'ACTIVE FILTERS',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
                color: AppColors.textFaint,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: chips,
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: _clearFilters,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 15, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      'Clear All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

/// The screen's identity band, in place of an AppBar.
///
/// Uses the app's existing brand hero ramp so Incidents sits in the same family
/// as the home header rather than introducing a second visual language.
class _Header extends StatelessWidget {
  final Animation<double> animation;
  final int total;
  final bool loading;
  final int activeFilters;
  final VoidCallback onBack;
  final VoidCallback onFilter;

  const _Header({
    Key? key,
    required this.animation,
    required this.total,
    required this.loading,
    required this.activeFilters,
    required this.onBack,
    required this.onFilter,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final rise = Tween<Offset>(
      begin: const Offset(0, 0.28),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroDeep, AppColors.heroMid, AppColors.heroEdge],
        ),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(26)),
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
          padding: const EdgeInsets.fromLTRB(6, 4, 12, 18),
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
                      onPressed: onBack,
                      tooltip: 'Back',
                    ),
                    _PulsingBadge(animation: animation),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Site Incidents',
                                style: TextStyle(
                                  color: AppColors.onPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _CountPill(count: total, loading: loading),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Monitor and manage all site incidents',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.onPrimary.withOpacity(0.82),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _FilterButton(
                        activeCount: activeFilters, onTap: onFilter),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The header's incident mark — a slow breathing halo, so the screen reads as
/// "live monitoring" without anything actually moving on the page.
class _PulsingBadge extends StatefulWidget {
  final Animation<double> animation;

  const _PulsingBadge({Key? key, required this.animation}) : super(key: key);

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: widget.animation, curve: Curves.easeOutBack),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = _pulse.value;
          return Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withOpacity(0.16),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.onPrimary.withOpacity(0.10 + 0.10 * t),
                  blurRadius: 8 + 10 * t,
                  spreadRadius: 1 + 2 * t,
                ),
              ],
            ),
            child: child,
          );
        },
        child: const Icon(Icons.report_problem_rounded,
            color: AppColors.onPrimary, size: 22),
      ),
    );
  }
}

/// Live incident count next to the title.
class _CountPill extends StatelessWidget {
  final int count;
  final bool loading;

  const _CountPill({Key? key, required this.count, required this.loading})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
      child: Container(
        key: ValueKey(loading ? -1 : count),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.onPrimary.withOpacity(0.20),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          loading ? '—' : '$count',
          style: const TextStyle(
            color: AppColors.onPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Filter button; carries the active-filter count as a badge.
/// Filter entry point, carrying the active count as a filled badge.
class _FilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;

  const _FilterButton({
    Key? key,
    required this.activeCount,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final active = activeCount > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: EdgeInsets.fromLTRB(13, 9, active ? 8 : 13, 9),
          decoration: BoxDecoration(
            color: AppColors.onPrimary.withOpacity(active ? 0.20 : 0.13),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.onPrimary.withOpacity(active ? 0.34 : 0.20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_list_rounded,
                  color: AppColors.onPrimary, size: 18),
              const SizedBox(width: 7),
              const Text(
                'Filter',
                style: TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // The badge grows in rather than appearing: applying a filter
              // should be visible in the control you just used.
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                child: active
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.onPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$activeCount',
                            style: TextStyle(
                              color: AppColors.primaryDeep,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

/// The call to action for reporting a new incident.
///
/// An extended FAB rather than a header button: it stays reachable at the
/// thumb while the feed scrolls, and the label spells out what it does instead
/// of leaving a bare plus to be interpreted. Enters after the first frame so it
/// does not compete with the header and summary animating in.
class _AddIncidentButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AddIncidentButton({Key? key, required this.onTap}) : super(key: key);

  @override
  State<_AddIncidentButton> createState() => _AddIncidentButtonState();
}

class _AddIncidentButtonState extends State<_AddIncidentButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  Timer? _start;

  @override
  void initState() {
    super.initState();
    _start = Timer(const Duration(milliseconds: 520), () {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack),
      // An extended FAB is pinned to 48dp by its own theme, so the height has
      // to come down through extendedSizeConstraints rather than a SizedBox,
      // which the button would simply ignore.
      child: Theme(
        data: Theme.of(context).copyWith(
          floatingActionButtonTheme:
              Theme.of(context).floatingActionButtonTheme.copyWith(
                    extendedSizeConstraints:
                        const BoxConstraints.tightFor(height: 40),
                    extendedPadding:
                        const EdgeInsets.symmetric(horizontal: 14),
                  ),
        ),
        child: FloatingActionButton.extended(
          onPressed: widget.onTap,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 6,
          extendedIconLabelSpacing: 6,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text(
            'Add Incident',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

/// Palette for the HUD summary.
///
/// Fixed rather than theme-derived, like an instrument that looks the same
/// whatever light is in the room. The panel is its own dark environment, so it
/// cannot take the page's neutrals without losing the glow the design lives on.
class _Hud {
  static const panelTop = Color(0xFF0A121C);
  static const panelBottom = Color(0xFF05090F);
  static const border = Color(0x14FFFFFF);

  /// The dome runs red at the open end through violet to blue at the resolved
  /// end — the same left-to-right journey the numbers below describe.
  static const arcStart = Color(0xFFFF3B4E);
  static const arcMid = Color(0xFFA855F7);
  static const arcEnd = Color(0xFF3B82F6);

  static const open = Color(0xFF3B82F6);
  static const critical = Color(0xFFEF4444);
  static const closed = Color(0xFF22C55E);

  static const ink = Color(0xFFFFFFFF);
  static const inkSoft = Color(0xB3FFFFFF);
  static const inkFaint = Color(0x59FFFFFF);
}

/// The summary: an incident status HUD.
///
/// A dome gauge carrying the total, its two endpoints trailing particle wings,
/// and three readings beneath a glowing rule. Everything but the type is drawn
/// by [_GaugePainter] — the arc, its ticks, the end lamps and the wings share
/// one coordinate space, which is the only way the wings can be guaranteed to
/// start exactly where the arc stops.
class _IncidentHud extends StatefulWidget {
  final int total;
  final int open;
  final int critical;
  final int closed;

  const _IncidentHud({
    Key? key,
    required this.total,
    required this.open,
    required this.critical,
    required this.closed,
  }) : super(key: key);

  @override
  State<_IncidentHud> createState() => _IncidentHudState();
}

class _IncidentHudState extends State<_IncidentHud>
    with TickerProviderStateMixin {
  /// Slow drift through the wing strands and the end lamps.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat();

  /// The dome draws itself once on arrival.
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _drift.dispose();
    _sweep.dispose();
    super.dispose();
  }

  int get _loaded => widget.open + widget.closed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Hud.panelTop, _Hud.panelBottom],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Hud.border),
        boxShadow: [
          BoxShadow(
            color: _Hud.panelBottom.withOpacity(0.55),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dome(),
            _GlowRule(colour: _Hud.arcEnd),
            _readings(),
            // The seam of light along the foot, as in the reference.
            _GlowRule(colour: _Hud.arcEnd, strength: 0.7),
          ],
        ),
      ),
    );
  }

  // -- the dome -------------------------------------------------------------

  Widget _dome() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The dome keeps a sane radius on a tablet instead of stretching to
        // whatever width it is handed.
        final arcWidth = math.min(constraints.maxWidth * 0.66, 300.0);
        final radius = arcWidth / 2;
        const topPad = 18.0;
        final height = topPad + radius + 24;

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_drift, _sweep]),
                  builder: (context, _) => CustomPaint(
                    painter: _GaugePainter(
                      radius: radius,
                      baselineY: topPad + radius,
                      drift: _drift.value,
                      sweep: Curves.easeOutCubic.transform(_sweep.value),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: topPad + radius * 0.38,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _total(),
                    const SizedBox(height: 6),
                    const Text(
                      'TOTAL INCIDENTS',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 4.2,
                        fontWeight: FontWeight.w600,
                        color: _Hud.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _NodeRule(),
                    if (_loaded < widget.total) ...[
                      const SizedBox(height: 9),
                      Text(
                        '${widget.total - _loaded} STILL LOADING',
                        style: const TextStyle(
                          fontSize: 8,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                          color: _Hud.inkFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The total, over a shield watermark, in gradient type.
  Widget _total() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Watermark sits behind and slightly high, so the numeral overlaps its
        // lower half exactly as in the reference.
        Positioned(
          top: -22,
          child: Icon(
            Icons.gpp_maybe_outlined,
            size: 92,
            color: _Hud.ink.withOpacity(0.05),
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: widget.total.toDouble()),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_Hud.ink, Color(0xFFB9D4FF)],
            ).createShader(rect),
            blendMode: BlendMode.srcIn,
            child: Text(
              '${value.round()}',
              style: const TextStyle(
                fontSize: 44,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -2,
                color: _Hud.ink,
                shadows: [
                  Shadow(color: Color(0x803B82F6), blurRadius: 26),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -- the readings ---------------------------------------------------------

  Widget _readings() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _HudReading(
              value: widget.open,
              label: 'OPEN',
              colour: _Hud.open,
              glyph: Icons.circle,
              glyphSize: 12,
              watermark: Icons.assignment_outlined,
              watermarkLeft: true,
            ),
          ),
          const _CellRule(),
          Expanded(
            child: _HudReading(
              value: widget.critical,
              label: 'CRITICAL',
              colour: _Hud.critical,
              glyph: Icons.warning_amber_rounded,
              glyphSize: 12,
              watermark: Icons.warning_amber_rounded,
              // The only reading that breathes — a live critical count should
              // find the eye before the eye goes looking.
              pulse: widget.critical > 0 ? _drift : null,
            ),
          ),
          const _CellRule(),
          Expanded(
            child: _HudReading(
              value: widget.closed,
              label: 'CLOSED',
              colour: _Hud.closed,
              glyph: Icons.check_rounded,
              glyphSize: 12,
              watermark: Icons.assignment_turned_in_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

/// One reading: ringed glyph, count, underscore, label, over a watermark.
class _HudReading extends StatelessWidget {
  final int value;
  final String label;
  final Color colour;
  final IconData glyph;
  final double glyphSize;
  final IconData watermark;
  final bool watermarkLeft;
  final Animation<double>? pulse;

  const _HudReading({
    Key? key,
    required this.value,
    required this.label,
    required this.colour,
    required this.glyph,
    required this.glyphSize,
    required this.watermark,
    this.watermarkLeft = false,
    this.pulse,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: watermarkLeft ? -14 : null,
          right: watermarkLeft ? null : -14,
          top: 12,
          child: Icon(watermark, size: 72, color: colour.withOpacity(0.07)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ring(),
                  const SizedBox(width: 9),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: value.toDouble()),
                    duration: const Duration(milliseconds: 950),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(
                      // Zero-padded so the three readings hold a common width.
                      v.round().toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 22,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: colour,
                        shadows: [
                          Shadow(color: colour.withOpacity(0.5), blurRadius: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // The short underscore under each figure in the reference.
              Container(
                width: 42,
                height: 2.5,
                decoration: BoxDecoration(
                  color: colour,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(color: colour.withOpacity(0.6), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w700,
                  color: colour,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ring() {
    final ring = Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colour.withOpacity(0.75), width: 1.6),
        boxShadow: [
          BoxShadow(color: colour.withOpacity(0.28), blurRadius: 12),
        ],
      ),
      child: Icon(glyph, size: glyphSize, color: colour),
    );
    if (pulse == null) return ring;
    return AnimatedBuilder(
      animation: pulse!,
      builder: (context, child) {
        // Triangle wave off the drift controller, so the ring breathes in step
        // with the wings rather than on a ticker of its own.
        final t = (pulse!.value * 2 <= 1)
            ? pulse!.value * 2
            : 2 - pulse!.value * 2;
        return Opacity(opacity: 0.65 + 0.35 * t, child: child);
      },
      child: ring,
    );
  }
}

/// Hairline between readings, fading out at both ends.
class _CellRule extends StatelessWidget {
  const _CellRule({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            _Hud.ink.withOpacity(0.14),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// A full-width rule with light pooling at its centre.
class _GlowRule extends StatelessWidget {
  final Color colour;
  final double strength;

  const _GlowRule({Key? key, required this.colour, this.strength = 1})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _Hud.ink.withOpacity(0.12 * strength),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 60),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  colour.withOpacity(0.85 * strength),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: colour.withOpacity(0.45 * strength),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Short rule with a node at its centre, under the hero label.
class _NodeRule extends StatelessWidget {
  const _NodeRule({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget arm(bool leftward) => Container(
          width: 62,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: leftward ? Alignment.centerLeft : Alignment.centerRight,
              end: leftward ? Alignment.centerRight : Alignment.centerLeft,
              colors: [Colors.transparent, _Hud.ink.withOpacity(0.32)],
            ),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        arm(true),
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: _Hud.ink.withOpacity(0.7),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: _Hud.ink.withOpacity(0.5), blurRadius: 6),
            ],
          ),
        ),
        arm(false),
      ],
    );
  }
}

/// The dome, its ticks, its end lamps and the particle wings.
///
/// All four share this painter because they share a geometry: the wings have to
/// originate exactly where the arc terminates, and the lamps have to sit on
/// that same point. Splitting them across widgets would mean duplicating the
/// arithmetic and watching it drift apart.
class _GaugePainter extends CustomPainter {
  final double radius;
  final double baselineY;

  /// 0..1 wrapping — drives the shimmer travelling out along the wings.
  final double drift;

  /// 0..1 one-shot — how much of the dome has been drawn.
  final double sweep;

  const _GaugePainter({
    required this.radius,
    required this.baselineY,
    required this.drift,
    required this.sweep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, baselineY);
    final left = Offset(centre.dx - radius, baselineY);
    final right = Offset(centre.dx + radius, baselineY);

    _wings(canvas, left, isLeft: true, colour: _Hud.arcStart, span: left.dx);
    _wings(canvas, right,
        isLeft: false, colour: _Hud.arcEnd, span: size.width - right.dx);

    _ticks(canvas, centre);
    _arc(canvas, centre);

    if (sweep > 0.98) {
      _lamp(canvas, left, _Hud.arcStart);
      _lamp(canvas, right, _Hud.arcEnd);
    }
  }

  /// The dome itself: a half turn, gradient along its length, drawn in.
  void _arc(Canvas canvas, Offset centre) {
    if (sweep <= 0) return;
    final rect = Rect.fromCircle(center: centre, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        // The sweep starts at 3 o'clock, so the dome occupies the second half
        // of the turn; the stops place red at the left end and blue at the
        // right, matching the direction the readings run.
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          _Hud.arcEnd,
          _Hud.arcEnd,
          _Hud.arcMid,
          _Hud.arcStart,
          _Hud.arcEnd,
        ],
        stops: [0.0, 0.5, 0.75, 1.0, 1.0],
      ).createShader(rect);

    canvas.drawArc(rect, math.pi, math.pi * sweep, false, paint);

    // A second, wider pass at low alpha reads as bloom around the filament.
    final bloom = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          _Hud.arcEnd,
          _Hud.arcEnd,
          _Hud.arcMid,
          _Hud.arcStart,
          _Hud.arcEnd,
        ],
        stops: [0.0, 0.5, 0.75, 1.0, 1.0],
      ).createShader(rect)
      ..color = _Hud.ink.withOpacity(0.4);
    canvas.drawArc(rect, math.pi, math.pi * sweep, false, bloom);
  }

  /// Graduations inside the dome, every 3°, taller every fifth.
  void _ticks(Canvas canvas, Offset centre) {
    if (sweep <= 0) return;
    final paint = Paint()..strokeCap = StrokeCap.round;
    const count = 60;
    for (var i = 0; i <= count; i++) {
      final t = i / count;
      if (t > sweep) break;
      final angle = math.pi + math.pi * t;
      final major = i % 5 == 0;
      final inner = radius - (major ? 16 : 11);
      final outer = radius - 6;
      paint
        ..color = _Hud.ink.withOpacity(major ? 0.30 : 0.15)
        ..strokeWidth = major ? 1.6 : 1;
      canvas.drawLine(
        centre + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        centre + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        paint,
      );
    }
  }

  /// The glowing bead where the arc terminates.
  void _lamp(Canvas canvas, Offset at, Color colour) {
    canvas.drawCircle(
      at,
      9,
      Paint()
        ..color = colour.withOpacity(0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawCircle(at, 4, Paint()..color = colour);
    canvas.drawCircle(at, 1.8, Paint()..color = _Hud.ink.withOpacity(0.9));
  }

  /// Filaments streaming outward from an end lamp, with drifting sparks.
  ///
  /// Deterministic by index rather than random: the pattern has to be identical
  /// on every repaint, or the wings would boil.
  void _wings(
    Canvas canvas,
    Offset origin, {
    required bool isLeft,
    required Color colour,
    required double span,
  }) {
    if (sweep < 0.6 || span <= 8) return;

    // Fades in over the back half of the dome sweep, so the wings arrive after
    // the arc that feeds them.
    final entrance = ((sweep - 0.6) / 0.4).clamp(0.0, 1.0);
    final direction = isLeft ? -1.0 : 1.0;
    final reach = math.min(span, 190.0);
    const strands = 13;

    for (var i = 0; i < strands; i++) {
      final t = strands == 1 ? 0.5 : i / (strands - 1);
      final spread = (t - 0.5) * 2; // -1..1
      final length = reach * (0.55 + 0.45 * (1 - spread.abs()));
      final endX = origin.dx + direction * length;
      final endY = origin.dy + spread * 34;

      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..quadraticBezierTo(
          origin.dx + direction * length * 0.5,
          origin.dy + spread * 6,
          endX,
          endY,
        );

      // Each strand brightens as the drift wave passes along it.
      final wave = 0.5 + 0.5 * math.sin((drift * 2 - t) * math.pi * 2);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = colour.withOpacity((0.05 + 0.16 * wave) * entrance),
      );
    }

    // Sparks riding the same field.
    for (var i = 0; i < 9; i++) {
      final t = ((drift + i / 9) % 1.0);
      final lane = (i % 5) / 4 - 0.5;
      final x = origin.dx + direction * reach * (0.15 + 0.85 * t);
      final y = origin.dy + lane * 40 * t;
      final fade = math.sin(t * math.pi).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x, y),
        1.4,
        Paint()..color = colour.withOpacity(0.55 * fade * entrance),
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.drift != drift || old.sweep != sweep || old.radius != radius;
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onRemove;

  const _ActiveFilterChip({
    Key? key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 11, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.tint(accent, 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Its own tap target rather than the whole chip: tapping a filter to
          // read it should not delete it.
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close_rounded, size: 14, color: accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Incident card
// ---------------------------------------------------------------------------

/// One incident, drawn as a torn-off report ticket.
///
/// The stub down the left carries the reference number and the severity mark,
/// and its edge is perforated so the card reads as something issued rather than
/// a row in a list. Colour on the stub is the fastest read on the screen: you
/// know how bad it is before any text resolves.
///
/// On a wide screen the disposition — severity, status, the way in — sits in a
/// tinted panel torn off down the right. Below [_wideBreakpoint] that panel
/// cannot hold its content without crushing it, so it folds into a footer bar
/// and the ticket keeps its shape.
class _IncidentCard extends StatelessWidget {
  final SiteIncident incident;
  final bool expanded;
  final DateFormat stamp;
  final VoidCallback onToggle;
  final VoidCallback onOpenFull;

  /// Below this the right-hand panel folds into a footer row.
  static const double _wideBreakpoint = 560;

  const _IncidentCard({
    Key? key,
    required this.incident,
    required this.expanded,
    required this.stamp,
    required this.onToggle,
    required this.onOpenFull,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final severity = severityStyleFor(incident.severity);
    final status = statusStyleFor(incident.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: AppColors.surface,
            child: InkWell(
              onTap: onToggle,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= _wideBreakpoint;
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TicketStub(
                          reference: _reference,
                          colour: severity.color,
                          glyph: severity.icon,
                          width: wide ? 46 : 36,
                        ),
                        Expanded(child: _body(context, wide, severity, status)),
                        if (wide)
                          _DispositionPanel(
                            severity: severity,
                            status: status,
                            onView: onOpenFull,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _reference =>
      '#INC-${incident.siteIncidentId.toString().padLeft(4, '0')}';

  // -- the body -------------------------------------------------------------

  Widget _body(BuildContext context, bool wide, SeverityStyle severity,
      StatusStyle status) {
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 18 : 14, 12, wide ? 18 : 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _typeAndSiteRow(),
          const SizedBox(height: 7),
          _dateLine(),
          const SizedBox(height: 9),
          _headline(),
          const SizedBox(height: 11),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 9),
          _attribution(wide),
          // Folded panel: on a narrow card the disposition rides here instead.
          if (!wide) ...[
            const SizedBox(height: 10),
            _footerBar(severity, status),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? _ExpandedDetails(
                    incident: incident,
                    stamp: stamp,
                    onOpenFull: onOpenFull,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// When and where, split by a hairline.
  /// Type on the left, site on the right, on one line.
  ///
  /// These are the two things that identify an incident at a glance — what
  /// happened and where — so they take the top line together. Both sides flex
  /// and ellipsis rather than wrapping, which keeps the row a fixed height
  /// however long a site name runs.
  Widget _typeAndSiteRow() {
    final type =
        incident.incidentType.isEmpty ? 'Incident' : incident.incidentType;
    final accent = incidentTypeAccent(incident.incidentType);
    final where =
        incident.location.isEmpty ? 'Unknown site' : incident.location;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(incidentTypeIcon(incident.incidentType),
                  size: 14, color: accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.place_outlined, size: 13, color: AppColors.primary),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  where,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// When the incident happened. The reported date is deliberately absent from
  /// the card — one date on a ticket cannot be misread for the other.
  Widget _dateLine() {
    return _metaItem(
      Icons.calendar_today_rounded,
      incident.incidentDate == null
          ? 'Date not recorded'
          : stamp.format(incident.incidentDate!),
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.primary),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// The description, set as the card's title.
  ///
  /// The API carries no separate title field — `incidentDescription` is the one
  /// piece of free text on the record, so it takes the headline slot rather
  /// than being buried under a repeated copy of the type. The full text is in
  /// the expansion when it runs longer than two lines.
  Widget _headline() {
    final text = incident.incidentDescription.isEmpty
        ? 'No description recorded'
        : incident.incidentDescription;

    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 15.5,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: incident.incidentDescription.isEmpty
            ? AppColors.textFaint
            : AppColors.textPrimary,
      ),
    );
  }

  /// Who owns it, who raised it, when it was raised.
  Widget _attribution(bool wide) {
    final cells = <Widget>[
      _AttributionCell(
        icon: Icons.person_outline_rounded,
        label: 'Responsible',
        value: incident.responsibleEmployeeName.isEmpty
            ? 'Unassigned'
            : incident.responsibleEmployeeName,
      ),
      _AttributionCell(
        icon: Icons.badge_outlined,
        label: 'Reported By',
        value: incident.reportedByName.isEmpty
            ? 'Unknown'
            : incident.reportedByName,
      ),
    ];

    if (!wide) {
      // Three columns on a phone leaves each about 90dp — enough for a label
      // but not for a name, so they stack into rows instead.
      return Column(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            cells[i],
            if (i != cells.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            Expanded(child: cells[i]),
            if (i != cells.length - 1)
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: AppColors.divider,
              ),
          ],
        ],
      ),
    );
  }

  /// The narrow-screen stand-in for the disposition panel.
  Widget _footerBar(SeverityStyle severity, StatusStyle status) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 7, 7),
      decoration: BoxDecoration(
        color: AppColors.tint(severity.color, 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _SeverityPill(severity: severity),
          const SizedBox(width: 10),
          Flexible(child: _StatusStamp(status: status, compact: true)),
          const Spacer(),
          _ViewButton(colour: severity.color, onTap: onOpenFull, compact: true),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ticket parts
// ---------------------------------------------------------------------------

/// The coloured stub: reference number set vertically, severity mark below it,
/// and a perforated edge where it would tear away.
class _TicketStub extends StatelessWidget {
  final String reference;
  final Color colour;
  final IconData glyph;
  final double width;

  const _TicketStub({
    Key? key,
    required this.reference,
    required this.colour,
    required this.glyph,
    required this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: CustomPaint(
        painter: _PerforationPainter(
          stub: colour,
          punch: AppColors.surface,
        ),
        child: Padding(
          // Right inset clears the punched notches so nothing sits under them.
          padding: const EdgeInsets.only(top: 11, bottom: 10, right: 5),
          child: Column(
            children: [
              Expanded(
                child: RotatedBox(
                  quarterTurns: 1,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      reference,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Icon(glyph, size: 16, color: AppColors.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fills the stub and punches a column of notches out of its trailing edge.
class _PerforationPainter extends CustomPainter {
  final Color stub;
  final Color punch;

  static const double _radius = 3.6;
  static const double _spacing = 11;

  const _PerforationPainter({required this.stub, required this.punch});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = stub);

    // Notches are centred on the edge itself, so half of each circle bites into
    // the stub and half lands on the body — the tear line reads as one row of
    // holes rather than two rows of bumps.
    final paint = Paint()..color = punch;
    for (double y = _spacing / 2; y < size.height; y += _spacing) {
      canvas.drawCircle(Offset(size.width, y), _radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter old) =>
      old.stub != stub || old.punch != punch;
}

/// The torn-off right panel: how bad, what state, and the way in.
class _DispositionPanel extends StatelessWidget {
  final SeverityStyle severity;
  final StatusStyle status;
  final VoidCallback onView;

  const _DispositionPanel({
    Key? key,
    required this.severity,
    required this.status,
    required this.onView,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 158,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tint(severity.color, 0.07),
        border: Border(left: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SeverityPill(severity: severity),
          const SizedBox(height: 11),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          // Rotation is painted, not laid out, so the stamp needs its own
          // breathing room or its corners ride over the rule above it.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: _StatusStamp(status: status),
          ),
          const SizedBox(height: 11),
          _ViewButton(colour: severity.color, onTap: onView),
        ],
      ),
    );
  }
}

class _SeverityPill extends StatelessWidget {
  final SeverityStyle severity;

  const _SeverityPill({Key? key, required this.severity}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.tint(severity.color, 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: severity.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            severity.label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w800,
              color: severity.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status, drawn as a rubber stamp struck across the ticket.
///
/// The card is a report ticket, so its disposition is the one thing on it that
/// should look applied rather than printed — set at an angle, in a double-ruled
/// box, in ink that has not quite taken evenly. It also solves a legibility
/// problem the old treatment had: OPEN and Closed were two words in two colours
/// that scanned almost identically down a column of cards. A tilted stamp is
/// recognisable from the shape alone, before the word is read.
class _StatusStamp extends StatelessWidget {
  final StatusStyle status;
  final bool compact;

  const _StatusStamp({
    Key? key,
    required this.status,
    this.compact = false,
  }) : super(key: key);

  /// Shallower on the footer bar, where a steeper tilt would foul its
  /// neighbours — rotation paints outside the layout box.
  double get _angle => compact ? -0.075 : -0.13;

  @override
  Widget build(BuildContext context) {
    final ink = status.color;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        // easeOutBack overshoots past 1, which is what gives the press its
        // recoil — but opacity has to be clamped or it throws.
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: _angle,
            // Struck from above: starts oversized and settles onto the card.
            child: Transform.scale(scale: 1 + 0.3 * (1 - t), child: child),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(compact ? 2 : 2.5),
        decoration: BoxDecoration(
          border: Border.all(color: ink.withOpacity(0.75), width: 2),
          borderRadius: BorderRadius.circular(compact ? 5 : 6),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 11,
            vertical: compact ? 3 : 5,
          ),
          decoration: BoxDecoration(
            // The inner rule is the detail that reads as a stamp rather than
            // as a button with a heavy border.
            border: Border.all(color: ink.withOpacity(0.35)),
            borderRadius: BorderRadius.circular(compact ? 3 : 4),
          ),
          child: Text(
            status.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 10.5 : 12.5,
              height: 1,
              letterSpacing: compact ? 1.4 : 1.9,
              fontWeight: FontWeight.w900,
              // Slightly short of full strength, so the ink reads as pressed
              // into the card rather than set in type.
              color: ink.withOpacity(0.88),
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewButton extends StatelessWidget {
  final Color colour;
  final VoidCallback onTap;
  final bool compact;

  const _ViewButton({
    Key? key,
    required this.colour,
    required this.onTap,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: compact ? null : double.infinity,
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 11 : 10, vertical: compact ? 6 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.tint(colour, 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility_outlined, size: 14, color: colour),
              const SizedBox(width: 6),
              Text(
                'View',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: colour,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon over a label/value pair, used across the attribution row.
class _AttributionCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AttributionCell({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textFaint,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The in-place expansion: everything the feed row leaves out.
class _ExpandedDetails extends StatelessWidget {
  final SiteIncident incident;
  final DateFormat stamp;
  final VoidCallback onOpenFull;

  const _ExpandedDetails({
    Key? key,
    required this.incident,
    required this.stamp,
    required this.onOpenFull,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 12),
        IncidentDetailSections(incident: incident, stamp: stamp),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onOpenFull,
            icon: const Icon(Icons.open_in_full_rounded, size: 15),
            label: const Text('Full details'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

/// The detail blocks, shared by the expanded card and the full-screen view so
/// the two can never drift apart.
class IncidentDetailSections extends StatelessWidget {
  final SiteIncident incident;
  final DateFormat stamp;

  const IncidentDetailSections({
    Key? key,
    required this.incident,
    required this.stamp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final severity = severityStyleFor(incident.severity);
    final status = statusStyleFor(incident.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _block(
          'Overview',
          Icons.dashboard_rounded,
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _fact('Incident ID',
                  'INC-${incident.siteIncidentId.toString().padLeft(4, '0')}'),
              _fact('Type',
                  incident.incidentType.isEmpty ? '—' : incident.incidentType),
              _fact('Site',
                  incident.location.isEmpty ? '—' : incident.location),
              _fact('Severity', severity.label, color: severity.color),
              _fact('Status', status.label, color: status.color),
              if (incident.incidentDate != null)
                _fact('Incident date', stamp.format(incident.incidentDate!)),
            ],
          ),
        ),
        if (incident.incidentDescription.isNotEmpty)
          _block('Description', Icons.notes_rounded,
              _paragraph(incident.incidentDescription)),
        if (incident.implication.isNotEmpty)
          _block('Impact', Icons.warning_amber_rounded,
              _paragraph(incident.implication)),
        if (incident.suggestionForFuture.isNotEmpty)
          _block('Future prevention', Icons.lightbulb_outline_rounded,
              _paragraph(incident.suggestionForFuture)),
        _block(
          'Responsibility',
          Icons.groups_rounded,
          Column(
            children: [
              _person('Responsible', incident.responsibleEmployeeName),
              _person('Supervisor', incident.supervisorName),
              _person('Reported by', incident.reportedByName),
            ],
          ),
        ),
        _block(
          'Timeline',
          Icons.timeline_rounded,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _step(
                'Incident occurred',
                incident.incidentDate == null
                    ? 'Not recorded'
                    : stamp.format(incident.incidentDate!),
                AppColors.warning,
                isLast: false,
              ),
              _step(
                'Reported',
                incident.reportedDate == null
                    ? 'Not recorded'
                    : stamp.format(incident.reportedDate!),
                AppColors.primary,
                isLast: false,
              ),
              _step('Current status', status.label, status.color,
                  isLast: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _block(String title, IconData icon, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: AppColors.textFaint),
                const SizedBox(width: 5),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            child,
          ],
        ),
      );

  Widget _fact(String label, String value, {Color? color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: AppColors.textFaint)),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      );

  Widget _paragraph(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _person(String role, String name) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            InitialsAvatar(name: name, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Not assigned' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(role,
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textFaint)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _step(String title, String detail, Color color,
          {required bool isLast}) =>
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.divider),
                  ),
              ],
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(detail,
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Full-screen detail
// ---------------------------------------------------------------------------

class _IncidentDetailScreen extends StatelessWidget {
  final SiteIncident incident;
  final DateFormat stamp;

  const _IncidentDetailScreen({
    Key? key,
    required this.incident,
    required this.stamp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final severity = severityStyleFor(incident.severity);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: severity.color,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        title: Text(
          'INC-${incident.siteIncidentId.toString().padLeft(4, '0')}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: ContentWidthLimit(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: AppColors.shadow, blurRadius: 14),
              ],
            ),
            child: IncidentDetailSections(incident: incident, stamp: stamp),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared pieces
// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;

  const _Badge({
    Key? key,
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : AppColors.tint(color, 0.12),
        borderRadius: BorderRadius.circular(99),
        border: filled ? null : Border.all(color: AppColors.tint(color, 0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: filled ? AppColors.onPrimary : color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: filled ? AppColors.onPrimary : color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade + rise entrance, staggered by [position].
///
/// Each instance owns its controller and cancels its pending start on dispose,
/// so a fast scroll that builds and discards rows cannot leave timers running.
class _EntranceAnimation extends StatefulWidget {
  final int position;
  final Widget child;
  final double offsetY;

  const _EntranceAnimation({
    Key? key,
    required this.position,
    required this.child,
    this.offsetY = 0.12,
  }) : super(key: key);

  @override
  State<_EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<_EntranceAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  Timer? _start;

  @override
  void initState() {
    super.initState();
    // Capped so a long page does not leave the last rows waiting seconds.
    final delay = 40 * (widget.position.clamp(0, 8));
    _start = Timer(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _start?.cancel();
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
          begin: Offset(0, widget.offsetY),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading / empty / error states
// ---------------------------------------------------------------------------

/// Skeleton mirroring the real layout — HUD panel then ticket cards — so the
/// screen does not visibly re-flow when the data lands.
class _SkeletonFeed extends StatelessWidget {
  final Animation<double> shimmer;

  const _SkeletonFeed({Key? key, required this.shimmer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: ContentWidthLimit(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A dark block at the panel size rather than a shimmering one: the
            // HUD is its own dark environment, and a pale placeholder would
            // flash white before the panel paints over it.
            Container(
              height: 300,
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_Hud.panelTop, _Hud.panelBottom],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _Hud.border),
              ),
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_Hud.arcEnd.withOpacity(0.7)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  for (var i = 0; i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: _ShimmerBox(
                          animation: shimmer, height: 132, radius: 16),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single shimmering placeholder block.
class _ShimmerBox extends StatelessWidget {
  final Animation<double> animation;
  final double height;
  final double? width;
  final double radius;

  const _ShimmerBox({
    Key? key,
    required this.animation,
    required this.height,
    required this.radius,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // A band sweeping left→right, rather than a whole-block pulse: it reads
        // as loading progress instead of a flashing rectangle.
        // Band travels from fully off the left edge to fully off the right,
        // so every part of the block gets swept.
        final x = -2.0 + 4.0 * animation.value;
        return Container(
          height: height,
          width: width ?? double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
              colors: [
                AppColors.surfaceAlt,
                AppColors.surface,
                AppColors.surfaceAlt,
              ],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool filtersActive;
  final VoidCallback onClear;

  const _EmptyState({
    Key? key,
    required this.filtersActive,
    required this.onClear,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _EntranceAnimation(
        position: 0,
        offsetY: 0.2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: AppColors.tint(AppColors.success, 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.verified_rounded,
                      size: 42, color: AppColors.success),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No incidents found',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                filtersActive
                    ? 'Nothing matches the filters you have applied. Try widening the date range or clearing a filter.'
                    : 'No site incidents have been reported yet. Anything raised will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              if (filtersActive) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                  label: const Text('Clear filters'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    Key? key,
    required this.message,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _EntranceAnimation(
        position: 0,
        offsetY: 0.2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.tint(AppColors.danger, 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_off_rounded,
                    size: 40, color: AppColors.danger),
              ),
              const SizedBox(height: 18),
              Text(
                'Could not load incidents',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
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
      ),
    );
  }
}
