import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDateRangePicker extends StatefulWidget {
  final Function(DateTime, DateTime, String) onDateRangeSelected;
  final String selectedDateRange;

  CustomDateRangePicker({
    required this.onDateRangeSelected,
    required this.selectedDateRange,
  });

  @override
  _CustomDateRangePickerState createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
  DateTime? _startDate;
  DateTime? _endDate;
  late String _selectedRange;
  String _customRangeText = '';

  @override
  void initState() {
    super.initState();
    _selectedRange = widget.selectedDateRange;
    _updateDateRangeFromSelected();
  }

  void _updateDateRangeFromSelected() {
    DateTime now = DateTime.now();
    if (_selectedRange.startsWith('&startDate=')) {
      List<String> dates = _selectedRange.split('&');
      _startDate = DateTime.parse(dates[1].split('=')[1]);
      _endDate = DateTime.parse(dates[2].split('=')[1]);
      _customRangeText =
          'Selected Date: ${DateFormat('yyyy-MM-dd').format(_startDate!)} to ${DateFormat('yyyy-MM-dd').format(_endDate!)}';
      _selectedRange = 'Custom';
    } else {
      switch (_selectedRange) {
        case '0':
          _startDate = _endDate = now;
          break;
        case '1':
          _startDate = _endDate = now.subtract(Duration(days: 1));
          break;
        case '7':
          _startDate = now.subtract(Duration(days: 7));
          _endDate = now;
          break;
        case '15':
          _startDate = now.subtract(Duration(days: 15));
          _endDate = now;
          break;
        case 'This Month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now;
          break;
        case 'Last Month':
          _startDate = DateTime(now.year, now.month - 1, 1);
          _endDate = DateTime(now.year, now.month, 0);
          break;
        default:
          _selectedRange = '0';
          _startDate = _endDate = now;
      }
    }
  }

  Future<void> _showCustomDateRangePicker(BuildContext context) async {
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
                      'Selected Date: ${DateFormat('yyyy-MM-dd').format(_startDate!)} to ${DateFormat('yyyy-MM-dd').format(_endDate!)}';
                  _selectedRange = 'Custom';
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
      height: 50.0,
      padding: EdgeInsets.symmetric(horizontal: 10.0),
      // decoration: BoxDecoration(
      //     //color: Colors.white,
      //     //borderRadius: BorderRadius.circular(8.0),
      //     //border: Border.all(color: Color.fromARGB(255, 41, 221, 200)),
      //     ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            //child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField2<String>(
              decoration: InputDecoration(
                labelText: 'Select Date',
                // fillColor: Color.fromARGB(255, 204, 230, 237),
                // filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      color: Color.fromRGBO(8, 101, 145, 1), width: 1.5),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      color: Color.fromRGBO(6, 73, 105, 1), width: 2),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              value: _selectedRange,
              items: [
                '0', // Today
                '1', // Yesterday
                '7', // Last 7 Days
                '15', // Last 15 Days
                // 'This Month',
                // 'Last Month',
                'Custom',
              ].map((String value) {
                String text;
                switch (value) {
                  case '0':
                    text = 'Today';
                    break;
                  case '1':
                    text = 'Yesterday';
                    break;
                  case '7':
                    text = 'Last 7 Days';
                    break;
                  case '15':
                    text = 'Last 15 Days';
                    break;
                  case 'This Month':
                    text = 'This Month';
                    break;
                  case 'Last Month':
                    text = 'Last Month';
                    break;
                  default:
                    text =
                        _customRangeText.isEmpty ? 'Custom' : _customRangeText;
                }
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(text),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  if (newValue == 'Custom') {
                    _showCustomDateRangePicker(context);
                  } else {
                    _selectPredefinedRange(newValue);
                  }
                }
              },
              isExpanded: true,
              dropdownStyleData: DropdownStyleData(
                maxHeight: 300,
                width: MediaQuery.of(context).size.width - 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  color: Colors.white,
                ),
              ),
            ),
            //),
          ),
        ],
      ),
    );
  }

  void _selectPredefinedRange(String option) {
    DateTime now = DateTime.now();
    DateTime startDate = now;
    DateTime endDate = now;

    switch (option) {
      case '0':
        startDate = endDate = now;
        widget.onDateRangeSelected(startDate, endDate, '0');
        break;
      case '1':
        startDate = endDate = now.subtract(Duration(days: 1));
        widget.onDateRangeSelected(startDate, endDate, '1');
        break;
      case '7':
        startDate = now.subtract(Duration(days: 7));
        endDate = now;
        widget.onDateRangeSelected(startDate, endDate, '7');
        break;
      case '15':
        startDate = now.subtract(Duration(days: 15));
        endDate = now;
        widget.onDateRangeSelected(startDate, endDate, '15');
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = now;
        widget.onDateRangeSelected(startDate, endDate, 'This Month');
        break;
      case 'Last Month':
        startDate = DateTime(now.year, now.month - 1, 1);
        endDate = DateTime(now.year, now.month, 0);
        widget.onDateRangeSelected(startDate, endDate, 'Last Month');
        break;
    }

    setState(() {
      _startDate = startDate;
      _endDate = endDate;
      _selectedRange = option;
      _customRangeText = '';
    });
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
          ),
        ],
      ),
    );
  }
}
