import 'package:flutter/foundation.dart';

import 'parking_printer.dart';
import 'pdf_receipt_printer.dart';
import 'pinelabs_printer.dart';
import 'receipt_document.dart';

/// The single way the parking screens print anything.
///
/// It picks the printer once and remembers it: the terminal's built-in roll
/// when the app is running on one, a PDF anywhere else. A screen asks for a
/// document to be printed and is told plainly whether it worked — which printer
/// did it is not a screen's business.
class ReceiptPrintingService {
  ReceiptPrintingService._();

  static final ReceiptPrintingService instance = ReceiptPrintingService._();

  final PineLabsPrinter _terminal = PineLabsPrinter();
  final PdfReceiptPrinter _fallback = PdfReceiptPrinter();

  ParkingPrinter? _chosen;

  /// True when there is a real roll to print on, so a screen can print without
  /// asking first. On a phone, printing raises a share sheet — fine when the
  /// operator asked for it, wrong to raise unprompted after every vehicle.
  Future<bool> hasDevicePrinter() => _terminal.isAvailable();

  Future<ParkingPrinter> _printer() async {
    final ParkingPrinter? chosen = _chosen;
    if (chosen != null) return chosen;
    final ParkingPrinter picked =
        await _terminal.isAvailable() ? _terminal : _fallback;
    _chosen = picked;
    debugPrint('Parking receipts will print via ${picked.name}');
    return picked;
  }

  /// Prints, and says what happened. Never throws: a barrier queue is no place
  /// for an unhandled error, and a receipt that failed to print is a smaller
  /// problem than a released vehicle whose exit was never recorded.
  Future<PrintResult> print(ReceiptDocument document) async {
    try {
      final printer = await _printer();
      final result = await printer.printDocument(document);
      if (!result.ok) {
        debugPrint('Print failed on ${printer.name}: ${result.message}');
      }
      return result;
    } catch (e) {
      debugPrint('ReceiptPrintingService.print error: $e');
      return const PrintResult.failure('Could not print. Try again.');
    }
  }

  /// Prints the same document again, marked so the copy cannot be mistaken for
  /// the original at cash-up.
  Future<PrintResult> reprint(ReceiptDocument document) => print(
        ReceiptDocument(
          kind: document.kind,
          reference: document.reference,
          lines: document.lines,
          isReprint: true,
        ),
      );

  /// Re-checks the hardware — for a settings screen, or after a device swap.
  void reset() {
    _chosen = null;
    _terminal.reset();
  }
}
