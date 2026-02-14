import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// Define e injeta a identidade visual do aplicativo.
/// Configura o Material 3 com todos os padrões de botões, inputs, cards e fontes.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.lightScheme());
  static ThemeData dark() => _build(AppColors.darkScheme());

  static ThemeData _build(ColorScheme cs) {
    // A base inicializa o Material 3 e define a cor principal.
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      brightness: cs.brightness,
    );

    // ==========================================
    // 1. INPUTS (CAMPOS DE TEXTO)
    // ==========================================
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.rMd),
      borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.55), width: 1),
    );

    return base.copyWith(
      // Puxa o fundo correto (claro ou escuro) do Design System
      scaffoldBackgroundColor: cs.background,

      // ==========================================
      // 2. TIPOGRAFIA E TEXTOS
      // ==========================================
      textTheme: base.textTheme.copyWith(
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: cs.onBackground,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(color: cs.onBackground),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: cs.onBackground),
      ),

      // ==========================================
      // 3. APP BAR (CABEÇALHOS)
      // ==========================================
      appBarTheme: AppBarTheme(
        backgroundColor: cs.primary, // Define a AppBar com a cor da marca
        foregroundColor: cs.onPrimary, // Define os ícones e textos da AppBar (Geralmente branco)
        elevation: 0,
        centerTitle: true,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: cs.onPrimary,
        ),
      ),

      // ==========================================
      // 4. CARDS (MODERNIDADE E PROFUNDIDADE)
      // ==========================================
      cardTheme: CardThemeData(
        elevation: 1, // Leve profundidade
        shadowColor: Colors.black.withOpacity(0.15),
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rLg),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.35)),
        ),
        margin: EdgeInsets.zero,
      ),

      // ==========================================
      // 5. DIVISORES
      // ==========================================
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withOpacity(0.40),
        thickness: 1,
        space: 1,
      ),

      // ==========================================
      // 6. FORMULÁRIOS
      // ==========================================
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true, // Fundos leves em inputs ajudam a destacar
        fillColor: cs.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: 16),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: cs.error, width: 1.2),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        labelStyle: TextStyle(color: cs.onSurfaceVariant),
      ),

      // ==========================================
      // 7. BOTÕES (UNIFORMIDADE)
      // ==========================================
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppTokens.btnHeight),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          elevation: 2,
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
          side: BorderSide(color: cs.primary, width: 1.2),
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