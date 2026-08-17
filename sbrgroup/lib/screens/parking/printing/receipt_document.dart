import 'package:intl/intl.dart';

import '../parking_models.dart';

/// What a printed line is, independent of how any particular printer draws it.
///
/// Deliberately not Flutter widgets and not printer bytes: the same document is
/// rendered to a thermal roll on the terminal, to a PDF on a phone, and to a
/// preview on screen. Adding a printer later means adding a renderer, not
/// touching the receipt.
enum ReceiptLineKind {
  /// Centred, double height — the site name at the top of the roll.
  title,

  /// Centred, small — the address line under the title.
  subtitle,

  /// Centred, bold, boxed by the renderer if it can — the ticket number.
  reference,

  /// Label on the left, value on the right, dot-filled between.
  keyValue,

  /// Same, but printed bold — the amount actually collected.
  emphasis,

  /// Centred free text.
  centred,

  /// Left-aligned free text, wrapped by the renderer.
  text,

  /// A rule across the roll.
  divider,

  /// One blank line.
  blank,

  /// A scannable code carrying [ReceiptLine.value].
  barcode,
}

class ReceiptLine {
  final ReceiptLineKind kind;
  final String label;
  final String value;

  const ReceiptLine(this.kind, {this.label = '', this.value = ''});

  const ReceiptLine.divider() : this(ReceiptLineKind.divider);
  const ReceiptLine.blank() : this(ReceiptLineKind.blank);
}

/// One thing to print, start to finish.
class ReceiptDocument {
  /// ENTRY_TICKET or EXIT_RECEIPT — carried so the printer can be told what it
  /// is printing, and so a reprint can be labelled in the movement log.
  final String kind;

  /// The number a person would quote when asking about this piece of paper.
  final String reference;

  final List<ReceiptLine> lines;

  /// A reprint is marked on the paper itself. Two identical receipts in a till
  /// at cash-up is a dispute; one marked DUPLICATE is a reprint.
  final bool isReprint;

  const ReceiptDocument({
    required this.kind,
    required this.reference,
    required this.lines,
    this.isReprint = false,
  });

  static const String entryTicket = 'ENTRY_TICKET';
  static const String exitReceipt = 'EXIT_RECEIPT';

  bool get isEntryTicket => kind == entryTicket;
}

/// Turns what the server said into what the paper says.
///
/// The server already returns everything a receipt needs — the amounts, the tax
/// split, the GSTIN — so nothing here is calculated. Anything printed that the
/// server did not send would be a second source of truth for money, which is
/// how a till and a report end up disagreeing.
class ParkingReceiptBuilder {
  ParkingReceiptBuilder._();

  static final DateFormat _stamp = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _short = DateFormat('dd/MM/yy HH:mm');

  /// Rupees for a thermal roll. The rupee sign is not in the character sets
  /// these printers ship with, so it prints as "Rs." rather than as a blank or
  /// a stray glyph.
  static String amount(double? value) => 'Rs.${(value ?? 0).toStringAsFixed(2)}';

  static String _duration(int? minutes) {
    if (minutes == null) return '-';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h == 0 ? '${m}m' : '${h}h ${m}m';
  }

  static String _label(String? code) => ParkingConstants.label(code);

  /// The ticket handed to the driver on the way in.
  ///
  /// The barcode is the point of it: exit looks a stay up by scanning this, so
  /// a ticket that prints without one costs the driver a manual plate search at
  /// the barrier.
  static ReceiptDocument entryTicket(
    SessionEntryResponse r, {
    String? siteName,
    String? laneName,
    String? operatorName,
    bool isReprint = false,
  }) {
    final lines = <ReceiptLine>[
      ReceiptLine(ReceiptLineKind.title, value: siteName ?? 'PARKING'),
      const ReceiptLine(ReceiptLineKind.subtitle, value: 'ENTRY TICKET'),
      const ReceiptLine.divider(),
      ReceiptLine(ReceiptLineKind.reference, value: r.ticketNumber ?? '-'),
      const ReceiptLine.blank(),
      ReceiptLine(ReceiptLineKind.keyValue,
          label: 'Vehicle', value: r.displayPlateNumber ?? r.plateNumber ?? '-'),
      ReceiptLine(ReceiptLineKind.keyValue,
          label: 'Type', value: _label(r.vehicleType)),
      ReceiptLine(ReceiptLineKind.keyValue,
          label: 'Category', value: _label(r.sessionType)),
      ReceiptLine(ReceiptLineKind.keyValue,
          label: 'Entry',
          value: r.entryTime == null ? '-' : _stamp.format(r.entryTime!)),
      if ((r.zoneName ?? '').isNotEmpty)
        ReceiptLine(ReceiptLineKind.keyValue,
            label: 'Level', value: r.zoneName!),
      if ((laneName ?? '').isNotEmpty)
        ReceiptLine(ReceiptLineKind.keyValue, label: 'Lane', value: laneName!),
      if ((operatorName ?? '').isNotEmpty)
        ReceiptLine(ReceiptLineKind.keyValue,
            label: 'Issued by', value: operatorName!),
    ];

    if ((r.barcodeValue ?? '').isNotEmpty) {
      lines
        ..add(const ReceiptLine.blank())
        ..add(ReceiptLine(ReceiptLineKind.barcode, value: r.barcodeValue!));
    }

    lines
      ..add(const ReceiptLine.divider())
      ..add(const ReceiptLine(ReceiptLineKind.centred,
          value: 'Keep this ticket safe'))
      ..add(const ReceiptLine(ReceiptLineKind.centred,
          value: 'A lost ticket is charged at the lost-ticket rate'))
      ..add(const ReceiptLine(ReceiptLineKind.centred,
          value: 'Park at owner\'s risk'));

    return ReceiptDocument(
      kind: ReceiptDocument.entryTicket,
      reference: r.ticketNumber ?? '',
      lines: lines,
      isReprint: isReprint,
    );
  }

  /// The receipt handed over once the vehicle is paid for and released.
  static ReceiptDocument exitReceipt(
    ExitConfirmResponse r, {
    String? laneName,
    String? operatorName,
    bool isReprint = false,
  }) {
    final lines = <ReceiptLine>[
      ReceiptLine(ReceiptLineKind.title, value: r.siteName ?? 'PARKING'),
      const ReceiptLine(ReceiptLineKind.subtitle, value: 'PARKING RECEIPT'),
      if ((r.gstin ?? '').isNotEmpty)
        ReceiptLine(ReceiptLineKind.subtitle, value: 'GSTIN: ${r.gstin}'),
      const ReceiptLine.divider(),
      ReceiptLine(ReceiptLineKind.reference, value: r.receiptNumber ?? '-'),
      const ReceiptLine.blank(),
      ReceiptLine(ReceiptLineKind.keyValue,
          label: 'Vehicle', value: r.plateNumber ?? '-'),
      ReceiptLine(ReceiptLineKind.keyValue,
          label: 'Ticket', value: r.ticketNumber ?? '-'),
      ReceiptLine(ReceiptLineKind.keyValue,
          label: 'In',
          value: r.entryTime == null ? '-' : _short.format(r.entryTime!)),
      ReceiptLine(ReceiptLineKind.keyValue,
          label: 'Out',
          value: r.exitTime == null ? '-' : _short.format(r.exitTime!)),
      ReceiptLine(ReceiptLineKind.keyValue,
          label: 'Duration', value: _duration(r.durationMinutes)),
      const ReceiptLine.divider(),
    ];

    // The tax split is printed only when there is tax, because a zero-tax line
    // on a receipt invites the question of why it is there.
    if ((r.taxableAmount ?? 0) > 0 && (r.taxAmount ?? 0) > 0) {
      lines
        ..add(ReceiptLine(ReceiptLineKind.keyValue,
            label: 'Taxable', value: amount(r.taxableAmount)))
        ..add(ReceiptLine(ReceiptLineKind.keyValue,
            label: 'Tax', value: amount(r.taxAmount)));
    }
    if ((r.waivedAmount ?? 0) > 0) {
      lines.add(ReceiptLine(ReceiptLineKind.keyValue,
          label: 'Waived', value: amount(r.waivedAmount)));
    }

    lines.add(ReceiptLine(ReceiptLineKind.emphasis,
        label: 'PAID', value: amount(r.netAmount)));
    lines.add(ReceiptLine(ReceiptLineKind.keyValue,
        label: 'Mode', value: _label(r.paymentMode)));

    if ((r.tenderedAmount ?? 0) > 0) {
      lines.add(ReceiptLine(ReceiptLineKind.keyValue,
          label: 'Tendered', value: amount(r.tenderedAmount)));
    }
    if ((r.changeAmount ?? 0) > 0) {
      lines.add(ReceiptLine(ReceiptLineKind.emphasis,
          label: 'CHANGE', value: amount(r.changeAmount)));
    }

    if ((laneName ?? '').isNotEmpty || (operatorName ?? '').isNotEmpty) {
      lines.add(const ReceiptLine.divider());
      if ((laneName ?? '').isNotEmpty) {
        lines.add(ReceiptLine(ReceiptLineKind.keyValue,
            label: 'Lane', value: laneName!));
      }
      if ((operatorName ?? '').isNotEmpty) {
        lines.add(ReceiptLine(ReceiptLineKind.keyValue,
            label: 'Operator', value: operatorName!));
      }
    }

    lines.add(const ReceiptLine.divider());
    if (r.exitGraceMinutes != null) {
      lines.add(ReceiptLine(ReceiptLineKind.centred,
          value: 'Please exit within ${r.exitGraceMinutes} minutes'));
    }
    lines.add(const ReceiptLine(ReceiptLineKind.centred, value: 'Thank you'));

    return ReceiptDocument(
      kind: ReceiptDocument.exitReceipt,
      reference: r.receiptNumber ?? '',
      lines: lines,
      isReprint: isReprint,
    );
  }
}
