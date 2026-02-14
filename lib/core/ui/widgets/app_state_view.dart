import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';
import 'app_button.dart';

/// Widget centralizado para exibir estados vazios, de erro ou carregamento.
/// Padrão de Excelência: Focado em UX clara, adaptável e com suporte semântico.
class AppStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  const AppStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.color,
  });

  // ==========================================
  // CONSTRUTORES SEMÂNTICOS (FACTORY)
  // ==========================================

  /// Estado vazio: Usado quando listas de canteiros, insumos ou registros estão vazias.
  factory AppStateView.empty({
    Key? key,
    String title = 'Nada por aqui ainda',
    String message =
        'Parece que você ainda não tem registros cadastrados nesta seção.',
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      AppStateView(
        key: key,
        icon: Icons.eco_outlined, // Ícone agronômico
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  /// Estado de erro: Usado quando falha a conexão ou ocorre erro de permissão no Firebase.
  factory AppStateView.error({
    Key? key,
    String title = 'Houve um imprevisto',
    String message =
        'Não conseguimos carregar os dados. Verifique sua conexão ou tente novamente.',
    String actionLabel = 'Tentar novamente',
    VoidCallback? onAction,
  }) =>
      AppStateView(
        key: key,
        icon: Icons.wifi_off_rounded,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
        color: const Color(0xFFD64545), // Cor de erro do Design System
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.text;

    // Cor baseada na semântica ou no tema primário
    final baseColor = color ?? colors.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.xxl),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 400), // Largura ideal para leitura
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Container do Ícone com Soft UI
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: baseColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTokens.rLg),
                  border: Border.all(color: baseColor.withOpacity(0.2)),
                ),
                child: Icon(icon, size: 40, color: baseColor),
              ),
              const SizedBox(height: AppTokens.xl),
              // Título com Peso Máximo
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: AppTokens.xs),
              // Mensagem de apoio
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppTokens.xl),
                // Botão de ação integrado ao Design System
                AppButton.primary(
                  label: actionLabel!,
                  onPressed: onAction,
                  fullWidth: false, // Centralizado e encolhido
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
