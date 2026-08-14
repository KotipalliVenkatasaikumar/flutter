import 'package:ajna/theme/app_colors.dart';
import 'package:flutter/material.dart';

import 'parking_printer.dart';
import 'receipt_document.dart';
import 'receipt_printing_service.dart';

/// Prints a receipt, and shows what became of it.
///
/// Built once and shared by entry and exit so the two behave the same way. The
/// rules it encodes are the ones a barrier queue needs:
///
/// On a terminal with a roll, the first copy prints on its own — nobody should
/// have to press a button per vehicle. On a phone, printing raises a share
/// sheet, so it waits to be asked.
///
/// A failed print is stated where the operator is already looking, with a way
/// to try again. It never blocks the screen: the vehicle is already admitted or
/// released by the time this runs, and paper must not hold up a barrier.
class ReceiptPrintButton extends StatefulWidget {
  /// Built lazily so the document is composed with whatever is on screen now.
  final ReceiptDocument Function() document;

  /// Wording for the first press — "Print ticket" or "Print receipt".
  final String label;

  const ReceiptPrintButton({
    Key? key,
    required this.document,
    required this.label,
  }) : super(key: key);

  @override
  State<ReceiptPrintButton> createState() => _ReceiptPrintButtonState();
}

class _ReceiptPrintButtonState extends State<ReceiptPrintButton> {
  bool _busy = false;
  bool _printed = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _autoPrint();
  }

  Future<void> _autoPrint() async {
    final bool hasRoll =
        await ReceiptPrintingService.instance.hasDevicePrinter();
    if (!hasRoll || !mounted) return;
    await _print();
  }

  Future<void> _print() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });

    // A second copy is marked DUPLICATE, so two receipts in a till can always
    // be told apart at cash-up.
    final ReceiptDocument document = widget.document();
    final PrintResult result = _printed
        ? await ReceiptPrintingService.instance.reprint(document)
        : await ReceiptPrintingService.instance.print(document);

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.ok) {
        _printed = true;
      } else {
        _error = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.print_disabled_outlined,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error,
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _print,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withOpacity(0.45)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : Icon(_printed ? Icons.copy_outlined : Icons.print_outlined),
            label: Text(
              _busy
                  ? 'Printing…'
                  : _printed
                      ? 'Print another copy'
                      : widget.label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
