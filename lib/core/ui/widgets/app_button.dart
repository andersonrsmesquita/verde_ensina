import 'package:flutter/material.dart';

enum _BtnKind { primary, secondary }

class AppButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final _BtnKind kind;

  const AppButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.kind = _BtnKind.primary,
  });

  factory AppButton.primary({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,
    bool loading = false,
  }) {
    return AppButton(
      key: key,
      text: label,
      icon: icon,
      onPressed: onPressed,
      loading: loading,
      kind: _BtnKind.primary,
    );
  }

  factory AppButton.secondary({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,
    bool loading = false,
  }) {
    return AppButton(
      key: key,
      text: label,
      icon: icon,
      onPressed: onPressed,
      loading: loading,
      kind: _BtnKind.secondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          );

    final style = kind == _BtnKind.primary
        ? ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          )
        : OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          );

    return SizedBox(
      width: double.infinity,
      child: kind == _BtnKind.primary
          ? ElevatedButton(
              onPressed: loading ? null : onPressed,
              style: style,
              child: child,
            )
          : OutlinedButton(
              onPressed: loading ? null : onPressed,
              style: style,
              child: child,
            ),
    );
  }
}
