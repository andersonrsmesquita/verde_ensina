import 'package:flutter/material.dart';

/// Central de Tokens de Design do Aplicativo (Design System).
class AppTokens {
  AppTokens._();

  // ==========================================
  // 1. ESPAÇAMENTOS
  // ==========================================
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // ==========================================
  // 2. ARREDONDAMENTOS (COMPATIBILIDADE TOTAL)
  // ==========================================

  // Nomes novos (Usados na Tela de Irrigação)
  static const double radiusXs = 8.0;
  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 32.0;
  static const double radiusPill = 999.0;

  // Nomes antigos (Usados no resto do App - Aliases)
  static const double rXs = radiusXs;
  static const double rSm = radiusSm;
  static const double rMd = radiusMd;
  static const double rLg = radiusLg;
  static const double rXl = radiusXl;
  static const double rPill = radiusPill;

  // ==========================================
  // 3. TAMANHOS
  // ==========================================
  static const double maxWidth = 900.0;
  static const double btnHeight = 48.0;
  static const double btnHeightSm = 36.0;
  static const double iconSm = 18.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;

  // ==========================================
  // 4. ANIMAÇÕES
  // ==========================================
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 350);
  static const Curve curveDefault = Curves.easeInOut;

  // ==========================================
  // 5. SOMBRAS
  // ==========================================
  static List<BoxShadow> shadowSm(Color c) => [
        BoxShadow(
          color: c.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> shadowLg(Color c) => [
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
