import 'package:flutter/material.dart';

class AppKeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;

  const AppKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = color ?? theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isBold ? textColor : textColor.withOpacity(0.7),
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
