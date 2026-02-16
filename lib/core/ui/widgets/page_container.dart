// FILE: lib/core/ui/page_container.dart
import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../app_responsive.dart';

class PageContainer extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottom;
  final Widget? bottomBar;

  // 🛡️ Mudei o padrão para FALSE. Assim as listas nunca mais vão sumir.
  // Telas de formulário devem passar scroll: true explicitamente.
  final bool scroll;

  final bool center;
  final bool? centered;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool usePadding;
  final double? maxWidth;

  const PageContainer({
    super.key,
    this.title,
    this.subtitle,
    required this.body,
    this.actions,
    this.bottom,
    this.bottomBar,
    this.scroll = false, // Padrão agora é fixo (seguro para listas)
    bool center = false,
    this.centered,
    this.floatingActionButton,
    this.backgroundColor,
    this.usePadding = true,
    this.maxWidth,
  }) : center = centered ?? center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    final padding =
        usePadding ? AppResponsive.pagePadding(screenWidth) : EdgeInsets.zero;
    final effectiveMaxWidth = maxWidth ?? AppTokens.maxWidth;
    final effectiveBottom = bottomBar ?? bottom;

    Widget constrained = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
      child: body,
    );

    Widget pageBody;

    if (scroll) {
      pageBody = LayoutBuilder(
        builder: (context, constraints) {
          final minH = (constraints.maxHeight - padding.vertical);
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minH < 0 ? 0 : minH),
              child: center
                  ? Center(child: constrained)
                  : Align(alignment: Alignment.topCenter, child: constrained),
            ),
          );
        },
      );
    } else {
      pageBody = SizedBox.expand(
        child: Padding(
          padding: padding,
          child: center
              ? Center(child: constrained)
              : Align(alignment: Alignment.topCenter, child: constrained),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? colors.surface,
      appBar: title == null
          ? null
          : AppBar(
              centerTitle: true,
              actions: actions,
              scrolledUnderElevation: 0,
              backgroundColor: colors.surface,
              title: subtitle == null
                  ? Text(
                      title!,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title!,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
      body: SafeArea(child: pageBody),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: effectiveBottom == null
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
                    horizontal: AppTokens.md,
                    vertical: AppTokens.sm,
                  ),
                  // ✅ CORREÇÃO AQUI: heightFactor garante que o Center pegue a altura mínima e não a tela toda!
                  child: Center(
                    heightFactor: 1.0,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
                      child: effectiveBottom,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
