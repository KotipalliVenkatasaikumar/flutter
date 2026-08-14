import 'receipt_document.dart';

/// What came of a print attempt.
///
/// Never carries a platform error string: an operator at a barrier can act on
/// "the printer is out of paper" and cannot act on an exception, so the detail
/// stays in the log and the message stays plain.
class PrintResult {
  final bool ok;

  /// Shown to the operator. Empty when there is nothing worth saying.
  final String message;

  /// True when the job did not print but trying again might work — out of
  /// paper, cover open, printer busy. Drives whether a Retry is offered.
  final bool retryable;

  const PrintResult.success([this.message = ''])
      : ok = true,
        retryable = false;

  const PrintResult.failure(this.message, {this.retryable = true}) : ok = false;
}

/// Something that can put a receipt on paper.
///
/// The parking screens depend on this and never on a particular device, so the
/// Pine Labs terminal, a phone falling back to a PDF, and whatever replaces
/// either of them are interchangeable.
abstract class ParkingPrinter {
  /// For the settings screen and the logs — "Pine Labs terminal", "PDF".
  String get name;

  /// Whether this printer can be used on the hardware the app is running on.
  /// Called rarely and cached; it may go to the platform.
  Future<bool> isAvailable();

  Future<PrintResult> printDocument(ReceiptDocument document);
}
