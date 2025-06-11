import 'dart:io';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class GenerateReportScreen extends StatefulWidget {
  final List locations;
  const GenerateReportScreen({Key? key, required this.locations})
      : super(key: key);

  @override
  State<GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends State<GenerateReportScreen> {
  String? selectedMonth;
  String? selectedYear;
  String? selectedLocation;

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
  }

  @override
  void didUpdateWidget(covariant GenerateReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('selectedLocationId: '
        '[32m$selectedLocationId[0m, selectedMonthNumber: '
        '[32m$selectedMonthNumber[0m, selectedYearNumber: '
        '[32m$selectedYearNumber[0m');
  }

  Future<bool> _requestPermission(Permission permission) async {
    final status = await permission.request();
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
    try {
      print('Calling ApiService.generateAttendanceExcel with locationId: '
          '\u001b[32m$selectedLocationId\u001b[0m, month: '
          '\u001b[32m$selectedMonthNumber\u001b[0m, year: '
          '\u001b[32m$selectedYearNumber\u001b[0m');
      final response = await ApiService.generateAttendanceExcel(
        locationId: selectedLocationId!,
        month: selectedMonthNumber!,
        year: selectedYearNumber!,
      );
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
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await OpenFile.open(filePath);
                },
                child: const Text('Open'),
              ),
            ],
          ),
        );
      } else {
        print(
            'Failed to generate Excel report. Status: [32m${response.statusCode}[0m');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: const Text('Failed to generate Excel report.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Exception in generateExcelReport: $e');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Error: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: Text(
          'Attendance Report',
          style: TextStyle(
            fontSize: screenWidth > 600 ? 22 : 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
      ),
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
                            value: selectedMonth,
                            decoration: InputDecoration(
                              labelText: 'Month',
                              prefixIcon: const Icon(Icons.calendar_month,
                                  color: Color.fromRGBO(6, 73, 105, 1)),
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
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField2<String>(
                            value: selectedYear,
                            decoration: InputDecoration(
                              labelText: 'Year',
                              prefixIcon: const Icon(Icons.calendar_today,
                                  color: Color.fromRGBO(6, 73, 105, 1)),
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
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField2<String>(
                            value: selectedLocation,
                            decoration: InputDecoration(
                              labelText: 'Location',
                              prefixIcon: const Icon(Icons.location_on,
                                  color: Color.fromRGBO(6, 73, 105, 1)),
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
                                child: Text(loc.location),
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
                                color: Colors.white,
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
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text('Generate Report',
                          style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () async {
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
