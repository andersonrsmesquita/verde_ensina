import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_responsive.dart';
import '../app_context_ext.dart';

/// O esqueleto mestre de todas as páginas do aplicativo.
/// Padrão de Excelência: Garante largura máxima (Desktop), scroll controlado,
/// e alinhamento perfeito de barras de ação e navegação.
class PageContainer extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottom;
  final bool scroll;
  final bool center;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  const PageContainer({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.bottom,
    this.scroll = true,
    this.center = true,
    this.floatingActionButton,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final screenWidth = context.screenWidth;
    final padding = AppResponsive.pagePadding(screenWidth);

    // Constrói o conteúdo base com restrição de largura máxima (PC/Tablet)
    Widget content = body;

    // Gerencia o scroll e o alinhamento vertical
    if (scroll) {
      content = LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - padding.vertical,
                maxWidth: AppTokens.maxWidth,
              ),
              child: IntrinsicHeight(
                child: center ? Center(child: content) : content,
              ),
            ),
          );
        },
      );
    } else {
      content = Padding(
        padding: padding,
        child: center ? Center(child: content) : content,
      );
    }

    // Aplica a restrição de largura máxima global para o conteúdo do body
    content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTokens.maxWidth),
        child: content,
      ),
    );

    return Scaffold(
      backgroundColor: backgroundColor ?? colors.background,
      appBar: title == null
          ? null
          : AppBar(
              title: Text(title!),
              actions: actions,
              surfaceTintColor:
                  Colors.transparent, // Mantém a cor sólida na rolagem
              elevation: 0,
            ),
      body: content,
      // Barra de ação inferior (Ex: Botão de Salvar)
      bottomNavigationBar: bottom == null
          ? null
          : Container(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top:
                      BorderSide(color: colors.outlineVariant.withOpacity(0.3)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.md),
                  child: Row(
                    // Usamos Row para permitir que o Center funcione sem erro de parâmetro
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: AppTokens.maxWidth),
                          child: bottom!,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: floatingActionButton,
    );
  }
}
