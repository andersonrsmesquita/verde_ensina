import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';

class AppBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = context.cs;

        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: EdgeInsets.only(
              left: AppTokens.md,
              right: AppTokens.md,
              top: 10,
              bottom: 12 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppTokens.rXl),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
              boxShadow: AppTokens.softShadow(cs.shadow),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                if (title != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        );
      },
    );
  }
}
