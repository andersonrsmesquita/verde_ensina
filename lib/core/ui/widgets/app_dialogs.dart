import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';
import '../app_colors.dart';

/// Central de Diálogos e Alertas do ecossistema Verde Ensina.
/// Padrão de Excelência: Focado em segurança de dados e UX responsiva.
class AppDialogs {
  // Construtor privado para evitar instanciação.
  AppDialogs._();

  /// Diálogo de Confirmação (Sim/Não).
  /// Essencial para ações destrutivas como excluir registros de custos ou histórico.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    bool isDanger = false,
  }) async {
    final colors = context.colors;

    // Feedback tátil ao abrir o diálogo
    HapticFeedback.mediumImpact();

    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Força a interação do usuário
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rLg),
          ),
          title: Text(
            title,
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDanger ? AppColors.error : colors.onSurface,
            ),
          ),
          content: Text(
            message,
            style: context.text.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: AppTokens.md,
            vertical: AppTokens.sm,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                cancelText,
                style: TextStyle(
                    color: colors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDanger ? AppColors.error : colors.primary,
                foregroundColor: isDanger ? Colors.white : colors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.rMd),
                ),
              ),
              onPressed: () {
                if (isDanger) HapticFeedback.heavyImpact();
                Navigator.of(ctx).pop(true);
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return res ?? false;
  }

  /// Diálogo Informativo (Aviso Simples).
  /// Útil para explicar regras de calagem ou adubação Organo 15[cite: 6].
  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
    String okText = 'Entendi',
  }) async {
    final colors = context.colors;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rLg),
        ),
        title: Text(
          title,
          style: context.text.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: colors.onSurface,
          ),
        ),
        content: Text(
          message,
          style:
              context.text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.rMd),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(okText),
          ),
        ],
      ),
    );
  }
}
