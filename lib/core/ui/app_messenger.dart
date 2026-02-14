import 'package:flutter/material.dart';

class AppMessenger {
  AppMessenger._();

  /// Use no MaterialApp: scaffoldMessengerKey: AppMessenger.key
  static final GlobalKey<ScaffoldMessengerState> key =
      GlobalKey<ScaffoldMessengerState>();

  static void _show(
    String message, {
    required Color backgroundColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = key.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        duration: duration,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void success(String message) {
    _show(
      message,
      backgroundColor: const Color(0xFF1B8A5A),
      icon: Icons.check_circle_outline,
    );
  }

  static void info(String message) {
    _show(
      message,
      backgroundColor: const Color(0xFF2D6CDF),
      icon: Icons.info_outline,
    );
  }

  static void warn(String message) {
    _show(
      message,
      backgroundColor: const Color(0xFFE28A00),
      icon: Icons.warning_amber_outlined,
    );
  }

  static void error(String message) {
    _show(
      message,
      backgroundColor: const Color(0xFFD64545),
      icon: Icons.error_outline,
    );
  }

  /// Compat: telas antigas chamam `AppMessenger.show("...")`.
  ///
  /// Heurística simples:
  /// - começa com "✅" => success
  /// - começa com "⚠" => warn
  /// - começa com "❌" => error
  /// - senão => info
  static void show(String message) {
    final trimmed = message.trimLeft();
    if (trimmed.startsWith('✅')) return success(message);
    if (trimmed.startsWith('⚠')) return warn(message);
    if (trimmed.startsWith('❌')) return error(message);
    return info(message);
  }
}
