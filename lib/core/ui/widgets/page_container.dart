import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_responsive.dart';
import '../app_context_ext.dart';

class PageContainer extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottom;
  final bool scroll;
  final bool center;
  final Widget? floatingActionButton;

  const PageContainer({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.bottom,
    this.scroll = true,
    this.center = true,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final padding = AppResponsive.pagePadding(context.w);

    Widget content = body;

    if (scroll) {
      content = SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: content,
      );
    }

    content = Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTokens.maxWidth),
          child: content,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: title == null
          ? null
          : AppBar(
              title: Text(title!),
              actions: actions,
            ),
      body: content,
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(AppTokens.md),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                    top: BorderSide(color: cs.outlineVariant.withOpacity(0.35)),
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: AppTokens.maxWidth),
                    child: bottom!,
                  ),
                ),
              ),
            ),
      floatingActionButton: floatingActionButton,
    );
  }
}
