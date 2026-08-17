import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'parking_printer.dart';
import 'receipt_document.dart';

/// The receipt as a PDF, handed to whatever the phone can print or share with.
///
/// Two jobs. It is the fallback wherever there is no terminal printer — a
/// supervisor on their own phone can still produce a receipt. And it is how the
/// layout can be proved right before the terminal arrives: the page is a 58 mm
/// roll, so what appears here is what the paper will say.
class PdfReceiptPrinter implements ParkingPrinter {
  /// 58 mm roll. PdfPageFormat works in points — 1 mm is 72/25.4 of one.
  static const double _rollWidth = 58 * PdfPageFormat.mm;

  @override
  String get name => 'PDF';

  /// Always available: every platform this app runs on can share a file.
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<PrintResult> printDocument(ReceiptDocument document) async {
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(
            _rollWidth,
            double.infinity,
            marginAll: 4 * PdfPageFormat.mm,
          ),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (document.isReprint) ...[
                pw.Center(
                  child: pw.Text('*** DUPLICATE ***',
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 4),
              ],
              ...document.lines.map(_line),
            ],
          ),
        ),
      );

      final bytes = await doc.save();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: _fileName(document),
      );
      return const PrintResult.success();
    } catch (e) {
      debugPrint('PdfReceiptPrinter.printDocument error: $e');
      return const PrintResult.failure('Could not produce the receipt.');
    }
  }

  String _fileName(ReceiptDocument document) {
    final String prefix =
        document.isEntryTicket ? 'parking_ticket' : 'parking_receipt';
    final String reference =
        document.reference.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return reference.isEmpty ? prefix : '${prefix}_$reference';
  }

  pw.Widget _line(ReceiptLine line) {
    switch (line.kind) {
      case ReceiptLineKind.title:
        return pw.Center(
          child: pw.Text(line.value,
              textAlign: pw.TextAlign.center,
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        );

      case ReceiptLineKind.subtitle:
        return pw.Center(
          child: pw.Text(line.value,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8)),
        );

      case ReceiptLineKind.reference:
        return pw.Center(
          child: pw.Text(line.value,
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        );

      case ReceiptLineKind.keyValue:
        return _pair(line, bold: false);

      case ReceiptLineKind.emphasis:
        return _pair(line, bold: true);

      case ReceiptLineKind.centred:
        return pw.Center(
          child: pw.Text(line.value,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 7.5)),
        );

      case ReceiptLineKind.text:
        return pw.Text(line.value, style: const pw.TextStyle(fontSize: 8));

      case ReceiptLineKind.divider:
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Divider(height: 0.5, thickness: 0.5),
        );

      case ReceiptLineKind.blank:
        return pw.SizedBox(height: 5);

      case ReceiptLineKind.barcode:
        return pw.Center(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: line.value,
              width: 90,
              height: 90,
              drawText: false,
            ),
          ),
        );
    }
  }

  pw.Widget _pair(ReceiptLine line, {required bool bold}) {
    final style = pw.TextStyle(
      fontSize: 8.5,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(line.label, style: style),
          pw.Flexible(
            child: pw.Text(line.value,
                textAlign: pw.TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}
