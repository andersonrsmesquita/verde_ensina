import 'package:flutter/material.dart';

import '../app_tokens.dart';

/// Card de Módulo padronizado para navegação principal.
/// Padrão de Excelência: sombras suaves, tipografia hierárquica e tokens Material 3.
class AppModuleCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  /// Visual-only: quando true, mostra cadeado/estilo "bloqueado".
  final bool locked;

  /// Texto curto (ex: "PRO", "EM BREVE") para destacar status.
  final String? badge;

  const AppModuleCard({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.locked = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final iconBg = locked
        ? colors.surfaceContainerHighest
        : colors.primaryContainer.withOpacity(0.4);
    final iconFg = locked ? colors.onSurfaceVariant : colors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        boxShadow: AppTokens.shadowSm(colors.shadow),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.rLg),
          onTap: onTap,
          splashColor: colors.primary.withOpacity(0.10),
          highlightColor: colors.primary.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.all(AppTokens.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.rLg),
              border: Border.all(color: colors.outlineVariant.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                // Ícone
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(AppTokens.rMd),
                      ),
                      child: Icon(icon, color: iconFg, size: 24),
                    ),
                    if (locked)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: colors.outlineVariant.withOpacity(0.4)),
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: AppTokens.md),

                // Textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: colors.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            _BadgePill(text: badge!, locked: locked),
                          ],
                        ],
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

                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.outline.withOpacity(0.5),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final String text;
  final bool locked;

  const _BadgePill({required this.text, required this.locked});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg =
        locked ? cs.surfaceContainerHighest : cs.primary.withOpacity(0.12);
    final fg = locked ? cs.onSurfaceVariant : cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );
  }
}
