import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';

enum AppButtonKind { primary, secondary, ghost, danger }

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

  factory AppButton.primary({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,
    bool loading = false,
  }) =>
      AppButton(
        key: key,
        label: label,
        icon: icon,
        onPressed: onPressed,
        loading: loading,
        kind: AppButtonKind.primary,
      );

  factory AppButton.secondary({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,
    bool loading = false,
  }) =>
      AppButton(
        key: key,
        label: label,
        icon: icon,
        onPressed: onPressed,
        loading: loading,
        kind: AppButtonKind.secondary,
      );

  factory AppButton.ghost({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,
    bool loading = false,
  }) =>
      AppButton(
        key: key,
        label: label,
        icon: icon,
        onPressed: onPressed,
        loading: loading,
        kind: AppButtonKind.ghost,
      );

  factory AppButton.danger({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,
    bool loading = false,
  }) =>
      AppButton(
        key: key,
        label: label,
        icon: icon,
        onPressed: onPressed,
        loading: loading,
        kind: AppButtonKind.danger,
      );

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    final bool disabled = onPressed == null || loading;

    final Widget inner = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color:
                  kind == AppButtonKind.secondary ? cs.primary : cs.onPrimary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 10),
              ],
              Text(label),
            ],
          );

    final Widget btn;
    switch (kind) {
      case AppButtonKind.primary:
        btn = FilledButton(
          onPressed: disabled ? null : onPressed,
          child: inner,
        );
        break;
      case AppButtonKind.secondary:
        btn = OutlinedButton(
          onPressed: disabled ? null : onPressed,
          child: inner,
        );
        break;
      case AppButtonKind.ghost:
        btn = TextButton(
          onPressed: disabled ? null : onPressed,
          child: inner,
        );
        break;
      case AppButtonKind.danger:
        btn = FilledButton(
          onPressed: disabled ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            minimumSize: const Size.fromHeight(AppTokens.btnHeight),
          ),
          child: inner,
        );
        break;
    }

    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
