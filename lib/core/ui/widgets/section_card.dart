import 'package:flutter/material.dart';
import '../app_tokens.dart';

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
    // ✅ Padronização para Flutter Nativo
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(
          color: colors.outlineVariant.withOpacity(0.2),
        ),
        // Se AppTokens.shadowSm não for estático, ajuste aqui.
        // Assumindo que é uma lista de BoxShadow:
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
