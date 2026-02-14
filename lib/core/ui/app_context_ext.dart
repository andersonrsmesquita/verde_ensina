import 'package:flutter/material.dart';

import 'app_colors.dart'; // Importando nosso Design System de cores

extension AppContextExt on BuildContext {
  // ==========================================
  // 1. ATALHOS DE TEMA (THEME)
  // ==========================================
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => theme.colorScheme;
  TextTheme get text => theme.textTheme;

  // ==========================================
  // 2. ATALHOS DE TELA E MEDIDAS (RESPONSIVIDADE)
  // ==========================================
  
  // ⚠️ Padrão de Excelência: sizeOf() evita rebuilds desnecessários (ex: quando o teclado sobe)
  Size get _size => MediaQuery.sizeOf(this);

  double get screenWidth => _size.width;
  double get screenHeight => _size.height;

  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;
  bool get isDesktop => screenWidth >= 1024;

  EdgeInsets get pagePadding => EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 24.0,
        vertical: 16.0,
      );

  // ==========================================
  // 3. MENSAGENS E FEEDBACK (SNACKBARS)
  // ==========================================
  
  /// Exibe um SnackBar padronizado, arredondado e flutuante.
  void showSnack(
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    // maybeOf previne o crash se a tela for fechada antes do SnackBar aparecer
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;

    // Define a cor baseada no Design System (AppColors)
    Color bgColor = colors.inverseSurface; // Cor neutra padrão (cinza escuro/preto)
    if (isError) bgColor = AppColors.error;
    if (isSuccess) bgColor = AppColors.success;

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: bgColor,
          margin: const EdgeInsets.all(16), // Descola das bordas (efeito flutuante real)
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Bordas arredondadas (Material 3)
          ),
          duration: const Duration(seconds: 4),
        ),
      );
  }
}