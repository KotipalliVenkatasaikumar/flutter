import 'dart:io';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

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
    selectedMonth = months[now.month - 1];
    selectedYear = now.year.toString();
    selectedLocation = widget.locations.isNotEmpty
        ? widget.locations.first.id.toString()
        : null;
  }

  @override
  void didUpdateWidget(covariant GenerateReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('selectedLocationId: '
        '[32m$selectedLocationId[0m, selectedMonthNumber: '
        '[32m$selectedMonthNumber[0m, selectedYearNumber: '
        '[32m$selectedYearNumber[0m');
  }

  Future<void> generateExcelReport() async {
    print('generateExcelReport called');
    print(
        'selectedLocationId: $selectedLocationId, selectedMonthNumber: $selectedMonthNumber, selectedYearNumber: $selectedYearNumber');
    if (selectedLocationId == null ||
        selectedMonthNumber == null ||
        selectedYearNumber == null) {
      print('Validation failed: One or more fields are null');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select all fields')),
      );
      return;
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
          try {
            downloadsDir = Directory('/storage/emulated/0/Download');
            if (!await downloadsDir.exists()) {
              downloadsDir = await getExternalStorageDirectory();
            }
          } catch (e) {
            print('Error getting downloads directory: $e');
            downloadsDir = await getExternalStorageDirectory();
          }
        } else {
          downloadsDir = await getDownloadsDirectory();
        }
        final file = File('${downloadsDir!.path}/attendance_report.xlsx');
        await file.writeAsBytes(bytes);
        print('Excel file written to: \u001b[32m${file.path}\u001b[0m');
        await OpenFile.open(file.path);
        print('OpenFile.open called');
      } else {
        print(
            'Failed to generate Excel report. Status: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate Excel report.')),
        );
      }
    } catch (e) {
      print('Exception in generateExcelReport: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Report',
              style: TextStyle(
                fontSize: screenWidth > 600 ? 22 : 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            DropdownButtonFormField2<String>(
              value: selectedMonth,
              decoration: InputDecoration(
                labelText: 'Month',
                hintText: 'Select Month',
                prefixIcon: Icon(Icons.calendar_month,
                    color: Color.fromRGBO(6, 73, 105, 1)),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: [
                DropdownMenuItem(
                    value: null,
                    child: Text('Select Month',
                        style: TextStyle(color: Colors.grey))),
                ...months
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
              ],
              onChanged: (v) {
                setState(() {
                  selectedMonth = v;
                  if (v != null) {
                    selectedMonthNumber = months.indexOf(v) + 1;
                  } else {
                    selectedMonthNumber = null;
                  }
                });
              },
              dropdownStyleData: DropdownStyleData(
                maxHeight: 250,
                width: MediaQuery.of(context).size.width - 40,
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
                hintText: 'Select Year',
                prefixIcon: Icon(Icons.calendar_today,
                    color: Color.fromRGBO(6, 73, 105, 1)),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: [
                DropdownMenuItem(
                    value: null,
                    child: Text('Select Year',
                        style: TextStyle(color: Colors.grey))),
                ...years
                    .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                    .toList(),
              ],
              onChanged: (v) {
                setState(() {
                  selectedYear = v;
                  if (v != null) {
                    selectedYearNumber = int.tryParse(v);
                  } else {
                    selectedYearNumber = null;
                  }
                });
              },
              dropdownStyleData: DropdownStyleData(
                maxHeight: 250,
                width: MediaQuery.of(context).size.width - 40,
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
                hintText: 'Select Location',
                prefixIcon: Icon(Icons.location_on,
                    color: Color.fromRGBO(6, 73, 105, 1)),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: [
                DropdownMenuItem(
                    value: null,
                    child: Text('Select Location',
                        style: TextStyle(color: Colors.grey))),
                ...widget.locations.map<DropdownMenuItem<String>>((loc) {
                  return DropdownMenuItem(
                    value: loc.id.toString(),
                    child: Text(loc.location),
                  );
                }).toList(),
              ],
              onChanged: (v) {
                setState(() {
                  selectedLocation = v;
                  if (v != null) {
                    selectedLocationId = int.tryParse(v);
                  } else {
                    selectedLocationId = null;
                  }
                });
              },
              dropdownStyleData: DropdownStyleData(
                maxHeight: 250,
                width: MediaQuery.of(context).size.width - 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  color: Colors.white,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: generateExcelReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Generate', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
