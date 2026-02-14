import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';

class AppTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AppTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.rMd),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
                ),
                child: Icon(icon, size: 20),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.tt.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ] else if (onTap != null) ...[
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}
