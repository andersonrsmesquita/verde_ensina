import 'package:flutter/material.dart';

class AppMessenger {
  AppMessenger._();

  static final GlobalKey<ScaffoldMessengerState> key =
      GlobalKey<ScaffoldMessengerState>();

  static void showSnack(
    String msg, {
    Color? cor,
    Duration duration = const Duration(seconds: 2),
  }) {
    final messenger = key.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: cor ?? Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  static void success(String msg) => showSnack(msg, cor: Colors.green);
  static void error(String msg) => showSnack(msg, cor: Colors.red);
  static void warning(String msg) => showSnack(msg, cor: Colors.orange);
  static void info(String msg) => showSnack(msg, cor: Colors.black87);
}
