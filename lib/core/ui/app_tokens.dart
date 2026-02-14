import 'package:flutter/material.dart';

class AppTokens {
  // Spacing
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  // Radius
  static const double rSm = 12;
  static const double rMd = 14;
  static const double rLg = 18;
  static const double rXl = 24;

  // Max widths
  static const double maxWidth = 900;

  // Button
  static const double btnHeight = 48;

  // Animations
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 220);

  // Shadows (soft premium)
  static List<BoxShadow> softShadow(Color c) => [
        BoxShadow(
          color: c.withOpacity(0.08),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: c.withOpacity(0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
}
