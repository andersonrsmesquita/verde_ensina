import 'dart:math';
import 'package:flutter/services.dart';

class AppFormatters {
  // Construtor privado para evitar instanciações acidentais (AppFormatters())
  AppFormatters._();

  /// Converte uma String de dinheiro para double.
  /// Blindado contra símbolos, letras e espaços (Ex: "R$ 1.234,56" vira 1234.56)
  static double parseMoney(String? v) {
    if (v == null || v.trim().isEmpty) return 0.0;
    
    // Remove tudo que não for dígito, vírgula ou sinal de menos
    String clean = v.replaceAll(RegExp(r'[^\d,-]'), '');
    
    // Troca a vírgula decimal pelo ponto do Dart
    clean = clean.replaceAll(',', '.');
    
    return double.tryParse(clean) ?? 0.0;
  }

  /// Formata centavos (Ex: 123456) para Moeda BR (Ex: "1.234,56")
  static String formatMoneyFromCents(int cents) {
    final value = cents / 100.0;
    final strValue = value.toStringAsFixed(2);
    final parts = strValue.split('.');
    
    final intPart = parts[0];
    final decPart = parts[1];
    
    // Regex elegante padrão da indústria para adicionar o ponto de milhar
    final regex = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final formattedInt = intPart.replaceAll(regex, '.');
    
    return '$formattedInt,$decPart';
  }
}

/// Máscara genérica inteligente que preserva a posição do cursor (Ex: CPF, CNPJ, CEP)
class AppMaskInputFormatter extends TextInputFormatter {
  final String mask;
  final String separator;

  AppMaskInputFormatter(this.mask, {this.separator = '#'});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final oldOffset = oldValue.selection.end;
    
    var out = '';
    var di = 0;
    
    // Constrói a nova string mascarada
    for (int i = 0; i < mask.length; i++) {
      if (di >= digits.length) break;
      if (mask[i] == separator) {
        out += digits[di];
        di++;
      } else {
        out += mask[i];
      }
    }

    // Lógica para manter o cursor no lugar correto caso o usuário edite no meio da string
    int newOffset = newValue.selection.end;
    if (oldValue.text.length < newValue.text.length) {
      // Se está digitando, o cursor avança pulando a máscara
      while (newOffset < out.length && mask[newOffset - 1] != separator) {
        newOffset++;
      }
    } else if (oldValue.text.length > newValue.text.length && oldOffset > 0) {
      // Se está apagando, garante que o cursor não se perca
      newOffset = max(0, newOffset);
    }

    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: min(newOffset, out.length)),
    );
  }
}

/// Máscara de Moeda BR (R$ digitado da direita pra esquerda)
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

    // Trava de segurança para não explodir o tamanho do int
    final trimmed = digits.length > maxDigits ? digits.substring(0, maxDigits) : digits;
    
    // tryParse no lugar de parse previne crashes caso a string venha corrompida
    final cents = int.tryParse(trimmed) ?? 0; 
    
    final formatted = AppFormatters.formatMoneyFromCents(cents);

    // Em campos de dinheiro onde se digita centavos primeiro, 
    // o cursor DEVE ficar travado no final. Aqui está correto!
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}