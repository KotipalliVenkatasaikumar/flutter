import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/error_handler.dart';
import 'package:ajna/screens/util.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'map_screen.dart';

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  _QrGeneratorScreenState createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey _qrKey = GlobalKey();
  String? _qrData;

  int? intRoleId;
  int? intOraganizationId;
  int? userId;

  List<Map<String, dynamic>> _projects = [];
  int? _selectedProjectId;
  bool _isLoading = true;
  bool _showQR = false;
  String _organizationName = '';
  String? _generationTime;
  int? _selectedQrTypeId;

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  Future<void> initializeData() async {
    intOraganizationId = await Util.getOrganizationId();
    intRoleId = await Util.getRoleId();
    userId = await Util.getUserId();
    _fetchOrganizationDetails(intOraganizationId!);
    _fetchProjects(intOraganizationId!);
  }

  Future<void> _fetchOrganizationDetails(int organizationId) async {
    try {
      final response = await ApiService.fetchOrgDetails(organizationId);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _organizationName = data['organizationName'];
        });
      } else {
        // throw Exception('Failed to load organization details');
        ErrorHandler.handleError(
          context,
          'Failed to load organization details. Please try again later.',
          'Error sending organization details: ${response.statusCode}',
        );
      }
    } catch (e) {
      // print('Error fetching organization details: $e');
      ErrorHandler.handleError(
        context,
        'Failed to fetching organization details. Please try again later.',
        'Error fetching organization details: $e',
      );
    }
  }

  Future<void> _fetchProjects(int organizationId) async {
    try {
      final response = await ApiService.fetchOrgProjects(organizationId);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _projects = data
              .map((project) =>
                  {'id': project['projectId'], 'name': project['projectName']})
              .toList();
          if (_projects.isNotEmpty) {
            _selectedProjectId = _projects.first['id'];
          }
          _isLoading = false;
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

  Future<void> refreshData() async {
    await initializeData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: const Text(
          'Generate QR Code ',
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
      body: RefreshIndicator(
        onRefresh: refreshData,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _showQR
                ? _buildQRView()
                : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 15),
              Text(
                'Organization: $_organizationName',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 125, 125, 124),
                ),
              ),
              const SizedBox(height: 20),
              // DropdownButtonFormField<int>(
              //   decoration: const InputDecoration(
              //     labelText: 'Select Project',
              //   ),
              //   value: _selectedProjectId,
              //   items: _projects.map((Map<String, dynamic> project) {
              //     return DropdownMenuItem<int>(
              //       value: project['id'],
              //       child: Text(project['name']),
              //     );
              //   }).toList(),
              //   onChanged: (int? value) {
              //     if (value != null) {
              //       setState(() {
              //         _selectedProjectId = value;
              //       });
              //     }
              //   },
              // ),
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
                value: _selectedProjectId,
                items: _projects.isNotEmpty
                    ? _projects.map<DropdownMenuItem<int>>(
                        (Map<String, dynamic> project) {
                        return DropdownMenuItem<int>(
                          value: project['id'],
                          child: Text(project['name'],
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: Color.fromARGB(255, 80, 79, 79))),
                        );
                      }).toList()
                    : [
                        const DropdownMenuItem<int>(
                          value: -1,
                          child: Text('No Projects Available'),
                        )
                      ],
                onChanged: (int? value) {
                  if (value != null) {
                    setState(() {
                      _selectedProjectId = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value == -1) {
                    return 'Please select a project';
                  }
                  return null;
                },
                isExpanded: true,
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 300,
                  width: MediaQuery.of(context).size.width - 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Enter Location Name',
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Location is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField2<int>(
                decoration: InputDecoration(
                  labelText: 'Select QR Type',
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
                value:
                    _selectedQrTypeId, // This should be the selected value variable
                items: [
                  DropdownMenuItem<int>(
                    value: 215,
                    child: const Text('Attendance',
                        style: TextStyle(
                            fontSize: 16,
                            color: Color.fromARGB(255, 80, 79, 79))),
                  ),
                  DropdownMenuItem<int>(
                    value: 91,
                    child: const Text('Security',
                        style: TextStyle(
                            fontSize: 16,
                            color: Color.fromARGB(255, 80, 79, 79))),
                  ),
                ],
                onChanged: (int? value) {
                  if (value != null) {
                    setState(() {
                      _selectedQrTypeId = value; // Assign the selected value
                    });
                  }
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a QR type';
                  }
                  return null;
                },
                isExpanded: true,
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 300,
                  width: MediaQuery.of(context).size.width - 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
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
                            _generationTime = DateTime.now()
                                .toString(); // Set generation time
                          });
                        },
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize
                      .min, // To adjust the button size to fit content
                  children: [
                    Icon(Icons.location_on,
                        color: Colors.white, size: 24), // Map icon
                    SizedBox(width: 8), // Space between icon and text
                    Text(
                      'Set Geo Location',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _latitudeController,
                readOnly: _generationTime !=
                    null, // Make it read-only if generation time is set
                decoration: InputDecoration(
                  labelText: 'Enter Latitude',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Color.fromARGB(255, 41, 221, 200),
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Color.fromARGB(255, 23, 158, 142),
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _longitudeController,
                readOnly: _generationTime !=
                    null, // Make it read-only if generation time is set
                decoration: InputDecoration(
                  labelText: 'Enter Longitude',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Color.fromARGB(255, 41, 221, 200),
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Color.fromARGB(255, 23, 158, 142),
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 20),
              // TextFormField(
              //   controller: _radiusController,
              //   decoration: InputDecoration(
              //     labelText: 'Enter Radius',
              //     border: OutlineInputBorder(
              //       borderRadius: BorderRadius.circular(8.0),
              //     ),
              //     enabledBorder: OutlineInputBorder(
              //       borderSide: BorderSide(
              //         color: Color.fromARGB(255, 41, 221, 200),
              //         width: 1.0,
              //       ),
              //       borderRadius: BorderRadius.circular(8.0),
              //     ),
              //     focusedBorder: OutlineInputBorder(
              //       borderSide: BorderSide(
              //         color: Color.fromARGB(255, 23, 158, 142),
              //         width: 2.0,
              //       ),
              //       borderRadius: BorderRadius.circular(8.0),
              //     ),
              //   ),
              //   keyboardType: TextInputType.text,
              //   validator: (value) {
              //     if (value == null || value.isEmpty) {
              //       return 'Radius is required';
              //     }
              //     final radius = double.tryParse(value);
              //     if (radius == null || radius < 4 || radius > 30) {
              //       return 'Radius must be between 4 and 30 meters';
              //     }
              //     return null;
              //   },
              // ),

              const SizedBox(height: 20),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ElevatedButton(
                    //   onPressed: () async {
                    //     await Navigator.push(
                    //       context,
                    //       MaterialPageRoute(
                    //         builder: (context) => MapScreen(
                    //           onGeofenceSelected:
                    //               (latitude, longitude, radius) {
                    //             setState(() {
                    //               _latitudeController.text =
                    //                   latitude.toString();
                    //               _longitudeController.text =
                    //                   longitude.toString();
                    //               _radiusController.text = radius.toString();
                    //               _generationTime = DateTime.now()
                    //                   .toString(); // Set generation time
                    //             });
                    //           },
                    //         ),
                    //       ),
                    //     );
                    //   },
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: Colors.blue,
                    //   ),
                    //   child: const Text(
                    //     'Select Geo Location',
                    //     style: TextStyle(color: Colors.white),
                    //   ),
                    // ),
                    const SizedBox(
                        width: 16), // Add some space between the buttons
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Map<String, dynamic> qrData = {
                            'orgId': intOraganizationId,
                            'projectId': _selectedProjectId,
                            'userId': userId,
                            'location': _locationController.text,
                            'latitude': _latitudeController.text,
                            'longitude': _longitudeController.text,
                            'radius': _radiusController.text,
                            'qrTypeId': _selectedQrTypeId,
                          };

                          setState(() {
                            _qrData = jsonEncode(qrData);
                            _showQR = true;
                          });

                          _postQrData(
                              qrData); // Call the method to post QR data
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(235, 23, 135, 182),
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 10, horizontal: 26),
                        child: Text(
                          'Generate QR Code',
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
    );
  }

  Widget _buildQRView() {
    return Padding(
      padding: const EdgeInsets.only(top: 30.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment
              .center, // Centering the column contents vertically
          crossAxisAlignment: CrossAxisAlignment
              .center, // Centering the column contents horizontally
          children: [
            RepaintBoundary(
              key: _qrKey,
              child: Center(
                child: Column(
                  children: [
                    // Adjust QR code size to be smaller
                    Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: QrImageView(
                        data: _qrData!,
                        version: QrVersions.auto,
                        size: 150.0, // Smaller size for the QR code
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Project: ${_projects.firstWhere((project) => project['id'] == _selectedProjectId)['name']}',
                            style: const TextStyle(fontSize: 10),
                            overflow: TextOverflow.ellipsis, // Handle overflow
                          ),
                          Text(
                            'Location: ${_locationController.text}',
                            style: const TextStyle(fontSize: 10),
                            overflow: TextOverflow.ellipsis, // Handle overflow
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _downloadQrCode,
                  child: const Text('Download QR Code'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _shareQrCode,
                  child: const Text('Share QR Code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _postQrData(Map<String, dynamic> qrData) async {
    try {
      final response = await ApiService.postQrData(qrData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('QR data successfully Sent')),
        // );

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
                    child: Text('QR Successfully Ganerated!'),
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
      } else {
        // throw Exception('Failed to send QR data to backend');
        ErrorHandler.handleError(
          context,
          'Failed to send QR data. Please try again later.',
          'Error sending QR data: ${response.statusCode}',
        );
      }
    } catch (e) {
      // print('Error posting QR data: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Failed to send QR data to backend')),
      // );
      ErrorHandler.handleError(
        context,
        'Failed to send QR data. Please try again later.',
        'Error sending QR data : $e',
      );
    }
  }

  Future<void> _downloadQrCode() async {
    if (await _requestPermission(Permission.storage)) {
      try {
        final RenderRepaintBoundary boundary =
            _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        final pdf = pw.Document();

        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Image(pw.MemoryImage(pngBytes)),
                  pw.Spacer(),
                  pw.RichText(
                    text: const pw.TextSpan(
                      children: [
                        pw.TextSpan(
                          text: 'Powered by ',
                          style: pw.TextStyle(fontSize: 8),
                        ),
                        pw.TextSpan(
                          text: 'CoreNuts Technologies',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );

//        final directory = await getExternalStorageDirectory();

        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
        } else if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        }

        final projectName = _projects.firstWhere(
            (project) => project['id'] == _selectedProjectId)['name'];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uniqueId = timestamp % 100000; // Last 5 digits of the timestamp
        final fileName =
            'qr_code_${projectName}_${_locationController.text}_$uniqueId.pdf';
        final filePath = '${directory!.path}/$fileName';

        final file = File(filePath);
        await file.writeAsBytes(await pdf.save());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR Code saved to ${file.path}')),
        );
      } catch (e) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save QR Code')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied')),
      );
    }
  }

  Future<void> _shareQrCode() async {
    if (await _requestPermission(Permission.storage)) {
      try {
        final RenderRepaintBoundary boundary =
            _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ImageByteFormat.png);
        final pngBytes = byteData?.buffer.asUint8List();

        final pdf = pw.Document();

        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Image(pw.MemoryImage(pngBytes!)),
                  pw.Spacer(),
                  pw.RichText(
                    text: const pw.TextSpan(
                      children: [
                        pw.TextSpan(
                          text: 'Powered by ',
                          style: pw.TextStyle(fontSize: 8),
                        ),
                        pw.TextSpan(
                          text: 'CoreNuts Technologies',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );

        //   final directory = await getTemporaryDirectory();
        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
        } else if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        }
        final projectName = _projects.firstWhere(
            (project) => project['id'] == _selectedProjectId)['name'];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uniqueId = timestamp % 100000; // Last 5 digits of the timestamp
        final fileName =
            'qr_code_${projectName}_${_locationController.text}_$uniqueId.pdf';
        final filePath = '${directory!.path}/$fileName';

        final file = File(filePath);
        await file.writeAsBytes(await pdf.save());
        // Share the PDF file using share_plus package
        //     await Share.share(file.path, subject: 'Here is my QR Code');
        //  await Share.shareFiles([filePath], text: 'Here is my QR Code');
        //  await Share.shareFiles([filePath], text: 'Here is my QR Code');
        // Share the PDF file using share_plus package
        final xFile = XFile(filePath);
        await Share.shareXFiles([xFile], text: 'Here is my QR Code');
      } catch (e) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share QR Code')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied')),
      );
    }
  }

  Future<bool> _requestPermission(Permission permission) async {
    final status = await permission.request();
    return true;
  }
}
