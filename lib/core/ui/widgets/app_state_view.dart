import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';
import 'app_button.dart';

class AppStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  factory AppStateView.empty({
    Key? key,
    String title = 'Nada por aqui',
    String message = 'Não encontrei nenhum registro.',
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      AppStateView(
        key: key,
        icon: Icons.inbox_outlined,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  factory AppStateView.error({
    Key? key,
    String title = 'Deu ruim',
    String message = 'Ocorreu um erro ao carregar os dados.',
    String actionLabel = 'Tentar novamente',
    VoidCallback? onAction,
  }) =>
      AppStateView(
        key: key,
        icon: Icons.error_outline_rounded,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
                ),
                child: Icon(icon, size: 30, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text(title, style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                AppButton.primary(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
