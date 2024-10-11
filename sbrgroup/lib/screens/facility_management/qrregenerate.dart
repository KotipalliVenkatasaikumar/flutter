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

class QRInfo {
  final int orgId;
  final int projectId;
  final String location;
  final String latitude;
  final String longitude;
  final String radius;
  final String projectName;
  final int qrTypeId;

  QRInfo({
    required this.orgId,
    required this.projectId,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.projectName,
    required this.qrTypeId,
  });

  factory QRInfo.fromJson(Map<String, dynamic> json) {
    return QRInfo(
      orgId: json['orgId'],
      projectId: json['projectId'],
      location: json['location'],
      latitude: json['latitude'].toString(),
      longitude: json['longitude'].toString(),
      radius: json['radius'].toString(),
      projectName: json['projectName'],
      qrTypeId: json['qrTypeId'],
    );
  }

  String generateQRData() {
    return jsonEncode({
      'orgId': orgId,
      'projectId': projectId,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'qrTypeId': qrTypeId,
      // 'projectName': projectName,
    });
  }
}

class QrRegenerate extends StatefulWidget {
  const QrRegenerate({Key? key}) : super(key: key);

  @override
  _QrRegenerateState createState() => _QrRegenerateState();
}

class _QrRegenerateState extends State<QrRegenerate> {
  int? selectedOrgId;
  int? selectedProjectId;
  List<dynamic> projects = [];
  List<QRInfo> qrData = [];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey _qrKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    fetchLoggedInUserOrganization();
  }

  Future<void> fetchLoggedInUserOrganization() async {
    selectedOrgId = await Util
        .getOrganizationId(); // Example orgId, replace with your logic

    fetchProjects();
  }

  Future<void> fetchProjects() async {
    if (selectedOrgId == null) return;

    final response = await ApiService.fetchQrProjects(selectedOrgId!);

    if (response.statusCode == 200) {
      final List<dynamic> projectList = json.decode(response.body);
      setState(() {
        projects = projectList;
        if (projects.isNotEmpty) {
          selectedProjectId = projects[0]['projectId'];
          fetchQRData(selectedProjectId!);
        }
      });
    } else {
      // throw Exception('Failed to load projects');
      ErrorHandler.handleError(
        context,
        'Failed to load projects. Please try again later.',
        'Failed to load projects: ${response.statusCode}',
      );
    }
  }

  Future<void> fetchQRData(int projectId) async {
    if (selectedOrgId == null) return;

    final response =
        await ApiService.fetchQrReGenerate(projectId, selectedOrgId!);

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);

      setState(() {
        qrData = data.map((item) => QRInfo.fromJson(item)).toList();
      });
    } else {
      // throw Exception('Failed to load QR data');
      ErrorHandler.handleError(
        context,
        'Failed to load QR data. Please try again later.',
        'Failed to load QR data: ${response.statusCode}',
      );
    }
  }

  void _showQRDialog(BuildContext context, QRInfo qrInfo) {
    String qrData = qrInfo.generateQRData();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'QR Code',
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10.0),
                RepaintBoundary(
                  key: _qrKey,
                  child: QrImageView(
                    data: qrInfo.generateQRData(),
                    size: 150.0,
                  ),
                ),
                const SizedBox(height: 10.0),
                Text(
                  'Project: ${qrInfo.projectName}',
                  style: const TextStyle(fontSize: 16.0),
                ),
                const SizedBox(height: 5.0),
                Text(
                  'Location: ${qrInfo.location}',
                  style: const TextStyle(fontSize: 16.0),
                ),
                const SizedBox(height: 20.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        _downloadQrCode(context, qrInfo);
                      },
                      child: const Text('Download'),
                    ),
                    const SizedBox(width: 20.0),
                    ElevatedButton(
                      onPressed: () {
                        _shareQrCode(context, qrInfo);
                      },
                      child: const Text('Share'),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadQrCode(BuildContext context, QRInfo qrInfo) async {
    if (await _requestPermission(Permission.storage)) {
      try {
        final boundary =
            _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to find QR code boundary')),
          );
          return;
        }
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        final pdf = pw.Document();

        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Image(pw.MemoryImage(pngBytes)),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'Project: ${qrInfo.projectName}',
                      style: const pw.TextStyle(fontSize: 16.0),
                    ),
                    pw.Text(
                      'Location: ${qrInfo.location}',
                      style: const pw.TextStyle(fontSize: 16.0),
                    ),
                    pw.SizedBox(height: 20),
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
                ),
              );
            },
          ),
        );

        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
        } else if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        }

        final projectName = qrInfo.projectName;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uniqueId = timestamp % 100000;
        final fileName =
            'QR_${projectName}_Location_${qrInfo.location}_$uniqueId.pdf';
        final file = File('${directory!.path}/$fileName');
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

  Future<void> _shareQrCode(BuildContext context, QRInfo qrInfo) async {
    if (await _requestPermission(Permission.storage)) {
      try {
        final boundary =
            _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to find QR code boundary')),
          );
          return;
        }
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        final pdf = pw.Document();

        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Image(pw.MemoryImage(pngBytes)),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'Project: ${qrInfo.projectName}',
                      style: const pw.TextStyle(fontSize: 16.0),
                    ),
                    pw.Text(
                      'Location: ${qrInfo.location}',
                      style: const pw.TextStyle(fontSize: 16.0),
                    ),
                    pw.SizedBox(height: 20),
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
                ),
              );
            },
          ),
        );

        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
        } else if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        }

        final projectName = qrInfo.projectName;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uniqueId = timestamp % 100000;
        final fileName =
            'QR_${projectName}_Location_${qrInfo.location}_$uniqueId.pdf';
        final filePath = File('${directory!.path}/$fileName');
        await filePath.writeAsBytes(await pdf.save());

        // Share the PDF file using share_plus package
        final xFile = XFile(filePath.path); // Convert File to XFile with path
        await Share.shareXFiles([xFile], text: 'Here is my QR Code');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR Code shared to ${filePath.path}')),
        );
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
    if (await permission.isGranted) {
      return true;
    }

    final status = await permission.request();

    if (status.isGranted) {
      return true;
    } else {
      return true;
    }
  }

  Future<void> refreshData() async {
    await fetchLoggedInUserOrganization();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: const Text(
          'Regenerate QR Code',
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 15),
              const Text(
                'Get Location Wise QR Codes',
                style: TextStyle(
                  fontSize: 18,
                  color: Color.fromARGB(255, 125, 125, 124),
                  fontWeight: FontWeight.normal,
                ),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownButtonFormField2<int>(
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
                  value: selectedProjectId,
                  items: projects.isNotEmpty
                      ? projects.map<DropdownMenuItem<int>>((project) {
                          return DropdownMenuItem<int>(
                            value: project['projectId'],
                            child: Text(project['projectName']),
                          );
                        }).toList()
                      : [
                          const DropdownMenuItem<int>(
                            value: -1,
                            child: Text('No Projects Available'),
                          )
                        ],
                  onChanged: (int? newValue) {
                    setState(() {
                      selectedProjectId = newValue;
                    });
                    if (newValue != null && newValue != -1) {
                      fetchQRData(newValue);
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
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: qrData.length,
                  itemBuilder: (context, index) {
                    final qrInfo = qrData[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: const <TextSpan>[
                              TextSpan(
                                text: 'Location: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              // TextSpan(
                              //   text: '${qrInfo.projectName}',
                              // ),
                            ],
                          ),
                        ),
                        subtitle: RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: <TextSpan>[
                              // const TextSpan(
                              //   text: 'Location: ',
                              //   style: TextStyle(fontWeight: FontWeight.bold),
                              // ),
                              TextSpan(
                                text: '${qrInfo.location}',
                              ),
                            ],
                          ),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _showQRDialog(context, qrInfo),
                          child: const Text('Regenerate'),
                        ),
                      ),
                    );
                  },
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
