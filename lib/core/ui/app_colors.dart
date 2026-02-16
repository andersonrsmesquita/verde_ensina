// FILE: lib/core/ui/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF2E7D32);
  static const Color secondary = Color(0xFF795548);
  static const Color tertiary = Color(0xFFF57F17);

  // Semantic
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFFBC02D);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF1976D2);

  // Shadow
  static const Color shadow = Color(0x14000000);

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color surfaceLight = Colors.white;

  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  static ColorScheme lightScheme() => ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        background: backgroundLight,
        surface: surfaceLight,
        error: error,
        brightness: Brightness.light,
      );

  static ColorScheme darkScheme() => ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        background: backgroundDark,
        surface: surfaceDark,
        error: error,
        brightness: Brightness.dark,
      );
}
