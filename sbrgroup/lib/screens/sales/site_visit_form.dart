import 'dart:convert';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/home_screen.dart';
import 'package:ajna/screens/util.dart';

class LeadSource {
  final String name;
  final int leadSourceId;

  LeadSource(this.name, this.leadSourceId);
}

class CommonReferenceDetails {
  final int id;
  final String commonRefValue;

  CommonReferenceDetails(this.id, this.commonRefValue);
}

class CountryCode {
  final String commonRefKey;
  final String commonRefValue;

  CountryCode(this.commonRefKey, this.commonRefValue);
}

class LeadSubSource {
  final String name;
  final int leadSubSourceId;

  LeadSubSource(this.name, this.leadSubSourceId);
}

class Budget {
  final String commonRefKey;
  final String commonRefValue;

  Budget(this.commonRefKey, this.commonRefValue);
}

class User {
  final int userId;
  final String userName;

  User(this.userId, this.userName);
}

class Project {
  final int projectId;
  final String projectName;

  Project(this.projectId, this.projectName);
}

class SiteVisitForm extends StatefulWidget {
  @override
  _SiteVisitFormState createState() => _SiteVisitFormState();
}

class _SiteVisitFormState extends State<SiteVisitForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneNumberController = TextEditingController();
  //  TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  List<String> _addressSuggestions = [];
  // Form fields
  String _name = '';
  String _phoneNumber = '';
  String _email = '';
  String _address = '';
  int? _selectedCommonReferenceValue;
  int? _selectedLeadSourceId;
  DateTime _followupDateTime = DateTime.now();
  String _remarks = '';
  String? _selectedCountry = '+91';
  String? _selectedBudget;
  int? _selectedSubSource;
  bool _isSubmitDisabled = false;
  int? _selectedUserId;
  int? _pincode;
  int? _leadId;
  final bool _isSiteVisitForm = true;
  int? _selectedProjectId;

  // Dropdown data
  List<CommonReferenceDetails> _flatTypes = [];
  List<LeadSource> _sources = [];
  List<CountryCode> _countries = [];
  List<Budget> _budgets = [];
  List<LeadSubSource> _subSources = [];
  List<User> _users = [];
  int? intOraganizationId;
  List<Project> _projects = [];
  // Loading state
  bool _isLoading = false;

  @override
  void initState() {
    _phoneNumberController.text = _phoneNumber;
    super.initState();
    _fetchDropdownData();
  }

  @override
  void dispose() {
    _phoneNumberController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();

    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    intOraganizationId = await Util.getOrganizationId();
    await _fetchSources();
    await _fetchFlatTypes('Flat_Type');
    await _fetchCountries();
    await _fetchBudgets();
    // await _fetchUsers();
    await _fetchProjects(intOraganizationId!);
  }

  Future<void> _fetchFlatTypes(String typeName) async {
    try {
     
      final response = await ApiService.getCommonReferenceDetails(typeName);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _flatTypes = data
              .map((item) =>
                  CommonReferenceDetails(item['id'], item['commonRefValue']))
              .toList();
        });
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to fetch flat types. Please try again later.',
          'Failed to load flat types: ${response.statusCode}',
        );
      }
    } catch (e) {
      ErrorHandler.handleError(
        context,
        'Failed to fetch flat types. Please try again later.',
        'Error fetching flat types: $e',
      );
    }
  }

  Future<void> _fetchSources() async {
    try {
     

      final response = await ApiService.fetchLeadSource();
      if (response.statusCode == 200) {
        Iterable list = json.decode(response.body);
        setState(() {
          _sources = list
              .map((model) => LeadSource(model['name'], model['leadSourceId']))
              .toList();
        });
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to fetch sources. Please try again later.',
          'Failed to load sources',
        );
      }
    } catch (e) {
      ErrorHandler.handleError(
        context,
        'Failed to fetch sources. Please try again later.',
        'Error fetching sources: $e',
      );
    }
  }

  Future<void> _fetchSubSources(int sourceId) async {
    final response = await ApiService.fetchSubSources(sourceId);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      print('Fetched sub sources: $data'); // Debug line
      setState(() {
        _subSources = data
            .map((item) => LeadSubSource(item['name'], item['leadSubSourceId']))
            .toList();
      });
    } else {
      throw Exception('Failed to load sub sources');
    }
  }

  Future<void> _fetchProjects(int organizationId) async {
    try {
      final response = await ApiService.fetchOrgProjects(organizationId);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _projects = data
              .map((item) => Project(item['projectId'], item['projectName']))
              .toList();
        });
      } else {
        // throw Exception('Failed to load projects');
        ErrorHandler.handleError(
          context,
          'Failed to load projects. Please try again later.',
          'Error sending projects: ${response.statusCode}',
        );
      }
    } catch (e) {
      // print('Error fetching projects: $e');
      ErrorHandler.handleError(
        context,
        'Error fetching projects. Please try again later.',
        'Error fetching projects: $e',
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCountries() async {
    // final response = await http.get(Uri.parse(
    //     'http://localhost:9093/api/user/commonreferencedetails/types/Country_Code'));
    final response = await ApiService.fetchCountries();
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        _countries = data
            .map((item) =>
                CountryCode(item['commonRefValue'], item['commonRefKey']))
            .toList();
      });
    } else {
      throw Exception('Failed to load countries');
    }
  }

  Future<void> _fetchBudgets() async {
    // final response = await http.get(Uri.parse(
    //     'http://localhost:9093/api/user/commonreferencedetails/types/Budget_Type'));
    final response = await ApiService.fetchBudgets();

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        _budgets = data
            .map((item) => Budget(item['commonRefKey'], item['commonRefValue']))
            .toList();
      });
    } else {
      throw Exception('Failed to load Budget');
    }
  }

  Future<void> _fetchRecord() async {
    if (_phoneNumber.length == 10 && _selectedCountry != null) {
      final fullPhoneNumber =
          Uri.encodeComponent('$_selectedCountry $_phoneNumber');

      // setState(() {
      //   _isLoading = true;
      // });

      try {
        final response = await ApiService.fetchRecord(fullPhoneNumber);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          setState(() {
            _nameController.text = data['name'] ?? '';
            // _phoneNumberController.text = data['phoneNumber'] ?? '';
            _emailController.text = data['email'] ?? '';
            _addressController.text = data['homeLocation'] ?? '';
            _pincodeController.text = data['pincode']?.toString() ?? '';
            // _selectedCountry = data["phoneNumber"] ?? '';
            // _name = data['name'] ?? _name;
            // _phoneNumber = data['phoneNumber'] ?? _phoneNumber;
            // _email = data['email'] ?? _email;
            // _address = data['homeLocation'] ?? _address;
            final phoneNumber = data['phoneNumber'] ?? '';
            final phoneParts = phoneNumber.split(' ');
            if (phoneParts.length == 2) {
              _selectedCountry = phoneParts[0];
              _phoneNumberController.text = phoneParts[1];
            } else {
              _phoneNumberController.text = phoneNumber;
              _selectedCountry = ''; // Handle error or default case if needed
            }

            _remarksController.text = data['remarks'] ?? '';
            _followupDateTime = data['followupDateTime'] != null
                ? DateTime.parse(data['followupDateTime'])
                : _followupDateTime;
            _leadId =
                data['id'] != null ? int.tryParse(data['id'].toString()) : null;

            _patchDropdownSelections(data);
            _isSubmitDisabled = true;
          });
        } else if (response.statusCode == 404) {
          setState(() {
            // _name = '';
            // _email = '';
            // _address = '';
            // _nameController.clear();
            _emailController.clear();
            _addressController.clear();
            _selectedCommonReferenceValue = null;
            _selectedBudget = null;
            _selectedLeadSourceId = null;
            _selectedSubSource = null;
            _followupDateTime = DateTime.now();
            _remarks = '';
            _selectedUserId = null;
            _pincodeController.clear();
            _isSubmitDisabled = false;
          });
        }
      } finally {
        // setState(() {
        //   _isLoading = false;
        // });
      }
    }
  }

  void _patchDropdownSelections(Map<String, dynamic> data) {
    setState(() {
      // Update Lead Source dropdown
      if (data['sourceId'] != null) {
        _selectedLeadSourceId = data['sourceId'] != null
            ? int.tryParse(data['sourceId'].toString())
            : null;
        // Optionally fetch SubSources based on the Lead Source
        if (_selectedLeadSourceId != null) {
          _fetchSubSources(_selectedLeadSourceId!);
        }
      }

      // Update Budget dropdown
      _selectedBudget = data['budget'] ?? '';

      // Update Flat Type dropdown
      _selectedCommonReferenceValue = data['preferredFlatType'] != null
          ? int.tryParse(data['preferredFlatType'].toString())
          : null;

      // Update SubSource dropdown
      _selectedSubSource = data['subSourceId'] != null
          ? int.tryParse(data['subSourceId'].toString())
          : null;

      // Update sales dropdown
      _selectedUserId = data['assignedToSales'] != null
          ? int.tryParse(data['assignedToSales'].toString())
          : null;

      _selectedProjectId = data['projectId'] != null
          ? int.tryParse(data['projectId'].toString())
          : null;
      _projects;
    });
    _fetchUsers();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // setState(() {
      //   _isLoading = true;
      // });

      // Retrieve values from controllers
      final name = _name;
      final phoneNumber = '$_selectedCountry ${_phoneNumber}';
      final email = _email;
      final address = _addressController.text; // Fetch from address controller
      final projectId = _selectedProjectId ?? 0;
      final commonReferenceValue = _selectedCommonReferenceValue ?? 0;
      final budget = _selectedBudget?.toString() ?? "0";

      final leadSourceId = _selectedLeadSourceId ?? 0;
      final subSource = _selectedSubSource ?? 0;
      final followupDateTime = _followupDateTime ?? DateTime.now();
      final remarks = _remarks ?? "";
      final userId = _selectedUserId ?? 0;
      final pincode =
          int.tryParse(_pincodeController.text) ?? 0; // Fetch and parse pincode

      // Logging each variable
      print('Name: $name');
      print('Phone Number: $phoneNumber');
      print('Email: $email');
      print('Address: $address');
      print('Project ID: $projectId');
      print('Common Reference Value: $commonReferenceValue');
      print('Budget: $budget');
      print('Lead Source ID: $leadSourceId');
      print('Sub Source ID: $subSource');
      print('Followup DateTime: $followupDateTime');
      print('Remarks: $remarks');
      print('User ID: $userId');
      print('Pincode: $pincode');
      print('Is Site Visit Form: $_isSiteVisitForm');

      try {
        final response = await ApiService.saveSiteVisit(
          name,
          phoneNumber,
          email,
          address,
          projectId,
          commonReferenceValue,
          budget,
          leadSourceId,
          subSource,
          followupDateTime,
          remarks,
          userId,
          pincode,
          _isSiteVisitForm,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          _showSuccessDialog('Site visit form submitted successfully!');
          _resetForm(); // Show success dialog and reset the form
        } else {
          print('Response status: ${response.statusCode}');
          print('Response body: ${response.body}');
          _showErrorDialog(
              'Failed to submit site visit form. Please try again later.');
        }
      } catch (e) {
        print('Error occurred during form submission: $e');
        _showErrorDialog('An error occurred while submitting the form.');
      } finally {
        // setState(() {
        //   _isLoading = false;
        // });
      }
    }
  }

  Future<void> _updateRecord() async {
    if (_leadId == null || _leadId == 0) {
      _showErrorDialog('Lead ID is not set.');
      return;
    }

    // setState(() {
    //   _isLoading = true;
    // });

    // Retrieve values from controllers
    final leadId = _leadId!;
    final name = _nameController.text.isNotEmpty ? _nameController.text : "";
    final phoneNumber = '$_selectedCountry ${_phoneNumber ?? ""}';
    final email = _emailController.text.isNotEmpty ? _emailController.text : "";
    final address = _addressController.text.isNotEmpty
        ? _addressController.text
        : ""; // Fetch from address controller
    final projectId = _selectedProjectId ?? 0;
    final commonReferenceValue = _selectedCommonReferenceValue ?? 0;
    final budget = _selectedBudget?.toString() ?? "0";

    final leadSourceId = _selectedLeadSourceId ?? 0;
    final subSource = _selectedSubSource ?? 0;
    final followupDateTime = _followupDateTime ?? DateTime.now();
    final remarks =
        _remarksController.text.isNotEmpty ? _remarksController.text : "";
    final userId = _selectedUserId ?? 0;
    final pincode =
        int.tryParse(_pincodeController.text) ?? 0; // Fetch and parse pincode

    // Logging each variable
    print('Lead ID: $leadId');
    print('Name: $name');
    print('Phone Number: $phoneNumber');
    print('Email: $email');
    print('Address: $address');
    print('Project ID: $projectId');
    print('Common Reference Value: $commonReferenceValue');
    print('Budget: $budget');
    print('Lead Source ID: $leadSourceId');
    print('Sub Source ID: $subSource');
    print('Followup DateTime: $followupDateTime');
    print('Remarks: $remarks');
    print('User ID: $userId');
    print('Pincode: $pincode');
    print('Is Site Visit Form: $_isSiteVisitForm');

    try {
      final response = await ApiService.updateRecord(
        leadId,
        name,
        phoneNumber,
        email,
        address,
        projectId,
        commonReferenceValue,
        budget,
        leadSourceId,
        subSource,
        followupDateTime,
        remarks,
        userId,
        pincode,
        _isSiteVisitForm,
      );

      if (response.statusCode == 200) {
        _showSuccessDialog('Record updated successfully.');
      } else {
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
        _showErrorDialog(
            'Failed to update the record. Please try again later.');
      }
    } catch (e) {
      print('Error occurred during record update: $e');
      _showErrorDialog('An error occurred while updating the record.');
    } finally {
      // setState(() {
      //   _isLoading = false;
      // });
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final response =
          await ApiService.SalesUsers(intOraganizationId!, _selectedProjectId!);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _users = data
              .map((item) => User(item['userId'], item['userName']))
              .toList();
        });
      } else {
        ErrorHandler.handleError(
          context,
          'Failed to load managers. Please try again later.',
          'Error loading managers: ${response.statusCode}',
        );
      }
    } catch (e) {
      ErrorHandler.handleError(
        context,
        'Failed to fetch managers. Please try again later.',
        'Error fetching managers: $e',
      );
    }
  }

  Future<void> _fetchAddressesByPincode(String pincode, String location) async {
    // setState(() {
    //   _isLoading = true;
    // });

    try {
      final response = await ApiService.getAddressByPinCode(pincode, location);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          _addressSuggestions =
              data.values.map((item) => item as String).toList();
        });
      } else {
        // _showErrorDialog('API call failed with status: ${response.statusCode}');
      }
    } catch (e) {
      // _showErrorDialog('Error calling API: $e');
    } finally {
      // setState(() {
      //   _isLoading = false;
      // });
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Center(
            child: Icon(Icons.check_circle, color: Colors.green, size: 50),
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
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
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                  if (_isSiteVisitForm) {
                    // Navigate to a specific screen widget
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => HomeScreen()),
                    );
                  } else {
                    _resetForm(); // Reset the form after closing the dialog
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset(); // Reset form fields

    setState(() {
      _nameController.clear();
      _phoneNumberController.clear();
      _emailController.clear();
      _addressController.clear();
      _remarksController.clear();
      _pincodeController.clear();

      _name = '';
      _phoneNumber = '';
      _email = "";
      _address = '';
      _pincode = null;
      _remarks = '';
      _selectedCountry = null;
      _selectedCommonReferenceValue = null;
      _selectedBudget = null;
      _selectedLeadSourceId = null;
      _selectedSubSource = null;
      _followupDateTime = DateTime.now();
      _remarks = '';
      _selectedUserId = null;
    });
  }

// Add this boolean to your state to track if a dialog has been shown

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: const Text(
          'Site Visit Form',
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const SizedBox(height: 3),
                    TextFormField(
                      // decoration: const InputDecoration(labelText: 'Name'),
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Enter Name',
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                      onSaved: (newValue) => _name = newValue!,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField2<String>(
                            decoration: InputDecoration(
                              labelText: 'Country Code',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Color.fromARGB(255, 41, 221, 200),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Color.fromARGB(255, 23, 158, 142),
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            value: _countries
                                    .map((e) => e.commonRefValue)
                                    .contains(_selectedCountry)
                                ? _selectedCountry
                                : null,
                            onChanged: _isSubmitDisabled
                                ? null // Disable dropdown if _isSubmitDisabled is true
                                : (value) {
                                    setState(() {
                                      _selectedCountry = value;
                                    });
                                    if (_phoneNumber.length == 10) {
                                      _fetchRecord();
                                    }
                                  },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a country code';
                              }
                              return null;
                            },
                            items: _countries
                                .map(
                                  (type) => DropdownMenuItem<String>(
                                    value: type.commonRefValue,
                                    child: Text(type.commonRefKey),
                                  ),
                                )
                                .toList(),
                            dropdownStyleData: DropdownStyleData(
                              maxHeight: 300,
                              width: MediaQuery.of(context).size.width - 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: TextFormField(
                            controller: _phoneNumberController,
                            decoration: InputDecoration(
                              labelText: 'Enter Phone Number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Color.fromARGB(255, 41, 221, 200),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Color.fromARGB(255, 23, 158, 142),
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .digitsOnly, // Allow only digits
                              LengthLimitingTextInputFormatter(
                                  10), // Limit to 10 digits
                            ],
                            onChanged: (value) {
                              setState(() {
                                _phoneNumber = value;
                                if (_phoneNumber.length == 10 &&
                                    _selectedCountry != null) {
                                  _fetchRecord();
                                }
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a phone number';
                              } else if (value.length != 10) {
                                return 'Phone number must be exactly 10 digits';
                              }
                              return null;
                            },
                            enabled:
                                !_isSubmitDisabled, // Disable input field if _isSubmitDisabled is true
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField2<int>(
                      decoration: InputDecoration(
                        labelText: 'Select Project',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 41, 221, 200),
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 23, 158, 142),
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      value: _projects
                              .map((e) => e.projectId)
                              .contains(_selectedProjectId)
                          ? _selectedProjectId
                          : null, // Corrected value reference
                      onChanged: (value) {
                        setState(() {
                          _selectedProjectId =
                              value; // Update the selected project ID
                          _fetchUsers();
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a project'; // Validation error message
                        }
                        return null; // Validation passed
                      },
                      items: _projects
                          .map(
                            (type) => DropdownMenuItem<int>(
                              value: type.projectId,
                              child: Text(type.projectName),
                            ),
                          )
                          .toList(),
                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 250,
                        width: MediaQuery.of(context).size.width - 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),

                    // Add some spacing below the row
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Enter Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 41, 221, 200),
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 23, 158, 142),
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        // If the value is null or empty, it is considered valid
                        if (value == null || value.isEmpty) {
                          return null; // Optionally, you can return a message here if an email is mandatory
                        }

                        // Validate the email format using a regular expression
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                        if (!emailRegex.hasMatch(value)) {
                          return 'Enter a valid email address';
                        }

                        // If the value is valid, no validation error message is returned
                        return null;
                      },
                      onSaved: (newValue) => _email = newValue!,
                      enabled:
                          !_isSubmitDisabled, // Conditionally disable the field if necessary
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pincodeController,
                      decoration: InputDecoration(
                        labelText: 'Enter Pincode',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: (value) {
                        if (value.length == 6) {
                          // Fetch addresses based on pincode
                          _fetchAddressesByPincode(value, '');
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      CircularProgressIndicator()
                    else if (_addressSuggestions.isNotEmpty)
                      DropdownSearch<String>(
                        items: _addressSuggestions,
                        selectedItem: _addressController.text.isNotEmpty &&
                                _addressSuggestions
                                    .contains(_addressController.text)
                            ? _addressController.text
                            : null,
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            labelText: 'Select Address',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color.fromARGB(255, 41, 221, 200),
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color.fromARGB(255, 23, 158, 142),
                                width: 2.0,
                              ),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _addressController.text = value ?? '';
                          });
                        },
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
                              labelText: 'Search Address',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                          ),
                          constraints: const BoxConstraints(
                            maxHeight: 250,
                          ),
                        ),
                      )
                    else
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: 'Enter Address',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),
                    DropdownButtonFormField2<int>(
                      decoration: InputDecoration(
                        labelText: 'Select Flat Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 41, 221, 200),
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 23, 158, 142),
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      value: _flatTypes
                              .map((e) => e.id)
                              .contains(_selectedCommonReferenceValue)
                          ? _selectedCommonReferenceValue
                          : null,
                      onChanged: (value) {
                        setState(() {
                          _selectedCommonReferenceValue = value;
                        });
                      },
                      items: _flatTypes
                          .map(
                            (type) => DropdownMenuItem<int>(
                              value: type.id,
                              child: Text(type.commonRefValue),
                            ),
                          )
                          .toList(),
                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 300,
                        width: MediaQuery.of(context).size.width - 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField2<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Budget',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 41, 221, 200),
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 23, 158, 142),
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      value: _budgets
                              .map((e) => e.commonRefKey)
                              .contains(_selectedBudget)
                          ? _selectedBudget
                          : null,
                      onChanged: (value) {
                        setState(() {
                          _selectedBudget = value;
                        });
                      },
                      items: _budgets
                          .map(
                            (type) => DropdownMenuItem<String>(
                              value: type.commonRefKey,
                              child: Text(type.commonRefValue),
                            ),
                          )
                          .toList(),
                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 250,
                        width: MediaQuery.of(context).size.width - 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField2<int>(
                      value: _sources
                              .map((e) => e.leadSourceId)
                              .contains(_selectedLeadSourceId)
                          ? _selectedLeadSourceId
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Select Source',
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
                      onChanged: _isSubmitDisabled
                          ? null // Disable dropdown if _isSubmitDisabled is true
                          : (value) {
                              setState(() {
                                _selectedLeadSourceId = value;
                                _selectedSubSource =
                                    null; // Clear the previously selected subsource
                              });
                              if (value != null) {
                                _fetchSubSources(
                                    value); // Fetch subsources based on the selected source ID
                              }
                            },
                      items: _sources
                          .map(
                            (source) => DropdownMenuItem<int>(
                              value: source.leadSourceId,
                              child: Text(source.name),
                            ),
                          )
                          .toList(),
                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 250,
                        width: MediaQuery.of(context).size.width - 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
// SubSource Dropdown
                    DropdownButtonFormField2<int>(
                      value: _subSources
                              .map((e) => e.leadSubSourceId)
                              .contains(_selectedSubSource)
                          ? _selectedSubSource
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Select SubSource',
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
                      onChanged: _isSubmitDisabled
                          ? null // Disable dropdown if _isSubmitDisabled is true
                          : (value) {
                              setState(() {
                                _selectedSubSource = value;
                              });
                            },
                      items: _subSources
                          .map(
                            (subSource) => DropdownMenuItem<int>(
                              value: subSource.leadSubSourceId,
                              child: Text(subSource.name),
                            ),
                          )
                          .toList(),
                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 250,
                        width: MediaQuery.of(context).size.width - 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final selectedDate = await showDatePicker(
                                context: context,
                                initialDate: _followupDateTime,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (selectedDate != null) {
                                setState(() {
                                  _followupDateTime = selectedDate;
                                });
                              }
                            },
                            child: AbsorbPointer(
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Follow-up Date',
                                  suffixIcon: Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Color.fromARGB(255, 41, 221, 200),
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Color.fromARGB(255, 23, 158, 142),
                                      width: 2.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                controller: TextEditingController(
                                  text:
                                      '${_followupDateTime.day}/${_followupDateTime.month}/${_followupDateTime.year}',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField2<int>(
                      value:
                          _users.map((e) => e.userId).contains(_selectedUserId)
                              ? _selectedUserId
                              : null,
                      decoration: InputDecoration(
                        labelText: 'Select Sales Member',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 41, 221, 200),
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 23, 158, 142),
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedUserId = value;
                        });
                      },
                      items: _users
                          .map(
                            (user) => DropdownMenuItem<int>(
                              value: user.userId,
                              child: Text(user.userName),
                            ),
                          )
                          .toList(),
                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 150,
                        width: MediaQuery.of(context).size.width - 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      // decoration: const InputDecoration(labelText: 'Remarks'),
                      controller: _remarksController,
                      decoration: InputDecoration(
                        labelText: 'Enter Remarks',
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

                      onSaved: (newValue) => _remarks = newValue!,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          if (_isSubmitDisabled) {
                            // Perform the update action
                            _updateRecord();
                          } else {
                            // Perform the submit action
                            _submitForm();
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(235, 23, 135, 182),
                        foregroundColor: Colors.white, // Custom text color
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 36),
                        child: Text(
                          _isSubmitDisabled ? 'Update' : 'Submit',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  ],
                ),
              ),
      ),
    );
  }
}
