import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDateRangePicker1 extends StatefulWidget {
  final Function(DateTime?, DateTime?, String) onDateRangeSelected;
  final String selectedDateRange;

  CustomDateRangePicker1({
    required this.onDateRangeSelected,
    required this.selectedDateRange,
  });

  @override
  _CustomDateRangePicker1State createState() => _CustomDateRangePicker1State();
}

class _CustomDateRangePicker1State extends State<CustomDateRangePicker1> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _customRangeText = '';
  String _selectedOption = 'Today';

  @override
  void initState() {
    super.initState();
    _updateDateRangeFromSelected();
  }

  void _updateDateRangeFromSelected() {
    DateTime now = DateTime.now();
    if (widget.selectedDateRange.startsWith('&startDate=')) {
      List<String> dates = widget.selectedDateRange.split('&');
      _startDate = DateTime.parse(dates[1].split('=')[1]);
      _endDate = DateTime.parse(dates[2].split('=')[1]);
      _customRangeText =
          '${DateFormat('yyyy-MM-dd').format(_startDate!)} to ${DateFormat('yyyy-MM-dd').format(_endDate!)}';
      _selectedOption = 'Custom';
    } else {
      _startDate = _endDate = now;
    }
  }

  Future<void> _showCustomDateRangePicker1(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.all(10.0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: DateRangePickerDialog(
              initialStartDate: _startDate,
              initialEndDate: _endDate,
              onDateRangeSelected: (start, end) {
                setState(() {
                  _startDate = start;
                  _endDate = end;
                  _customRangeText =
                      '${DateFormat('yyyy-MM-dd').format(_startDate!)} to ${DateFormat('yyyy-MM-dd').format(_endDate!)}';
                  _selectedOption = 'Custom';
                });
                widget.onDateRangeSelected(
                  start,
                  end,
                  '&startDate=${DateFormat('yyyy-MM-ddT00:00:00').format(_startDate!)}&endDate=${DateFormat('yyyy-MM-ddT23:59:59').format(_endDate!)}',
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 70.0, // Slightly increased for better visual padding
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16.0), // Increased the corner radius
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.4),
            spreadRadius: 2,
            blurRadius: 10, // Enhanced shadow for better depth
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: DropdownButtonFormField2<String>(
          decoration: InputDecoration(
            labelText: 'Select Date',
            labelStyle: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.bold, // Added emphasis
              fontSize: 16.0, // Increased font size for better readability
            ),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16.0), // Matches outer container
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
            filled: true,
            fillColor: Colors.white,
          ),
          value: _selectedOption,
          items: [
            DropdownMenuItem<String>(
              value: 'Today',
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1), // Subtle background
                  borderRadius:
                      BorderRadius.circular(10.0), // Rounded corners for item
                ),
                child: const Row(
                  children: [
                    Icon(Icons.today, color: Colors.blue),
                    SizedBox(width: 10),
                    Text(
                      'Today',
                      style: TextStyle(
                          fontSize: 14.0, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            DropdownMenuItem<String>(
              value: 'All',
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.green),
                    SizedBox(width: 10),
                    Text(
                      'All',
                      style: TextStyle(
                          fontSize: 14.0, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            DropdownMenuItem<String>(
              value: 'Custom',
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: Colors.orange),
                    const SizedBox(width: 10),
                    Text(
                      _customRangeText.isEmpty ? 'Custom' : _customRangeText,
                      style: const TextStyle(
                          fontSize: 14.0, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (String? newValue) {
            setState(() {
              _selectedOption = newValue!;
            });
            if (newValue == 'Today') {
              widget.onDateRangeSelected(null, null, '0');
            } else if (newValue == 'All') {
              widget.onDateRangeSelected(null, null, '');
            } else if (newValue == 'Custom') {
              _showCustomDateRangePicker1(context);
            }
          },
          isExpanded: true,
          dropdownStyleData: DropdownStyleData(
            maxHeight: 300,
            width: MediaQuery.of(context).size.width - 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(16.0), // Rounded dropdown container
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4), // Elevated dropdown box
                ),
              ],
            ),
          ),
          buttonStyleData: ButtonStyleData(
            height: 60,
            width: MediaQuery.of(context).size.width - 32,
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
          ),
          iconStyleData: const IconStyleData(
            icon: Icon(
              Icons.arrow_drop_down,
              color: Colors.blue,
            ),
            iconSize: 30,
          ),
        ),
      ),
    );
  }
}

class DateRangePickerDialog extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final Function(DateTime, DateTime) onDateRangeSelected;

  DateRangePickerDialog({
    this.initialStartDate,
    this.initialEndDate,
    required this.onDateRangeSelected,
  });

  @override
  _DateRangePickerDialogState createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<DateRangePickerDialog> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate ?? DateTime.now();
    _endDate = widget.initialEndDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('Select Start Date'),
          CalendarDatePicker(
            initialDate: _startDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
            onDateChanged: (date) {
              setState(() {
                _startDate = date;
              });
            },
          ),
          const SizedBox(height: 20.0),
          const Text('Select End Date'),
          CalendarDatePicker(
            initialDate: _endDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
            onDateChanged: (date) {
              setState(() {
                _endDate = date;
              });
            },
          ),
          SizedBox(height: 20.0),
          ElevatedButton(
            onPressed: () {
              widget.onDateRangeSelected(_startDate, _endDate);
              Navigator.pop(context);
            },
            child: Text('OK'),
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
