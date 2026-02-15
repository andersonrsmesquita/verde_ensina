import 'package:flutter/material.dart';

typedef FieldValidator = String? Function(String? value);

/// Validações padronizadas do app.
/// Padrão Excelência:
/// - Cada método retorna um "validator function" (pra usar direto no TextFormField)
/// - compose() combina vários validators em um só
class AppValidators {
  AppValidators._();

  // ==========================
  // COMPOSIÇÃO
  // ==========================
  static FormFieldValidator<String> compose(List<FieldValidator> validators) {
    return (value) {
      for (final v in validators) {
        final err = v(value);
        if (err != null) return err;
      }
      return null;
    };
  }

  // ==========================
  // BÁSICOS
  // ==========================
  static FieldValidator required([String msg = 'Campo obrigatório.']) {
    return (v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return msg;
      return null;
    };
  }

  static FieldValidator minLen(int min, [String? msg]) {
    return (v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return null; // deixa o required cuidar do vazio
      if (t.length < min) return msg ?? 'Mínimo $min caracteres.';
      return null;
    };
  }

  static FieldValidator email([String msg = 'E-mail inválido.']) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return (v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return null;
      if (!re.hasMatch(t)) return msg;
      return null;
    };
  }

  static FieldValidator positiveNumber(
      [String msg = 'Informe um valor válido.']) {
    return (v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return null;
      final n = double.tryParse(t.replaceAll(',', '.'));
      if (n == null || n <= 0) return msg;
      return null;
    };
  }

  // ==========================
  // CPF/CNPJ (mantive sua lógica robusta)
  // ==========================
  static FieldValidator cpf([String msg = 'CPF inválido.']) {
    return (v) => _cpfValue(v, msg: msg);
  }

  static FieldValidator cnpj([String msg = 'CNPJ inválido.']) {
    return (v) => _cnpjValue(v, msg: msg);
  }

  static FieldValidator cpfOrCnpj([String msg = 'CPF/CNPJ inválido.']) {
    return (v) => _cpfOrCnpjValue(v, msg: msg);
  }

  static String _onlyDigits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  static String? _cpfOrCnpjValue(String? v, {required String msg}) {
    final digits = _onlyDigits((v ?? '').trim());
    if (digits.isEmpty) return null;

    if (digits.length == 11) return _cpfValue(digits, msg: msg);
    if (digits.length == 14) return _cnpjValue(digits, msg: msg);
    return msg;
  }

  static String? _cpfValue(String? v, {required String msg}) {
    final digits = _onlyDigits((v ?? '').trim());
    if (digits.isEmpty) return null;
    if (digits.length != 11) return msg;

    // evita sequência repetida
    if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return msg;

    int calcDigit(String base, List<int> weights) {
      var sum = 0;
      for (var i = 0; i < weights.length; i++) {
        sum += int.parse(base[i]) * weights[i];
      }
      final mod = sum % 11;
      return mod < 2 ? 0 : 11 - mod;
    }

    final d1 = calcDigit(digits.substring(0, 9), [10, 9, 8, 7, 6, 5, 4, 3, 2]);
    final d2 = calcDigit(
        '${digits.substring(0, 9)}$d1', [11, 10, 9, 8, 7, 6, 5, 4, 3, 2]);

    if (digits.endsWith('$d1$d2')) return null;
    return msg;
  }

  static String? _cnpjValue(String? v, {required String msg}) {
    final digits = _onlyDigits((v ?? '').trim());
    if (digits.isEmpty) return null;
    if (digits.length != 14) return msg;

    if (RegExp(r'^(\d)\1{13}$').hasMatch(digits)) return msg;

    int calcDigit(String base, List<int> weights) {
      var sum = 0;
      for (var i = 0; i < weights.length; i++) {
        sum += int.parse(base[i]) * weights[i];
      }
      final mod = sum % 11;
      return mod < 2 ? 0 : 11 - mod;
    }

    final d1 = calcDigit(
        digits.substring(0, 12), [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
    final d2 = calcDigit('${digits.substring(0, 12)}$d1',
        [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);

    if (digits.endsWith('$d1$d2')) return null;
    return msg;
  }
}
