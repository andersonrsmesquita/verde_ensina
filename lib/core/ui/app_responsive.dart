import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppResponsive {
  static double maxWidthFor(double screenWidth) {
    return screenWidth > AppTokens.maxWidth ? AppTokens.maxWidth : screenWidth;
  }

  static EdgeInsets pagePadding(double screenWidth) {
    final isMobile = screenWidth < 600;
    return EdgeInsets.symmetric(
      horizontal: isMobile ? 16 : 24,
      vertical: 16,
    );
  }

  static int gridColumns(double screenWidth) {
    if (screenWidth >= 1100) return 3;
    if (screenWidth >= 720) return 2;
    return 1;
  }
}
