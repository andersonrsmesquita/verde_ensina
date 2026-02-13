import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null || trailing != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: t.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: t.textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: scheme.outlineVariant.withOpacity(0.6)),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
