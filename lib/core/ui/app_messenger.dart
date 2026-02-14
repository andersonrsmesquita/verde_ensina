import 'package:flutter/material.dart';
import 'app_colors.dart'; // Importa nosso Design System

class AppMessenger {
  // Construtor privado
  AppMessenger._();

  /// Use no MaterialApp: scaffoldMessengerKey: AppMessenger.key
  static final GlobalKey<ScaffoldMessengerState> key =
      GlobalKey<ScaffoldMessengerState>();

  static void _show(
    String message, {
    required Color backgroundColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 4), // Aumentado para dar tempo de ler
    SnackBarAction? action, // Suporte a botões como "DESFAZER"
  }) {
    final messenger = key.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 24), // Descola bem do fundo e laterais
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: duration,
        backgroundColor: backgroundColor,
        elevation: 6, // Sombra suave (Material 3)
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: action,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void success(String message, {SnackBarAction? action}) {
    _show(
      message,
      backgroundColor: AppColors.success, // Puxando do Design System
      icon: Icons.check_circle_outline,
      action: action,
    );
  }

  static void info(String message, {SnackBarAction? action}) {
    _show(
      message,
      backgroundColor: AppColors.info,
      icon: Icons.info_outline,
      action: action,
    );
  }

  static void warn(String message, {SnackBarAction? action}) {
    _show(
      message,
      backgroundColor: AppColors.warning,
      icon: Icons.warning_amber_outlined,
      action: action,
    );
  }

  static void error(String message, {SnackBarAction? action}) {
    _show(
      message,
      backgroundColor: AppColors.error,
      icon: Icons.error_outline,
      action: action,
    );
  }

  /// Compatibilidade com telas antigas e Heurística Inteligente
  /// Remove os emojis do texto para não duplicar com os ícones reais
  static void show(String message, {SnackBarAction? action}) {
    final trimmed = message.trimLeft();

    if (trimmed.startsWith('✅')) {
      final cleanMsg = trimmed.replaceFirst('✅', '').trim();
      return success(cleanMsg, action: action);
    }
    if (trimmed.startsWith('⚠️') || trimmed.startsWith('⚠')) {
      final cleanMsg = trimmed.replaceFirst(RegExp(r'⚠️|⚠'), '').trim();
      return warn(cleanMsg, action: action);
    }
    if (trimmed.startsWith('❌')) {
      final cleanMsg = trimmed.replaceFirst('❌', '').trim();
      return error(cleanMsg, action: action);
    }

    return info(message, action: action);
  }
}