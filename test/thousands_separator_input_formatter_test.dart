import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixleo/app/widgets/thousands_separator_input_formatter.dart';

void main() {
  final formatter = ThousandsSeparatorInputFormatter(maxDigits: 10);
  TextEditingValue value(String text, [int? cursor]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor ?? text.length),
  );

  test('groups typed and pasted amounts and parses raw integers', () {
    for (final entry in {
      '100000': '100 000',
      '1250000': '1 250 000',
      '2000000000': '2 000 000 000',
      '12 345 678': '12 345 678',
    }.entries) {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        value(entry.key),
      );
      expect(result.text, entry.value);
      expect(
        ThousandsSeparatorInputFormatter.parse(result.text),
        int.parse(entry.key.replaceAll(' ', '')),
      );
      expect(result.selection.baseOffset, result.text.length);
    }
  });
  test('formats initial values, clears input, and enforces digit limit', () {
    expect(ThousandsSeparatorInputFormatter.format('150000'), '150 000');
    expect(formatter.formatEditUpdate(value('100 000'), value('')).text, '');
    expect(ThousandsSeparatorInputFormatter.parse(''), isNull);
    expect(
      formatter.formatEditUpdate(value('1 000'), value('12345678901')).text,
      '1 000',
    );
  });
  test('preserves caret when editing in middle and moving across a space', () {
    final edited = formatter.formatEditUpdate(
      value('100 000', 1),
      value('1200 000', 2),
    );
    expect(edited.text, '1 200 000');
    expect(edited.selection.baseOffset, 3);
    expect(
      formatter
          .formatEditUpdate(value('100 000', 4), value('100 000', 3))
          .selection
          .baseOffset,
      3,
    );
    final deleted = formatter.formatEditUpdate(
      value('100 000', 2),
      value('10 000', 1),
    );
    expect(deleted.text, '10 000');
    expect(deleted.selection.baseOffset, 1);
  });
}
