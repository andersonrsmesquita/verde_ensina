import 'dart:async';

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
  /// ✅ Compat:
  /// - suporte a onConfirm (async) para telas que chamam "AppDialogs.confirm(... onConfirm: ...)"
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    bool isDanger = false,

    /// ✅ novo: callback executado ao confirmar (pode ser async)
    FutureOr<void> Function()? onConfirm,

    /// ✅ alias (caso alguma tela use outro nome)
    FutureOr<void> Function()? onConfirmed,
  }) async {
    final colors = context.colors;

    // Feedback tátil ao abrir o diálogo
    HapticFeedback.mediumImpact();

    final action = onConfirm ?? onConfirmed;

    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Força a interação do usuário
      builder: (ctx) {
        bool busy = false;

        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> handleConfirm() async {
              if (busy) return;

              // Se não tem callback, é só fechar retornando true
              if (action == null) {
                if (isDanger) HapticFeedback.heavyImpact();
                Navigator.of(ctx).pop(true);
                return;
              }

              setState(() => busy = true);

              try {
                if (isDanger) HapticFeedback.heavyImpact();
                await Future<void>.sync(() => action());
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } catch (e) {
                // Não fecha: deixa o usuário tentar de novo
                setState(() => busy = false);

                // Feedback rápido (sem depender do AppMessenger)
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro: $e')),
                  );
                }
              }
            }

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
                  onPressed: busy ? null : () => Navigator.of(ctx).pop(false),
                  child: Text(
                    cancelText,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isDanger ? AppColors.error : colors.primary,
                    foregroundColor: isDanger ? Colors.white : colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                    ),
                  ),
                  onPressed: busy ? null : handleConfirm,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(confirmText),
                ),
              ],
            );
          },
        );
      },
    );

    return res ?? false;
  }

  /// Diálogo Informativo (Aviso Simples).
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
