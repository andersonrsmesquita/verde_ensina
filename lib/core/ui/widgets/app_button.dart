import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  /// primary: botão principal (verde)
  final bool primary;

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  }) : primary = true;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  }) : primary = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bg = primary ? scheme.primary : Colors.white;
    final fg = primary ? Colors.white : scheme.primary;
    final border = primary ? Colors.transparent : scheme.primary.withOpacity(0.35);

    final child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
        ],
        Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: primary ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: border),
          ),
        ),
        child: child,
      ),
    );
  }
}
