import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/util.dart';
import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'dart:convert';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';

// ShiftTiming model
class ShiftTiming {
  final int id;
  final String commonRefKey;
  final String commonRefValue;

  ShiftTiming({
    required this.id,
    required this.commonRefKey,
    required this.commonRefValue,
  });

  factory ShiftTiming.fromJson(Map<String, dynamic> json) {
    return ShiftTiming(
      id: json['id'],
      commonRefKey: json['commonRefKey'],
      commonRefValue: json['commonRefValue'],
    );
  }
}

class LocationModel {
  final int id;
  final String location;

  LocationModel({required this.id, required this.location});

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'],
      location: json['location'],
    );
  }
}

// User model
class UserModel {
  final int userId;
  final String userName;
  UserModel({required this.userId, required this.userName});
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'],
      userName: json['userName'],
    );
  }
}

class AbsentListScreen extends StatefulWidget {
  @override
  _AbsentListScreenState createState() => _AbsentListScreenState();
}

class _AbsentListScreenState extends State<AbsentListScreen> {
  int? organizationId;

  // Instance variables for state
  List<LocationModel> locations = [];
  List<ShiftTiming> shifts = [];
  List<UserModel> users = [];
  List<UserModel> allUsers = [];
  List<UserModel> selectedUsers = [];
  ShiftTiming? selectedShift;
  int? selectedShiftId;
  LocationModel? selectedLocation;

  // Add a search TextField and filtered user list with checkboxes
  String _userSearch = '';

  // Add a controller for the search field
  final TextEditingController _userSearchController = TextEditingController();

  /// Drives the spinner in the user list; the list used to show an empty area
  /// while the request was in flight.
  bool _isLoadingUsers = false;

  /// Blocks a second Submit while the first is still in flight — tapping twice
  /// used to send the absent list twice.
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    // Replace with your org id
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    // Reset all state variables to ensure fresh state if needed
    locations = [];
    shifts = [];
    users = [];
    allUsers = [];
    selectedUsers = [];
    selectedShift = null;
    selectedShiftId = null;
    selectedLocation = null;
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      organizationId = await Util.getOrganizationId();
      fetchShiftData();
      fetchAttendanceLocation(organizationId!);

      // fetchRoles();
    } catch (error) {
      ErrorHandler.handleError(
        context,
        'Failed to initialize data. Please try again later.',
        'Initialization error: $error',
      );
    } finally {}
  }

  Future<void> fetchShiftData() async {
    try {
      final response = await ApiService.fetchshiftData();
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        setState(() {
          shifts = jsonData
              .map<ShiftTiming>((json) => ShiftTiming.fromJson(json))
              .toList();
        });
      } else {
        throw Exception('Failed to load shifts');
      }
    } catch (error) {
      print("Error loading shift data: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load shift data.')),
      );
    }
  }

  Future<void> fetchAttendanceLocation(int organizationId) async {
    try {
      final response = await ApiService.fetchAttendanceLocation(organizationId);
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          locations = jsonData
              .map<LocationModel>((json) => LocationModel.fromJson(json))
              .toList();
        });
      } else {
        throw Exception('Failed to load locations');
      }
    } catch (error) {
      ErrorHandler.handleError(
        context,
        'Failed to load location data.',
        'Location data error: $error',
      );
    }
  }

  Future<void> fetchUsersByLocation(int selectedLocation,
      {String userName = ''}) async {
    setState(() => _isLoadingUsers = true);
    try {
      final response = await ApiService.fetchUsersForAbsent(
          organizationId.toString(), selectedLocation.toString(), userName);
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        setState(() {
          if (userName.isEmpty) {
            allUsers =
                jsonData.map((json) => UserModel.fromJson(json)).toList();
            users = List<UserModel>.from(allUsers);
          } else {
            users = jsonData.map((json) => UserModel.fromJson(json)).toList();
          }
          // Do NOT reset selectedUsers here, so old selections remain
        });
      } else {
        setState(() {
          users = [];
          // Do NOT reset selectedUsers here
        });
        print('Failed to load users');
      }
    } catch (error) {
      setState(() {
        users = [];
        // Do NOT reset selectedUsers here
      });
      debugPrint('Error loading users: $error');
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> submitAbsentList() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final response = await ApiService.submitAbsentEmployees(
        shiftId: selectedShiftId!,
        organizationId: organizationId!,
        locationId: selectedLocation!.id,
        userIds: selectedUsers.map((user) => user.userId).toList(),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        // Success
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success),
                const SizedBox(width: 8),
                const Text('Attendance Marked', style: TextStyle(fontSize: 17)),
              ],
            ),
            content: Text(
              '${selectedUsers.length} '
              '${selectedUsers.length == 1 ? "person has" : "people have"} '
              'been marked absent.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Close the dialog, then pop this screen with `true` so the
                  // report underneath refreshes. Popping (instead of rebuilding
                  // the stack) keeps the back navigation intact.
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        // The status code stays in the log; the user gets a sentence.
        debugPrint('Absent submit failed: HTTP ${response.statusCode} '
            '${response.body}');
        _showFailure('The absent list could not be saved. Please try again.');
      }
    } catch (e) {
      debugPrint('Absent submit error: $e');
      _showFailure(
          'Something went wrong while saving. Please check your connection '
          'and try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// One friendly failure dialog — the old one printed the raw exception (and,
  /// because the interpolation was escaped, printed it literally).
  void _showFailure(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            const Text('Not saved', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  bool get _canSubmit =>
      selectedLocation != null &&
      selectedShiftId != null &&
      selectedUsers.isNotEmpty &&
      !_isSubmitting;

  /// Up to two initials for a user's avatar plate.
  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textSecondary),
      prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  DropdownStyleData get _dropdownStyle => DropdownStyleData(
        maxHeight: 250,
        width: MediaQuery.of(context).size.width * 0.9,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      );

  /// Placeholder for the user list. Which one shows depends on how far through
  /// the form the user is — the list area used to be a blank half-screen until
  /// a location was picked.
  Widget _userListPlaceholder() {
    late IconData icon;
    late String title;
    late String message;

    if (selectedLocation == null) {
      icon = Icons.location_on_outlined;
      title = 'Choose a location';
      message = 'Pick a location above to load the people working there.';
    } else if (_isLoadingUsers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    } else if (allUsers.isEmpty) {
      icon = Icons.person_search_outlined;
      title = 'No users here';
      message = 'Nobody is mapped to this location yet.';
    } else {
      icon = Icons.search_off_rounded;
      title = 'No match';
      message = 'No one matches “$_userSearch”.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }

  Widget _userRow(UserModel user) {
    final bool checked = selectedUsers.contains(user);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          if (checked) {
            selectedUsers.remove(user);
          } else {
            selectedUsers.add(user);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tint(
                    checked ? AppColors.primary : AppColors.textSecondary,
                    0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                _initials(user.userName),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      checked ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                user.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: checked ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Checkbox(
              value: checked,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5)),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    if (!selectedUsers.contains(user)) selectedUsers.add(user);
                  } else {
                    selectedUsers.remove(user);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

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
          'Mark Absent',
          style: TextStyle(
            fontSize: screenWidth > 600 ? 22 : 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        top: false,
        child: ContentWidthLimit(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Filters --------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    DropdownButtonFormField2<LocationModel>(
                      isExpanded: true,
                      decoration: _fieldDecoration(
                        label: 'Location',
                        icon: Icons.location_on_outlined,
                      ),
                      dropdownStyleData: _dropdownStyle,
                      hint: Text('Select location',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textFaint)),
                      value: locations.contains(selectedLocation)
                          ? selectedLocation
                          : null,
                      items: locations
                          .map((loc) => DropdownMenuItem(
                                value: loc,
                                child: Text(loc.location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) async {
                        setState(() {
                          selectedLocation = value;
                          // The list below belongs to the previous site.
                          _userSearch = '';
                          _userSearchController.clear();
                        });
                        if (value != null) {
                          await fetchUsersByLocation(value.id);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField2<ShiftTiming>(
                      isExpanded: true,
                      decoration: _fieldDecoration(
                        label: 'Shift',
                        icon: Icons.access_time,
                      ),
                      dropdownStyleData: _dropdownStyle,
                      hint: Text('Select shift',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textFaint)),
                      value:
                          selectedShift != null && shifts.contains(selectedShift)
                              ? selectedShift
                              : null,
                      items: shifts
                          .map((shift) => DropdownMenuItem(
                                value: shift,
                                child: Text(shift.commonRefValue,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedShift = value;
                          selectedShiftId = value?.id;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _userSearchController,
                      enabled: selectedLocation != null,
                      style:
                          TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      decoration: _fieldDecoration(
                        label: 'Search user',
                        icon: Icons.search,
                        suffix: _userSearch.isEmpty
                            ? null
                            : IconButton(
                                icon: Icon(Icons.close,
                                    size: 18, color: AppColors.textSecondary),
                                onPressed: () {
                                  setState(() {
                                    _userSearch = '';
                                    _userSearchController.clear();
                                    users = List<UserModel>.from(allUsers);
                                  });
                                },
                              ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _userSearch = value;
                          if (_userSearch.isEmpty) {
                            users = List<UserModel>.from(allUsers);
                          } else {
                            users = allUsers
                                .where((user) => user.userName
                                    .toLowerCase()
                                    .contains(_userSearch.toLowerCase()))
                                .toList();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),

              // ---- People ---------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                child: Row(
                  children: [
                    Text(
                      'PEOPLE',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (allUsers.isNotEmpty)
                      Text(
                        '${users.length} of ${allUsers.length}',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textFaint),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: users.isEmpty
                      ? SingleChildScrollView(child: _userListPlaceholder())
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: users.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 54,
                            color: AppColors.divider,
                          ),
                          itemBuilder: (context, i) => _userRow(users[i]),
                        ),
                ),
              ),

              // ---- Selection + submit ---------------------------------------
              Container(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, 12 + bottomBarInset(context)),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                      top: BorderSide(color: AppColors.divider)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 14,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The selection used to sit in a fixed 150px card that took
                    // up half the screen even when nothing was selected. It is
                    // now a chip row that only appears once there is something
                    // in it.
                    if (selectedUsers.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.people_alt_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${selectedUsers.length} selected',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () =>
                                setState(() => selectedUsers = []),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text('Clear',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 92),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: selectedUsers
                                .map((user) => Chip(
                                      label: Text(user.userName,
                                          style: const TextStyle(fontSize: 12)),
                                      labelStyle: TextStyle(
                                          color: AppColors.textPrimary),
                                      backgroundColor: AppColors.tint(
                                          AppColors.primary, 0.08),
                                      side: BorderSide(
                                          color: AppColors.tint(
                                              AppColors.primary, 0.18)),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      deleteIcon: const Icon(Icons.close,
                                          size: 15),
                                      onDeleted: () => setState(
                                          () => selectedUsers.remove(user)),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          disabledBackgroundColor: AppColors.surfaceAlt,
                          disabledForegroundColor: AppColors.textFaint,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _canSubmit
                            ? () async {
                                await submitAbsentList();
                              }
                            : null,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.onPrimary),
                                ),
                              )
                            : Text(
                                selectedUsers.isEmpty
                                    ? 'Submit'
                                    : 'Mark ${selectedUsers.length} absent',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
