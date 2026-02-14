import 'package:flutter/material.dart';

extension AppContextExt on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get cs => theme.colorScheme;
  TextTheme get tt => theme.textTheme;
  MediaQueryData get mq => MediaQuery.of(this);

  double get w => mq.size.width;
  double get h => mq.size.height;

  bool get isMobile => w < 600;
  bool get isTablet => w >= 600 && w < 1024;
  bool get isDesktop => w >= 1024;

  EdgeInsets get pagePadding => EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 16,
      );

  void snack(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(this);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? cs.error : cs.inverseSurface,
      ),
    );
  }
}
