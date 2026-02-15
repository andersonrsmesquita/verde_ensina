import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';
import 'app_button.dart';

enum AppViewState { loading, empty, error }

/// View centralizada para estados vazios, erro e carregamento.
/// ✅ Compatível com:
/// - AppStateView(state: AppViewState.loading)
/// - AppStateView(state: AppViewState.error, title/message/icon...)
/// - usos antigos com icon/title/message sem state
class AppStateView extends StatelessWidget {
  final AppViewState? state;

  final IconData? icon;
  final String? title;
  final String? message;

  final String? actionLabel;
  final VoidCallback? onAction;

  final Color? color;

  const AppStateView({
    super.key,
    this.state,
    this.icon,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.color,
  });

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
        state: AppViewState.empty,
        icon: Icons.eco_outlined,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      );

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
        state: AppViewState.error,
        icon: Icons.wifi_off_rounded,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
        color: const Color(0xFFD64545),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.text;

    if (state == AppViewState.loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: AppTokens.md),
              Text(
                title ?? 'Carregando...',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if ((message ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: AppTokens.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // defaults por estado
    IconData resolvedIcon = icon ??
        (state == AppViewState.error ? Icons.cloud_off : Icons.inbox_outlined);

    String resolvedTitle = title ??
        (state == AppViewState.error ? 'Falha ao carregar' : 'Nada por aqui');

    String resolvedMsg = message ??
        (state == AppViewState.error
            ? 'Não consegui carregar os dados agora. Tente novamente.'
            : 'Você ainda não tem registros nesta seção.');

    final baseColor =
        color ?? (state == AppViewState.error ? colors.error : colors.primary);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: baseColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTokens.rLg),
                  border: Border.all(color: baseColor.withOpacity(0.2)),
                ),
                child: Icon(resolvedIcon, size: 40, color: baseColor),
              ),
              const SizedBox(height: AppTokens.xl),
              Text(
                resolvedTitle,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: AppTokens.xs),
              Text(
                resolvedMsg,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppTokens.xl),
                AppButton.primary(
                  label: actionLabel!,
                  onPressed: onAction,
                  fullWidth: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
