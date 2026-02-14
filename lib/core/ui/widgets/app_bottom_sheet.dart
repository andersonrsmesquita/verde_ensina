import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';

/// Utilitário para exibição de Bottom Sheets flutuantes padronizados.
/// Padrão de Excelência: Protegido contra quebras por teclado,
/// previne overflow vertical e adapta-se automaticamente para Tablets/Web.
class AppBottomSheet {
  // Impede instanciação acidental
  AppBottomSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool isScrollControlled = true,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      backgroundColor:
          Colors.transparent, // Transparente para usar o nosso Card customizado
      elevation: 0,
      builder: (ctx) {
        final colors = ctx.colors;

        return SafeArea(
          top:
              false, // Permite que a tela aproveite o espaço máximo se necessário
          child: Padding(
            // Empurra o modal para cima automaticamente e performaticamente quando o teclado abrir
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment
                  .center, // Centraliza no eixo horizontal (para tablets)
              children: [
                Flexible(
                  child: Container(
                    margin:
                        const EdgeInsets.all(AppTokens.sm), // Fica flutuante
                    constraints: const BoxConstraints(
                        maxWidth:
                            600), // Trava a largura para não ficar bizarro no iPad/PC
                    padding: const EdgeInsets.only(
                      left: AppTokens.md,
                      right: AppTokens.md,
                      top: AppTokens.sm,
                      bottom: AppTokens.md,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(
                          AppTokens.rXl), // Curvatura M3 grande
                      border: Border.all(
                          color: colors.outlineVariant.withOpacity(0.35)),
                      boxShadow: AppTokens.shadowLg(
                          colors.shadow), // Nossa sombra Premium
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize
                          .min, // Encolhe para o tamanho do conteúdo
                      children: [
                        // Puxador (Drag Handle) moderno
                        Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colors.outlineVariant.withOpacity(0.55),
                            borderRadius:
                                BorderRadius.circular(AppTokens.rPill),
                          ),
                        ),
                        if (title != null) ...[
                          const SizedBox(height: AppTokens.sm),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              title,
                              style: ctx.text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppTokens.md),
                        // O Flexible aqui garante que o conteúdo não exploda a tela se for muito longo
                        Flexible(child: child),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
