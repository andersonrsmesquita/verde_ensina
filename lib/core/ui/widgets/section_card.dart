import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../app_context_ext.dart';

class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(AppTokens.md),
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null || trailing != null) ...[
              Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  if (trailing != null) trailing!,
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
