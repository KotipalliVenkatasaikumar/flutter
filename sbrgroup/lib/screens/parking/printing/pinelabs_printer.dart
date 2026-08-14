import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'escpos_renderer.dart';
import 'parking_printer.dart';
import 'receipt_document.dart';

/// The printer built into the Pine Labs terminal.
///
/// The Dart side is complete: it renders the receipt to ESC/POS and hands the
/// bytes to the platform. What is not yet written is the Android side, because
/// the device and its integration kit are still to arrive — see
/// `android/app/src/main/kotlin/com/corenuts/ajna/ParkingPrinterPlugin.kt`.
///
/// Until that handler exists the channel answers with a missing-plugin error,
/// which is read here as "no terminal printer on this device" rather than as a
/// failure. That is what lets the same build run on an ordinary phone, where
/// [PdfReceiptPrinter] takes over.
///
/// When the kit lands, only the Kotlin side should need writing. If the SDK
/// turns out to want a formatted print job rather than raw bytes, the change
/// belongs in a new renderer next to [EscPosRenderer], still behind
/// [ParkingPrinter] — no parking screen should learn the difference.
class PineLabsPrinter implements ParkingPrinter {
  static const MethodChannel _channel =
      MethodChannel('com.corenuts.ajna/parking_printer');

  /// Bytes for a 58 mm roll, which is what these terminals carry.
  final EscPosRenderer _renderer = const EscPosRenderer(columns: 32);

  bool? _available;

  @override
  String get name => 'Pine Labs terminal';

  @override
  Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    try {
      final bool? result = await _channel.invokeMethod<bool>('isAvailable');
      _available = result ?? false;
    } on MissingPluginException {
      // no handler registered — an ordinary phone, or a build without the kit
      _available = false;
    } catch (e) {
      debugPrint('PineLabsPrinter.isAvailable error: $e');
      _available = false;
    }
    return _available!;
  }

  @override
  Future<PrintResult> printDocument(ReceiptDocument document) async {
    try {
      final Uint8List bytes = _renderer.render(document);
      final Map<Object?, Object?>? reply =
          await _channel.invokeMethod<Map<Object?, Object?>>('printBytes', {
        'bytes': bytes,
        'kind': document.kind,
        'reference': document.reference,
      });

      if (reply == null || reply['ok'] == true) {
        return const PrintResult.success();
      }

      // The platform side is expected to translate device status codes into
      // something an operator can act on; anything else gets the plain fallback.
      final String reason = (reply['message'] as String?)?.trim() ?? '';
      return PrintResult.failure(
        reason.isEmpty ? 'The printer did not respond. Try again.' : reason,
        retryable: reply['retryable'] != false,
      );
    } on MissingPluginException {
      _available = false;
      return const PrintResult.failure(
        'No printer on this device.',
        retryable: false,
      );
    } catch (e) {
      debugPrint('PineLabsPrinter.printDocument error: $e');
      return const PrintResult.failure('Could not print. Try again.');
    }
  }

  /// Forgets the cached answer — for a settings screen that lets an operator
  /// re-check after plugging something in.
  void reset() => _available = null;
}
