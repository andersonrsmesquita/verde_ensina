import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';

/// Central de botões padronizados (Excelência).
/// Mantém compatibilidade com chamadas novas e antigas.
class AppButtons {
  AppButtons._();

  static void _handlePress(VoidCallback? onPressed, bool loading) {
    if (onPressed == null || loading) return;
    HapticFeedback.lightImpact();
    onPressed();
  }

  static Widget _btnLoading(Color color) => SizedBox(
        width: AppTokens.iconSm,
        height: AppTokens.iconSm,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );

  // ============================================================
  // NOVOS (Compat com TelaLogin): primary / outlined / text
  // ============================================================

  static Widget primary({
    required Widget child,
    VoidCallback? onPressed,
    bool loading = false,
    bool fullWidth = true,
    ButtonStyle? style,
  }) {
    return _BaseButton(
      fullWidth: fullWidth,
      child: Builder(builder: (context) {
        final baseStyle = ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.md, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
        );

        return ElevatedButton(
          onPressed: loading ? null : () => _handlePress(onPressed, loading),
          style: style == null ? baseStyle : baseStyle.merge(style),
          child: AnimatedSwitcher(
            duration: AppTokens.animFast,
            child: loading ? _btnLoading(context.colors.onPrimary) : child,
          ),
        );
      }),
    );
  }

  static Widget outlined({
    required Widget child,
    VoidCallback? onPressed,
    bool loading = false,
    bool fullWidth = true,
    ButtonStyle? style,
  }) {
    return _BaseButton(
      fullWidth: fullWidth,
      child: Builder(builder: (context) {
        final baseStyle = OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.md, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
        );

        return OutlinedButton(
          onPressed: loading ? null : () => _handlePress(onPressed, loading),
          style: style == null ? baseStyle : baseStyle.merge(style),
          child: AnimatedSwitcher(
            duration: AppTokens.animFast,
            child: loading ? _btnLoading(context.colors.primary) : child,
          ),
        );
      }),
    );
  }

  static Widget text({
    required Widget child,
    VoidCallback? onPressed,
    bool loading = false,
    bool fullWidth = false,
    ButtonStyle? style,
  }) {
    return _BaseButton(
      fullWidth: fullWidth,
      child: Builder(builder: (context) {
        final baseStyle = TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sm, vertical: AppTokens.xs),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
        );

        return TextButton(
          onPressed: loading ? null : () => _handlePress(onPressed, loading),
          style: style == null ? baseStyle : baseStyle.merge(style),
          child: AnimatedSwitcher(
            duration: AppTokens.animFast,
            child: loading ? _btnLoading(context.colors.primary) : child,
          ),
        );
      }),
    );
  }

  // ============================================================
  // ANTIGOS (mantidos): elevatedIcon / outlinedIcon / textIcon
  // ============================================================

  static Widget elevatedIcon({
    required Widget icon,
    required Widget label,
    VoidCallback? onPressed,
    bool loading = false,
    bool fullWidth = false,
    ButtonStyle? style,
  }) {
    return _BaseButton(
      fullWidth: fullWidth,
      child: Builder(builder: (context) {
        final baseStyle = ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.md, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
        );

        return ElevatedButton.icon(
          onPressed: loading ? null : () => _handlePress(onPressed, loading),
          icon: AnimatedSwitcher(
            duration: AppTokens.animFast,
            child: loading ? _btnLoading(context.colors.onPrimary) : icon,
          ),
          label: DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.w800),
            child: label,
          ),
          style: style == null ? baseStyle : baseStyle.merge(style),
        );
      }),
    );
  }

  static Widget outlinedIcon({
    required Widget icon,
    required Widget label,
    VoidCallback? onPressed,
    bool loading = false,
    bool fullWidth = false,
    ButtonStyle? style,
  }) {
    return _BaseButton(
      fullWidth: fullWidth,
      child: Builder(builder: (context) {
        final baseStyle = OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.md, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
        );

        return OutlinedButton.icon(
          onPressed: loading ? null : () => _handlePress(onPressed, loading),
          icon: AnimatedSwitcher(
            duration: AppTokens.animFast,
            child: loading ? _btnLoading(context.colors.primary) : icon,
          ),
          label: DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.w800),
            child: label,
          ),
          style: style == null ? baseStyle : baseStyle.merge(style),
        );
      }),
    );
  }

  static Widget textIcon({
    required Widget icon,
    required Widget label,
    VoidCallback? onPressed,
    bool loading = false,
    bool fullWidth = false,
    ButtonStyle? style,
  }) {
    return _BaseButton(
      fullWidth: fullWidth,
      child: Builder(builder: (context) {
        final baseStyle = TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sm, vertical: AppTokens.xs),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
        );

        return TextButton.icon(
          onPressed: loading ? null : () => _handlePress(onPressed, loading),
          icon: AnimatedSwitcher(
            duration: AppTokens.animFast,
            child: loading ? _btnLoading(context.colors.primary) : icon,
          ),
          label: DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.w800),
            child: label,
          ),
          style: style == null ? baseStyle : baseStyle.merge(style),
        );
      }),
    );
  }
}

class _BaseButton extends StatelessWidget {
  final Widget child;
  final bool fullWidth;
  const _BaseButton({required this.child, required this.fullWidth});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: AppTokens.btnHeight,
      child: child,
    );
  }
}
