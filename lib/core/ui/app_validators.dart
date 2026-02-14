class AppValidators {
  static String? required(String? v, {String msg = 'Campo obrigatório'}) {
    if (v == null || v.trim().isEmpty) return msg;
    return null;
  }

  static String? minLen(String? v, int n, {String? msg}) {
    if (v == null) return msg ?? 'Mínimo de $n caracteres';
    if (v.trim().length < n) return msg ?? 'Mínimo de $n caracteres';
    return null;
  }

  static String? email(String? v, {String msg = 'E-mail inválido'}) {
    if (v == null || v.trim().isEmpty) return null;
    final r = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!r.hasMatch(v.trim())) return msg;
    return null;
  }

  static String? compose(String? v, List<String? Function(String?)> validators) {
    for (final fn in validators) {
      final res = fn(v);
      if (res != null) return res;
    }
    return null;
  }

  // ----- CPF / CNPJ -----
  static String? cpf(String? v, {String msg = 'CPF inválido'}) {
    if (v == null || v.trim().isEmpty) return null;
    final d = v.replaceAll(RegExp(r'\D'), '');
    if (d.length != 11) return msg;
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
