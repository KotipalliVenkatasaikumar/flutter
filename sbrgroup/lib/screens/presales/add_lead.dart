import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/util.dart'; // Import dropdown_button2

class LeadStatus {
  final String commonRefValue;
  final int id;

  LeadStatus(this.commonRefValue, this.id);
}

class LeadType {
  final int id;
  final String commonRefValue;

  LeadType(this.id, this.commonRefValue);
}

class LeadSource {
  final String name;
  final int leadSourceId;

  LeadSource(this.name, this.leadSourceId);
}

class LeadSubSource {
  final String name;
  final int leadSubSourceId;

  LeadSubSource(this.name, this.leadSubSourceId);
}

class Project {
  final int projectId; // Should be int
  final String projectName; // Should be String

  Project(this.projectId, this.projectName);
}

class Budget {
  final String commonRefKey;
  final String commonRefValue;

  Budget(this.commonRefKey, this.commonRefValue);
}

class UnitType {
  final String name;

  UnitType(this.name);

  // Convert UnitType to a JSON-compatible map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
    };
  }

  // Convert UnitType to a string representation
  @override
  String toString() {
    return name;
  }
}

class CountryCode {
  final String commonRefKey;
  final String commonRefValue;

  CountryCode(this.commonRefKey, this.commonRefValue);
}

class AddLeadScreen extends StatefulWidget {
  @override
  _AddLeadScreenState createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends State<AddLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _alternateContactController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _homeLocationController = TextEditingController();
  final TextEditingController _workLocationController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _languageController = TextEditingController();

  List<LeadStatus> _statuses = [];
  List<LeadType> _types = [];
  List<LeadSource> _sources = [];
  List<CountryCode> _countries = [];
  final List<String> _genders = ['Male', 'Female', 'Other'];
  List<LeadSubSource> _subSources = [];
  List<Project> _projects = [];
  List<UnitType> _unitTypes = [];
  List<Budget> _budgets = [];
  String leadType = 'Lead_Type';
  bool _isLoading = false; // Define the _isLoading variable

  int? _selectedStatus;
  int? _selectedType;
  int? _selectedSource;
  String? _selectedCountry;
  String? _selectedGender;
  int? _selectedSubSource;
  int? _selectedProject;
  UnitType? _selectedUnitType;

  String? _selectedBudget;

  @override
  void initState() {
    super.initState();
    // _fetchDropdownData();
    _fetchLeadStatuses();
    _fetchLeadTypes();
    _fetchLeadSources();
    _fetchCountries();
    _fetchProjects();
    _fetchUnitTypes();
    _fetchBudgets();
  }

  Future<void> _fetchDropdownData() async {
    try {
      await _fetchLeadStatuses();
      await _fetchLeadTypes();
      await _fetchLeadSources();
      await _fetchCountries();
      await _fetchProjects();
      await _fetchUnitTypes();
      await _fetchBudgets();
    } catch (e) {
      print('Error fetching dropdown data: $e');
    }
  }

  Future<void> _fetchLeadStatuses() async {
    try {
      // Retrieve user role name from local storage or a secure storage method
      final userRoleName = await Util.getRoleName(); // Implement this function

      // Ensure userRoleName is not null, default to empty string if it is
      final roleName = userRoleName?.toLowerCase() ?? '';

      // Determine module names based on role
      String moduleNames;
      if (roleName.contains('presales') || roleName.contains('sales head')) {
        moduleNames = 'P,PS';
      } else {
        moduleNames = 'S,PS';
      }

      // Fetch lead statuses based on module names
      // final response = await http.get(Uri.parse(
      //     'http://localhost:9093/api/user/commonreferencedetails/lead/status?typeName=Lead_Status&moduleNames=$moduleNames'));
      final response = await ApiService.fetchLeadStatuses(moduleNames);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _statuses = data
              .map((item) => LeadStatus(item['id'], item['commonRefValue']))
              .toList();
        });
      } else {
        throw Exception('Failed to load lead statuses');
      }
    } catch (error) {
      print('Error fetching lead statuses: $error');
      // Handle error appropriately (e.g., show a message to the user)
    }
  }

  Future<void> _fetchLeadTypes() async {
    final response = await ApiService.fetchLeadTypes();
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      print('Fetched lead types: $data'); // Debug line
      setState(() {
        _types = data
            .map((item) => LeadType(item['id'], item['commonRefValue']))
            .toList();
      });
    } else {
      throw Exception('Failed to load lead types');
    }
  }

  Future<void> _fetchLeadSources() async {
    final response = await ApiService.fetchLeadSources();
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      print('Fetched lead sources: $data'); // Debug line
      setState(() {
        _sources = data
            .map((item) => LeadSource(item['name'], item['leadSourceId']))
            .toList();
      });
    } else {
      throw Exception('Failed to load lead sources');
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

  Future<void> _fetchProjects() async {
    try {
      final response = await ApiService.fetchProjects();
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _projects = data
              .map((item) => Project(
                    item['projectId'] as int, // Ensure this is int
                    item['projectName'] as String, // Ensure this is String
                  ))
              .toList();
        });
      } else {
        throw Exception('Failed to load projects');
      }
    } catch (e) {
      // Handle the error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching projects: $e')),
      );
    }
  }

  Future<void> _fetchUnitTypes() async {
    // final response = await http
    //     .get(Uri.parse('http://localhost:9093/api/project/unit/type/findAll'));
    final response = await ApiService.fetchUnitTypes();
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        _unitTypes = data.map((item) => UnitType(item['name'])).toList();
      });
    } else {
      throw Exception('Failed to load unit types');
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

  Future<void> _submitLead() async {
    // Validate the form
    if (_formKey.currentState!.validate()) {
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      // Prepare the lead data to be submitted
      final leadData = {
        'name': _nameController.text,
        'phoneNumber':
            '$_selectedCountry ${_contactNumberController.text}', // Add space after country code
        'alternatePhoneNumber': _alternateContactController.text,
        'email': _emailController.text,
        'companyName': _companyNameController.text,
        'homeLocation': _homeLocationController.text,
        'workLocation': _workLocationController.text,
        'remarks': _remarksController.text,
        'statusId': _selectedStatus,
        'typeId': _selectedType,
        'sourceId': _selectedSource,
        'gender': _selectedGender,
        'subSourceId': _selectedSubSource,
        'projectId': _selectedProject,
        'preferredFlatType': _selectedUnitType?.toString(),
        'budget': _selectedBudget,
        'language': _languageController.text,
      };

      try {
        // Submit the lead data to the API
        final response = await ApiService.addLead(leadData);

        // Handle successful response
        if (response.statusCode == 201) {
          // Show success dialog
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Center(
                  child:
                      Icon(Icons.check_circle, color: Colors.green, size: 50),
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
                      child: Text('Lead added successfully!'),
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
                        // Navigator.pop(context); // Optionally close the screen
                      },
                    ),
                  ),
                ],
              );
            },
          );

          // Reset the form fields and state
          _formKey.currentState!.reset();
          setState(() {
            _nameController.clear();
            _contactNumberController.clear();
            _alternateContactController.clear();
            _emailController.clear();
            _companyNameController.clear();
            _homeLocationController.clear();
            _workLocationController.clear();
            _remarksController.clear();
            _languageController.clear();
            _selectedCountry = null;
            _selectedStatus = null;
            _selectedType = null;
            _selectedSource = null;
            _selectedGender = null;
            _selectedSubSource = null;
            _selectedProject = null;
            _selectedUnitType = null;
            _selectedBudget = null;
          });
        } else {
          // Handle error response
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add lead: ${response.body}')),
          );
        }
      } catch (e) {
        // Handle exceptions
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting lead: $e')),
        );
      } finally {
        // Hide loading indicator
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: const Text(
          'Add Lead',
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
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  // Country Dropdown (30% width)
                  Expanded(
                    flex: 4, // 30% of total width
                    child: DropdownButtonFormField2<String>(
                      decoration: InputDecoration(
                        labelText: 'Country Code',
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
                      value: _selectedCountry,
                      onChanged: (value) {
                        setState(() {
                          _selectedCountry = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select Country';
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
                  SizedBox(
                      width: 10), // Space between dropdown and contact number
                  // Contact Number Field (70% width)
                  Expanded(
                    flex: 6, // 70% of total width
                    child: TextFormField(
                      controller: _contactNumberController,
                      decoration: InputDecoration(
                        labelText: 'Contact Number',
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
                          return 'Contact number is required';
                        }
                        if (value.length != 10) {
                          return 'Phone number must contain exactly 10 digits';
                        }
                        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
                          return 'Phone number must start with 6, 7, 8, or 9';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              SizedBox(height: 10),

              // Alternate Contact Field
              TextFormField(
                controller: _alternateContactController,
                decoration: InputDecoration(
                  labelText: 'Alternate Contact',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 10),

              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  // If the value is null or empty, no validation is required
                  if (value == null || value.isEmpty) {
                    return null;
                  }

                  // If the value is not a valid email format, return a suggestion message
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Enter a valid email address';
                  }

                  // If the value is valid, no validation error message is returned
                  return null;
                },
              ),
              SizedBox(height: 10),
              DropdownButtonFormField2<String>(
                decoration: InputDecoration(
                  labelText: 'Select Gender',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                value: _selectedGender,
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
                items: _genders
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      ),
                    )
                    .toList(),
                // decoration: const InputDecoration(labelText: 'Flat Type'),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 300,
                  width: MediaQuery.of(context).size.width - 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 10),

              // Home Location Field
              TextFormField(
                controller: _homeLocationController,
                decoration: InputDecoration(
                  labelText: 'Home Location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _workLocationController,
                decoration: InputDecoration(
                  labelText: 'Work Location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _companyNameController,
                decoration: InputDecoration(
                  labelText: 'Company Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),

              SizedBox(height: 10),
              // Source Dropdown
              DropdownButtonFormField2<int>(
                decoration: InputDecoration(
                  labelText: 'Select Source',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                value: _selectedSource,
                onChanged: (value) {
                  setState(() {
                    _selectedSource = value;
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
              SizedBox(height: 10),
// SubSource Dropdown
              DropdownButtonFormField2<int>(
                decoration: InputDecoration(
                  labelText: 'Select SubSource',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                value: _selectedSubSource,
                onChanged: (value) {
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

              SizedBox(height: 10),
              DropdownButtonFormField2<int>(
                decoration: InputDecoration(
                  labelText: 'Select Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                value: _selectedType,
                onChanged: (int? value) {
                  setState(() {
                    _selectedType = value;
                  });
                },
                items: _types
                    .map(
                      (type) => DropdownMenuItem<int>(
                        value: type.id,
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

              SizedBox(height: 10),
              DropdownButtonFormField2<int>(
                decoration: InputDecoration(
                  labelText: 'Select Status',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                value: _selectedStatus,
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value;
                  });
                },

                items: _statuses
                    .map(
                      (type) => DropdownMenuItem<int>(
                        value: type.id,
                        child: Text(type.commonRefValue),
                      ),
                    )
                    .toList(),
                // decoration: const InputDecoration(labelText: 'Flat Type'),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 250,
                  width: MediaQuery.of(context).size.width - 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField2<int>(
                decoration: InputDecoration(
                  labelText: 'Select Project',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                value: _selectedProject,
                onChanged: (value) {
                  setState(() {
                    _selectedProject = value;
                  });
                },

                items: _projects
                    .map(
                      (type) => DropdownMenuItem<int>(
                        value: type.projectId,
                        child: Text(type.projectName),
                      ),
                    )
                    .toList(),
                // decoration: const InputDecoration(labelText: 'Flat Type'),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 250,
                  width: MediaQuery.of(context).size.width - 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),

              SizedBox(height: 10),

              DropdownButtonFormField2<UnitType>(
                decoration: InputDecoration(
                  labelText: 'Select Unit Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                value: _selectedUnitType,
                onChanged: (UnitType? value) {
                  setState(() {
                    _selectedUnitType = value;
                  });
                },
                items: _unitTypes
                    .map(
                      (type) => DropdownMenuItem<UnitType>(
                        value: type,
                        child: Text(type.name),
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

              SizedBox(height: 10),
              DropdownButtonFormField2<String>(
                decoration: InputDecoration(
                  labelText: 'Select Budget',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                value: _selectedBudget,
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
                // decoration: const InputDecoration(labelText: 'Flat Type'),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 250,
                  width: MediaQuery.of(context).size.width - 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),

              SizedBox(height: 10),

              // Remarks Field
              TextFormField(
                controller: _remarksController,
                decoration: InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 10),

              TextFormField(
                controller: _languageController,
                decoration: InputDecoration(
                  labelText: 'Spoken Language',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 41, 221, 200), width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 23, 158, 142), width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),

              // Submit Button
              ElevatedButton(
                onPressed: () {
                  // Check if both name and contact number are filled
                  if (_nameController.text.isNotEmpty &&
                      _contactNumberController.text.isNotEmpty) {
                    // Directly submit without validating the whole form
                    _submitLead(); // Save user data
                  } else {
                    // Validate the entire form
                    if (_formKey.currentState!.validate()) {
                      _submitLead(); // Save user data
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(235, 23, 135, 182),
                  foregroundColor: Colors.white, // Custom text color
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 36),
                  child: Text(
                    'Submit',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
