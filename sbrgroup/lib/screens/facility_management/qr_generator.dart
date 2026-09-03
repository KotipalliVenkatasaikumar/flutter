import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:ajna/main.dart';
import 'package:ajna/screens/connectivity_handler.dart';
import 'package:ajna/screens/incident/incident_models.dart';
import 'package:ajna/screens/incident/incident_pickers.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/util.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'map_screen.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';

/// QR types, keyed by their common_reference_details id. The same ids the
/// backend stores on qr_generator.qr_type_id.
const Map<int, String> kQrTypeNames = {
  215: 'Attendance',
  91: 'Security',
  404: 'FO Visit',
};

String qrTypeLabel(int? id) => kQrTypeNames[id] ?? 'Other';

/// A QR location as the listing endpoint returns it.
class QrCode {
  final int id;
  final int orgId;
  final int projectId;
  final String projectName;
  final String location;
  final String latitude;
  final String longitude;
  final String radius;
  final String status;
  final int qrTypeId;
  final String locationVerification;

  QrCode({
    required this.id,
    required this.orgId,
    required this.projectId,
    required this.projectName,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.status,
    required this.qrTypeId,
    required this.locationVerification,
  });

  factory QrCode.fromJson(Map<String, dynamic> j) => QrCode(
        id: j['id'] ?? 0,
        orgId: j['orgId'] ?? 0,
        projectId: j['projectId'] ?? 0,
        projectName: j['projectName'] ?? '',
        location: j['location'] ?? '',
        latitude: '${j['latitude'] ?? ''}',
        longitude: '${j['longitude'] ?? ''}',
        radius: '${j['radius'] ?? ''}',
        status: j['status'] ?? 'A',
        qrTypeId: j['qrTypeId'] ?? 0,
        locationVerification: j['locationVerification'] ?? 'yes',
      );

  bool get isActive => status.toUpperCase() == 'A';

  /// The payload printed into the QR image.
  ///
  /// Identical in shape to what the Re Generate screen has always produced, so
  /// a reprint scans exactly like the original sticker. The scanner overwrites
  /// the user id from the signed-in account, which is why it is not stored here.
  String qrPayload() => jsonEncode({
        'orgId': orgId,
        'projectId': projectId,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'qrTypeId': qrTypeId,
      });
}

// ---------------------------------------------------------------------------
// Shared PDF output. One implementation for both the new-QR screen and the
// reprint dialog, so a reprinted sheet looks exactly like the original.
// ---------------------------------------------------------------------------

Future<Uint8List?> _renderQrSheet(GlobalKey qrKey) async {
  final boundary =
      qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;

  final image = await boundary.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ImageByteFormat.png);
  final pngBytes = byteData?.buffer.asUint8List();
  if (pngBytes == null) return null;

  final logoData =
      (await rootBundle.load('lib/assets/images/corenuts-logo.png'))
          .buffer
          .asUint8List();
  final ajnaLogoData =
      (await rootBundle.load('lib/assets/images/ajna.png')).buffer.asUint8List();

  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Image(pw.MemoryImage(ajnaLogoData), width: 130),
            pw.Image(pw.MemoryImage(pngBytes)),
            pw.Spacer(),
            pw.Image(pw.MemoryImage(logoData), width: 200),
            pw.SizedBox(height: 15),
            pw.RichText(
              text: const pw.TextSpan(
                children: [
                  pw.TextSpan(
                      text: 'Powered by ', style: pw.TextStyle(fontSize: 8)),
                  pw.TextSpan(
                      text: 'CoreNuts Technologies',
                      style: pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Contact: info@corenuts.com',
                style: const pw.TextStyle(fontSize: 10)),
          ],
        );
      },
    ),
  );
  return Uint8List.fromList(await pdf.save());
}

Future<File?> _writeQrSheet(
    Uint8List bytes, String projectName, String location) async {
  Directory? directory;
  if (Platform.isAndroid) {
    directory = Directory('/storage/emulated/0/Download');
  } else if (Platform.isIOS) {
    directory = await getApplicationDocumentsDirectory();
  }
  if (directory == null) return null;

  final uniqueId = DateTime.now().millisecondsSinceEpoch % 100000;
  final safeLocation = location.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '');
  final file =
      File('${directory.path}/qr_code_${projectName}_${safeLocation}_$uniqueId.pdf');
  await file.writeAsBytes(bytes);
  return file;
}

void _toast(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
}

Future<void> downloadQrSheet(BuildContext context, GlobalKey qrKey,
    String projectName, String location) async {
  try {
    await Permission.storage.request();
    final bytes = await _renderQrSheet(qrKey);
    if (!context.mounted) return;
    if (bytes == null) {
      _toast(context, 'Could not prepare the QR sheet. Please try again.');
      return;
    }
    final file = await _writeQrSheet(bytes, projectName, location);
    if (!context.mounted) return;
    if (file == null) {
      _toast(context, 'Could not find a place to save the file.');
      return;
    }
    _toast(context, 'Saved to ${file.path}');
  } catch (e) {
    debugPrint('QR download failed: $e');
    if (context.mounted) {
      _toast(context, 'Could not save the QR sheet. Please try again.');
    }
  }
}

Future<void> shareQrSheet(BuildContext context, GlobalKey qrKey,
    String projectName, String location) async {
  try {
    await Permission.storage.request();
    final bytes = await _renderQrSheet(qrKey);
    if (!context.mounted) return;
    if (bytes == null) {
      _toast(context, 'Could not prepare the QR sheet. Please try again.');
      return;
    }
    final file = await _writeQrSheet(bytes, projectName, location);
    if (!context.mounted) return;
    if (file == null) {
      _toast(context, 'Could not find a place to save the file.');
      return;
    }
    await Share.shareXFiles([XFile(file.path)], text: 'Here is my QR Code');
  } catch (e) {
    debugPrint('QR share failed: $e');
    if (context.mounted) {
      _toast(context, 'Could not share the QR sheet. Please try again.');
    }
  }
}

Widget poweredByFooter(BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    // Bottom padding clears the system navigation bar (SDK 36 is always
    // edge-to-edge), so the footer is not hidden underneath it.
    padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomBarInset(context)),
    child: RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Powered by ',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          TextSpan(
            text: 'Core',
            style: const TextStyle(
                color: Color.fromARGB(255, 37, 219, 9), fontSize: 14),
            recognizer: TapGestureRecognizer()
              // ignore: deprecated_member_use
              ..onTap = () => launch('https://www.corenuts.com'),
          ),
          TextSpan(
            text: 'Nuts',
            style: const TextStyle(
                color: Color.fromARGB(255, 221, 10, 10), fontSize: 14),
            recognizer: TapGestureRecognizer()
              // ignore: deprecated_member_use
              ..onTap = () => launch('https://www.corenuts.com'),
          ),
          TextSpan(
            text: ' Technologies',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                decoration: TextDecoration.none),
          ),
        ],
      ),
    ),
  );
}

PreferredSizeWidget brandAppBar(BuildContext context, String title,
    {PreferredSizeWidget? bottom}) {
  final double screenWidth = MediaQuery.of(context).size.width;
  return AppBar(
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
      title,
      style: TextStyle(
        fontSize: screenWidth > 600 ? 22 : 18,
        color: Colors.white,
      ),
    ),
    centerTitle: true,
    iconTheme: const IconThemeData(color: Colors.white),
    bottom: bottom,
  );
}

Future<void> checkSessionAndRedirect(BuildContext context) async {
  try {
    final response = await ApiService.checkForUpdate();
    if (response.statusCode == 401) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!context.mounted) return;

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
                Navigator.pop(context);
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

      Future.delayed(const Duration(seconds: 5), () {
        if (!context.mounted) return;
        if (Navigator.canPop(context)) Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      });
    }
  } catch (e) {
    debugPrint('Error checking session: $e');
  }
}

// ---------------------------------------------------------------------------
// The QR list. Landing screen for the module.
// ---------------------------------------------------------------------------

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final ConnectivityHandler connectivityHandler = ConnectivityHandler();
  final TextEditingController _searchController = TextEditingController();

  int? _orgId;
  String _organizationName = '';
  List<Map<String, dynamic>> _projects = [];

  List<QrCode> _codes = [];
  bool _loading = true;
  bool _failed = false;

  // Filters
  String _search = '';
  int? _projectFilter; // null = all projects
  int _typeFilter = 0; // 0 = all types
  bool _activeOnly = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connected = await connectivityHandler.checkConnectivity(context);
    if (!connected || !mounted) return;
    _orgId = await Util.getOrganizationId();
    if (!mounted) return;
    checkSessionAndRedirect(context);
    await Future.wait([
      _fetchOrganization(),
      _fetchProjects(),
    ]);
    await _fetchCodes();
  }

  Future<void> _fetchOrganization() async {
    try {
      final response = await ApiService.fetchOrgDetails(_orgId!);
      if (!mounted || response.statusCode != 200) return;
      final data = jsonDecode(response.body);
      setState(() => _organizationName = data['organizationName'] ?? '');
    } catch (e) {
      debugPrint('QR list: organization lookup failed $e');
    }
  }

  Future<void> _fetchProjects() async {
    try {
      final response = await ApiService.fetchOrgProjects(_orgId!);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _projects = data
              .map((p) => {'id': p['projectId'], 'name': p['projectName'] ?? ''})
              .toList()
              .cast<Map<String, dynamic>>();
        });
      } else {
        debugPrint('QR list: projects failed ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('QR list: projects error $e');
    }
  }

  Future<void> _fetchCodes() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final response = await ApiService.fetchQrCodes(
        orgId: _orgId!,
        projectId: _projectFilter?.toString() ?? '',
        qrTypeId: _typeFilter,
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> rows = decoded is List
            ? decoded
            : (decoded is Map && decoded['records'] is List
                ? decoded['records']
                : const []);
        setState(() {
          _codes = rows.map((e) => QrCode.fromJson(e)).toList();
          _loading = false;
        });
      } else {
        debugPrint('QR list: load failed ${response.statusCode}');
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    } catch (e) {
      debugPrint('QR list: load error $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _refresh() async {
    checkSessionAndRedirect(context);
    await _fetchCodes();
  }

  List<QrCode> get _visible {
    final q = _search.trim().toLowerCase();
    return _codes.where((c) {
      if (_activeOnly && !c.isActive) return false;
      if (q.isEmpty) return true;
      return c.location.toLowerCase().contains(q) ||
          c.projectName.toLowerCase().contains(q);
    }).toList();
  }

  // -- filter actions ---------------------------------------------------------

  Future<void> _pickProject() async {
    final options = [
      const FilterOption(0, 'All projects'),
      ..._projects.map((p) => FilterOption(p['id'] as int, p['name'] as String)),
    ];
    FilterOption? selected;
    for (final o in options) {
      if (o.id == (_projectFilter ?? 0)) selected = o;
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
    final value = picked.id == 0 ? null : picked.id;
    if (value == _projectFilter) return;
    setState(() => _projectFilter = value);
    _fetchCodes();
  }

  void _selectType(int typeId) {
    if (typeId == _typeFilter) return;
    setState(() => _typeFilter = typeId);
    _fetchCodes();
  }

  String get _projectLabel {
    if (_projectFilter == null) return 'All projects';
    for (final p in _projects) {
      if (p['id'] == _projectFilter) return p['name'] as String;
    }
    return 'Selected project';
  }

  // -- row actions ------------------------------------------------------------

  Future<void> _openNewQr() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QrGenerateFormScreen(
          orgId: _orgId!,
          organizationName: _organizationName,
          projects: _projects,
        ),
      ),
    );
    if (created == true) _fetchCodes();
  }

  /// Reprint dialog.
  ///
  /// Uses [Dialog] rather than [AlertDialog] on purpose: AlertDialog wraps its
  /// contents in an IntrinsicWidth, and QrImageView is built on a LayoutBuilder,
  /// which cannot answer intrinsic-size queries. The combination throws
  /// "LayoutBuilder does not support returning intrinsic dimensions".
  void _showQr(QrCode code) {
    final GlobalKey qrKey = GlobalKey();
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                code.location.isEmpty ? 'QR code' : code.location,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${code.projectName} · ${qrTypeLabel(code.qrTypeId)}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: qrKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QrImageView(
                        data: code.qrPayload(),
                        version: QrVersions.auto,
                        size: 170,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Project: ${code.projectName}',
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontSize: 10, color: Colors.black),
                      ),
                      Text(
                        'Location: ${code.location}',
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontSize: 10, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Reprint of the existing code. Scanning behaviour is unchanged.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => downloadQrSheet(
                        dialogContext, qrKey, code.projectName, code.location),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download'),
                    style:
                        TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                  TextButton.icon(
                    onPressed: () => shareQrSheet(
                        dialogContext, qrKey, code.projectName, code.location),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share'),
                    style:
                        TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleStatus(QrCode code) async {
    final bool deactivating = code.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          deactivating ? 'Deactivate this QR?' : 'Activate this QR?',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              code.location,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              '${code.projectName} · ${qrTypeLabel(code.qrTypeId)}',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              deactivating
                  ? 'It will stop accepting scans and will not appear in pickers. '
                      'Past scans and reports are kept, and you can switch it back on later.'
                  : 'It will start accepting scans again and reappear in pickers.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.35, color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  deactivating ? AppColors.danger : AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: Text(deactivating ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final response =
          await ApiService.updateQrStatus(code.id, deactivating ? 'I' : 'A');
      if (!mounted) return;
      if (response.statusCode == 200) {
        _toast(context,
            deactivating ? 'QR deactivated.' : 'QR activated.');
        _fetchCodes();
      } else {
        debugPrint('QR status failed ${response.statusCode} ${response.body}');
        ErrorHandler.handleResponseError(
          context,
          response.body,
          fallback: 'Could not update this QR. Please try again.',
          logDetails: 'QR status update failed (${response.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('QR status error $e');
      if (mounted) {
        _toast(context, 'Could not update this QR. Please try again.');
      }
    }
  }

  // -- build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: brandAppBar(context, 'QR Codes'),
      bottomNavigationBar: poweredByFooter(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _orgId == null ? null : _openNewQr,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_2_rounded),
        label: const Text('New QR'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: _filterBar(),
            ),
            SizedBox(
              height: 2,
              child: (_loading && _codes.isNotEmpty)
                  ? const LinearProgressIndicator(
                      minHeight: 2, color: AppColors.primary)
                  : null,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.primary,
                child: _buildList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterBar() {
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
              _projectButton(),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              children: [
                _chip('All types', selected: _typeFilter == 0,
                    onTap: () => _selectType(0)),
                for (final entry in kQrTypeNames.entries)
                  _chip(entry.value,
                      selected: _typeFilter == entry.key,
                      onTap: () => _selectType(entry.key)),
                const SizedBox(width: 4),
                _chip('Active only',
                    selected: _activeOnly,
                    icon: Icons.check_circle_outline_rounded,
                    onTap: () => setState(() => _activeOnly = !_activeOnly)),
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
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (v) => setState(() => _search = v),
        cursorColor: AppColors.primary,
        style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search location',
          hintStyle: const TextStyle(fontSize: 14, color: AppColors.searchHint),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.primary, size: 20),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _search = '');
                  },
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

  Widget _projectButton() {
    final bool active = _projectFilter != null;
    final Color fg = active ? AppColors.primary : AppColors.textSecondary;
    return Material(
      color: active
          ? AppColors.tint(AppColors.primary, 0.12)
          : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _projects.isEmpty ? null : _pickProject,
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
                  _projectLabel,
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

  Widget _chip(String label,
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

  Widget _buildList() {
    if (_loading && _codes.isEmpty) {
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

    final rows = _visible;
    if (rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _placeholder(
            _failed ? Icons.cloud_off_outlined : Icons.qr_code_2_outlined,
            _failed
                ? 'The QR list could not be loaded.'
                : 'No QR codes match these filters.',
            hint: _failed
                ? 'Check your connection and try again.'
                : 'Change the filters, or create one with the New QR button.',
            action: _failed ? _fetchCodes : null,
          ),
        ],
      );
    }

    // Grouped by project so a long list stays navigable.
    final Map<String, List<QrCode>> byProject = {};
    for (final c in rows) {
      byProject
          .putIfAbsent(c.projectName.isEmpty ? 'Unassigned project' : c.projectName,
              () => [])
          .add(c);
    }

    final items = <Widget>[];
    for (final entry in byProject.entries) {
      items.add(_projectHeader(entry.key, entry.value.length));
      items.addAll(entry.value.map(_codeCard));
    }
    items.add(Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      child: Center(
        child: Text(
          rows.length == 1 ? '1 QR code' : '${rows.length} QR codes',
          style: TextStyle(color: AppColors.textFaint, fontSize: 12),
        ),
      ),
    ));

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, i) => items[i],
    );
  }

  Widget _projectHeader(String name, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          Text('$count',
              style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
        ],
      ),
    );
  }

  Widget _codeCard(QrCode code) {
    final bool active = code.isActive;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.tint(
                  active ? AppColors.primary : AppColors.textFaint, 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.qr_code_2_rounded,
                size: 20,
                color: active ? AppColors.primary : AppColors.textFaint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code.location.isEmpty ? 'Unnamed location' : code.location,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _tag(qrTypeLabel(code.qrTypeId), AppColors.primary),
                    if (!active) _tag('Inactive', AppColors.textFaint),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'View or reprint',
            onPressed: () => _showQr(code),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
            color: AppColors.primary,
          ),
          IconButton(
            tooltip: active ? 'Deactivate' : 'Activate',
            onPressed: () => _toggleStatus(code),
            icon: Icon(
                active
                    ? Icons.delete_outline_rounded
                    : Icons.restore_rounded,
                size: 20),
            color: active ? AppColors.danger : AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.tint(color, 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _placeholder(IconData icon, String text,
      {String? hint, VoidCallback? action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.textFaint),
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
              label: const Text('Retry'),
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
}

// ---------------------------------------------------------------------------
// The generation form, reached from the New QR button.
// ---------------------------------------------------------------------------

class QrGenerateFormScreen extends StatefulWidget {
  final int orgId;
  final String organizationName;
  final List<Map<String, dynamic>> projects;

  const QrGenerateFormScreen({
    super.key,
    required this.orgId,
    required this.organizationName,
    required this.projects,
  });

  @override
  State<QrGenerateFormScreen> createState() => _QrGenerateFormScreenState();
}

class _QrGenerateFormScreenState extends State<QrGenerateFormScreen> {
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey _qrKey = GlobalKey();

  String? _qrData;
  int? _userId;
  int? _selectedProjectId;
  int? _selectedQrTypeId;
  String? _generationTime;
  bool _showQR = false;
  bool _saved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.projects.isNotEmpty) {
      _selectedProjectId = widget.projects.first['id'] as int;
    }
    Util.getUserId().then((id) {
      if (mounted) setState(() => _userId = id);
    });
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String get _projectName {
    for (final p in widget.projects) {
      if (p['id'] == _selectedProjectId) return p['name'] as String;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.pop(context, _saved);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: brandAppBar(context, 'Generate QR Code'),
        bottomNavigationBar: poweredByFooter(context),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: _showQR ? _buildQRView() : _buildForm(),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.divider, width: 1.2),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              widget.organizationName.isEmpty
                  ? 'New QR code'
                  : 'Organization: ${widget.organizationName}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField2<int>(
              decoration: _fieldDecoration('Select Project'),
              value: _selectedProjectId,
              isExpanded: true,
              items: widget.projects.isNotEmpty
                  ? widget.projects
                      .map<DropdownMenuItem<int>>((p) => DropdownMenuItem<int>(
                            value: p['id'] as int,
                            child: Text(p['name'] as String,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textPrimary)),
                          ))
                      .toList()
                  : [
                      const DropdownMenuItem<int>(
                        value: -1,
                        child: Text('No Projects Available'),
                      )
                    ],
              onChanged: (int? value) {
                if (value != null) {
                  setState(() => _selectedProjectId = value);
                }
              },
              validator: (value) {
                if (value == null || value == -1) {
                  return 'Please select a project';
                }
                return null;
              },
              dropdownStyleData: DropdownStyleData(
                maxHeight: 300,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: _fieldDecoration('Enter Location Name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Location is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField2<int>(
              decoration: _fieldDecoration('Select QR Type'),
              value: _selectedQrTypeId,
              isExpanded: true,
              items: kQrTypeNames.entries
                  .map((e) => DropdownMenuItem<int>(
                        value: e.key,
                        child: Text(e.value,
                            style: TextStyle(
                                fontSize: 15, color: AppColors.textPrimary)),
                      ))
                  .toList(),
              onChanged: (int? value) {
                if (value != null) {
                  setState(() => _selectedQrTypeId = value);
                }
              },
              validator: (value) {
                if (value == null) return 'Please select a QR type';
                return null;
              },
              dropdownStyleData: DropdownStyleData(
                maxHeight: 300,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MapScreen(
                      onGeofenceSelected: (latitude, longitude, radius) {
                        setState(() {
                          _latitudeController.text = latitude.toString();
                          _longitudeController.text = longitude.toString();
                          _radiusController.text = radius.toString();
                          _generationTime = DateTime.now().toString();
                        });
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.location_on, size: 20),
              label: const Text('Set Geo Location'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _latitudeController,
              readOnly: _generationTime != null,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: _fieldDecoration('Enter Latitude'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _longitudeController,
              readOnly: _generationTime != null,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: _fieldDecoration('Enter Longitude'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Generate QR Code'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;

    final qrData = {
      'orgId': widget.orgId,
      'projectId': _selectedProjectId,
      'userId': _userId,
      'location': _locationController.text.trim(),
      'latitude': _latitudeController.text,
      'longitude': _longitudeController.text,
      'radius': _radiusController.text,
      'qrTypeId': _selectedQrTypeId,
    };

    setState(() => _saving = true);
    final ok = await _postQrData(qrData);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _qrData = jsonEncode(qrData);
        _showQR = true;
        _saved = true;
      }
    });
  }

  /// Saves first and only shows the code once the server accepted it, so a
  /// rejected location name never leaves a printable QR on screen.
  Future<bool> _postQrData(Map<String, dynamic> qrData) async {
    try {
      final response = await ApiService.postQrData(qrData);
      if (!mounted) return false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      // A location name is unique within a project, organisation and QR type,
      // so saving a name that is already taken fails here. Show the reason the
      // server gives rather than "try again later", which would never work for
      // a duplicate name.
      debugPrint('QR save failed (${response.statusCode}): ${response.body}');
      ErrorHandler.handleResponseError(
        context,
        response.body,
        fallback: 'Could not save this QR. A QR with this location name may '
            'already exist for the selected project — check the location '
            'name and try again.',
        logDetails: 'QR save failed (${response.statusCode})',
      );
      return false;
    } catch (e) {
      debugPrint('Error posting QR data: $e');
      if (mounted) {
        ErrorHandler.handleError(
          context,
          'Failed to send QR data. Please try again later.',
          'Error sending QR data : $e',
        );
      }
      return false;
    }
  }

  Widget _buildQRView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 22),
              const SizedBox(width: 8),
              Text(
                'QR code saved',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          RepaintBoundary(
            key: _qrKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(
                    data: _qrData!,
                    version: QrVersions.auto,
                    size: 170.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  Text('Project: $_projectName',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(fontSize: 10, color: Colors.black)),
                  Text('Location: ${_locationController.text}',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(fontSize: 10, color: Colors.black)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => downloadQrSheet(
                    context, _qrKey, _projectName, _locationController.text),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => shareQrSheet(
                    context, _qrKey, _projectName, _locationController.text),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Back to QR list',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
