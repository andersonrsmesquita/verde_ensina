// FILE: lib/core/ui/widgets/section_card.dart
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_tokens.dart';

class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final Widget? trailing;

  /// Quando true, o [child] será colocado dentro de um [Expanded] para
  /// suportar widgets scrolláveis (ex: ListView) dentro do card.
  ///
  /// Use APENAS quando o SectionCard estiver em um pai com altura limitada
  /// (ex: dentro de Expanded/SizedBox/altura fixa).
  final bool expandChild;

  final EdgeInsets? padding;
  final Color? color;

  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.trailing,
    this.expandChild = false,
    this.padding,
    this.color,
  });

  bool _isScrollable(Widget w) => w is ScrollView;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final canExpand = constraints.hasBoundedHeight;
        final shouldExpand =
            (expandChild || (canExpand && _isScrollable(child)));

        Widget bodyChild = child;

        // Se alguém passar Expanded/Flexible como child e NÃO houver altura limitada,
        // isso quebra layout. Aqui desembrulha.
        if (!canExpand && bodyChild is Flexible) {
          bodyChild = (bodyChild as Flexible).child;
        }

        if (shouldExpand && canExpand) {
          if (bodyChild is! Flexible) {
            bodyChild = Expanded(child: bodyChild);
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: color ?? cs.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: AppTokens.shadowSm(AppColors.shadow),
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppTokens.md),
            child: Column(
              mainAxisSize: shouldExpand ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                  const SizedBox(height: AppTokens.sm),
                ],
                bodyChild,
              ],
            ),
          ),
        );
      },
    );
  }
}
