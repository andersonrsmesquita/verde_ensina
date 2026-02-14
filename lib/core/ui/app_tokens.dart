import 'package:flutter/material.dart';

/// Central de Tokens de Design do Aplicativo (Design System).
/// Define espaçamentos, bordas, sombras e durações padronizadas.
/// Utiliza um sistema de grid de 4px/8px para consistência visual.
class AppTokens {
  // Impede a instanciação acidental da classe
  AppTokens._();

  // ==========================================
  // 1. ESPAÇAMENTOS (Grid de 4px / 8px)
  // ==========================================
  static const double xxs = 4.0;
  static const double xs  = 8.0;
  static const double sm  = 12.0;
  static const double md  = 16.0;
  static const double lg  = 20.0; // ou 24.0 (múltiplo de 8)
  static const double xl  = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // ==========================================
  // 2. ARREDONDAMENTOS (Bordas - Material 3)
  // ==========================================
  static const double rXs = 8.0;
  static const double rSm = 12.0;
  static const double rMd = 16.0; // Ajustado para o padrão M3
  static const double rLg = 24.0; // Excelente para modais curvos e botões grandes
  static const double rXl = 32.0;
  static const double rPill = 999.0; // Borda totalmente arredondada (Formato de pílula)

  // ==========================================
  // 3. TAMANHOS DE COMPONENTES E ÍCONES
  // ==========================================
  static const double maxWidth = 900.0;
  
  static const double btnHeight = 48.0;
  static const double btnHeightSm = 36.0; // Botões menores (ex: tags)
  
  static const double iconSm = 18.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;

  // ==========================================
  // 4. ANIMAÇÕES (Durações e Curvas)
  // ==========================================
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 350);
  
  // Curva padrão para movimentos suaves (Acelera e desacelera)
  static const Curve curveDefault = Curves.easeInOut;

  // ==========================================
  // 5. SOMBRAS (Elevações Premium)
  // ==========================================

  /// Sombra sutil para Cards do dia a dia e itens de lista.
  static List<BoxShadow> shadowSm(Color c) => [
        BoxShadow(
          color: c.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// Sombra "Premium" profunda para pop-ups, bottom sheets e modais.
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