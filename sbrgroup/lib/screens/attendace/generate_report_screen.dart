import 'dart:io';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ajna/theme/app_colors.dart';

class GenerateReportScreen extends StatefulWidget {
  final List locations;
  final String? selectedStatus;
  const GenerateReportScreen(
      {Key? key, required this.locations, required this.selectedStatus})
      : super(key: key);

  @override
  State<GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends State<GenerateReportScreen> {
  String? selectedMonth;
  String? selectedYear;
  String? selectedLocation;

  String? selectedStatus;

  int? selectedLocationId;
  int? selectedMonthNumber;
  int? selectedYearNumber;

  final List<String> months = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  late List<String> years;

  /// True while the report is being generated. The button used to look
  /// idle for the whole round trip, so a second tap started a second
  /// download.
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    years = List.generate(5, (i) => (now.year - i).toString());
    selectedMonth = null;
    selectedYear = null;
    selectedLocation = null;
    selectedMonthNumber = null;
    selectedYearNumber = null;
    selectedLocationId = null;
    selectedStatus = widget.selectedStatus;
  }

  /// Asks for the permission but does not gate on the answer: on Android 11+
  /// the app writes through the media store and the legacy storage grant is
  /// reported as denied even where the save works. Kept as-is deliberately —
  /// returning `status.isGranted` here would block a download that succeeds.
  Future<bool> _requestPermission(Permission permission) async {
    final status = await permission.request();
    debugPrint('Storage permission: $status');
    return true;
  }

  Future<void> generateExcelReport() async {
    print('generateExcelReport called');
    print(
        'selectedLocationId: $selectedLocationId, selectedMonthNumber: $selectedMonthNumber, selectedYearNumber: $selectedYearNumber');
    if (selectedLocationId == null ||
        selectedMonthNumber == null ||
        selectedYearNumber == null) {
      print('Validation failed: One or more fields are null');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Error'),
          content: const Text('Please select all fields'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    // Request storage permission on Android before proceeding
    if (Platform.isAndroid) {
      bool granted = await _requestPermission(Permission.storage);
      if (!granted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
                'Storage permission is required to save the report.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }
    setState(() => _isGenerating = true);
    try {
      print('Calling ApiService.generateAttendanceExcel with locationId: '
          '\u001b[32m$selectedLocationId\u001b[0m, month: '
          '\u001b[32m$selectedMonthNumber\u001b[0m, year: '
          '\u001b[32m$selectedYearNumber\u001b[0m');
      final response = await ApiService.generateAttendanceExcel(
          locationId: selectedLocationId!,
          month: selectedMonthNumber!,
          year: selectedYearNumber!,
          selectedStatus: selectedStatus);
      print('API response status: \u001b[32m${response.statusCode}\u001b[0m');
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        Directory? downloadsDir;
        if (Platform.isAndroid) {
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            downloadsDir = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          downloadsDir = await getApplicationDocumentsDirectory();
        } else {
          downloadsDir = await getDownloadsDirectory();
          // Fallback if getDownloadsDirectory returns null or not writable
          if (downloadsDir == null || !await downloadsDir.exists()) {
            downloadsDir = await getApplicationDocumentsDirectory();
          }
        }
        if (downloadsDir == null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Directory Error'),
              content: const Text(
                  'Could not determine a directory to save the file.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
        // Generate a unique file name using date and time
        final now = DateTime.now();
        final safeLocation =
            selectedLocation?.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ??
                'location';
        final fileName =
            'attendance_report_${safeLocation}_${selectedMonth}_${selectedYear}_${now.millisecondsSinceEpoch}.xlsx';
        final filePath = '${downloadsDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        print('Excel file written to: \u001b[32m$filePath\u001b[0m');
        final result = await OpenFile.open(filePath);
        String dialogContent;
        if (result.type == ResultType.done) {
          dialogContent = 'Report saved and opened from:\n$filePath';
        } else {
          dialogContent =
              'Report saved to:\n$filePath\n(You can open it now or later.)';
        }
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Report Saved'),
            content: Text(dialogContent),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
              // TextButton(
              //   onPressed: () async {
              //     Navigator.of(context).pop();
              //     await OpenFile.open(filePath);
              //   },
              //   child: const Text('Open'),
              // ),
            ],
          ),
        );
      } else {
        // The status code stays in the log; the user gets a sentence.
        debugPrint('Report failed: HTTP ${response.statusCode}');
        _showMessage('Could not generate the report',
            'The report could not be prepared for that month. Please try '
                'again.');
      }
    } catch (e) {
      debugPrint('Exception in generateExcelReport: $e');
      _showMessage('Could not generate the report',
          'Something went wrong while saving the file. Please check your '
              'connection and try again.');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  /// Shared dialog for every message this screen raises.
  void _showMessage(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 17)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
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
          'Generate Report',
          style: TextStyle(
            fontSize: screenWidth > 600 ? 22 : 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          DropdownButtonFormField2<String>(
                            // Without this the field sizes itself to the
                            // WIDEST item and overflows the row.
                            isExpanded: true,
                            value: selectedMonth,
                            decoration: InputDecoration(
                              labelText: 'Month',
                              prefixIcon: const Icon(Icons.calendar_month,
                                  color: AppColors.primary),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            hint: const Text('Select Month',
                                style: TextStyle(color: Colors.grey)),
                            items: months
                                .map((m) =>
                                    DropdownMenuItem(value: m, child: Text(m)))
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                selectedMonth = v;
                                selectedMonthNumber =
                                    v != null ? months.indexOf(v) + 1 : null;
                              });
                            },
                            validator: (v) =>
                                v == null ? 'Please select a month' : null,
                            dropdownStyleData: DropdownStyleData(
                              maxHeight: 250,
                              width: screenWidth - 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.0),
                                color: AppColors.surface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField2<String>(
                            // Without this the field sizes itself to the
                            // WIDEST item and overflows the row.
                            isExpanded: true,
                            value: selectedYear,
                            decoration: InputDecoration(
                              labelText: 'Year',
                              prefixIcon: const Icon(Icons.calendar_today,
                                  color: AppColors.primary),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            hint: const Text('Select Year',
                                style: TextStyle(color: Colors.grey)),
                            items: years
                                .map((y) =>
                                    DropdownMenuItem(value: y, child: Text(y)))
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                selectedYear = v;
                                selectedYearNumber =
                                    v != null ? int.tryParse(v) : null;
                              });
                            },
                            validator: (v) =>
                                v == null ? 'Please select a year' : null,
                            dropdownStyleData: DropdownStyleData(
                              maxHeight: 250,
                              width: screenWidth - 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.0),
                                color: AppColors.surface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField2<String>(
                            // Without this the field sizes itself to the
                            // WIDEST item and overflows the row.
                            isExpanded: true,
                            value: selectedLocation,
                            decoration: InputDecoration(
                              labelText: 'Location',
                              prefixIcon: const Icon(Icons.location_on,
                                  color: AppColors.primary),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            hint: const Text('Select Location',
                                style: TextStyle(color: Colors.grey)),
                            items: widget.locations
                                .map<DropdownMenuItem<String>>((loc) {
                              return DropdownMenuItem(
                                value: loc.id.toString(),
                                // Long site names now truncate instead of
                                // forcing the field wider than the screen.
                                child: Text(
                                  loc.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              setState(() {
                                selectedLocation = v;
                                selectedLocationId =
                                    v != null ? int.tryParse(v) : null;
                              });
                            },
                            validator: (v) =>
                                v == null ? 'Please select a location' : null,
                            dropdownStyleData: DropdownStyleData(
                              maxHeight: 250,
                              width: screenWidth - 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.0),
                                color: AppColors.surface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            )
                          : const Icon(Icons.download, color: Colors.white),
                      label: Text(
                          _isGenerating
                              ? 'Preparing report…'
                              : 'Generate Report',
                          style: const TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      onPressed: _isGenerating
                          ? null
                          : () async {
                        if (selectedMonth == null ||
                            selectedYear == null ||
                            selectedLocation == null) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Validation Error'),
                              content: const Text(
                                  'Please select all fields before generating the report.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                        await generateExcelReport();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
