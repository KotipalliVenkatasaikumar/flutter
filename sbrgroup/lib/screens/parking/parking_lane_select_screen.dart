import 'dart:convert';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/parking/parking_context.dart';
import 'package:ajna/screens/parking/parking_models.dart';
import 'package:ajna/screens/parking/parking_widgets.dart';
import 'package:ajna/screens/util.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:flutter/material.dart';

/// Pick the site and lane the attendant is posted at.
///
/// Sites, zones and lanes are created on the **web admin** — this only lists
/// what is already configured. The pick is saved, so it is a one-time step per
/// posting rather than something to repeat for every vehicle.
class ParkingLaneSelectScreen extends StatefulWidget {
  /// Restrict the lane list to lanes usable for this direction.
  /// 'IN' for entry, 'OUT' for exit, null to show all.
  final String? requiredDirection;

  const ParkingLaneSelectScreen({Key? key, this.requiredDirection})
      : super(key: key);

  @override
  State<ParkingLaneSelectScreen> createState() =>
      _ParkingLaneSelectScreenState();
}

class _ParkingLaneSelectScreenState extends State<ParkingLaneSelectScreen> {
  List<ParkingProject> _projects = [];
  List<ParkingSite> _sites = [];
  List<ParkingLane> _lanes = [];
  ParkingProject? _project;
  ParkingSite? _site;
  bool _loadingProjects = false;
  bool _loadingSites = false;

  /// Whether to show the full project list.
  ///
  /// A posted operator works one project for months, so re-listing every
  /// project the organisation owns on each visit is noise — and an extra call.
  /// The saved project is used straight away and only re-picked on request.
  bool _pickingProject = false;
  bool _loadingLanes = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (ParkingContext.projectId != null) {
      // Go straight to the saved project's sites — no project call at all.
      _project = ParkingProject(
        projectId: ParkingContext.projectId,
        projectName: ParkingContext.projectName,
      );
      _loadSites();
    } else {
      _pickingProject = true;
      _loadProjects();
    }
  }

  /// Show the list so a different project can be chosen.
  void _changeProject() {
    setState(() {
      _pickingProject = true;
      _sites = [];
      _lanes = [];
      _site = null;
    });
    if (_projects.isEmpty) _loadProjects();
  }

  /// Projects for the operator's organisation. Sites hang off a project, so
  /// this narrows the site list instead of showing every site the company owns.
  Future<void> _loadProjects() async {
    setState(() {
      _loadingProjects = true;
      _error = null;
    });
    try {
      final int? orgId = await Util.getOrganizationId();
      if (orgId == null) {
        _fail('Could not identify your organisation. Please log in again.');
        return;
      }
      final response = await ApiService.fetchOrgProjects(orgId);
      if (ApiService.isSuccess(response.statusCode)) {
        final decoded = jsonDecode(response.body);
        final list = (decoded is List) ? decoded : (decoded['data'] ?? []);
        final projects = (list as List)
            .map((e) => ParkingProject.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint('Parking projects loaded: ${projects.length}');
        if (!mounted) return;
        setState(() {
          _projects = projects;
          _loadingProjects = false;
        });

        // Reuse the project this operator worked last; otherwise skip the step
        // entirely when there is only one to choose.
        ParkingProject? preselect;
        for (final p in projects) {
          if (p.projectId == ParkingContext.projectId) preselect = p;
        }
        preselect ??= projects.length == 1 ? projects.first : null;
        if (preselect != null) _selectProject(preselect);
      } else {
        debugPrint('Parking projects failed: HTTP ${response.statusCode} '
            '${response.body}');
        _fail('Could not load projects. Please try again.');
      }
    } catch (e) {
      debugPrint('Parking projects error: $e');
      _fail('Could not load projects. Please check your connection.');
    }
  }

  Future<void> _selectProject(ParkingProject project) async {
    await ParkingContext.saveProject(project);
    if (!mounted) return;
    setState(() {
      _project = project;
      _pickingProject = false;
      _sites = [];
      _lanes = [];
      _site = null;
    });
    _loadSites();
  }

  Future<void> _loadSites() async {
    setState(() {
      _loadingSites = true;
      _error = null;
    });
    try {
      final response =
          await ApiService.getParkingSites(projectId: _project?.projectId);
      if (ApiService.isSuccess(response.statusCode)) {
        final decoded = jsonDecode(response.body);
        final list = (decoded is List) ? decoded : (decoded['data'] ?? []);
        final sites = (list as List)
            .map((e) => ParkingSite.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint('Parking sites loaded: ${sites.length}');
        if (!mounted) return;
        setState(() {
          _sites = sites;
          _loadingSites = false;
        });
        // Straight to the lanes when there is only one site to choose.
        if (sites.length == 1) _selectSite(sites.first);
      } else {
        // Friendly text on screen, the detail here — a 404 means /parking is
        // not deployed on this server, 401/403 a token or role problem.
        debugPrint('Parking sites failed: HTTP ${response.statusCode} '
            '${response.body}');
        _fail('Could not load parking sites. Please try again.');
      }
    } catch (e) {
      debugPrint('Parking sites error: $e');
      _fail('Could not load parking sites. Please check your connection.');
    }
  }

  Future<void> _selectSite(ParkingSite site) async {
    setState(() {
      _site = site;
      _lanes = [];
      _loadingLanes = true;
      _error = null;
    });
    try {
      final response = await ApiService.getParkingLanesBySite(site.siteId ?? 0);
      if (ApiService.isSuccess(response.statusCode)) {
        final decoded = jsonDecode(response.body);
        final list = (decoded is List) ? decoded : (decoded['data'] ?? []);
        var lanes = (list as List)
            .map((e) => ParkingLane.fromJson(e as Map<String, dynamic>))
            .toList();
        // Only offer lanes that can actually take this movement — the backend
        // refuses an entry on an OUT lane, better to not show it at all.
        final dir = widget.requiredDirection;
        if (dir == ParkingConstants.laneDirectionIn) {
          lanes = lanes.where((l) => l.allowsEntry).toList();
        } else if (dir == ParkingConstants.laneDirectionOut) {
          lanes = lanes.where((l) => l.allowsExit).toList();
        }
        debugPrint('Parking lanes loaded for site ${site.siteId}: '
            '${lanes.length} (after direction filter)');
        if (!mounted) return;
        setState(() {
          _lanes = lanes;
          _loadingLanes = false;
        });
      } else {
        debugPrint('Parking lanes failed: HTTP ${response.statusCode} '
            '${response.body}');
        _fail('Could not load lanes for this site.');
      }
    } catch (e) {
      debugPrint('Parking lanes error: $e');
      _fail('Could not load lanes. Please check your connection.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loadingProjects = false;
      _loadingSites = false;
      _loadingLanes = false;
      _error = message;
    });
  }

  Future<void> _choose(ParkingLane lane) async {
    if (!lane.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warning,
          content: Text('${lane.laneName ?? "This lane"} is not active.',
              style: const TextStyle(color: AppColors.onPrimary)),
        ),
      );
      return;
    }
    await ParkingContext.saveLane(_site!, lane);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Select Lane'),
        centerTitle: true,
      ),
      body: _error != null
          ? _errorView()
          : ContentWidthLimit(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionLabel('Project'),
                  if (!_pickingProject && _project != null)
                    _chosenProjectChip()
                  else if (_loadingProjects)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary)),
                    )
                  else if (_projects.isEmpty)
                    _emptyNote('No projects found for your organisation.')
                  else
                    ..._projects.asMap().entries.map((e) => AnimatedEntry(
                        index: e.key, child: _projectTile(e.value))),
                  if (_project != null) ...[
                    const SizedBox(height: 18),
                    _sectionLabel('Site in ${_project!.projectName ?? ""}'),
                    if (_loadingSites)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary)),
                      )
                    else if (_sites.isEmpty)
                      _emptyNote('No parking sites configured for this '
                          'project. Sites are set up on the web admin.')
                    else
                      ..._sites.asMap().entries.map((e) => AnimatedEntry(
                          index: e.key, child: _siteTile(e.value))),
                  ],
                  if (_site != null) ...[
                    const SizedBox(height: 18),
                    _sectionLabel('Lane at ${_site!.siteName ?? ""}'),
                    if (_loadingLanes)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary)),
                      )
                    else if (_lanes.isEmpty)
                      _emptyNote(widget.requiredDirection == null
                          ? 'No lanes configured for this site.'
                          : 'No lane at this site accepts '
                              '${widget.requiredDirection == ParkingConstants.laneDirectionIn ? "entry" : "exit"}.')
                    else
                      ..._lanes.asMap().entries.map((e) => AnimatedEntry(
                          index: e.key, child: _laneTile(e.value))),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );

  Widget _emptyNote(String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(text, style: TextStyle(color: AppColors.textSecondary)),
      );

  /// The remembered project, compact, with a way back to the list.
  Widget _chosenProjectChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.tint(AppColors.primary, 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.apartment, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _project?.projectName ?? 'Project ${_project?.projectId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: _changeProject,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Change',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _projectTile(ParkingProject project) {
    final bool selected = _project?.projectId == project.projectId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _selectProject(project),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.tint(AppColors.primary, 0.08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.divider,
                width: selected ? 1.6 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.apartment,
                    color: selected ? AppColors.primary : AppColors.textFaint,
                    size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                      project.projectName ?? 'Project ${project.projectId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                ),
                if (selected)
                  const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _siteTile(ParkingSite site) {
    final bool selected = _site?.siteId == site.siteId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _selectSite(site),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.tint(AppColors.primary, 0.08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.divider,
                width: selected ? 1.6 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.location_city,
                    color: selected ? AppColors.primary : AppColors.textFaint,
                    size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(site.siteName ?? 'Site ${site.siteId}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          )),
                      if ((site.siteCode ?? '').isNotEmpty)
                        Text(site.siteCode!,
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _laneTile(ParkingLane lane) {
    final bool active = lane.isActive;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _choose(lane),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.tint(
                        active ? AppColors.primary : AppColors.textFaint, 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                      lane.direction == ParkingConstants.laneDirectionIn
                          ? Icons.login
                          : lane.direction == ParkingConstants.laneDirectionOut
                              ? Icons.logout
                              : Icons.swap_horiz,
                      color: active ? AppColors.primary : AppColors.textFaint,
                      size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lane.laneName ?? 'Lane ${lane.laneId}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          )),
                      const SizedBox(height: 2),
                      Text(
                        [
                          ParkingConstants.label(lane.direction),
                          if ((lane.zoneName ?? '').isNotEmpty) lane.zoneName!,
                          if (!active) 'Inactive',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: active
                              ? AppColors.textSecondary
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppColors.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 44, color: AppColors.textFaint),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                onPressed: _loadProjects,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
