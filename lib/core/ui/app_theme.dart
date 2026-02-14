import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

class AppTheme {
  static ThemeData light() => _build(AppColors.lightScheme());
  static ThemeData dark() => _build(AppColors.darkScheme());

  static ThemeData _build(ColorScheme cs) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      brightness: cs.brightness,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.rMd),
      borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.55), width: 1),
    );

    return base.copyWith(
      scaffoldBackgroundColor: cs.surface,

      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rLg),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.35)),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withOpacity(0.40),
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: 14),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: cs.primary, width: 1.2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: cs.error, width: 1.2),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: cs.error, width: 1.2),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppTokens.btnHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppTokens.btnHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(AppTokens.btnHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
