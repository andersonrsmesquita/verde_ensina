import 'package:flutter/material.dart';

/// Classe utilitária com validadores padrão para formulários.
/// Pode ser usada em conjunto com o `validator:` do TextFormField.
class AppValidators {
  // Impede a instanciação da classe.
  AppValidators._();

  // ==========================================
  // 1. VALIDADORES BÁSICOS
  // ==========================================

  static String? required(String? v, {String msg = 'Campo obrigatório'}) {
    if (v == null || v.trim().isEmpty) return msg;
    return null;
  }

  static String? minLen(String? v, int n, {String? msg}) {
    if (v == null || v.trim().isEmpty) return null; // Deixa o 'required' pegar campos vazios
    if (v.trim().length < n) return msg ?? 'Mínimo de $n caracteres';
    return null;
  }

  static String? email(String? v, {String msg = 'E-mail inválido'}) {
    if (v == null || v.trim().isEmpty) return null;
    // Regex robusta padrão W3C para validação de e-mails corporativos e normais
    final r = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    if (!r.hasMatch(v.trim())) return msg;
    return null;
  }

  // ==========================================
  // 2. VALIDADORES DE NEGÓCIO (AGRONOMIA / MATEMÁTICA)
  // ==========================================

  /// Garante que o texto digitado seja um número válido e maior que zero.
  /// Ideal para medidas de canteiro, volume de calda, custos, etc.
  static String? positiveNumber(String? v, {String msg = 'Informe um valor maior que zero'}) {
    if (v == null || v.trim().isEmpty) return null;
    
    // Limpa a string caso venha formatada (Ex: 1.234,56 -> 1234.56)
    final cleaned = v.replaceAll('.', '').replaceAll(',', '.');
    final number = double.tryParse(cleaned);
    
    if (number == null || number <= 0) return msg;
    return null;
  }

  // ==========================================
  // 3. COMPOSIÇÃO DE VALIDADORES
  // ==========================================

  /// Executa uma lista de validadores em ordem. O primeiro a falhar retorna o erro.
  static String? compose(String? v, List<String? Function(String?)> validators) {
    for (final fn in validators) {
      final res = fn(v);
      if (res != null) return res;
    }
    return null;
  }

  // ==========================================
  // 4. DOCUMENTOS BRASILEIROS
  // ==========================================

  /// Validador Inteligente: Descobre se é CPF ou CNPJ pelo tamanho e valida.
  static String? cpfOrCnpj(String? v, {String msg = 'Documento inválido'}) {
    if (v == null || v.trim().isEmpty) return null;
    final d = v.replaceAll(RegExp(r'\D'), '');
    
    if (d.length == 11) return cpf(v, msg: msg);
    if (d.length == 14) return cnpj(v, msg: msg);
    
    return msg; // Se não tem nem 11 nem 14 dígitos, é inválido.
  }

  static String? cpf(String? v, {String msg = 'CPF inválido'}) {
    if (v == null || v.trim().isEmpty) return null;
    final d = v.replaceAll(RegExp(r'\D'), '');
    
    if (d.length != 11) return msg;
    
    // Rejeita CPFs com todos os números iguais (Ex: 111.111.111-11)
    if (RegExp(r'^(\d)\1{10}$').hasMatch(d)) return msg;

    int calc(int len) {
      int sum = 0;
      int w = len + 1;
      for (int i = 0; i < len; i++) {
        sum += int.parse(d[i]) * (w - i);
      }
      final mod = (sum * 10) % 11;
      return mod == 10 ? 0 : mod;
    }

    final d1 = calc(9);
    final d2 = calc(10);
    if (d1 != int.parse(d[9]) || d2 != int.parse(d[10])) return msg;
    return null;
  }

  static String? cnpj(String? v, {String msg = 'CNPJ inválido'}) {
    if (v == null || v.trim().isEmpty) return null;
    final d = v.replaceAll(RegExp(r'\D'), '');
    
    if (d.length != 14) return msg;
    
    // Rejeita CNPJs com todos os números iguais
    if (RegExp(r'^(\d)\1{13}$').hasMatch(d)) return msg;

    int calc(List<int> weights) {
      int sum = 0;
      for (int i = 0; i < weights.length; i++) {
        sum += int.parse(d[i]) * weights[i];
      }
      final mod = sum % 11;
      return mod < 2 ? 0 : 11 - mod;
    }

    final w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    final w2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

    final d1 = calc(w1);
    final d2 = calc(w2);

    if (d1 != int.parse(d[12]) || d2 != int.parse(d[13])) return msg;
    return null;
  }
}