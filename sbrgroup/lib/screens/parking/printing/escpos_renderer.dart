import 'dart:convert';
import 'dart:typed_data';

import 'receipt_document.dart';

/// Renders a [ReceiptDocument] to ESC/POS, the command set every thermal roll
/// printer in this class of device understands.
///
/// Written by hand rather than pulled from a package because the command set we
/// need is small and fixed, and because a printer that ships with a vendor SDK
/// usually wants the bytes handed to it rather than a socket opened — a package
/// built around network printers would be carried for the encoder alone.
class EscPosRenderer {
  /// Characters per line at Font A. 32 for a 58 mm roll, 48 for 80 mm.
  final int columns;

  const EscPosRenderer({this.columns = 32});

  static const int _esc = 0x1B;
  static const int _gs = 0x1D;

  Uint8List render(ReceiptDocument doc) {
    final out = BytesBuilder();

    out.add([_esc, 0x40]); // initialise — clears whatever the last job left set

    if (doc.isReprint) {
      _align(out, 1);
      _bold(out, true);
      _text(out, '*** DUPLICATE ***');
      _bold(out, false);
      _feed(out, 1);
    }

    for (final line in doc.lines) {
      _renderLine(out, line);
    }

    // Feed clear of the tear bar before cutting, or the last line is cut
    // through. Four lines is the usual gap on a 58 mm mechanism.
    _feed(out, 4);
    out.add([_gs, 0x56, 0x42, 0x00]); // partial cut

    return out.toBytes();
  }

  void _renderLine(BytesBuilder out, ReceiptLine line) {
    switch (line.kind) {
      case ReceiptLineKind.title:
        _align(out, 1);
        _size(out, width: 2, height: 2);
        _bold(out, true);
        // at double width the roll holds half as many characters
        _text(out, _clip(line.value, columns ~/ 2));
        _bold(out, false);
        _size(out, width: 1, height: 1);
        break;

      case ReceiptLineKind.subtitle:
        _align(out, 1);
        _text(out, _clip(line.value, columns));
        break;

      case ReceiptLineKind.reference:
        _align(out, 1);
        _size(out, width: 2, height: 2);
        _bold(out, true);
        _text(out, _clip(line.value, columns ~/ 2));
        _bold(out, false);
        _size(out, width: 1, height: 1);
        break;

      case ReceiptLineKind.keyValue:
        _align(out, 0);
        _text(out, _spread(line.label, line.value));
        break;

      case ReceiptLineKind.emphasis:
        _align(out, 0);
        _bold(out, true);
        _text(out, _spread(line.label, line.value));
        _bold(out, false);
        break;

      case ReceiptLineKind.centred:
        _align(out, 1);
        for (final part in _wrap(line.value, columns)) {
          _text(out, part);
        }
        break;

      case ReceiptLineKind.text:
        _align(out, 0);
        for (final part in _wrap(line.value, columns)) {
          _text(out, part);
        }
        break;

      case ReceiptLineKind.divider:
        _align(out, 0);
        _text(out, '-' * columns);
        break;

      case ReceiptLineKind.blank:
        _feed(out, 1);
        break;

      case ReceiptLineKind.barcode:
        _align(out, 1);
        _qr(out, line.value);
        break;
    }
  }

  // ---- ESC/POS primitives

  void _align(BytesBuilder out, int mode) => out.add([_esc, 0x61, mode]);

  void _bold(BytesBuilder out, bool on) => out.add([_esc, 0x45, on ? 1 : 0]);

  void _feed(BytesBuilder out, int lines) => out.add([_esc, 0x64, lines]);

  void _size(BytesBuilder out, {required int width, required int height}) =>
      out.add([_gs, 0x21, ((width - 1) << 4) | (height - 1)]);

  void _text(BytesBuilder out, String value) {
    out.add(_encode(value));
    out.add([0x0A]);
  }

  /// QR rather than a 1D barcode, because the exit flow reads tickets with the
  /// app's own QR scanner — a CODE128 strip would print perfectly well and then
  /// not be read by the one thing that has to read it.
  void _qr(BytesBuilder out, String data) {
    final bytes = _encode(data);

    // model 2
    out.add([_gs, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);
    // module size — 6 dots keeps a ticket number readable on a 58 mm roll
    out.add([_gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06]);
    // error correction M: enough to survive a thumbprint or a fold
    out.add([_gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);

    // store: the length covers the three bytes of the sub-command as well
    final int length = bytes.length + 3;
    out.add([
      _gs,
      0x28,
      0x6B,
      length & 0xFF,
      (length >> 8) & 0xFF,
      0x31,
      0x50,
      0x30,
    ]);
    out.add(bytes);

    // print what was stored
    out.add([_gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
    out.add([0x0A]);
  }

  // ---- text fitting

  /// "Label ......... value" across the roll. When the pair cannot fit, the
  /// label gives way — a truncated amount would be worse than a truncated word.
  String _spread(String label, String value) {
    final l = _ascii(label);
    final v = _ascii(value);
    if (l.isEmpty) return _clip(v, columns);
    if (l.length + v.length + 1 > columns) {
      final room = columns - v.length - 1;
      return room <= 0 ? _clip(v, columns) : '${_clip(l, room)} $v';
    }
    return l + ' ' * (columns - l.length - v.length) + v;
  }

  List<String> _wrap(String value, int width) {
    final words = _ascii(value).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      if (current.isEmpty) {
        current = word;
      } else if (current.length + 1 + word.length <= width) {
        current = '$current $word';
      } else {
        lines.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? [''] : lines;
  }

  String _clip(String value, int width) {
    final v = _ascii(value);
    return v.length <= width ? v : v.substring(0, width);
  }

  /// These printers carry a single-byte code page. Anything outside it prints as
  /// a stray glyph or nothing at all, so the few characters the app actually
  /// produces are mapped and the rest are dropped.
  String _ascii(String value) => value
      .replaceAll('₹', 'Rs.') // ₹
      .replaceAll('—', '-') // —
      .replaceAll('–', '-') // –
      .replaceAll('‘', "'")
      .replaceAll('’', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '');

  Uint8List _encode(String value) =>
      Uint8List.fromList(ascii.encode(_ascii(value)));
}
