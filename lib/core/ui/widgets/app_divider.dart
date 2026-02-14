import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../app_context_ext.dart';

/// Divisor padronizado para separação de seções e itens.
/// Padrão de Excelência: Suporta orientações horizontal/vertical e utiliza tokens de espaçamento.
class AppDivider extends StatelessWidget {
  final double? space;
  final double thickness;
  final bool isVertical;

  const AppDivider({
    super.key,
    this.space,
    this.thickness = 1.0,
    this.isVertical = false,
  });

  /// Construtor utilitário para divisores verticais (usado em Rows).
  factory AppDivider.vertical({double? width, double thickness = 1.0}) =>
      AppDivider(
        space: width,
        thickness: thickness,
        isVertical: true,
      );

  @override
  Widget build(BuildContext context) {
    // Define a cor de forma sutil para não sobrecarregar a UI
    final Color dividerColor = context.colors.outlineVariant.withOpacity(0.35);

    if (isVertical) {
      return VerticalDivider(
        width: space ?? AppTokens.md, // Padrão de 16px se não informado
        thickness: thickness,
        color: dividerColor,
      );
    }

    return Divider(
      height: space ?? AppTokens.md, // Padrão de 16px se não informado
      thickness: thickness,
      color: dividerColor,
    );
  }
}
