import 'package:flutter/services.dart';

class AppFormatters {
  static double? parseMoney(String? v) {
    if (v == null) return null;
    final s = v.trim();
    if (s.isEmpty) return null;
    final cleaned = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  static String formatMoneyFromCents(int cents) {
    final value = cents / 100.0;
    final s = value.toStringAsFixed(2).replaceAll('.', ',');
    // milhar simples
    final parts = s.split(',');
    final intPart = parts[0];
    final decPart = parts[1];
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final pos = intPart.length - i;
      buf.write(intPart[i]);
      if (pos > 1 && pos % 3 == 1) buf.write('.');
    }
    return '${buf.toString()},$decPart';
  }
}

/// Máscara simples tipo "(##) #####-####" usando # como dígito.
class AppMaskInputFormatter extends TextInputFormatter {
  final String mask;
  final String separator;

  AppMaskInputFormatter(this.mask, {this.separator = '#'});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    var out = '';
    var di = 0;

    for (int i = 0; i < mask.length; i++) {
      if (di >= digits.length) break;
      if (mask[i] == separator) {
        out += digits[di];
        di++;
      } else {
        out += mask[i];
      }
    }

    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}

/// Moeda BR (digita números e vira "1.234,56")
class BrMoneyInputFormatter extends TextInputFormatter {
  final int maxDigits;
  BrMoneyInputFormatter({this.maxDigits = 14});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final trimmed = digits.length > maxDigits ? digits.substring(0, maxDigits) : digits;
    final cents = int.parse(trimmed);
    final formatted = AppFormatters.formatMoneyFromCents(cents);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
