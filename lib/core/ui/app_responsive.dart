import 'package:flutter/material.dart';
import 'app_tokens.dart';

/// Central de Responsividade do App.
/// Mantém as regras de adaptação de tela (Breakpoints e Grids) centralizadas.
class AppResponsive {
  AppResponsive._();

  // ==========================================
  // 1. FONTES DE VERDADE (BREAKPOINTS MATERIAL 3)
  // ==========================================
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;
  static const double desktopBreakpoint = 1440.0;

  // ==========================================
  // 2. LIMITADORES DE TELA
  // ==========================================
  static double maxWidthFor(double screenWidth) {
    return screenWidth > AppTokens.maxWidth ? AppTokens.maxWidth : screenWidth;
  }

  // ==========================================
  // 3. ESPAÇAMENTOS E PADDINGS
  // ==========================================
  static EdgeInsets pagePadding(double screenWidth) {
    final isMobile = screenWidth < mobileBreakpoint;
    return EdgeInsets.symmetric(
      horizontal: isMobile ? 16.0 : 24.0,
      vertical: 16.0,
    );
  }

  // ==========================================
  // 4. GRIDS INTELIGENTES
  // ==========================================
  /// Retorna o número ideal de colunas. Pode ser limitado por [maxColumns].
  static int gridColumns(double screenWidth, {int maxColumns = 3}) {
    int cols = 1;
    if (screenWidth >= tabletBreakpoint) {
      cols = maxColumns;
    } else if (screenWidth >= mobileBreakpoint) {
      cols = 2;
    }
    return cols > maxColumns ? maxColumns : cols;
  }
}

// ==========================================
// 5. WIDGET CONSTRUTOR RESPONSIVO (EXCELÊNCIA)
// ==========================================

/// Widget que desenha layouts diferentes dependendo do tamanho da tela.
/// Uso: ResponsiveBuilder(mobile: WidgetA(), desktop: WidgetB())
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= AppResponsive.tabletBreakpoint) {
          return desktop;
        } else if (width >= AppResponsive.mobileBreakpoint) {
          return tablet ?? mobile; // Se não tiver layout pra tablet, usa o mobile
        } else {
          return mobile;
        }
      },
    );
  }
}