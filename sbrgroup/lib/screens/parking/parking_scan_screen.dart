import 'dart:io';

import 'package:ajna/screens/parking/parking_widgets.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

/// Scans a printed parking ticket and pops the scanned string back.
///
/// Exit is normally driven by scanning the ticket QR — the backend resolves it
/// by barcode first and falls back to the printed number, so whatever the
/// camera reads can be sent straight through as `credentialValue`.
class ParkingScanScreen extends StatefulWidget {
  const ParkingScanScreen({Key? key}) : super(key: key);

  @override
  State<ParkingScanScreen> createState() => _ParkingScanScreenState();
}

class _ParkingScanScreenState extends State<ParkingScanScreen> {
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'parkingQR');
  QRViewController? _controller;
  bool _handled = false;

  // Required by qr_code_scanner: the camera must be paused/resumed around a
  // hot reload on Android or the preview comes back black.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      _controller?.pauseCamera();
    }
    _controller?.resumeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onCreated(QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((scanData) {
      final String? code = scanData.code;
      // The stream keeps firing while the code is in frame — take the first
      // read only, otherwise we pop several times.
      if (_handled || code == null || code.trim().isEmpty) return;
      _handled = true;
      controller.pauseCamera();
      if (mounted) Navigator.pop(context, code.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final double cutOut = MediaQuery.of(context).size.width < 400 ? 220 : 280;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: parkingAppBar('Scan Ticket'),
      body: Stack(
        children: [
          QRView(
            key: _qrKey,
            onQRViewCreated: _onCreated,
            overlay: QrScannerOverlayShape(
              borderColor: AppColors.brandEmerald,
              borderRadius: 12,
              borderLength: 28,
              borderWidth: 8,
              cutOutSize: cutOut,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: Column(
              children: [
                const Text(
                  'Point the camera at the ticket QR',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.keyboard, color: Colors.white),
                  label: const Text('Enter number instead',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
