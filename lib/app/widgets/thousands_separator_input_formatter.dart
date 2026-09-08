import 'package:flutter/services.dart';

/// Keeps a monetary amount grouped from the right: `200000000` becomes
/// `200 000 000`. Non-digit input is ignored and the caret stays beside the
/// same digit when editing in the middle of the amount.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  ThousandsSeparatorInputFormatter({this.maxDigits});
  final int? maxDigits;
  static int? parse(String text) =>
      int.tryParse(text.replaceAll(RegExp(r'\D'), ''));
  static String format(String text) =>
      _format(text.replaceAll(RegExp(r'\D'), ''));
  static final _nonDigits = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Pure cursor/selection move (arrow keys, tap) — the text is unchanged,
    // so leave the selection exactly as the platform placed it. Re-deriving
    // it from a digit count collapses the "before the space" / "after the
    // space" cursor positions into one, which makes left/right navigation
    // get stuck at the space between digit groups.
    if (newValue.text == oldValue.text) return newValue;

    final digits = newValue.text.replaceAll(_nonDigits, '');
    if (maxDigits != null && digits.length > maxDigits!) return oldValue;
    if (digits.isEmpty) {
      return const TextEditingValue(
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final baseDigitCount = _digitCountBefore(
      newValue.text,
      newValue.selection.baseOffset,
    );
    final extentDigitCount = _digitCountBefore(
      newValue.text,
      newValue.selection.extentOffset,
    );
    final formatted = _format(digits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: _offsetAfterDigits(formatted, baseDigitCount),
        extentOffset: _offsetAfterDigits(formatted, extentDigitCount),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
    );
  }

  int _digitCountBefore(String text, int rawOffset) {
    final offset = rawOffset.clamp(0, text.length);
    return text.substring(0, offset).replaceAll(_nonDigits, '').length;
  }

  static String _format(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  int _offsetAfterDigits(String formatted, int digitCount) {
    if (digitCount <= 0) return 0;

    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (formatted.codeUnitAt(i) != 0x20) {
        seen++;
        if (seen == digitCount) return i + 1;
      }
    }
    return formatted.length;
  }
}
