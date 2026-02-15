import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../app_responsive.dart';

/// Esqueleto mestre de páginas (Excelência SaaS).
class PageContainer extends StatelessWidget {
  final String? title;

  /// ✅ novo: subtítulo abaixo do título
  final String? subtitle;

  final Widget body;
  final List<Widget>? actions;

  /// ✅ novo: bottomBar (mantém compat com telas novas)
  final Widget? bottomBar;

  /// Alias compatível com telas antigas que usam "bottom"
  final Widget? bottom;

  final bool scroll;

  /// Centro do conteúdo (geralmente usado em login/onboarding)
  final bool center;

  /// Alias compatível com telas antigas que usam "centered"
  final bool? centered;

  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool usePadding;

  /// Permite reduzir largura (ex: login com 520)
  final double? maxWidth;

  const PageContainer({
    super.key,
    this.title,
    this.subtitle,
    required this.body,
    this.actions,
    this.bottomBar,
    this.bottom,
    this.scroll = true,
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

    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
      child: body,
    );

    if (scroll) {
      content = LayoutBuilder(
        builder: (context, constraints) {
          final minH = (constraints.maxHeight - padding.vertical);
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minH < 0 ? 0 : minH),
              child: center ? Center(child: content) : content,
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

    content = Center(child: content);

    final effectiveBottom = bottomBar ?? bottom;

    return Scaffold(
      backgroundColor: backgroundColor ?? colors.surface,
      appBar: title == null
          ? null
          : AppBar(
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
              centerTitle: true,
              actions: actions,
              scrolledUnderElevation: 0,
              backgroundColor: colors.surface,
            ),
      body: content,
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
                  child: Center(
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
