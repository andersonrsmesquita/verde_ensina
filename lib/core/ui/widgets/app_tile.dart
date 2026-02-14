import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';

/// Componente de item de lista padronizado (ListTile customizado).
/// Padrão de Excelência: Área de toque otimizada, feedback tátil e design Material 3.
class AppTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const AppTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.text;

    // Função para lidar com o clique e feedback
    void _handleTap() {
      if (onTap == null) return;
      HapticFeedback.lightImpact(); // Vibração premium ao tocar
      onTap!();
    }

    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.rMd),
      onTap: onTap != null ? _handleTap : null,
      splashColor: colors.primary.withOpacity(0.08),
      highlightColor: colors.primary.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.md,
          vertical: AppTokens.sm, // 12px
        ),
        child: Row(
          children: [
            // Container do Ícone (Soft UI)
            if (icon != null) ...[
              Container(
                width: 44, // Tamanho ideal para harmonia visual
                height: 44,
                decoration: BoxDecoration(
                  color: (iconColor ?? colors.primary).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTokens.rSm),
                  border: Border.all(
                    color: (iconColor ?? colors.primary).withOpacity(0.2),
                  ),
                ),
                child: Icon(
                  icon,
                  size: AppTokens.iconMd,
                  color: iconColor ?? colors.primary,
                ),
              ),
              const SizedBox(width: AppTokens.md),
            ],

            // Textos (Título e Subtítulo)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Elemento de fechamento (Trailing ou Chevron)
            if (trailing != null) ...[
              const SizedBox(width: AppTokens.sm),
              trailing!,
            ] else if (onTap != null) ...[
              const SizedBox(width: AppTokens.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.outline.withOpacity(0.5),
                size: AppTokens.iconMd,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
