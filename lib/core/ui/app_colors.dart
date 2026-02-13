import 'package:flutter/material.dart';

/// Paleta central do app.
///
/// Mesmo usando ColorScheme/Theme, ter uma referência aqui evita
/// `Color(0xFF...)` espalhado pelo projeto.
class AppColors {
  AppColors._();

  // Brand (seed do tema)
  static const Color brand = Color(0xFF2E7D32);
  static const Color brandSoft = Color(0xFFE8F5E9);

  // Neutros
  static const Color text = Color(0xFF1B1B1B);
  static const Color muted = Color(0xFF6B6B6B);
  static const Color border = Color(0xFFE0E0E0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF6F6F6);

  // Feedback
  static const Color danger = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFF9A825);
  static const Color info = Color(0xFF1976D2);
}
