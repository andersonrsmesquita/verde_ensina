import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';

class AppBadge extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.text,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final bg = color ?? cs.primaryContainer;
    final fg = color != null ? Colors.white : cs.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.rXl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(text, style: context.tt.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
