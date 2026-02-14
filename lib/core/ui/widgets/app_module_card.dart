import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';

/// Card de Módulo padronizado para navegação principal.
/// Padrão de Excelência: Utiliza sombras suaves, tipografia hierárquica e tokens Material 3.
class AppModuleCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const AppModuleCard({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.text;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        boxShadow:
            AppTokens.shadowSm(colors.shadow), // Aplica nossa sombra premium
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.rLg),
          onTap: onTap,
          splashColor: colors.primary.withOpacity(0.1),
          highlightColor: colors.primary.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.all(AppTokens.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.rLg),
              border: Border.all(color: colors.outlineVariant.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                // Container do Ícone com Soft UI
                Container(
                  width: AppTokens.xxl, // 32px + padding interno
                  height: AppTokens.xxl,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(AppTokens.rMd),
                  ),
                  child: Icon(
                    icon,
                    color: colors.primary,
                    size: AppTokens.iconMd,
                  ),
                ),
                const SizedBox(width: AppTokens.md),
                // Textos Hierárquicos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colors.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Indicador de Navegação
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.outline.withOpacity(0.5),
                  size: AppTokens.iconMd,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
