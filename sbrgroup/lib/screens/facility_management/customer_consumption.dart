import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerConsumptionScreen extends StatefulWidget {
  @override
  _CustomerConsumptionScreenState createState() =>
      _CustomerConsumptionScreenState();
}

class _CustomerConsumptionScreenState extends State<CustomerConsumptionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController currentConsumptionController = TextEditingController();
  List<String> consumptionTypeList = [];
  List<int> consumptionYearList = [];
  List<Map<String, dynamic>> customerList = [];

  String? selectedConsumptionType;
  int? selectedConsumptionMonth;
  int? selectedConsumptionYear;
  int? selectedCustomerId;

  final List<Map<String, dynamic>> months = [
    {'index': 1, 'name': 'January'},
    {'index': 2, 'name': 'February'},
    {'index': 3, 'name': 'March'},
    {'index': 4, 'name': 'April'},
    {'index': 5, 'name': 'May'},
    {'index': 6, 'name': 'June'},
    {'index': 7, 'name': 'July'},
    {'index': 8, 'name': 'August'},
    {'index': 9, 'name': 'September'},
    {'index': 10, 'name': 'October'},
    {'index': 11, 'name': 'November'},
    {'index': 12, 'name': 'December'},
  ];

  @override
  void initState() {
    super.initState();
    fetchConsumptionTypeList();
    fetchConsumptionYearList();
    loadCustomers();
    setDefaultMonthAndYear();
  }

  void setDefaultMonthAndYear() {
    final now = DateTime.now();
    setState(() {
      selectedConsumptionMonth = now.month;
      selectedConsumptionYear = now.year;
    });
  }

  Future<void> fetchConsumptionTypeList() async {
   
    final response = await ApiService.fetchConsumptionTypeList();
    if (response.statusCode == 200) {
      setState(() {
        var data = json.decode(response.body) as List;
        consumptionTypeList =
            data.map((item) => item['commonRefValue'].toString()).toList();
      });
    } else {
      // throw Exception('Failed to load consumption types');
      ErrorHandler.handleError(
        context,
        'Failed to load consumption types. Please try again later.',
        'Error load consumption types: ${response.statusCode}',
      );
    }
  }

  Future<void> fetchConsumptionYearList() async {
    
    final response = await ApiService.fetchConsumptionYearList();
    if (response.statusCode == 200) {
      setState(() {
        var data = json.decode(response.body) as List;
        consumptionYearList = data
            .map((item) => int.parse(item['commonRefValue'].toString()))
            .toList();
      });
    } else {
      // throw Exception('Failed to load consumption years');
      ErrorHandler.handleError(
        context,
        'Failed to load consumption years. Please try again later.',
        'Error load consumption years: ${response.statusCode}',
      );
    }
  }

  Future<void> loadCustomers() async {
   
    final response = await ApiService.fetchloadCustomers();
    if (response.statusCode == 200) {
      setState(() {
        customerList =
            List<Map<String, dynamic>>.from(json.decode(response.body));
      });
    } else {
      // throw Exception('Failed to load customers');
      ErrorHandler.handleError(
        context,
        'Failed to load customers. Please try again later.',
        'Error load customers: ${response.statusCode}',
      );
    }
  }

  Future<void> save() async {
    if (_formKey.currentState!.validate()) {
      final data = {
        'currentConsumption': currentConsumptionController.text,
        'consumptionType': selectedConsumptionType,
        'consumptionMonth': selectedConsumptionMonth,
        'consumptionYear': selectedConsumptionYear,
        'customerId': selectedCustomerId,
      };

      print('Data to be sent to API: $data'); // Print statement for debug

    
      final response = await ApiService.saveConsumptionData(data);

      if (response.statusCode == 201) {
        // Successfully added, show a dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Center(
                child: Icon(Icons.check_circle, color: Colors.green, size: 50),
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Text(
                      'Success!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 10),
                  Center(
                    child: Text('Customer consumption saved successfully!'),
                  ),
                ],
              ),
              actions: <Widget>[
                Center(
                  child: TextButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                          const Color.fromRGBO(6, 73, 105, 1)),
                      foregroundColor:
                          MaterialStateProperty.all<Color>(Colors.white),
                    ),
                    child: Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                    },
                  ),
                ),
              ],
            );
          },
        );

        resetForm(); // Clear the form fields
      } else {
        // throw Exception('Failed to save customer consumption');
        ErrorHandler.handleError(
          context,
          'Failed to save customer consumption. Please try again later.',
          'Error sending customer consumption: ${response.statusCode}',
        );
      }
    }
  }

  Future<void> refreshData() async {
    await fetchConsumptionTypeList();
    await fetchConsumptionYearList();
    await loadCustomers();
  }

  void resetForm() {
    currentConsumptionController.clear();
    setState(() {
      selectedConsumptionType = null;
      setDefaultMonthAndYear();
      selectedCustomerId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: const Text(
          'Customer Consumption',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: refreshData,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment
                .center, // Aligns children to the start of the column
            children: [
              const SizedBox(height: 15),
              const Text(
                'Enter Customer & Consumption Details',
                style: TextStyle(
                  fontSize: 18,
                  color: Color.fromARGB(255, 125, 125, 124),
                  fontWeight: FontWeight.normal,
                ),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Select Customer',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 41, 221, 200),
                              width: 1.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 23, 158, 142),
                              width: 2.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      value: selectedCustomerId,
                      items: customerList.map((customer) {
                        return DropdownMenuItem<int>(
                          value: customer['customerId'],
                          child: Text(customer['name']),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          selectedCustomerId = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a customer';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 25),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Consumption Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 41, 221, 200),
                              width: 1.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 23, 158, 142),
                              width: 2.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      value: selectedConsumptionType,
                      items: consumptionTypeList.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          selectedConsumptionType = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a consumption type';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 25),
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Select Month',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 41, 221, 200),
                              width: 1.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 23, 158, 142),
                              width: 2.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      value: selectedConsumptionMonth,
                      items: months.map((month) {
                        return DropdownMenuItem<int>(
                          value: month['index'] as int,
                          child: Text(month['name']!),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          selectedConsumptionMonth = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a month';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 25),
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Select Year',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 41, 221, 200),
                              width: 1.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 23, 158, 142),
                              width: 2.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      value: selectedConsumptionYear,
                      items: consumptionYearList.map((int year) {
                        return DropdownMenuItem<int>(
                          value: year,
                          child: Text(year.toString()),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          selectedConsumptionYear = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a year';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 25),
                    TextFormField(
                      controller: currentConsumptionController,
                      decoration: InputDecoration(
                        labelText: 'Enter Current Consumption',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 41, 221, 200),
                              width: 1.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 23, 158, 142),
                              width: 2.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter current consumption';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      onPressed: save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(235, 23, 135, 182),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 10, horizontal: 36),
                        child: Text(
                          'Submit',
                          style: TextStyle(color: Colors.white),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
      bottomNavigationBar: Container(
        color: const Color.fromRGBO(6, 73, 105, 1),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'Powered by ',
                style: TextStyle(
                  color: Color.fromARGB(255, 230, 227, 227),
                  fontSize: 12,
                ),
              ),
              TextSpan(
                text: 'Core',
                style: const TextStyle(
                  color: Color.fromARGB(255, 37, 219, 9),
                  fontSize: 14,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    //ignore: deprecated_member_use
                    launch('https://www.corenuts.com');
                  },
              ),
              TextSpan(
                text: 'Nuts',
                style: const TextStyle(
                  color: Color.fromARGB(255, 221, 10, 10),
                  fontSize: 14,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    //ignore: deprecated_member_use
                    launch('https://www.corenuts.com');
                  },
              ),
              const TextSpan(
                text: ' Technologies',
                style: TextStyle(
                  color: Color.fromARGB(
                      255, 230, 227, 227), // Choose a suitable color
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
