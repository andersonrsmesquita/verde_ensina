import 'package:flutter/material.dart';

class AppMessenger {
  AppMessenger._();

  /// ✅ Use no MaterialApp.router(scaffoldMessengerKey: AppMessenger.key)
  static final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// ✅ Mantém compatibilidade com teu main.dart (AppMessenger.key)
  static GlobalKey<ScaffoldMessengerState> get key => _messengerKey;

  static void success(String msg) => _show(msg, bg: Colors.green.shade700);
  static void info(String msg) => _show(msg, bg: Colors.blue.shade700);

  /// ✅ TelaHome usa warn() -> agora existe
  static void warn(String msg) => _show(msg, bg: Colors.orange.shade800);

  static void error(String msg) => _show(msg, bg: Colors.red.shade700);

  static void _show(String msg, {required Color bg}) {
    final state = _messengerKey.currentState;
    if (state == null) return;

    state.clearSnackBars();
    state.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
