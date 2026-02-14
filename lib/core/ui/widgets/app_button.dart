import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para o HapticFeedback

import '../app_tokens.dart';
import '../app_context_ext.dart';
import '../app_colors.dart';

enum AppButtonKind { primary, secondary, ghost, danger }

/// Componente de botão padronizado do ecossistema Verde Ensina.
/// Suporta estados de carregamento, ícones e diferentes variantes semânticas.
class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final AppButtonKind kind;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.kind = AppButtonKind.primary,
    this.fullWidth = true,
  });

  // ==========================================
  // CONSTRUTORES DE FÁBRICA (FACTORY)
  // ==========================================

  factory AppButton.primary({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,
    bool loading = false,
    bool fullWidth = true,
  }) =>
      AppButton(
        key: key,
        label: label,
        icon: icon,
        onPressed: onPressed,
        loading: loading,
        kind: AppButtonKind.primary,
        fullWidth: fullWidth,
      );

  factory AppButton.secondary({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,
    bool loading = false,
    bool fullWidth = true,
  }) =>
      AppButton(
        key: key,
        label: label,
        icon: icon,
        onPressed: onPressed,
        loading: loading,
        kind: AppButtonKind.secondary,
        fullWidth: fullWidth,
      );

  factory AppButton.ghost({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,
    bool loading = false,
    bool fullWidth = true,
  }) =>
      AppButton(
        key: key,
        label: label,
        icon: icon,
        onPressed: onPressed,
        loading: loading,
        kind: AppButtonKind.ghost,
        fullWidth: fullWidth,
      );

  factory AppButton.danger({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,
    bool loading = false,
    bool fullWidth = true,
  }) =>
      AppButton(
        key: key,
        label: label,
        icon: icon,
        onPressed: onPressed,
        loading: loading,
        kind: AppButtonKind.danger,
        fullWidth: fullWidth,
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bool isDisabled = onPressed == null || loading;

    // Função interna para lidar com o clique e feedback tátil
    void _handlePress() {
      if (isDisabled) return;
      HapticFeedback.lightImpact(); // Pequena vibração ao tocar (Premium Feel)
      onPressed?.call();
    }

    // Conteúdo interno do botão (Lida com o estado de Loading)
    final Widget content = AnimatedSwitcher(
      duration: AppTokens.animFast,
      child: loading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: AppTokens.iconSm,
              height: AppTokens.iconSm,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: kind == AppButtonKind.secondary
                    ? colors.primary
                    : colors.onPrimary,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AppTokens.iconSm),
                  const SizedBox(width: AppTokens.xs),
                ],
                Text(label),
              ],
            ),
    );

    // Variantes de estilo baseadas no 'kind'
    final Widget btn;
    switch (kind) {
      case AppButtonKind.primary:
        btn = FilledButton(
          onPressed: isDisabled ? null : _handlePress,
          child: content,
        );
        break;
      case AppButtonKind.secondary:
        btn = OutlinedButton(
          onPressed: isDisabled ? null : _handlePress,
          child: content,
        );
        break;
      case AppButtonKind.ghost:
        btn = TextButton(
          onPressed: isDisabled ? null : _handlePress,
          child: content,
        );
        break;
      case AppButtonKind.danger:
        btn = FilledButton(
          onPressed: isDisabled ? null : _handlePress,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: content,
        );
        break;
    }

    // Retorna o botão com largura fixa (AppTokens.btnHeight) e largura opcional total
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: AppTokens.btnHeight,
      child: btn,
    );
  }
}
