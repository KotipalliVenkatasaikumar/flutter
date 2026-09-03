import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/util.dart';
import 'package:ajna/screens/face_detection/face_detection.dart';
import 'package:ajna/screens/face_detection/logout_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';

class AttendanceDashboardScreen extends StatefulWidget {
  @override
  _AttendanceDashboardScreenState createState() =>
      _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState extends State<AttendanceDashboardScreen> {
  List<dynamic> _projects = [];
  int? _selectedProjectId;
  String _selectedProjectName = '';

  bool _isLoading = true;

  /// Set when the locations call fails, so the picker can offer Retry instead
  /// of an empty screen the user cannot get out of.
  bool _loadFailed = false;

  /// True while the user is re-picking a location they had already saved.
  /// Without this the picker only ever appeared on the very first run — once a
  /// location was in SharedPreferences there was no way back to the list.
  bool _isPickingLocation = false;

  String _locationSearch = '';
  final TextEditingController _searchController = TextEditingController();

  int? _userId;
  int? _organizationId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    _userId = await Util.getUserId();
    _organizationId = await Util.getOrganizationId();
    await _loadSelectedProject();
    await _fetchProjects();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadSelectedProject() async {
    final prefs = await SharedPreferences.getInstance();
    final projectId = prefs.getInt('selectedProjectId');
    final projectName = prefs.getString('selectedProjectName');
    if (projectId != null && projectName != null) {
      setState(() {
        _selectedProjectId = projectId;
        _selectedProjectName = projectName;
      });
    }
  }

  Future<void> _fetchProjects() async {
    try {
      final response = await ApiService.fetchLocation(_organizationId!);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _projects = data; // Assume list of projects with id and name
          _loadFailed = false;
        });
      } else {
        setState(() => _loadFailed = true);
      }
    } catch (e) {
      print('Error fetching projects: $e');
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _refreshProjects() async {
    await _fetchProjects();
  }

  Future<void> _selectProject(dynamic project) async {
    final int? projectId = project['id'];
    final String projectName = project['location'] ?? 'Unknown';
    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid project selected.')),
      );
      return;
    }
    setState(() {
      _selectedProjectId = projectId;
      _selectedProjectName = projectName;
      _isPickingLocation = false;
      _locationSearch = '';
      _searchController.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedProjectId', projectId);
    await prefs.setString('selectedProjectName', projectName);
  }

  Future<void> _markAttendance(bool isLogin) async {
    if (_selectedProjectId == null) return;
    // Navigate to face screen
    if (isLogin) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FaceAttendanceScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LogOutFaceAttendanceScreen()),
      );
    }
  }

  /// Time-of-day greeting for the header.
  bool get _showPicker => _selectedProjectId == null || _isPickingLocation;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

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
        // The site is the one piece of context a guard must confirm before
        // marking attendance, so it sits in the bar rather than in a panel
        // below it. The greeting that used to fill that panel told them
        // nothing they needed.
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Attendance',
              style: TextStyle(
                fontSize: width > 600 ? 22 : 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (!_showPicker)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: Colors.white, size: 13),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      _selectedProjectName.isEmpty
                          ? 'No location'
                          : _selectedProjectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_showPicker)
            TextButton.icon(
              onPressed: () => setState(() => _isPickingLocation = true),
              icon: const Icon(Icons.swap_horiz_rounded,
                  size: 18, color: Colors.white),
              label: const Text('Change',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _showPicker
              ? _buildLocationPicker()
              : _buildAttendanceHome(),
    );
  }

  // ---------------------------------------------------------------------------
  // Attendance home — location is chosen, offer Login / Logout.
  // ---------------------------------------------------------------------------
  Widget _buildAttendanceHome() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 24 + bottomBarInset(context)),
      child: ContentWidthLimit(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionLabel('MARK YOUR ATTENDANCE'),
              const SizedBox(height: 14),
              // Colour carries the meaning here, not the words. Guards pick
              // the button by the green or red block and the large IN / OUT,
              // without having to read the English underneath.
              _ActionCard(
                icon: Icons.login_rounded,
                accent: AppColors.success,
                bigLabel: 'IN',
                title: 'Login',
                subtitle: 'Start your shift with face verification',
                onTap: () => _markAttendance(true),
              ),
              const SizedBox(height: 14),
              _ActionCard(
                icon: Icons.logout_rounded,
                accent: AppColors.danger,
                bigLabel: 'OUT',
                title: 'Logout',
                subtitle: 'End your shift with face verification',
                onTap: () => _markAttendance(false),
              ),
              const SizedBox(height: 20),
              _buildHintCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHintCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tint(AppColors.primary, 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tint(AppColors.primary, 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined,
              size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your face is verified at the selected location. Make sure you are '
              'at the right site before marking attendance.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Location picker
  // ---------------------------------------------------------------------------
  Widget _buildLocationPicker() {
    final query = _locationSearch.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _projects
        : _projects
            .where((p) => (p['location'] ?? '')
                .toString()
                .toLowerCase()
                .contains(query))
            .toList();

    return Column(
      children: [
        ContentWidthLimit(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select your location',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Attendance is marked against this site.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Only offer Cancel when there is a saved location to go
                    // back to — on first run there is nothing behind this.
                    if (_selectedProjectId != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _isPickingLocation = false;
                          _locationSearch = '';
                          _searchController.clear();
                        }),
                        child: const Text('Cancel'),
                      ),
                  ],
                ),
                if (_projects.length > 6) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _locationSearch = v),
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search location',
                      hintStyle: TextStyle(color: AppColors.textFaint),
                      prefixIcon:
                          Icon(Icons.search, color: AppColors.textSecondary),
                      suffixIcon: _locationSearch.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(Icons.close,
                                  size: 18, color: AppColors.textSecondary),
                              onPressed: () => setState(() {
                                _locationSearch = '';
                                _searchController.clear();
                              }),
                            ),
                      filled: true,
                      fillColor: AppColors.surface,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refreshProjects,
            child: filtered.isEmpty
                ? _buildEmptyState(query.isNotEmpty)
                : ContentWidthLimit(
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                          16, 8, 16, 24 + bottomBarInset(context)),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final project = filtered[index];
                        final isSelected = _selectedProjectId == project['id'];
                        return _LocationCard(
                          name: project['location'] ?? 'Unknown',
                          accent: AppColors.tileAccent(index),
                          isSelected: isSelected,
                          onTap: () => _selectProject(project),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// Empty / failed state. Always scrollable so pull-to-refresh still works
  /// when there is nothing in the list to drag.
  Widget _buildEmptyState(bool isSearching) {
    final failed = _loadFailed && _projects.isEmpty;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 60),
      children: [
        Icon(
          isSearching
              ? Icons.search_off_rounded
              : failed
                  ? Icons.cloud_off_rounded
                  : Icons.location_off_outlined,
          size: 56,
          color: AppColors.textFaint,
        ),
        const SizedBox(height: 14),
        Text(
          isSearching
              ? 'No location matches your search'
              : failed
                  ? 'Could not load locations'
                  : 'No locations available',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isSearching
              ? 'Try a different name.'
              : 'Pull down to refresh.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
        ),
        if (!isSearching) ...[
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: _refreshProjects,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      );
}

/// Full-width Login / Logout card — the two primary actions on this screen.
/// A full-colour attendance action.
///
/// Deliberately not a white card with a small coloured icon. Guards on site do
/// not necessarily read the English label, so the whole button carries the
/// colour and a large IN / OUT, which is what they actually recognise. Green
/// means starting the shift, red means ending it, and the two blocks are never
/// mistakable for one another at a glance.
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String bigLabel;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    Key? key,
    required this.icon,
    required this.accent,
    required this.bigLabel,
    required this.title,
    required this.subtitle,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Darkened toward the bottom-right so white text keeps its contrast on the
    // lighter brand green, which is too pale for small type on its own.
    final Color deep = Color.alphaBlend(Colors.black.withOpacity(0.22), accent);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withOpacity(0.18),
        highlightColor: Colors.white.withOpacity(0.08),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, deep],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: deep.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                child: Icon(icon, size: 30, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bigLabel,
                      style: const TextStyle(
                        fontSize: 30,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: Colors.white.withOpacity(0.92),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row in the location picker.
class _LocationCard extends StatelessWidget {
  final String name;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;

  const _LocationCard({
    Key? key,
    required this.name,
    required this.accent,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: accent.withOpacity(0.12),
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.tint(AppColors.primary, 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.tint(accent, 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.apartment_rounded, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: isSelected ? AppColors.primary : AppColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
