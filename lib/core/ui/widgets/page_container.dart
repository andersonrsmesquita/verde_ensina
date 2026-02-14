import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../app_responsive.dart'; // Mantido se você usa para paddings específicos

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

  // Novo: Permite remover o padding padrão se necessário (ex: mapas, imagens full)
  final bool usePadding;

  const PageContainer({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.bottom,
    this.scroll = true,
    this.center =
        false, // Mudado para false por padrão (alinhamento topo é mais comum)
    this.floatingActionButton,
    this.backgroundColor,
    this.usePadding = true,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Padronização Nativa (Sem dependência de context.colors quebrada)
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Padding responsivo inteligente
    final padding =
        usePadding ? AppResponsive.pagePadding(screenWidth) : EdgeInsets.zero;

    // 1. Conteúdo Base com Restrições de Largura (Para Desktop/Tablet)
    Widget content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppTokens.maxWidth),
      child: body,
    );

    // 2. Gerenciamento de Scroll e Alinhamento
    if (scroll) {
      content = LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // Garante que o conteúdo tenha pelo menos a altura da tela
                minHeight: constraints.maxHeight - padding.vertical,
              ),
              child: center
                  ? Center(child: content)
                  : content, // Se não for center, alinha ao topo (padrão)
            ),
          );
        },
      );
    } else {
      // Sem scroll: Apenas padding e alinhamento
      content = Padding(
        padding: padding,
        child: center ? Center(child: content) : content,
      );
    }

    // 3. Centralização Global (Para telas muito largas)
    content = Center(child: content);

    return Scaffold(
      backgroundColor: backgroundColor ??
          colors.surface, // Usa surface por padrão (Material 3)
      appBar: title == null
          ? null
          : AppBar(
              title: Text(
                title!,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              centerTitle: true, // Padrão elegante
              actions: actions,
              scrolledUnderElevation: 0, // Evita mudança brusca de cor
              backgroundColor: colors.surface,
            ),
      body: content,
      floatingActionButton: floatingActionButton,

      // 4. Barra Inferior Elevada (Design Premium)
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
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.md, vertical: AppTokens.sm),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: AppTokens.maxWidth),
                      child: bottom!,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
