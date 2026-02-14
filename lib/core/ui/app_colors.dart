import 'package:flutter/material.dart';

class AppColors {
  // Troque aqui pelo seu “azul de marca”, se quiser.
  // Se você já tem paleta (tipo SIGORC/Sigfood etc), mete ela aqui.
  static const Color brand = Color(0xFF0C41FF);

  static ColorScheme lightScheme() => ColorScheme.fromSeed(
        seedColor: brand,
        brightness: Brightness.light,
      );

  static ColorScheme darkScheme() => ColorScheme.fromSeed(
        seedColor: brand,
        brightness: Brightness.dark,
      );
}
