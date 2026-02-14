import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';

class AppDialogs {
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    bool danger = false,
  }) async {
    final cs = context.cs;

    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rLg)),
          title: Text(title, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelText),
            ),
            FilledButton(
              style: danger
                  ? FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError)
                  : null,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return res ?? false;
  }

  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
    String okText = 'OK',
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rLg)),
        title: Text(title, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(okText),
          ),
        ],
      ),
    );
  }
}
