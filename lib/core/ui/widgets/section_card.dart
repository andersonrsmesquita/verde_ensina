import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';

/// Card de Seção padronizado para agrupar conteúdos relacionados.
/// Padrão de Excelência: Suporta sombras premium, títulos com ícones (trailing)
/// e adaptabilidade cromática para o Material 3.
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets? padding;
  final Color? color;

  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.trailing,
    this.padding,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Verifique se o seu arquivo 'app_context_ext.dart'
    // possui os getters 'colors' e 'text'.
    final colors = context.colors;
    final textTheme = context.text;

    return Container(
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(
          color: colors.outlineVariant.withOpacity(0.2),
        ),
        boxShadow: AppTokens.shadowSm(colors.shadow),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppTokens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null || trailing != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colors.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppTokens.xs),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: AppTokens.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
