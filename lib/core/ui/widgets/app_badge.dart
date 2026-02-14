import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_colors.dart'; // Adicionado para puxar a paleta semântica
import '../app_context_ext.dart';

/// Componente de "Pílula" (Badge) para exibir status, tags ou categorias.
/// Padrão de Excelência: Utiliza "Soft UI" (Fundo claro, texto destacado) e construtores semânticos.
class AppBadge extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  final bool
      isSolid; // Permite trocar entre fundo suave (padrão) e fundo sólido

  const AppBadge({
    super.key,
    required this.text,
    this.color,
    this.icon,
    this.isSolid = false,
  });

  // ==========================================
  // CONSTRUTORES NOMEADOS (SEMÂNTICA)
  // ==========================================

  /// Badge Verde (Ex: "Livre", "Concluído", "Ativo")
  factory AppBadge.success(String text,
          {IconData? icon, bool isSolid = false}) =>
      AppBadge(
          text: text,
          color: AppColors.success,
          icon: icon ?? Icons.check_circle_outline,
          isSolid: isSolid);

  /// Badge Vermelho (Ex: "Ocupado", "Praga", "Perda")
  factory AppBadge.error(String text, {IconData? icon, bool isSolid = false}) =>
      AppBadge(
          text: text,
          color: AppColors.error,
          icon: icon ?? Icons.error_outline,
          isSolid: isSolid);

  /// Badge Laranja (Ex: "Manutenção", "Fora de Época")
  factory AppBadge.warning(String text,
          {IconData? icon, bool isSolid = false}) =>
      AppBadge(
          text: text,
          color: AppColors.warning,
          icon: icon ?? Icons.warning_amber_outlined,
          isSolid: isSolid);

  /// Badge Azul (Ex: "Irrigação", "Informativo")
  factory AppBadge.info(String text, {IconData? icon, bool isSolid = false}) =>
      AppBadge(
          text: text,
          color: AppColors.info,
          icon: icon ?? Icons.info_outline,
          isSolid: isSolid);

  @override
  Widget build(BuildContext context) {
    // Usando as extensões que atualizamos no passo anterior
    final themeColors = context.colors;

    // Cor base: a cor passada por parâmetro ou a cor primária do tema
    final baseColor = color ?? themeColors.primary;

    // Lógica do Soft UI:
    // Se for sólido, fundo = cor principal, texto = branco.
    // Se for suave, fundo = 12% opacidade, texto = cor principal.
    final bg = isSolid ? baseColor : baseColor.withOpacity(0.12);
    final fg = isSolid ? Colors.white : baseColor;
    final borderColor =
        isSolid ? Colors.transparent : baseColor.withOpacity(0.3);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sm, // 12px
        vertical: AppTokens.xxs, // 4px
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            BorderRadius.circular(AppTokens.rPill), // Borda infinita de pílula
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppTokens.iconSm, color: fg),
            const SizedBox(width: AppTokens.xs), // 8px de espaçamento
          ],
          Text(
            text,
            style: context.text.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              letterSpacing:
                  0.3, // Leve espaçamento entre as letras dá um ar sofisticado
            ),
          ),
        ],
      ),
    );
  }
}
